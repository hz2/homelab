{ pkgs, ... }:

let
  frigateConfig = pkgs.writeText "frigate.yml"
    (builtins.readFile ../../../configs/frigate.yml);
in
{
  systemd.tmpfiles.rules = [
    "d /var/lib/frigate        0755 root root -"
    "d /var/lib/frigate/media  0755 root root -"
  ];

  # copy config from nix store, then substitute credential placeholders from secrets.env
  systemd.services."podman-frigate".preStart = ''
    cp ${frigateConfig} /var/lib/frigate/config.yml
    chmod 644 /var/lib/frigate/config.yml
    source /var/lib/frigate/secrets.env
    sed -i "s|{FRIGATE_RTSP_USER}|$FRIGATE_RTSP_USER|g" /var/lib/frigate/config.yml
    sed -i "s|{FRIGATE_RTSP_PASSWORD}|$FRIGATE_RTSP_PASSWORD|g" /var/lib/frigate/config.yml
  '';

  virtualisation.oci-containers.containers.frigate = {
    image = "ghcr.io/blakeblackshear/frigate:stable";
    extraOptions = [
      "--network=host"
      "--device=/dev/dri:/dev/dri"
      "--shm-size=256m"
    ];
    volumes = [
      "/var/lib/frigate/config.yml:/config/config.yml"
      "/var/lib/frigate/media:/media/frigate"
      "/etc/localtime:/etc/localtime:ro"
    ];
    # credentials live in /var/lib/frigate/secrets.env on the host, never in git
    environmentFiles = [ "/var/lib/frigate/secrets.env" ];
  };
}
