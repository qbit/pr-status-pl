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
            perl' = pkgs.perl.withPackages (pp:
              [
                pp.Mojolicious
                pp.JSON
                pp.Git
              ]);
        in {
          pr-status = pkgs.perlPackages.buildPerlPackage {
            pname = "pr-status";
            version = "v0.0.4";
            src = ./.;
            buildInputs = with pkgs; [ makeWrapper ];
            propagatedBuildInputs = [
              perl'
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
            perl' = pkgs.perl.withPackages (pp: with pp; [
              Git
              JSON
              Mojolicious
            ]);
        npPackages = with pkgs; [
          elmPackages.elm
          elmPackages.elm-test
          elmPackages.elm-live
          elmPackages.elm-json
          perl'
        ];
        in {
          default = pkgs.mkShell {
            shellHook = ''
              PS1='\u@\h:\@; '
              nix run github:qbit/xin#flake-warn
              echo "Perl `${pkgs.perl}/bin/perl --version`"
            '';
            buildInputs = [
            ] ++ npPackages;
          };
        });
    };
}

