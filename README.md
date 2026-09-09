# Ballerina PostgreSQL-backed short-term chat message store connector

[![Build](https://github.com/ballerina-platform/module-ballerinax-ai.memory.postgresql/actions/workflows/ci.yml/badge.svg)](https://github.com/ballerina-platform/module-ballerinax-ai.memory.postgresql/actions/workflows/ci.yml)
[![GitHub Last Commit](https://img.shields.io/github/last-commit/ballerina-platform/module-ballerinax-ai.memory.postgresql.svg)](https://github.com/ballerina-platform/module-ballerinax-ai.memory.postgresql/commits/main)
[![GitHub Issues](https://img.shields.io/github/issues/ballerina-platform/ballerina-library/module/ai.memory.postgresql.svg?label=Open%20Issues)](https://github.com/ballerina-platform/ballerina-library/labels/module%2Fai.memory.postgresql)

## Overview

This module provides a PostgreSQL-backed short-term memory store to use with AI messages (e.g., with AI agents, model providers, etc.).

## Prerequisites

- Configuration for a PostgreSQL database
- The database tables described below

### Database tables

This store uses two tables, one for the chat history and one for human-in-the-loop pause state. You name them with the `tableName` and `checkpointTableName` parameters when creating the store. Production deployments are expected to provision both up front, typically by a DBA, rather than relying on the application to create them.

The chat history table is created at initialization if it does not already exist, which is convenient for development, but in production create it beforehand. Use the name you pass as `tableName`, which defaults to `chat_messages`:

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

The checkpoint table holds human-in-the-loop pause state. The store never creates it, so it must exist before an agent with approval-gated tools runs. A deployment that does not use human-in-the-loop does not need it at all. Use the name you pass as `checkpointTableName`, which defaults to `checkpoints`:

```sql
CREATE TABLE checkpoints (
    session_id TEXT PRIMARY KEY,
    approval_json TEXT NOT NULL,
    updated_at TIMESTAMPTZ NOT NULL DEFAULT NOW()
);
```

> **Note on table naming**: PostgreSQL folds unquoted identifiers to lower case. The default table names and the validation regex (`^[A-Za-z_][A-Za-z0-9_]*$`) keep things simple — any value supplied via the `tableName`/`checkpointTableName` arguments is inlined unquoted into SQL and will therefore be lowercased by PostgreSQL.

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

    Optionally, specify the per-key message capacity (`maxMessagesPerKey` - defaults to `20`) and/or the table name (`tableName` - defaults to `"chat_messages"`).

    > **Note**: `maxMessagesPerKey` is an advisory capacity reported via `getCapacity()`/`isFull()`. The store does not reject messages that exceed it; trimming is performed by the `ai:ShortTermMemory` overflow handler.

    ```ballerina
    ai:ShortTermMemoryStore store = check new postgresql:ShortTermMemoryStore({
        host, username, password, database
    }, 10);
    ```

## Build from the source

### Setting up the prerequisites

1. Download and install Java SE Development Kit (JDK) version 21. You can download it from either of the following sources:

    * [Oracle JDK](https://www.oracle.com/java/technologies/downloads/)
    * [OpenJDK](https://adoptium.net/)

   > **Note:** After installation, remember to set the `JAVA_HOME` environment variable to the directory where JDK was installed.

2. Download and install [Ballerina Swan Lake](https://ballerina.io/).

3. Download and install [Docker](https://www.docker.com/get-started).

   > **Note**: Ensure that the Docker daemon is running before executing any tests.

4. Export Github Personal access token with read package permissions as follows,

    ```bash
    export packageUser=<Username>
    export packagePAT=<Personal access token>
    ```

### Build options

Execute the commands below to build from the source.

1. To build the package:

   ```bash
   ./gradlew clean build
   ```

2. To run the tests:

   ```bash
   ./gradlew clean test
   ```

3. To build without the tests:

   ```bash
   ./gradlew clean build -x test
   ```

4. To run tests against different environments:

   ```bash
   ./gradlew clean test -Pgroups=<Comma separated groups/test cases>
   ```

5. To debug the package with a remote debugger:

   ```bash
   ./gradlew clean build -Pdebug=<port>
   ```

6. To debug with the Ballerina language:

   ```bash
   ./gradlew clean build -PbalJavaDebug=<port>
   ```

7. Publish the generated artifacts to the local Ballerina Central repository:

    ```bash
    ./gradlew clean build -PpublishToLocalCentral=true
    ```

8. Publish the generated artifacts to the Ballerina Central repository:

   ```bash
   ./gradlew clean build -PpublishToCentral=true
   ```

## Contribute to Ballerina

As an open-source project, Ballerina welcomes contributions from the community.

For more information, go to the [contribution guidelines](https://github.com/ballerina-platform/ballerina-lang/blob/master/CONTRIBUTING.md).

## Code of conduct

All the contributors are encouraged to read the [Ballerina Code of Conduct](https://ballerina.io/code-of-conduct).

## Useful links

* For more information go to the [`ai.memory.postgresql` package](https://central.ballerina.io/ballerinax/ai.memory.postgresql/latest).
* For example demonstrations of the usage, go to [Ballerina By Examples](https://ballerina.io/learn/by-example/).
* Chat live with us via our [Discord server](https://discord.gg/ballerinalang).
* Post all technical questions on Stack Overflow with the [#ballerina](https://stackoverflow.com/questions/tagged/ballerina) tag.
