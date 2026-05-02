---
name: update-version
description: A skill that fetches the latest published version of vite-plus from the npm registry and updates the version string and all three hash values in `flake.nix`.
disable-model-invocation: false
---

# Update vite-plus Version and Hashes

## Step 1: Fetch the latest version from npm

Run the following to get the latest published version:

```bash
curl -s https://registry.npmjs.org/vite-plus/latest | jq -r '.version'
```

Read the current version from `flake.nix`. If the current version already matches the latest, report that the package is already up to date and stop.

## Step 2: Update the version and URL in flake.nix

Rewrite the following lines in `flake.nix` with the new version:

- `version = "X.Y.Z";`
- The version string inside the `fetchurl` `url`

Leave `hash` unchanged for now — it will be updated in the next step.

## Step 3: Update the fetchurl hash

Run the following to fetch the correct sha256 hash of the new npm tarball:

```bash
nix store prefetch-file --json --hash-type sha256 "https://registry.npmjs.org/vite-plus/-/vite-plus-<NEW_VERSION>.tgz"
```

Extract the `hash` field from the JSON output and update `hash = "sha256-...";` in `flake.nix`.

## Step 4: Update the outputHash of the prepared derivation

Temporarily replace `outputHash` in `flake.nix` with a dummy value:

```
outputHash = "sha256-AAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAA=";
```

Then run `nix build 2>&1`. Nix will print a hash mismatch error like:

```
error: hash mismatch in fixed-output derivation ...
  specified: sha256-AAAA...
       got:    sha256-xxxx...
```

Replace `outputHash` with the value shown after `got:`.

## Step 5: Update npmDepsHash

Temporarily replace `npmDepsHash` in `flake.nix` with a dummy value:

```
npmDepsHash = "sha256-AAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAA=";
```

Then run `nix build 2>&1` again and extract the correct hash from the `got:` line in the error output. Update `npmDepsHash` with that value.

## Step 6: Verify the build

Run `nix build` and confirm it succeeds. Report the old version, the new version, and all updated hash values to the user.

### Constraints

- `nix build` requires network access and may take a while.
- Always use SRI format for hashes: `sha256-<base64>=`.
- Steps 4 and 5 must be done in order — `outputHash` must be correct before `buildNpmPackage` is reached.
- Use `sha256-AAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAA=` as the dummy hash (44 `A` characters followed by `=`).

