## Overview

This module provides a PostgreSQL-backed short-term memory store to use with AI messages (e.g., with AI agents, model providers, etc.).

### Key Features

- PostgreSQL-backed persistent storage for short-term AI message memory
- Configurable maximum messages per key with automatic eviction
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
    configurable string user = ?;
    configurable string password = ?;
    configurable string database = ?;

    ai:ShortTermMemoryStore store = check new postgresql:ShortTermMemoryStore({
        host, user, password, database
    });
    ```

    ii. Using a `postgresql:Client` client

    ```ballerina
    import ballerina/ai;
    import ballerinax/postgresql;
    import ballerinax/ai.memory.postgresql as postgresqlStore;

    configurable string host = ?;
    configurable string user = ?;
    configurable string password = ?;
    configurable string database = ?;

    postgresql:Client postgresqlClient = check new (host = host, username = user, password = password, database = database);
    ai:ShortTermMemoryStore store = check new postgresqlStore:ShortTermMemoryStore(postgresqlClient);
    ```

    Optionally, specify the maximum number of messages to store per key (`maxMessagesPerKey` - defaults to `20`), the configuration for the in-memory cache for messages (`cacheConfig` - defaults to no cache), and/or the table name (`tableName` - defaults to `"chat_messages"`).

    ```ballerina
    ai:ShortTermMemoryStore store = check new postgresql:ShortTermMemoryStore({
        host, user, password, database
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

CREATE INDEX chat_messages_key_created_idx
    ON chat_messages (message_key, created_at);

CREATE UNIQUE INDEX chat_messages_system_uidx
    ON chat_messages (message_key) WHERE message_role = 'system';
```

The partial unique index enforces the "at most one system message per key" invariant and powers the upsert via `INSERT … ON CONFLICT … DO UPDATE`.
