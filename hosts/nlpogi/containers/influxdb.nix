{ ... }:

{
  systemd.tmpfiles.rules = [
    "d /var/lib/influxdb 0755 1500 1500 -"
  ];

  virtualisation.oci-containers.containers.influxdb = {
    image = "influxdb:3-core";
    extraOptions = [ "--network=host" ];
    volumes = [ "/var/lib/influxdb:/var/lib/influxdb3" ];
    # default http port is 8181; override to 8086 to match plan
    # --without-auth: no token required in phase 2; harden in phase 10
    cmd = [
      "serve"
      "--node-id=nlpogi"
      "--object-store=file"
      "--data-dir=/var/lib/influxdb3"
      "--http-bind=0.0.0.0:8086"
      "--without-auth"
    ];
  };
}
