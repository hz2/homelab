{ pkgs, ... }:

let
  natsConf = pkgs.writeText "nats.conf" ''
    port: 4222
    http_port: 8222

    jetstream {
      store_dir: /data
      max_memory_store: 4294967296
      max_file_store: 53687091200
    }

    leafnodes {
      port: 7422
    }

    # built-in mqtt bridge: sensors/foo/bar -> sensors.foo.bar (slashes to dots)
    mqtt {
      port: 1883
    }
  '';
in
{
  systemd.tmpfiles.rules = [
    "d /var/lib/nats 0755 root root -"
  ];

  virtualisation.oci-containers.containers.nats = {
    image = "nats:latest";
    extraOptions = [ "--network=host" ];
    volumes = [
      "/var/lib/nats:/data"
      "${natsConf}:/etc/nats/nats.conf:ro"
    ];
    cmd = [ "-c" "/etc/nats/nats.conf" ];
  };

  # create jetstream streams once after nats starts; idempotent (|| true)
  systemd.services.nats-streams = {
    description = "initialize nats jetstream streams";
    after = [ "podman-nats.service" ];
    wants = [ "podman-nats.service" ];
    wantedBy = [ "multi-user.target" ];
    path = [ pkgs.natscli pkgs.curl ];
    serviceConfig = {
      Type = "oneshot";
      RemainAfterExit = true;
    };
    script = ''
      for i in $(seq 1 30); do
        curl -sf http://localhost:8222/healthz && break
        sleep 2
      done

      nats --server=nats://localhost:4222 stream add SENSORS \
        --subjects="sensors.>" --storage=file --retention=limits \
        --max-age=7d --replicas=1 --defaults 2>/dev/null || true

      nats --server=nats://localhost:4222 stream add TASKS \
        --subjects="tasks.>" --storage=file --retention=workq \
        --replicas=1 --defaults 2>/dev/null || true

      nats --server=nats://localhost:4222 stream add RESULTS \
        --subjects="results.>" --storage=file --retention=limits \
        --max-age=7d --replicas=1 --defaults 2>/dev/null || true
    '';
  };
}
