{ homelabServices, ... }:
{
  systemd.services.influx-writer = {
    description = "NATS -> InfluxDB writer";
    wantedBy = [ "multi-user.target" ];
    after = [ "network.target" "podman-nats.service" "podman-influxdb.service" ];
    wants = [ "podman-nats.service" "podman-influxdb.service" ];
    environment = {
      NATS_URL = "nats://localhost:4222";
      RUST_LOG = "info";
    };
    serviceConfig = {
      ExecStart = "${homelabServices}/bin/influx-writer";
      Restart = "on-failure";
      RestartSec = "5s";
      DynamicUser = true;
    };
  };
}
