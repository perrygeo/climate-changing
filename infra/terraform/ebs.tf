########################################
# era_ts data volume (EBS)
#
# A normal, persistent ext4 EBS disk mounted at
# /var/lib/climate-changed/era_ts by the NixOS config. It replaces the old
# ZeroFS -> NBD -> ZFS stack: the data now lives on a plain gp3 volume that
# survives instance termination/rebuild (the volume is attached, not baked
# into the root disk). Data migration from the S3 bucket happens separately.
#
# The instance is Nitro-based, so the volume shows up as /dev/nvme1n1
# (root is /dev/nvme0n1); see infra/nixos/configuration.nix.
########################################

resource "aws_ebs_volume" "data" {
  availability_zone = aws_instance.app.availability_zone
  size              = var.data_volume_size
  type              = "gp3"
  encrypted         = true

  tags = {
    Name = "climate-changed-era-ts-data"
  }
}

resource "aws_volume_attachment" "data" {
  device_name = "/dev/sdf"
  volume_id   = aws_ebs_volume.data.id
  instance_id = aws_instance.app.id
}
