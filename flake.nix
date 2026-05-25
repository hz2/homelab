{
  description = "homelab";

  inputs = {
    nixpkgs.url = "github:nixos/nixpkgs/nixos-unstable";
    disko = {
      url = "github:nix-community/disko";
      inputs.nixpkgs.follows = "nixpkgs";
    };
    sops-nix = {
      url = "github:mic92/sops-nix";
      inputs.nixpkgs.follows = "nixpkgs";
    };
  };

  outputs = { self, nixpkgs, disko, sops-nix, ... }: {
    nixosConfigurations.nlpogi = nixpkgs.lib.nixosSystem {
      system = "x86_64-linux";
      modules = [
        ./hosts/nlpogi/configuration.nix
        ./hosts/nlpogi/disk.nix
        disko.nixosModules.disko
        sops-nix.nixosModules.sops
      ];
    };

    # installer iso - build with: nix build .#installer
    # flash with:  sudo dd if=result/iso/*.iso of=/dev/sdX bs=4M status=progress conv=fsync
    packages.x86_64-linux.installer =
      (nixpkgs.lib.nixosSystem {
        system = "x86_64-linux";
        modules = [ ./hosts/nlpogi/installer.nix ];
      }).config.system.build.isoImage;
  };
}
