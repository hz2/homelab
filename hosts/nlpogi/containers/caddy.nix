{ pkgs, ... }:

let
  caddyfile = pkgs.writeText "Caddyfile"
    (builtins.readFile ../../../configs/caddy/Caddyfile);
in
{
  systemd.tmpfiles.rules = [
    "d /var/lib/caddy 0755 root root -"
  ];

  virtualisation.oci-containers.containers.caddy = {
    image = "caddy:latest";
    extraOptions = [ "--network=host" ];
    volumes = [
      "${caddyfile}:/etc/caddy/Caddyfile:ro"
      "/var/lib/caddy:/data"
    ];
  };
}
