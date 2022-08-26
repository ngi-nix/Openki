{
  inputs.dream2nix.url = "github:nix-community/dream2nix";
  inputs.src = {
    type = "gitlab";
    owner = "Openki";
    repo = "Openki";
    ref = "dev";
    flake = false;
  };

  outputs =
    { self
    , dream2nix
    , src
    }:
    let
      systems = [ "x86_64-linux" ];
      pkgs = dream2nix.inputs.nixpkgs.legacyPackages.x86_64-linux;

      d2n-flake =
        dream2nix.lib.makeFlakeOutputs
          {
            inherit systems;
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

      overrideDevShells = {
        devShells =
          d2n-flake.devShells
          // {
            x86_64-linux =
              d2n-flake.devShells.x86_64-linux
              // {
                default =
                  d2n-flake.devShells.x86_64-linux.default.overrideAttrs
                    (old: with pkgs; {
                      nativeBuildInputs =
                        old.nativeBuildInputs ++ [
                          meteor
                        ];

                      shellHook = old.shellHook + ''
                        export LD_LIBRARY_PATH=${pkgs.curl.out}/lib:${pkgs.lzma.out}/lib
                      '';
                    });
              };
          };
      };

      nixosModule = {
        nixosModules.openki = { config, lib, pkgs }:
          with lib;
          let
            cfg = config.services.openki;
            user = "openki";
            group = "openki";
            statePath = cfg.statePath;
          in
          {
            options.services.openki = {
              enable = mkEnableOption "Enable Openki server";
              config = mkOption {
                default = "";
                description = "Openki configuration";
              };
            };

            config = mkIf cfg.enable {
              services.mongodb = {
                enable = mkDefault true;

                bind_ip = "0.0.0.0";
                package = pkgs.mongodb;
                extraConfig = ''
                  net:
                    port: 1234
                '';
              };

              systemd.services.openki = {
                wantedBy = [ "multi-user.target" ];
                after = [ "mongodb.service" "network.target" ];
                wants = [ "mongodb.service" ];
                description = "Start the Openki server.";
                serviceConfig = {
                  ExecStart = "MONGO_URL=" mongodb://0.0.0.0:1234/meteor " ${pkgs.meteor}/bin/meteor npm run dev";
                  User = user;
                  Group = group;
                };
              };
            };
          };
      };
    in
    d2n-flake // overrideDevShells // nixosModule;
}
