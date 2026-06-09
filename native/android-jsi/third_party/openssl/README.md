# OpenSSL libcrypto (vendored at build time)

This directory is the build-time destination for a static, 16 KB
page-aligned `libcrypto.a` built from pinned OpenSSL LTS source, one
subdirectory per Android ABI:

```
<abi>/lib/libcrypto.a
<abi>/include/openssl/*.h
```

The binaries are **intentionally absent from the git repository** — they
are built by `scripts/vendor-openssl.sh` (wired into the npm `postinstall`
hook) and included in the released dist tarball, so consuming apps get
prebuilt archives and need no NDK-at-install-time step.

## Why this replaces the OpenSSL prefab

The previous source of libcrypto, Google's NDK prefab
`com.android.ndk.thirdparty:openssl:1.1.1q-beta-1`, ships prebuilt
`libcrypto.so` / `libssl.so` that are only 4 KB page-aligned (OpenSSL
1.1.1q, built 2022; the project is abandoned and no 16 KB build exists).
Google Play requires 16 KB page size support for new apps/updates
targeting Android 15+, so that prefab can never pass review.

Building libcrypto from source as a *static* archive and linking it into
`libwatermelondb-jsi.so` — which is already linked with
`-Wl,-z,max-page-size=16384` — folds the crypto code into an
already-compliant library, so no separate (misaligned) `.so` ships at all.
SQLCipher's codec only needs libcrypto; libssl (TLS) is dropped entirely.

## How to populate

```bash
yarn vendor:openssl
# or directly:
bash scripts/vendor-openssl.sh
```

Requires Android NDK r27+ (set `ANDROID_NDK_HOME`, or have
`$ANDROID_HOME/ndk/27.*`). The script pins an OpenSSL version, verifies
its SHA-256, and is idempotent. Without an NDK it skips gracefully —
the Android build's CMakeLists fails loudly if the archives are missing.

## See also

- `scripts/vendor-openssl.sh` — the builder (pinned version + SHA-256)
- `NOTICE` (this directory) — attribution and license
- `native/android-jsi/src/main/cpp/CMakeLists.txt` — where libcrypto.a is
  imported and linked
- `native/sqlite-cipher-amalgamation/` — the SQLCipher engine this serves
