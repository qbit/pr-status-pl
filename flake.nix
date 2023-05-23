{
  description = "pr-status: a tool to query NixOS/nixpkgs pull request status as they move along the build chain";

  inputs.nixpkgs.url = "nixpkgs/nixos-22.11";

  outputs = { self, nixpkgs }:
    let
      supportedSystems =
        [ "x86_64-linux" "x86_64-darwin" "aarch64-linux" "aarch64-darwin" ];
      forAllSystems = nixpkgs.lib.genAttrs supportedSystems;
      nixpkgsFor = forAllSystems (system: import nixpkgs { inherit system; });
    in {
      packages = forAllSystems (system:
        let pkgs = nixpkgsFor.${system};
        in {
          pr-status = pkgs.stdenv.mkDerivation {
            pname = "pr-status";
            version = "v0.0.1";
            src = ./.;
            buildInputs = with pkgs.perlPackages; [ PerlTidy ];
            nativeBuildInputs = with pkgs.perlPackages; [ perl ];

            propagatedBuildInputs = with pkgs.perlPackages; [
              Mojolicious
              JSON
              Git
            ];

            outputs = [ "out" "dev" ];
          };
        });

      defaultPackage = forAllSystems (system: self.packages.${system}.pr-status);
      devShells = forAllSystems (system:
        let pkgs = nixpkgsFor.${system};
        in {
          default = pkgs.mkShell {
            shellHook = ''
              PS1='\u@\h:\@; '
              nix flake run github:qbit/xin#flake-warn
              echo "Perl `${pkgs.perl}/bin/perl --version`"
            '';
            buildInputs = with pkgs.perlPackages; [
              Git
              JSON
              Mojolicious
              perl
              PerlCritic
              PerlTidy
            ];
          };
        });
    };
}

