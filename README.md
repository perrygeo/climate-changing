# Climate Changing

A fullstack application to analyze ERA5 weather data timeseries for select locations.


## Source code

Key source directories

```
 build                                        ;; uberjar build script
 dev                                          ;; utils for local development
 infra                                        ;; NixOS and terraform for prod deployment
 resources                                    ;; static files shipped with release
 src/clj/climate_changing/backend/             ;; web server
 src/clj/climate_changing/era5/                ;; core weather data actions
 src/cljc/climate_changing/                    ;; shared utils, common math, clj/cljs agnostic
 src/cljs/climate_changing/frontend/           ;; interactive web map application
 src/rs/era5-timeseries/                      ;; rust command line utility for fetching ERA5
 test                                         ;; unit/integration tests
```

### Server

The server side is JVM Clojure.

* bidi routing
* integrant components
* ring
* jetty9
* `GET /api/locations` returns all locations as GeoJSON (RFC 7946), served
  from a bundled Natural Earth resource

The server namespaces split by concern:

* `backend/main.clj` - Configuration and entry point
* `backend/components.clj` - init/halt methods for the components
* `backend/server.clj` - routes and the ring middleware stack
* `backend/handlers.clj` - the individual ring handlers (HTTP logic, calls domain logic defined in other namespaces)

### Client

The client side is ClojureScript compiled to JS

* reagent for components
* shadow-cljs builds
* garden for css

Client code is in `frontend/`, split by concern: `main` (entry point),
`app` (top-level view), `search`, `interactive-map`, and `state` (ratoms).

### Shared

When possible, define common functions and data using `.cljc` files


## Development

Use the `Makefile` and the utility fns in `dev/user.clj`

```
$ make
Usage:
  make clean     - clean temporary files
  make dev       - development REPL
  make release   - production build
  make test      - run all tests (JVM and Node)
  make test-clj  - run Clojure tests on the JVM
  make test-cljs - run ClojureScript tests on Node
```
## Production Release


### Infrastructure

AWS infrastructure is defined with Terraform in [`infra/terraform/`](infra/terraform/README.md):

* EC2 spot `t3.medium` running NixOS (configured by the flake in `infra/flake.nix`),
  SSH-able as `root`, with an instance profile for S3
* CloudFront distribution pointing at the EC2 instance on port 9000 - caching is
  origin-controlled: only responses whose origin sets `Cache-Control`/`Expires`
  are cached, which today is only the satellite tiles endpoint
* S3 bucket to hold the timeseries data

See [`infra/README.md`](infra/terraform/README.md) for how to run
Terraform and how to (manually) configure DNS to point `climate-changing.org` at
the CloudFront distribution.

To verify, SSH into the ec2, run something on port 9000
(e.g. `nix-shell -p python3 --run 'python3 -m http.server 9000'`), and see the
results at `climate-changing.org`

### Systemd
The files live in `/var/lib/climate-changed/` on the live server.

### era_ts storage (EBS-backed)

The ERA5 timeseries parquet cache lives at
`/var/lib/climate-changed/era_ts`. It is backed by a plain, persistent ext4
EBS data volume (gp3, encrypted) that Terraform creates and attaches to the
instance (`infra/terraform/ebs.tf`), and that the NixOS config formats on first
boot and mounts at that path (`infra/nixos/configuration.nix`). The volume
survives instance termination/rebuild, unlike the old ZeroFS -> NBD -> ZFS
stack it replaced. Data migration from the old S3 bucket
`climate-changed-era5-timeseries-v1` is done separately.
