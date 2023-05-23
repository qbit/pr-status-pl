{ lib, config, pkgs, ... }:
let cfg = config.services.pr-status;
in {
  options = with lib; {
    services.pr-status = {
      enable = lib.mkEnableOption "Enable pr-status";

      port = mkOption {
        type = types.int;
        default = 3003;
        description = ''
          Port to listen on
        '';
      };

      user = mkOption {
        type = with types; oneOf [ str int ];
        default = "pr-status";
        description = ''
          The user the service will use.
        '';
      };

      group = mkOption {
        type = with types; oneOf [ str int ];
        default = "pr-status";
        description = ''
          The group the service will use.
        '';
      };

      package = mkOption {
        type = types.package;
        default = pkgs.pr-status;
        defaultText = literalExpression "pkgs.pr-status";
        description = "The package to use for pr-status";
      };
    };
  };

  config = lib.mkIf (cfg.enable) {
    users.groups.${cfg.group} = { };
    users.users.${cfg.user} = {
      description = "pr-status service user";
      isSystemUser = true;
      home = "/var/lib/pr-status";
      createHome = true;
      group = "${cfg.group}";
    };

    systemd.services.pr-status = {
      enable = true;
      description = "pr-status server";
      wantedBy = [ "network-online.target" ];
      after = [ "network-online.target" ];

      environment = { HOME = "/var/lib/pr-status"; };

      serviceConfig = {
        User = cfg.user;
        Group = cfg.group;

        ExecStart =
          "${cfg.package}/bin/pr-status.pl daemon -m production -l http://127.0.0.1:${
            toString cfg.port
          }";
      };
    };
  };
}
