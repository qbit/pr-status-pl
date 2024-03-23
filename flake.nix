{
  description =
    "pr-status: a tool to query NixOS/nixpkgs pull request status as they move along the build chain";

  inputs.nixpkgs.url = "nixpkgs/nixos-unstable";

  outputs = { self, nixpkgs }:
    let
      supportedSystems =
        [ "x86_64-linux" "x86_64-darwin" "aarch64-linux" "aarch64-darwin" ];
      forAllSystems = nixpkgs.lib.genAttrs supportedSystems;
      nixpkgsFor = forAllSystems (system: import nixpkgs { inherit system; });
    in {
      overlay = final: prev: {
        pr-status = self.packages.${prev.system}.pr-status;
      };
      nixosModule = import ./module.nix;
      packages = forAllSystems (system:
        let pkgs = nixpkgsFor.${system};
        in {
          pr-status = pkgs.perlPackages.buildPerlPackage {
            pname = "pr-status";
            version = "v0.0.4";
            src = ./.;
            buildInputs = with pkgs; [ makeWrapper ];
            propagatedBuildInputs = with pkgs.perlPackages; [
              Mojolicious
              JSON
              Git
            ];

            postInstall = ''
              wrapProgram $out/bin/pr-status.pl --prefix PATH : ${
                nixpkgs.lib.makeBinPath [ pkgs.git pkgs.perl ]
              }
            '';

            outputs = [ "out" "dev" ];
          };
        });

      defaultPackage =
        forAllSystems (system: self.packages.${system}.pr-status);
      devShells = forAllSystems (system:
        let pkgs = nixpkgsFor.${system};
        npPackages = with pkgs; [
          elmPackages.elm
          elmPackages.elm-test
          elmPackages.elm-live
          elmPackages.elm-json
        ];
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
            ] ++ npPackages;
          };
        });
    };
}

