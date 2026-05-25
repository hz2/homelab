{ ... }:

{
  systemd.tmpfiles.rules = [
    "d /var/lib/minio 0755 root root -"
  ];

  virtualisation.oci-containers.containers.minio = {
    image = "minio/minio";
    extraOptions = [ "--network=host" ];
    environment = {
      # changeme - rotate in phase 10 with sops-nix
      MINIO_ROOT_USER = "minioadmin";
      MINIO_ROOT_PASSWORD = "changeme123";
    };
    volumes = [ "/var/lib/minio:/data" ];
    cmd = [ "server" "/data" "--console-address" ":9001" ];
  };
}
