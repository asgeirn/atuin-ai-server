{
  description = "Atuin AI Server development shell and installer";

  inputs.nixpkgs.url = "github:NixOS/nixpkgs/nixos-26.05";

  outputs = { nixpkgs, ... }:
    let
      systems = [
        "x86_64-linux"
        "aarch64-linux"
      ];

      forAllSystems = nixpkgs.lib.genAttrs systems;
      installers = forAllSystems mkInstaller;

      mkPkgs = system: import nixpkgs { inherit system; };

      mkInstaller =
        system:
        let
          pkgs = mkPkgs system;
          beam = pkgs.beam.packages.erlang_27;
        in
        pkgs.writeShellApplication {
          name = "atuin-ai-server-installer";

          runtimeInputs = [
            beam.erlang
            beam.elixir_1_18
            beam.rebar3
            pkgs.gleam
            pkgs.git
            pkgs.cacert
            pkgs.coreutils
          ];

          text = ''
            set -euo pipefail

            install_dir="$HOME/.local/opt/atuin-ai-server"
            config_dir="$HOME/.config/atuin-ai"
            systemd_user_dir="$HOME/.config/systemd/user"
            cache_dir="''${XDG_CACHE_HOME:-$HOME/.cache}/atuin-ai-server"
            build_dir="$(mktemp -d)"
            source_dir="$build_dir/src"

            trap 'rm -rf "$build_dir"' EXIT

            export MIX_HOME="$cache_dir/mix"
            export HEX_HOME="$cache_dir/hex"
            export PATH="$MIX_HOME/bin:$HEX_HOME/bin:$PATH"
            export LANG="en_US.UTF-8"
            export SSL_CERT_FILE="${pkgs.cacert}/etc/ssl/certs/ca-bundle.crt"
            export MIX_ENV="prod"

            mkdir -p "$MIX_HOME" "$HEX_HOME" "$cache_dir"

            echo "Copying source..."
            mkdir -p "$source_dir"
            cp -a ${./.}/. "$source_dir/"

            cd "$source_dir"

            echo "Bootstrapping Hex/Rebar..."
            mix local.hex --force
            mix local.rebar --force

            echo "Fetching dependencies and building release..."
            mix deps.get --only prod
            mix deps.compile
            mix compile
            mix release

            echo "Installing release to $install_dir..."
            rm -rf "$install_dir"
            mkdir -p "$install_dir"
            cp -a _build/prod/rel/atuin_ai_server/. "$install_dir/"

            echo "Installing config and systemd unit..."
            mkdir -p "$config_dir" "$systemd_user_dir"

            if [ ! -f "$config_dir/config.toml" ]; then
              cp ${./config.example.toml} "$config_dir/config.toml"
              echo "Created $config_dir/config.toml"
            else
              echo "Keeping existing $config_dir/config.toml"
            fi

            cp ${./systemd/atuin-ai-server.service} "$systemd_user_dir/atuin-ai-server.service"

            if [ ! -f "$config_dir/atuin-ai-server.env" ]; then
              : > "$config_dir/atuin-ai-server.env"
              chmod 600 "$config_dir/atuin-ai-server.env"
              echo "Created optional $config_dir/atuin-ai-server.env"
            fi

            cat <<EOF
            Installed Atuin AI Server.

            Next steps:
              1. Edit $config_dir/config.toml
              2. Optionally add AUTH_TOKEN or API keys to $config_dir/atuin-ai-server.env
              3. Run: systemctl --user daemon-reload
              4. Run: systemctl --user enable --now atuin-ai-server.service

            To start the user service automatically after reboot before login:
              sudo loginctl enable-linger "$USER"
            EOF
          '';
        };
    in
    {
      devShells = forAllSystems (
        system:
        let
          pkgs = mkPkgs system;
          beam = pkgs.beam.packages.erlang_27;
        in
        {
          default = pkgs.mkShell {
            packages = [
              beam.erlang
              beam.elixir_1_18
              beam.rebar3
              pkgs.gleam
              pkgs.git
              pkgs.cacert
            ];

            shellHook = ''
              export MIX_HOME="$PWD/.nix-mix"
              export HEX_HOME="$PWD/.nix-hex"
              export PATH="$MIX_HOME/bin:$HEX_HOME/bin:$PATH"
              export LANG="en_US.UTF-8"
              export SSL_CERT_FILE="${pkgs.cacert}/etc/ssl/certs/ca-bundle.crt"

              mkdir -p "$MIX_HOME" "$HEX_HOME"
            '';
          };
        }
      );

      packages = forAllSystems (
        system:
        let
          installer = installers.${system};
        in
        {
          atuin-ai-server-installer = installer;
          default = installer;
        }
      );

      apps = forAllSystems (
        system:
        let
          installer = installers.${system};
        in
        {
          install = {
            type = "app";
            program = "${installer}/bin/atuin-ai-server-installer";
          };

          default = {
            type = "app";
            program = "${installer}/bin/atuin-ai-server-installer";
          };
        }
      );

      formatter = forAllSystems (
        system: (mkPkgs system).nixfmt-rfc-style
      );
    };
}
