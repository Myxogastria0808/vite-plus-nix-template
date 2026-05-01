{
  description = "vite-plus-nix-template";
  inputs = {
    nixpkgs.url = "github:NixOS/nixpkgs/nixpkgs-unstable";
    flake-utils.url = "github:numtide/flake-utils";
  };

  outputs =
    inputs:
    inputs.flake-utils.lib.eachDefaultSystem (
      system:
      let
        pkgs = inputs.nixpkgs.legacyPackages.${system};

        # fetchurl (not fetchFromGitHub) because the npm tarball ships pre-built dist/
        # and native NAPI binaries as optionalDependencies. Building from the GitHub
        # source would require Rust + napi-rs compilation.
        vite-plus =
          let
            version = "0.1.20";

            src = pkgs.fetchurl {
              url = "https://registry.npmjs.org/vite-plus/-/vite-plus-${version}.tgz";
              hash = "sha256-sIQWJmClPT+noDGtceZENSpY7QqqHRxEKDG/61XoEuA=";
            };

            # Fixed-output derivation: declares its output hash upfront, which permits
            # network access during the build. Nix verifies the hash after the build;
            # a mismatch is a build error. fetchurl and fetchFromGitHub use the same
            # mechanism internally.
            #
            # Purpose: the npm tarball lacks package-lock.json (required by buildNpmPackage).
            # This derivation generates one via `npm install --package-lock-only` after
            # stripping private devDependencies from package.json.
            #
            # To update (e.g. on a version bump):
            #   1. Set outputHash = pkgs.lib.fakeHash
            #   2. Run `nix develop` — Nix will fail and print the actual hash
            #   3. Replace outputHash with the printed value
            prepared = pkgs.stdenv.mkDerivation {
              name = "vite-plus-${version}-prepared";
              inherit src;
              sourceRoot = "package";

              nativeBuildInputs = with pkgs; [
                nodejs
                cacert
              ];

              # The Nix build sandbox has no system SSL certificates. NODE_EXTRA_CA_CERTS
              # points Node.js to the CA bundle from pkgs.cacert so npm's HTTPS connections
              # to the registry succeed.
              NODE_EXTRA_CA_CERTS = "${pkgs.cacert}/etc/ssl/certs/ca-bundle.crt";

              buildPhase = ''
                # Nix intentionally sets HOME to /homeless-shelter, a non-writable dummy
                # directory, rather than leaving it unset. This forces build scripts that
                # write to $HOME (e.g. ~/.npm cache) to fail loudly, making the dependency
                # on a home directory explicit. The design goal is that Nix builds should
                # be fully reproducible without relying on any user home directory.
                # npm tries to write its cache to ~/.npm, so we redirect HOME to $TMPDIR,
                # a per-build writable temporary directory provided by the sandbox.
                export HOME="$TMPDIR"

                # The published package.json references private monorepo packages
                # (e.g. @voidzero-dev/vite-plus-test) that are not published to npm.
                # npm fails with a peer-dependency resolution error when it encounters them,
                # so we strip devDependencies and scripts before generating the lock file.
                node -e "
                  const fs = require('fs');
                  const pkg = JSON.parse(fs.readFileSync('package.json', 'utf8'));
                  delete pkg.devDependencies;
                  delete pkg.scripts;
                  fs.writeFileSync('package.json', JSON.stringify(pkg, null, 2));
                "

                # Generate package-lock.json without installing anything.
                # --package-lock-only skips actual installation; --ignore-scripts
                # suppresses lifecycle scripts.
                npm install --package-lock-only --ignore-scripts
              '';

              # Copy the generated files to $out so buildNpmPackage's postPatch can
              # reference them via ${prepared}. stdenv does not create $out automatically.
              # outputHashMode = "recursive" hashes the entire $out directory as a NAR archive.
              installPhase = ''
                mkdir $out
                cp package.json      $out/
                cp package-lock.json $out/
              '';

              outputHashMode = "recursive";
              outputHashAlgo = "sha256";
              outputHash = "sha256-r+JSbywCN1mtI1KfHXxi0d57aNsi0HW9zCdO1Y+gIAQ=";
            };
          in
          pkgs.buildNpmPackage {
            pname = "vite-plus";
            inherit version src;
            sourceRoot = "package";
            # Pin to pkgs.nodejs (LTS) so npmHooks uses a binary-cached Node.js.
            # Without this, buildNpmPackage may resolve a different nodejs from the
            # callPackage context that isn't in the binary cache and must be compiled
            # from source (~60 min).
            nodejs = pkgs.nodejs;
            postPatch = ''
              cp ${prepared}/package.json      package.json
              cp ${prepared}/package-lock.json package-lock.json
            '';
            npmDepsHash = "sha256-oBjJF5FQCebsvKi76YcSlsUJWTT7G5xM4jspu+aIKdE=";
            dontNpmBuild = true; # dist/ is pre-built in the npm tarball
          };
      in
      {
        devShells.default = pkgs.mkShell {
          packages = with pkgs; [
            corepack
            vite-plus
          ];

        };
      }
    );
}

