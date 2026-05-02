# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## What This Repository Is

A **Nix flake** that packages and distributes [`vite-plus`](https://www.npmjs.com/package/vite-plus) (version pinned in `flake.nix`) as a reusable Nix package. Other projects add this flake as an input to get the `vite-plus` CLI tool and its associated binaries (`oxlint`, `oxfmt`) in their dev shells.

## Commands

This is a pure Nix project — there is no `package.json` or `Makefile` at the root.

```bash
nix build          # Build the vite-plus package
nix develop        # Enter the dev shell (nodejs, corepack, vite-plus available)
nix eval           # Evaluate flake expressions
```

## Architecture

`flake.nix` uses a two-stage build:

1. **"prepared" derivation** (fixed-output): Fetches the npm tarball from the registry (not GitHub — the tarball includes pre-built `dist/` and NAPI binaries), strips unpublished monorepo devDependencies, injects `typescript` as a direct dependency (needed for `vp pack --dts`), and generates `package-lock.json` via `npm install --package-lock-only`. This stage runs with network access.

2. **`buildNpmPackage`**: Standard Nix npm packaging that consumes the prepared `package.json` and lock file. Sets `dontNpmBuild = true` (dist/ is already built). Wraps all `$out/bin/*` with `makeWrapper` to prepend `$out/bin` to `PATH` — this lets `vp` spawn sibling binaries (e.g., `vp migrate` calling `vp install`) even from outside the store.

### Key design decisions

- `fetchurl` over `fetchFromGitHub` because the npm tarball bundles pre-built native binaries.
- `NODE_EXTRA_CA_CERTS` is set in the prepared derivation for SSL in the Nix sandbox.
- `HOME` is redirected to `$TMPDIR` for reproducible builds.
- Node.js version is pinned so binary cache hits are consistent across machines.

### `example/`

A minimal working example showing how a downstream project consumes this flake — adds `nodejs`, `corepack`, and `vite-plus` to its `devShell`. Uses `.envrc` with `use flake` for direnv integration.

## Updating the Packaged Version

1. Change the version string near the top of `flake.nix`.
2. Update the `fetchurl` URL and `sha256`/`hash` for the new npm tarball.
3. Update the fixed-output hash of the "prepared" derivation (run `nix build` with a dummy hash to get the correct one from the error).
4. Run `nix build` to verify the full build succeeds.
