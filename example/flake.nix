{
  description = "Example: using vite-plus-nix-template in your own project";

  inputs = {
    nixpkgs.url = "github:NixOS/nixpkgs/nixpkgs-unstable";
    flake-utils.url = "github:numtide/flake-utils";

    vite-plus-nix.url = "github:Myxogastria0808/vite-plus-nix-template";
  };

  outputs =
    inputs:
    inputs.flake-utils.lib.eachDefaultSystem (
      system:
      let
        pkgs = inputs.nixpkgs.legacyPackages.${system};
        vite-plus = inputs.vite-plus-nix.packages.${system}.vite-plus;
      in
      {
        devShells.default = pkgs.mkShell {
          packages = [
            pkgs.corepack
            vite-plus
          ];
        };
      }
    );
}

