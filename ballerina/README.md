## Overview

This module provides a PostgreSQL-backed short-term memory store to use with AI messages (e.g., with AI agents, model providers, etc.).

### Key Features

- PostgreSQL-backed persistent storage for short-term AI message memory
- Configurable per-key capacity, surfaced via `getCapacity()` and `isFull()` for the `ai:ShortTermMemory` overflow handler to manage trimming
- Built-in in-memory caching for improved read performance
- Support for both direct database configuration and existing PostgreSQL client reuse

## Prerequisites

- Configuration for a PostgreSQL database

## Quickstart

Follow the steps below to use this store in your Ballerina application:

1. Import the `ballerinax/ai.memory.postgresql` module.

```ballerina
import ballerinax/ai.memory.postgresql;
```

Optionally, import the `ballerina/ai` and/or `ballerinax/postgresql` module(s).

```ballerina
import ballerina/ai;
import ballerinax/postgresql;
```

2. Create the short-term memory store, by passing either the configuration for the database or a `postgresql:Client` client.

    i. Using the configuration

    ```ballerina
    import ballerina/ai;
    import ballerinax/ai.memory.postgresql;

    configurable string host = ?;
    configurable string username = ?;
    configurable string password = ?;
    configurable string database = ?;

    ai:ShortTermMemoryStore store = check new postgresql:ShortTermMemoryStore({
        host, username, password, database
    });
    ```

    ii. Using a `postgresql:Client` client

    ```ballerina
    import ballerina/ai;
    import ballerinax/postgresql;
    import ballerinax/ai.memory.postgresql as postgresqlStore;

    configurable string host = ?;
    configurable string username = ?;
    configurable string password = ?;
    configurable string database = ?;

    postgresql:Client postgresqlClient = check new (host = host, username = username, password = password, database = database);
    ai:ShortTermMemoryStore store = check new postgresqlStore:ShortTermMemoryStore(postgresqlClient);
    ```

    Optionally, specify the per-key message capacity (`maxMessagesPerKey` - defaults to `20`), the configuration for the in-memory cache for messages (`cacheConfig` - defaults to no cache), and/or the table name (`tableName` - defaults to `"chat_messages"`).

    > **Note**: `maxMessagesPerKey` is an advisory capacity reported via `getCapacity()`/`isFull()`. The store does not reject messages that exceed it; trimming is performed by the `ai:ShortTermMemory` overflow handler.

    ```ballerina
    ai:ShortTermMemoryStore store = check new postgresql:ShortTermMemoryStore({
        host, username, password, database
    }, 10, {capacity: 10});
    ```

> **Note on table naming**: PostgreSQL folds unquoted identifiers to lower case. The default table name `chat_messages` and the validation regex (`^[A-Za-z_][A-Za-z0-9_]*$`) keep things simple — any value supplied via the `tableName` argument is inlined unquoted into SQL and will therefore be lowercased by PostgreSQL.

## Schema

On initialization, the store creates the following objects in the connected database (using `CREATE … IF NOT EXISTS`, so it is safe to re-run):

```sql
CREATE TABLE chat_messages (
    id BIGINT GENERATED ALWAYS AS IDENTITY PRIMARY KEY,
    message_key TEXT NOT NULL,
    message_role TEXT NOT NULL CHECK (message_role IN ('user', 'system', 'assistant', 'function')),
    message_json TEXT NOT NULL,
    created_at TIMESTAMPTZ NOT NULL DEFAULT NOW()
);

CREATE INDEX chat_messages_key_id_idx
    ON chat_messages (message_key, id);

CREATE UNIQUE INDEX chat_messages_system_uidx
    ON chat_messages (message_key) WHERE message_role = 'system';
```

Messages are ordered by the monotonically-increasing `id` column. The `created_at` column is identical for all rows inserted within a single transaction (such as a batch insert from `put` with multiple messages), so it cannot be relied on for ordering; `id` is used instead.

The partial unique index enforces the "at most one system message per key" invariant and powers the upsert via `INSERT … ON CONFLICT … DO UPDATE`.
