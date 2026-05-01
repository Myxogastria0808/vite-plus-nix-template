# vite-plus (Vite+) nixpkg

Nix flake that provides [vite-plus](https://www.npmjs.com/package/vite-plus) as a package.

## Usage

Add this flake as an input in your `flake.nix`:

```nix
{
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
```

See [`example/`](./example) for a working example.

