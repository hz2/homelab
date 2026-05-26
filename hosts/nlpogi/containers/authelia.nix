{ pkgs, ... }:

let
  autheliaConfig = pkgs.writeText "authelia-configuration.yml"
    (builtins.readFile ../../../configs/authelia/configuration.yml);
in
{
  systemd.tmpfiles.rules = [
    "d /var/lib/authelia      0700 root root -"
    "d /var/lib/authelia/data 0700 root root -"
  ];

  # copy config from nix store and substitute secrets before container starts
  # secrets.env must exist on the host at /var/lib/authelia/secrets.env (not in git)
  # users.yml must exist on the host at /var/lib/authelia/users.yml (not in git)
  # generate secrets: openssl rand -base64 32
  # generate password hash: docker run --rm authelia/authelia:4 authelia crypto hash generate bcrypt
  systemd.services."podman-authelia".preStart = ''
    cp ${autheliaConfig} /var/lib/authelia/configuration.yml
    chmod 644 /var/lib/authelia/configuration.yml
    source /var/lib/authelia/secrets.env
    sed -i "s|{AUTHELIA_SESSION_SECRET}|$AUTHELIA_SESSION_SECRET|g" /var/lib/authelia/configuration.yml
    sed -i "s|{AUTHELIA_STORAGE_KEY}|$AUTHELIA_STORAGE_KEY|g" /var/lib/authelia/configuration.yml
    sed -i "s|{AUTHELIA_JWT_SECRET}|$AUTHELIA_JWT_SECRET|g" /var/lib/authelia/configuration.yml
  '';

  virtualisation.oci-containers.containers.authelia = {
    image = "authelia/authelia:4";
    extraOptions = [ "--network=host" ];
    volumes = [
      "/var/lib/authelia/configuration.yml:/config/configuration.yml:ro"
      "/var/lib/authelia/users.yml:/config/users.yml:ro"
      "/var/lib/authelia/data:/data"
    ];
  };
}
