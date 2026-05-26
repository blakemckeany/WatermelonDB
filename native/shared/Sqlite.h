#pragma once

#include <string>
#include <sqlite3.h>

namespace watermelondb {

// Lightweight wrapper for handling sqlite3 lifetime
class SqliteDb {
public:
    // `passphrase` must be a non-empty string; the database is opened with
    // SQLCipher's sqlite3_key and probed before returning, so a wrong key
    // surfaces as a thrown std::runtime_error rather than silent corruption.
    SqliteDb(std::string path, const std::string &passphrase);
    ~SqliteDb();
    void destroy();

    sqlite3 *sqlite;

    SqliteDb &operator=(const SqliteDb &) = delete;
    SqliteDb(const SqliteDb &) = delete;

private:
    bool isDestroyed_;
};

class SqliteStatement {
public:
    SqliteStatement(sqlite3_stmt *statement);
    ~SqliteStatement();

    sqlite3_stmt *stmt;

    void reset();
};

} // namespace watermelondb

