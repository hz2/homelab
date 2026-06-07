{ ... }:

{
  virtualisation.oci-containers.containers.jsondev = {
    image = "ghcr.io/hz2/jsondev:latest";
    extraOptions = [ "--network=host" ];
    environment = {
      PORT = "3000";
      RUST_LOG = "jsondev=info";
    };
  };
}
