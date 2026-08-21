{
  description = "Atuin AI Server development shell";

  inputs.nixpkgs.url = "github:NixOS/nixpkgs/nixos-26.05";

  outputs = { nixpkgs, ... }:
    let
      systems = [
        "x86_64-linux"
        "aarch64-linux"
      ];

      forAllSystems = nixpkgs.lib.genAttrs systems;
    in
    {
      devShells = forAllSystems (
        system:
        let
          pkgs = import nixpkgs { inherit system; };
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

      formatter = forAllSystems (
        system: (import nixpkgs { inherit system; }).nixfmt-rfc-style
      );
    };
}
