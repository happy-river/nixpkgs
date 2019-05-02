{ config, lib, pkgs, ... }:

let
  cfg = config.services.mastodon;

  env = {
    RAILS_ENV = "production";
    NODE_ENV = "production";

    VAPID_PUBLIC_KEY = cfg.vapidPublicKey;
    DB_USER = cfg.dbUser;
    SMTP_LOGIN  = cfg.smtpLogin;

    REDIS_HOST = cfg.redisHost;
    REDIS_PORT = toString(cfg.redisPort);
    DB_HOST = cfg.dbHost;
    DB_PORT = toString(cfg.dbPort);
    DB_NAME = cfg.dbName;
    LOCAL_DOMAIN = cfg.localDomain;
    SMTP_SERVER = cfg.smtpServer;
    SMTP_PORT = toString(cfg.smtpPort);
    SMTP_FROM_ADDRESS = cfg.smtpFromAddress;
    PAPERCLIP_ROOT_PATH = "/var/lib/mastodon/public-system";
    PAPERCLIP_ROOT_URL = "/system";
    ES_ENABLED = if (cfg.elasticsearchHost != null) then "true" else "false";
    ES_HOST = cfg.elasticsearchHost;
    ES_PORT = toString(cfg.elasticsearchPort);
  };

in {

  options = {
    services.mastodon = {
      enable = lib.mkEnableOption "Mastodon federated social network";
      configureNginx = lib.mkEnableOption ''
        Configure nginx as reverse proxy for mastodon
        Alternatively you can configure a reverse-proxy of your choice to serve these paths:

        / -> $(nix-instantiate --eval '&lt;nixpkgs&gt;' -A mastodon.outPath)/public
        / -> 127.0.0.1:{{ webPort }} (if there was no file in the directory above)
        /system/ -> /var/lib/mastodon/public-system/
        /api/v1/streaming/ -> 127.0.0.1:{{ streamingPort }}

        Make sure that websockets are forwarded properly. You might want to set up caching
        of some requests, take a look at mastodon's provided nginx configuration at
        https://github.com/tootsuite/mastodon/blob/master/dist/nginx.conf
      '';
      user = lib.mkOption {
        description = ''
          User under which mastodon runs
          If it is set to "mastodon", a user will be created.
        '';
        type = lib.types.str;
        default = "mastodon";
      };
      group = lib.mkOption {
        description = ''
          Group under which mastodon runs
          If it is set to "mastodon", a group will be created.
        '';
        type = lib.types.str;
        default = "mastodon";
      };

      streamingPort = lib.mkOption {
        description = "TCP port used by the mastodon-streaming service";
        type = lib.types.port;
        default = 55000;
      };
      webPort = lib.mkOption {
        description = "TCP port used by the mastodon-web service";
        type = lib.types.port;
        default = 55001;
      };
      sidekiqPort = lib.mkOption {
        description = "TCP port used by the mastodon-sidekiq service";
        type = lib.types.port;
        default = 55002;
      };

      dbUser = lib.mkOption {
        description = "Postgres login username";
        type = lib.types.str;
        default = "mastodon";
      };
      vapidPublicKey = lib.mkOption {
        description = ''
          The public key used for Web Push Voluntary Application Server Identification

          A keypair can be generated by running
          cd $(nix-instantiate --eval '&lt;nixpkgs&gt;' -A mastodon.outPath); bin/rake webpush:generate_keys
        '';
        type = lib.types.str;
      };
      smtpLogin = lib.mkOption {
        description = "SMTP login name";
        type = lib.types.str;
      };

      secretKeyBaseFile = lib.mkOption {
        description = ''
          Path to file containing the secret key base

          Can be generated by running
          cd $(nix-instantiate --eval '&lt;nixpkgs&gt;' -A mastodon.outPath); bin/rake secret
        '';
        type = lib.types.str;
      };
      otpSecretFile = lib.mkOption {
        description = ''
          Path to file containing the OTP secret

          Can be generated by running
          cd $(nix-instantiate --eval '&lt;nixpkgs&gt;' -A mastodon.outPath); bin/rake secret
        '';
        type = lib.types.str;
      };
      vapidPrivateKeyFile = lib.mkOption {
        description = ''
          Path to file containing the private key used for Web Push Voluntary Application Server Identification

          A keypair can be generated by running
          cd ${pkgs.mastodon}; bin/rake webpush:generate_keys
        '';
        type = lib.types.str;
      };
      dbPassFile = lib.mkOption {
        description = ''
          Path to file containing the Postgres database password
          cd $(nix-instantiate --eval '&lt;nixpkgs&gt;' -A mastodon.outPath); bin/rake webpush:generate_keys
        '';
        type = lib.types.str;
      };
      smtpPasswordFile = lib.mkOption {
        description = ''
          Path to file containing the SMTP password
        '';
        type = lib.types.str;
      };

      redisHost = lib.mkOption {
        description = "Redis host";
        type = lib.types.str;
        default = "127.0.0.1";
      };
      redisPort = lib.mkOption {
        description = "Redis port";
        type = lib.types.port;
        default = 6379;
      };
      dbHost = lib.mkOption {
        description = ''
          Postgres database host address, or path to Postgres database socket directory (usually <filename>/run/postgres</filename>).
          '';
        type = lib.types.str;
        default = "127.0.0.1";
      };
      dbPort = lib.mkOption {
        description = "Postgres database port";
        type = lib.types.port;
        default = 5432;
      };
      dbName = lib.mkOption {
        description = "Postgres database name";
        type = lib.types.str;
        default = "mastodon";
      };
      localDomain = lib.mkOption {
        description = "The domain serving your Mastodon instance";
        default = "social.example.org";
        type = lib.types.str;
      };
      smtpServer = lib.mkOption {
        description = "SMTP host used when sending Emails to users";
        type = lib.types.str;
      };
      smtpPort = lib.mkOption {
        description = "SMTP port used when sending Emails to users";
        type = lib.types.port;
        default = 587;
      };
      smtpFromAddress = lib.mkOption {
        description = ''"From" address used when sending Emails to users'';
        type = lib.types.str;
      };
      elasticsearchHost = lib.mkOption {
        description = ''
          Elasticsearch host
          If it is not null, Elasticsearch full text search will be enabled
        '';
        type = lib.types.nullOr lib.types.str;
        default = null;
      };
      elasticsearchPort = lib.mkOption {
        description = "Elasticsearch port";
        type = lib.types.port;
        default = 9200;
      };

    };
  };

  config = lib.mkIf cfg.enable {
    systemd.services.mastodon-init-dirs = {
      script = ''
        umask 077
        cat > /var/lib/mastodon/.secrets_env <<EOF
        SECRET_KEY_BASE=$(cat ${cfg.secretKeyBaseFile})
        OTP_SECRET=$(cat ${cfg.otpSecretFile})
        VAPID_PRIVATE_KEY=$(cat ${cfg.vapidPrivateKeyFile})
        DB_PASS=$(cat ${cfg.dbPassFile})
        SMTP_PASSWORD=$(cat ${cfg.smtpPasswordFile})
        EOF
      '';
      serviceConfig = {
        Type = "oneshot";
        User = cfg.user;
        Group = cfg.group;
        LogsDirectory = "mastodon";
        StateDirectory = "mastodon";
      };
      after = [ "network.target" ];
      wantedBy = [ "multi-user.target" ];
    };

    systemd.services.mastodon-init-db = {
      script = ''
        cd ${pkgs.mastodon}
        rake db:migrate
      '';
      path = [ pkgs.mastodon ];
      environment = env;
      serviceConfig = {
        Type = "oneshot";
        User = cfg.user;
        Group = cfg.group;
        EnvironmentFile = "/var/lib/mastodon/.secrets_env";
        PrivateTmp = true;
        LogsDirectory = "mastodon";
        StateDirectory = "mastodon";
      };
      after = [ "mastodon-init-dirs.service" "network.target" ];
      wantedBy = [ "multi-user.target" ];
    };

    systemd.services.mastodon-streaming = {
      after = [ "mastodon-init-db.service" "network.target" ];
      description = "Mastodon streaming";
      wantedBy = [ "multi-user.target" ];
      environment = env // {
        PORT = toString(cfg.streamingPort);
      };
      serviceConfig = {
        ExecStart = "${pkgs.nodejs-slim}/bin/node streaming";
        Restart = "always";
        RestartSec = 20;
        User = cfg.user;
        Group = cfg.group;
        WorkingDirectory = pkgs.mastodon;
        EnvironmentFile = "/var/lib/mastodon/.secrets_env";
        PrivateTmp = true;
        LogsDirectory = "mastodon";
        StateDirectory = "mastodon";
      };
    };

    systemd.services.mastodon-web = {
      after = [ "mastodon-init-db.service" "network.target" ];
      description = "Mastodon web";
      wantedBy = [ "multi-user.target" ];
      environment = env // {
        PORT = toString(cfg.webPort);
      };
      serviceConfig = {
        ExecStart = "${pkgs.mastodon}/bin/puma -C config/puma.rb";
        Restart = "always";
        RestartSec = 20;
        User = cfg.user;
        Group = cfg.group;
        WorkingDirectory = pkgs.mastodon;
        EnvironmentFile = "/var/lib/mastodon/.secrets_env";
        PrivateTmp = true;
        LogsDirectory = "mastodon";
        StateDirectory = "mastodon";
      };
      path = with pkgs; [ file imagemagick ffmpeg ];
    };

    systemd.services.mastodon-sidekiq = {
      after = [ "mastodon-init-db.service" "network.target" ];
      description = "Mastodon sidekiq";
      wantedBy = [ "multi-user.target" ];
      environment = env // {
        PORT = toString(cfg.sidekiqPort);
      };
      serviceConfig = {
        ExecStart = "${pkgs.mastodon}/bin/sidekiq -c 25 -r ${pkgs.mastodon}";
        Restart = "always";
        RestartSec = 20;
        User = cfg.user;
        Group = cfg.group;
        WorkingDirectory = pkgs.mastodon;
        EnvironmentFile = "/var/lib/mastodon/.secrets_env";
        PrivateTmp = true;
        LogsDirectory = "mastodon";
        StateDirectory = "mastodon";
      };
    };

    services.nginx = lib.mkIf cfg.configureNginx {
      enable = true;
      virtualHosts."${cfg.localDomain}" = {
        root = "${pkgs.mastodon}/public/";

        locations."/system/".alias = "/var/lib/mastodon/public-system/";

        locations."/" = {
          tryFiles = "$uri @proxy";
        };

        locations."@proxy" = {
          proxyPass = "http://127.0.0.1:${toString(cfg.webPort)}";
          proxyWebsockets = true;
        };

        locations."/api/v1/streaming/" = {
          proxyPass = "http://127.0.0.1:${toString(cfg.streamingPort)}/";
          proxyWebsockets = true;
        };
      };
    };

    users.users.mastodon = lib.mkIf (cfg.user == "mastodon") {
      isSystemUser = true;
      inherit (cfg) group;
    };

    users.groups.mastodon = lib.mkIf (cfg.group == "mastodon") { };
  };

}
