{ config, pkgs, homelabServices, ... }:
{
  imports = [
    ./hardware-configuration.nix
    ./networking.nix
    ./containers/nats.nix
    # emqx: deferred - nats built-in mqtt replaces the mqtt->nats bridge for phase 2
    # ./containers/emqx.nix
    ./containers/influxdb.nix
    ./containers/minio.nix
    ./containers/frigate.nix
    ./containers/caddy.nix
    ./containers/authelia.nix
    ./containers/jsondev.nix
    ./services/sensor.nix
    ./services/camera.nix
    ./services/influx-writer.nix
  ];

  system.stateVersion = "25.05";

  boot.loader.systemd-boot.enable = true;
  boot.loader.efi.canTouchEfiVariables = true;

  networking.hostName = "nlpogi";
  time.timeZone = "America/Los_Angeles";

  users.users.jos = {
    isNormalUser = true;
    extraGroups = [ "wheel" "podman" ];
    # changeme - change after first login
    hashedPassword = "$6$VW11YcP4h1Lku93H$Zr5nud9Ekf8WRfXXfVdr.GVmpEZexcEsl2N5VEl3icepS0WQD4VCydGbSVtFV3tih21SGaTwiro84fMPCGc.b.";
    openssh.authorizedKeys.keys = [
      "ssh-ed25519 AAAAC3NzaC1lZDI1NTE5AAAAIKbI0qm9KuVdB2fMQhDAxYwzQdwmsiuyMeuw7VyemXVI dev.json2@gmail.com"
    ];
  };

  services.openssh = {
    enable = true;
    settings = {
      PasswordAuthentication = false;
      PermitRootLogin = "no";
    };
  };

  environment.systemPackages = with pkgs; [
    vim
    git
    curl
    htop
    tcpdump
    natscli
    mosquitto
  ];

  security.sudo.wheelNeedsPassword = false;

  hardware.graphics = {
    enable = true;
    extraPackages = with pkgs; [ intel-media-driver ];
  };

  virtualisation.podman = {
    enable = true;
    dockerCompat = true;
  };

  virtualisation.oci-containers.backend = "podman";
}
