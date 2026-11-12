{
  config,
  pkgs,
  lib,
  modulesPath,
  ...
}:
{
  imports = [
    (modulesPath + "/virtualisation/amazon-image.nix")
  ];

  system.stateVersion = "26.05";

  # CloudFront reaches the origin on this port (matches var.app_port default).
  networking.firewall.allowedTCPPorts = [ 9000 ];

  # ---------------------------------------------------------------------------
  # era_ts data disk: a plain ext4 EBS volume.
  #
  # Terraform creates a gp3 volume and attaches it as /dev/sdf, which a
  # Nitro-based instance exposes as /dev/nvme1n1 (the root volume is
  # /dev/nvme0n1). `autoFormat` formats the empty volume on first boot and
  # mounts it on every subsequent boot. This replaces the old
  # ZeroFS -> NBD -> ZFS stack with a normal Linux filesystem on EBS.
  # ---------------------------------------------------------------------------
  fileSystems."/var/lib/climate-changed/era_ts" = {
    device = "/dev/nvme1n1";
    fsType = "ext4";
    autoFormat = true;
    options = [ "noatime" ];
  };

  environment.systemPackages = [
    pkgs.htop
    pkgs.sysstat
  ];

  # /var/lib/climate-changed must exist before the era_ts filesystem mounts
  # under it.
  systemd.tmpfiles.rules = [
    "d /var/lib/climate-changed 0755 root root -"
  ];

  # ---------------------------------------------------------------------------
  # climate-changed application service
  #
  # The uberjar is deployed manually (see `make deploy`) rather than built as a
  # nix package. Deployment uploads a timestamped jar to /var/lib/climate-changed
  # and repoints the `production.jar` symlink, which this unit executes.
  #
  # era_ts is the persistent EBS mount; the app must not start before it.
  # ---------------------------------------------------------------------------
  systemd.services.climate-changed = {
    description = "climate-changed web application";
    wantedBy = [ "multi-user.target" ];
    after = [
      "network.target"
      "local-fs.target"
    ];

    environment = {
      PORT = "9000";
      # Cache the extracted era5-timeseries binary in a stable, owned
      # location instead of accumulating temp files in /tmp.
      ERA5_FETCHER_CACHE = "/var/lib/climate-changed/era5-timeseries";
      # ducktape binds libduckdb.so via the JDK Foreign Function API, so the
      # native library must be discoverable at runtime. Pin it to nixpkgs'
      # duckdb (1.5.5), whose ABI matches the ducktape binding.
      LD_LIBRARY_PATH = "${pkgs.duckdb.lib}/lib";
    };

    serviceConfig = {
      # StateDirectory creates/owns /var/lib/climate-changed for us.
      StateDirectory = "climate-changed";
      WorkingDirectory = "/var/lib/climate-changed";
      # --enable-native-access silences the JVM's "restricted method" warnings
      # triggered by Hadoop's NativeCodeLoader calling System::loadLibrary.
      ExecStart = "${pkgs.openjdk25_headless}/bin/java --enable-native-access=ALL-UNNAMED -jar /var/lib/climate-changed/production.jar";
      Restart = "on-failure";
      RestartSec = 5;
      # Only start once the symlink exists; avoids crash-looping before first deploy.
      ExecCondition = "${pkgs.coreutils}/bin/test -e /var/lib/climate-changed/production.jar";
    };
  };

  # Enable flakes and the new nix CLI permanently so that `nixos-rebuild
  # --flake`, `nix shell`, and `nix-shell` work without passing
  # `--extra-experimental-features 'nix-command flakes'` on every invocation.
  nix.settings.experimental-features = [
    "nix-command"
    "flakes"
  ];
}
