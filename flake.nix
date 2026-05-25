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
    crane.url = "github:ipetkov/crane";
  };

  outputs = { self, nixpkgs, disko, sops-nix, crane, ... }:
  let
    pkgs = nixpkgs.legacyPackages.x86_64-linux;
    craneLib = crane.mkLib pkgs;

    # include rust sources + proto files for the crane build
    servicesSrc = pkgs.lib.cleanSourceWith {
      src = craneLib.path ./.;
      filter = path: type:
        (craneLib.filterCargoSources path type) ||
        (pkgs.lib.hasSuffix ".proto" path);
    };

    servicesArgs = {
      src = servicesSrc;
      pname = "homelab-services";
      version = "0.1.0";
      # workspace Cargo.toml is in services/ subdirectory
      cargoExtraArgs = "--workspace --manifest-path services/Cargo.toml";
      # Cargo.lock is also in services/, so point crane at it explicitly
      cargoVendorDir = craneLib.vendorCargoDeps { cargoLock = ./services/Cargo.lock; };
      # proto files are passed as an absolute store path so build.rs can find them
      PROTO_ROOT = builtins.path { path = ./proto; name = "proto"; };
      strictDeps = true;
      nativeBuildInputs = [ pkgs.protobuf pkgs.pkg-config ];
      buildInputs = [ pkgs.openssl ];
    };

    # build deps separately for caching
    servicesDeps = craneLib.buildDepsOnly servicesArgs;

    servicesClippy = craneLib.cargoClippy (servicesArgs // {
      cargoArtifacts = servicesDeps;
      cargoClippyExtraArgs = "--all-features -- -D warnings";
      doNotPostBuildInstallCargoBinaries = true;
    });
  in {
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

    # rust services workspace - requires services/Cargo.lock to exist
    # generate with: cd services && cargo generate-lockfile (inside nix develop)
    packages.x86_64-linux.services = craneLib.buildPackage (servicesArgs // {
      cargoArtifacts = servicesDeps;
      # crane's postBuild install hook calls `cargo metadata` without --manifest-path
      # which fails since there's no Cargo.toml at the source root (it's in services/).
      # skip crane's hook and install from the known target path directly.
      doNotPostBuildInstallCargoBinaries = true;
      installPhase = ''
        runHook preInstall
        mkdir -p $out/bin
        find services/target/release -maxdepth 1 -type f -executable \
          ! -name "*.so" \
          -exec install -Dm755 {} $out/bin/ \;
        runHook postInstall
      '';
    });

    checks.x86_64-linux.services-clippy = servicesClippy;

    devShells.x86_64-linux.default = pkgs.mkShell {
      packages = with pkgs; [
        # rust toolchain
        cargo rustc clippy rust-analyzer rustfmt
        # protobuf / buf
        buf protobuf
        # homelab ops
        natscli mosquitto
        # python clients
        (python3.withPackages (p: with p; [ grpcio-tools grpcio ]))
        # native-tls deps (pulled in by async-nats -> reqwest)
        openssl pkg-config
      ];
      shellHook = ''
        echo "proto:    cd proto && buf generate"
        echo "rust:     cd services && cargo build"
        echo "nix build .#services  (needs services/Cargo.lock first)"
      '';
    };
  };
}
