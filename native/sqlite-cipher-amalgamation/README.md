# SQLCipher amalgamation (vendored at build time)

This directory is the build-time destination for SQLCipher Community
Edition's `sqlite3.c` and `sqlite3.h`. It is **intentionally empty in the
git repository** — the actual sources are large (~10 MB) and are fetched
by `scripts/vendor-sqlcipher.sh` so we don't carry a vendored blob in git
history.

## How to populate

```bash
yarn vendor:sqlcipher
# or directly:
bash scripts/vendor-sqlcipher.sh
```

This runs automatically as part of `yarn install` (npm `postinstall`
hook), so a fresh clone + `yarn` should produce a fully buildable tree.

## Why not commit the .c file?

1. Reviewability — a 10 MB single-file generated amalgamation defeats `git
   diff` and inflates the repo by ~50% per version bump.
2. Provenance — the vendor script pins a specific SQLCipher tag and
   verifies its SHA-256 before installing. A blob in git is opaque.
3. Licensing hygiene — distributing the SQLCipher sources alongside our
   own code without conspicuous notice raises questions; downloading it
   on demand makes the provenance obvious.

If you prefer to commit the amalgamation in your own fork (for example,
for fully offline builds), simply run the vendor script once and commit
the resulting `sqlite3.c` / `sqlite3.h`. The build system does not care
whether the files arrived from git or from the postinstall script.

## See also

- `scripts/vendor-sqlcipher.sh` — the fetcher
- `NOTICE` (this directory) — attribution and license
- `WatermelonDB.podspec` — iOS path (uses the `SQLCipher` CocoaPod instead
  of this directory)
- `native/android-jsi/src/main/cpp/CMakeLists.txt` — Android path (this is
  where the amalgamation gets compiled in)
