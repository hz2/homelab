{ homelabServices, ... }:
{
  systemd.services.sensor-api = {
    description = "sensor gRPC API";
    wantedBy = [ "multi-user.target" ];
    after = [ "network.target" "podman-nats.service" ];
    wants = [ "podman-nats.service" ];
    environment = {
      NATS_URL = "nats://localhost:4222";
      RUST_LOG = "info";
    };
    serviceConfig = {
      ExecStart = "${homelabServices}/bin/sensor";
      Restart = "on-failure";
      RestartSec = "5s";
      DynamicUser = true;
    };
  };
}
