{ homelabServices, ... }:
{
  systemd.services.camera-api = {
    description = "camera gRPC API";
    wantedBy = [ "multi-user.target" ];
    after = [ "network.target" "podman-nats.service" ];
    wants = [ "podman-nats.service" ];
    environment = {
      NATS_URL = "nats://localhost:4222";
      RUST_LOG = "info";
    };
    serviceConfig = {
      ExecStart = "${homelabServices}/bin/camera";
      Restart = "on-failure";
      RestartSec = "5s";
      DynamicUser = true;
    };
  };
}
