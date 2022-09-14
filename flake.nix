{
  inputs = {
    nixpkgs.url = "nixpkgs/nixos-unstable";
    dream2nix.url = "github:nix-community/dream2nix";
    nixos-shell.url = "github:mic92/nixos-shell";

    src = {
      type = "gitlab";
      owner = "Openki";
      repo = "Openki";
      ref = "v0.9.0";
      flake = false;
    };
  };

  outputs =
    { self
    , nixpkgs
    , dream2nix
    , nixos-shell
    , src
    }:
    let
      supportedSystems = [ "x86_64-linux" ];
      forAllSystems = f: nixpkgs.lib.genAttrs supportedSystems (system: f system);
      nixpkgsFor = forAllSystems (system: import nixpkgs { inherit system; });

      d2n-flake = forAllSystems
        (system: {
          d2n = dream2nix.lib.makeFlakeOutputs {
            inherit system;
            config.projectRoot = ./.;
            source = "${src}";
            packageOverrides = {
              chromedriver = {
                skip-chromedriver = {
                  preBuild = ''
                    export CHROMEDRIVER_SKIP_DOWNLOAD=true
                  '';
                };
              };
            };
          };
        });
    in
    d2n-flake //
    {
      nixosModules.openki = import ./module.nix;

      devShell = forAllSystems (system:
        nixpkgsFor."${system}".mkShell {
          buildInputs = [
            nixos-shell.defaultPackage."${system}"
          ];
        }
      );

      packages = forAllSystems (system:
        {
          nixos-vm =
            let
              nixos = nixpkgs.lib.nixosSystem {
                inherit system;
                modules = [
                  self.nixosModules.openki
                ];
              };
            in
            nixos.config.system.build.vm;
        });

      apps = forAllSystems (system: {

        vm = {
          type = "app";
          program = builtins.toString (nixpkgs.legacyPackages."${system}".writeScript "vm" ''
            ${self.packages."${system}".nixos-vm}/bin/run-nixos-vm
          '');
        };

        vm-clear-state = {
          type = "app";
          program = builtins.toString (nixpkgs.legacyPackages."${system}".writeScript "vm-clear-state" ''
            rm nixos.qcow2
          '');
        };

        nixos-shell = {
          type = "app";
          program = builtins.toString (nixpkgs.legacyPackages."${system}".writeScript "nixos-shell" ''
            ${nixos-shell.defaultPackage."${system}"}/bin/nixos-shell \
              -I nixpkgs=${nixpkgs} \
              ./module.nix
          '');
        };

      });
    };
}
