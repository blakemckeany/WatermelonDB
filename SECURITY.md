# Security

## Encryption at rest

This fork of WatermelonDB enables full-database encryption by default via
[SQLCipher Community Edition](https://www.zetetic.net/sqlcipher/). The
on-disk database is encrypted with AES-256-CBC, with HMAC-SHA512 page
authentication and PBKDF2 key derivation (256,000 rounds, per-database
salt) per SQLCipher 4's defaults.

### What we encrypt

- The SQLite database file containing your records (`*.db`).
- The WAL and SHM sidecar files written during writes.

### What we do NOT encrypt

- The schema cache file (if any) and any other adapter-internal metadata
  outside the SQLite file.
- The Loki/IndexedDB browser adapter — that path is not within scope.
- The legacy `NativeModules` bridge — if you instantiate `SQLiteAdapter`
  without `jsi: true`, the database is opened by the bridge unencrypted
  and a warning is logged at startup.

### Your responsibilities

You are responsible for **supplying** and **storing** the passphrase. The
library does not generate, derive, or persist a key for you — by design.

- Store the passphrase in the platform secure enclave:
  - iOS: [Keychain Services](https://developer.apple.com/documentation/security/keychain_services)
    (e.g. `react-native-keychain`).
  - Android: [Android Keystore](https://developer.android.com/training/articles/keystore)
    via `EncryptedSharedPreferences` (e.g. `react-native-keychain`).
  - Expo: `expo-secure-store`.
- Treat the passphrase as PII: never log it, never send it over the network,
  never commit it to version control.
- Decide an appropriate key-rotation policy. SQLCipher supports
  `PRAGMA rekey = 'new-key'` for in-place rekeying, but this fork does not
  expose that API yet — you would need to rewrite the database.

### Threat model

| Threat                                         | Mitigated? |
| ---------------------------------------------- | ---------- |
| Physical access, device powered down, FDE off  | ✅          |
| Stolen device backup (iCloud / Google Backup)  | ✅          |
| Rooted/jailbroken device, attacker has shell   | ⚠️ Only if the passphrase is not in memory at the moment of compromise. The passphrase lives in JS heap during initialization. |
| Compromised RN bundle / supply-chain attack    | ❌ The bundle has access to the running passphrase. Use code signing and integrity checks. |
| Forensic memory dump while DB is open          | ❌ SQLCipher keeps the key in process memory while the DB is open. |

## Reporting Security Issues

If you believe you've found a security vulnerability in this fork of
WatermelonDB, please open a private security advisory on the GitHub
repository.

Upstream WatermelonDB vulnerabilities can be reported at
<https://nozbe.com/bug-bounty/>.
