{ pkgs, ... }:

let
  # NATS bridge: routes sensors/# and flipper/# from MQTT to NATS subjects
  # subject conversion: sensors/pi-a/temperature -> sensors.pi-a.temperature
  # if bridge doesn't load from file, configure via dashboard at :18083
  emqxConf = pkgs.writeText "emqx.conf" ''
    node {
      name = "emqx@127.0.0.1"
      cookie = "emqxsecretcookie"
      data_dir = "/opt/emqx/data"
    }

    cluster {
      discovery_strategy = manual
    }

    dashboard {
      listeners {
        http {
          bind = "0.0.0.0:18083"
        }
      }
      default_password = "changeme123"
    }

    listeners {
      tcp {
        default {
          bind = "0.0.0.0:1883"
          max_connections = 1024000
        }
      }
    }

    connectors {
      nats {
        "homelab" {
          enable = true
          server = "nats://127.0.0.1:4222"
          pool_size = 4
        }
      }
    }

    actions {
      nats {
        "sensors_to_nats" {
          enable = true
          connector = "homelab"
          parameters {
            subject_template = "''${replace(topic, '/', '.')}"
            payload_template = "''${payload}"
          }
        }
      }
    }

    rule_engine {
      rules {
        "route_to_nats" {
          sql = "SELECT * FROM \"sensors/#\", \"flipper/#\""
          actions = ["nats:sensors_to_nats"]
          enable = true
        }
      }
    }
  '';
in
{
  systemd.tmpfiles.rules = [
    "d /var/lib/emqx 0755 1000 1000 -"
  ];

  virtualisation.oci-containers.containers.emqx = {
    image = "emqx/emqx:latest";
    extraOptions = [ "--network=host" ];
    environment = {
      EMQX_NODE__NAME = "emqx@127.0.0.1";
      EMQX_CLUSTER__DISCOVERY_STRATEGY = "manual";
    };
    volumes = [
      "/var/lib/emqx:/opt/emqx/data"
      "${emqxConf}:/opt/emqx/etc/emqx.conf:ro"
    ];
  };
}
