### Highlights

- **Encryption-at-rest is now mandatory.** This fork ships SQLCipher (Community Edition, AES-256) as its SQLite engine. `SQLiteAdapter` requires a non-empty `passphrase: string` option, and the database file on disk is fully encrypted.

### BREAKING CHANGES

- **`SQLiteAdapter` now requires a `passphrase: string` option.** Omitting it (or passing an empty string) will throw at construction time. Supply the key from Keychain (iOS) / Android Keystore / Expo SecureStore — never hard-code it in your bundle.
- **Encryption only applies on the JSI path.** If you instantiate `SQLiteAdapter` without `jsi: true`, the database is opened by the legacy `NativeModules` bridge unencrypted, and a warning is logged. To get encryption, set `jsi: true`.
- **Plain SQLite databases from upstream WatermelonDB cannot be opened by this build.** SQLCipher and stock SQLite read different file headers. To migrate existing data, open the old database with upstream `@nozbe/watermelondb`, export via your sync layer, then re-import into a freshly created encrypted DB.
- **iOS**: the podspec no longer links the system `sqlite3` library; it now depends on the `SQLCipher` (~> 4.6) CocoaPod. `pod install` will pull this transitively. No additional Podfile changes are needed.
- **Android (JSI)**: the JSI library now bundles the SQLCipher amalgamation instead of upstream `@nozbe/sqlite`. Your host app's `minSdkVersion` must be at least 21 (Android 5.0) to satisfy the bundled OpenSSL prefab.

### Deprecations

### New features

- New `passphrase` option on `SQLiteAdapter` — see Installation > Encryption at rest.
- `scripts/vendor-sqlcipher.sh` (run automatically by `yarn install`) fetches and builds the pinned SQLCipher Community Edition amalgamation. Override with `SQLCIPHER_VERSION=…` if you need a custom build.

### Fixes

- [LokiJS] Multitab sync issue fix
- [Android] Added linker flag for building with 16kB page alignment
- [TS] make catchError visible to typescript

### Performance

### Changes

- Updated better-sqlite3 to 11.9.1

### Internal

- Updated internal dependencies
- Updated documentation scripts
