{ pkgs, config, lib, ... }:
let
  cfg = config.services.openki;
  user = "openki";
  group = "openki";
  statePath = cfg.statePath;
in
{
  options.services.openki = {
    enable = lib.mkEnableOption "Enable Openki server";
    config = lib.mkOption {
      default = "";
      description = "Openki configuration";
    };
  };

  config = {
    users.groups = {
      openki = {
        members = [ "openki" ];
      };
    };

    users.users = {
      root.password = "root";

      openki = {
        isNormalUser = true;
        home = "/home/openki";
        group = "openki";
        password = "openki";
      };
    };

    services.mongodb = {
      enable = lib.mkDefault true;

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
        Environment = "MONGO_URL=mongodb://0.0.0.0:1234/meteor";
        ExecStart = "${pkgs.meteor}/bin/meteor npm install && ${pkgs.meteor}/bin/meteor npm run dev";
        User = user;
        Group = group;
      };
    };
  };
}
