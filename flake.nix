{
  description = "Official Epic Games Launcher for Linux";

  inputs.nixpkgs.url = "github:NixOS/nixpkgs/nixos-unstable";

  outputs =
    { self, nixpkgs }:
    let
      inherit (nixpkgs) lib;
      systems = [ "x86_64-linux" ];
      forAllSystems = lib.genAttrs systems;
      pkgsFor =
        system:
        import nixpkgs {
          inherit system;
          config.allowUnfree = true;
          overlays = [ self.overlays.default ];
        };
    in
    {
      overlays.default = final: _prev: {
        epic-games-launcher = final.callPackage ./pkgs/epic-games-launcher.nix { };
      };

      packages = forAllSystems (
        system:
        let
          pkgs = pkgsFor system;
        in
        {
          default = pkgs.epic-games-launcher;
          epic-games-launcher = pkgs.epic-games-launcher;
        }
      );

      apps = forAllSystems (
        system:
        let
          pkg = self.packages.${system}.epic-games-launcher;
        in
        {
          default = {
            type = "app";
            program = "${pkg}/bin/epic-games-launcher";
          };
          epic-games-launcher = {
            type = "app";
            program = "${pkg}/bin/epic-games-launcher";
          };
        }
      );

      formatter = forAllSystems (system: (pkgsFor system).nixfmt);
    };
}
