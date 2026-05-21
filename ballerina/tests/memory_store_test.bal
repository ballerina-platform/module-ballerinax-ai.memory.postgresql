// Copyright (c) 2026 WSO2 LLC (http://www.wso2.com).
//
// WSO2 LLC. licenses this file to you under the Apache License,
// Version 2.0 (the "License"); you may not use this file except
// in compliance with the License.
// You may obtain a copy of the License at
//
// http://www.apache.org/licenses/LICENSE-2.0
//
// Unless required by applicable law or agreed to in writing,
// software distributed under the License is distributed on an
// "AS IS" BASIS, WITHOUT WARRANTIES OR CONDITIONS OF ANY
// KIND, either express or implied.  See the License for the
// specific language governing permissions and limitations
// under the License.

import ballerina/ai;
import ballerina/cache;
import ballerina/sql;
import ballerina/test;
import ballerinax/postgresql;

const string K1 = "key1";
const string K2 = "key2";
const string K3 = "key3";

const string DB_HOST = "localhost";
const string DB_USER = "postgres";
const string DB_PASSWORD = "Test-1234#";
const string DB_NAME = "message_db";
const string CUSTOM_TABLE = "custom_chat_messages";

const ai:ChatSystemMessage K1SM1 = {role: ai:SYSTEM, content: "You are a helpful assistant that is aware of the weather."};

const ai:ChatUserMessage K1M1 = {role: ai:USER, content: "Hello, my name is Alice. I'm from Seattle."};
final readonly & ai:ChatAssistantMessage k1m2 = {role: ai:ASSISTANT, content: "Hello Alice, what can I do for you?"};
const ai:ChatUserMessage K1M3 = {role: ai:USER, content: "I would like to know the weather today."};
final readonly & ai:ChatAssistantMessage K1M4 = {
    role: ai:ASSISTANT,
    content: "The weather in Seattle today is mostly cloudy with occasional showers and a high around 58°F."
};

const ai:ChatUserMessage K2M1 = {role: ai:USER, content: "Hello, my name is Bob."};

const ai:ChatUserMessage OM1 = {role: ai:USER, content: "overflow message 1"};
const ai:ChatUserMessage OM2 = {role: ai:USER, content: "overflow message 2"};
const ai:ChatUserMessage OM3 = {role: ai:USER, content: "overflow message 3"};
const ai:ChatUserMessage OM4 = {role: ai:USER, content: "overflow message 4"};
const ai:ChatUserMessage OM5 = {role: ai:USER, content: "overflow message 5"};
const ai:ChatUserMessage OM6 = {role: ai:USER, content: "overflow message 6"};

isolated postgresql:Client? modCl = ();

@test:BeforeSuite
function initClient() returns error? {
    lock {
        modCl = check new (host = DB_HOST, username = DB_USER, password = DB_PASSWORD, database = DB_NAME);
    }
}

@test:AfterSuite
function closeClient() returns error? {
    lock {
        postgresql:Client? cl = modCl;
        if cl is postgresql:Client {
            check cl.close();
        }
    }
}

function getClient() returns postgresql:Client {
    lock {
        return <postgresql:Client>modCl;
    }
}

function dropTable() returns error? {
    postgresql:Client cl = getClient();
    _ = check cl->execute(`DROP TABLE IF EXISTS chat_messages`);
}

@test:Config {
    before: dropTable
}
function testBasicStore() returns error? {
    postgresql:Client cl = getClient();
    ShortTermMemoryStore store = check new (cl);

    check store.put(K1, K1SM1);
    check store.put(K1, K1M1);
    check store.put(K1, k1m2);
    check store.put(K2, K2M1);

    check assertFromDatabase(cl, K1, [K1SM1], SYSTEM);
    check assertFromDatabase(cl, K1, [K1M1, k1m2], INTERACTIVE);
    check assertFromDatabase(cl, K1, [K1SM1, K1M1, k1m2]);

    check assertAllMessages(store, K1, [K1SM1, K1M1, k1m2]);
    check assertSystemMessage(store, K1, K1SM1);
    check assertInteractiveMessages(store, K1, [K1M1, k1m2]);

    check assertFromDatabase(cl, K2, [], SYSTEM);
    check assertFromDatabase(cl, K2, [K2M1], INTERACTIVE);
    check assertFromDatabase(cl, K2, [K2M1]);

    check assertAllMessages(store, K2, [K2M1]);
    check assertSystemMessage(store, K2, ());
    check assertInteractiveMessages(store, K2, [K2M1]);

    check store.removeAll(K1);

    check assertFromDatabase(cl, K1, [], SYSTEM);
    check assertFromDatabase(cl, K1, [], INTERACTIVE);
    check assertFromDatabase(cl, K1, []);

    check assertAllMessages(store, K1, []);
    check assertSystemMessage(store, K1, ());
    check assertInteractiveMessages(store, K1, []);

    check assertFromDatabase(cl, K2, [], SYSTEM);
    check assertFromDatabase(cl, K2, [K2M1], INTERACTIVE);
    check assertFromDatabase(cl, K2, [K2M1]);

    check assertAllMessages(store, K2, [K2M1]);
    check assertSystemMessage(store, K2, ());
    check assertInteractiveMessages(store, K2, [K2M1]);

    // Add more messages to K1 after deletion.
    check store.put(K1, K1M3);

    check assertFromDatabase(cl, K1, [], SYSTEM);
    check assertFromDatabase(cl, K1, [K1M3], INTERACTIVE);
    check assertFromDatabase(cl, K1, [K1M3]);

    check assertAllMessages(store, K1, [K1M3]);
    check assertSystemMessage(store, K1, ());
    check assertInteractiveMessages(store, K1, [K1M3]);
}

@test:Config {
    before: dropTable
}
function testRemoveSystemMessage() returns error? {
    postgresql:Client cl = getClient();
    ShortTermMemoryStore store = check new (cl);

    check store.put(K1, K1SM1);
    check store.put(K1, K1M1);
    check store.put(K1, k1m2);
    check store.put(K2, K2M1);

    check store.removeChatSystemMessage(K1);

    check assertFromDatabase(cl, K1, [], SYSTEM);
    check assertFromDatabase(cl, K1, [K1M1, k1m2], INTERACTIVE);
    check assertFromDatabase(cl, K1, [K1M1, k1m2]);

    check assertAllMessages(store, K1, [K1M1, k1m2]);
    check assertSystemMessage(store, K1, ());
    check assertInteractiveMessages(store, K1, [K1M1, k1m2]);

    check assertFromDatabase(cl, K2, [], SYSTEM);
    check assertFromDatabase(cl, K2, [K2M1], INTERACTIVE);
    check assertFromDatabase(cl, K2, [K2M1]);

    check assertAllMessages(store, K2, [K2M1]);
    check assertSystemMessage(store, K2, ());
    check assertInteractiveMessages(store, K2, [K2M1]);

    check store.removeChatSystemMessage(K2);

    check assertFromDatabase(cl, K2, [], SYSTEM);
    check assertFromDatabase(cl, K2, [K2M1], INTERACTIVE);
    check assertFromDatabase(cl, K2, [K2M1]);

    check assertAllMessages(store, K2, [K2M1]);
    check assertSystemMessage(store, K2, ());
    check assertInteractiveMessages(store, K2, [K2M1]);
}

@test:Config {
    before: dropTable
}
function testRemoveInteractiveMessages() returns error? {
    postgresql:Client cl = getClient();
    ShortTermMemoryStore store = check new (cl);

    check store.put(K1, K1SM1);
    check store.put(K1, K1M1);
    check store.put(K1, k1m2);
    check store.put(K2, K2M1);

    check store.removeChatInteractiveMessages(K1);

    check assertFromDatabase(cl, K1, [K1SM1], SYSTEM);
    check assertFromDatabase(cl, K1, [], INTERACTIVE);
    check assertFromDatabase(cl, K1, [K1SM1]);

    check assertAllMessages(store, K1, [K1SM1]);
    check assertSystemMessage(store, K1, K1SM1);
    check assertInteractiveMessages(store, K1, []);

    check assertFromDatabase(cl, K2, [], SYSTEM);
    check assertFromDatabase(cl, K2, [K2M1], INTERACTIVE);
    check assertFromDatabase(cl, K2, [K2M1]);

    check assertAllMessages(store, K2, [K2M1]);
    check assertSystemMessage(store, K2, ());
    check assertInteractiveMessages(store, K2, [K2M1]);

    check store.removeChatInteractiveMessages(K2);

    check assertFromDatabase(cl, K1, [K1SM1], SYSTEM);
    check assertFromDatabase(cl, K1, [], INTERACTIVE);
    check assertFromDatabase(cl, K1, [K1SM1]);

    check assertAllMessages(store, K1, [K1SM1]);
    check assertSystemMessage(store, K1, K1SM1);
    check assertInteractiveMessages(store, K1, []);

    check assertFromDatabase(cl, K2, [], SYSTEM);
    check assertFromDatabase(cl, K2, [], INTERACTIVE);
    check assertFromDatabase(cl, K2, []);

    check assertAllMessages(store, K2, []);
    check assertSystemMessage(store, K2, ());
    check assertInteractiveMessages(store, K2, []);
}

@test:Config {
    before: dropTable
}
function testRemoveAllMessages() returns error? {
    postgresql:Client cl = getClient();
    ShortTermMemoryStore store = check new (cl);

    check store.put(K1, K1SM1);
    check store.put(K1, K1M1);
    check store.put(K1, k1m2);
    check store.put(K2, K2M1);

    check store.removeAll(K1);

    check assertFromDatabase(cl, K1, [], SYSTEM);
    check assertFromDatabase(cl, K1, [], INTERACTIVE);
    check assertFromDatabase(cl, K1, []);

    check assertAllMessages(store, K1, []);
    check assertSystemMessage(store, K1, ());
    check assertInteractiveMessages(store, K1, []);

    check assertFromDatabase(cl, K2, [], SYSTEM);
    check assertFromDatabase(cl, K2, [K2M1], INTERACTIVE);
    check assertFromDatabase(cl, K2, [K2M1]);

    check assertAllMessages(store, K2, [K2M1]);
    check assertSystemMessage(store, K2, ());
    check assertInteractiveMessages(store, K2, [K2M1]);

    check store.removeAll(K2);

    check assertFromDatabase(cl, K1, [], SYSTEM);
    check assertFromDatabase(cl, K1, [], INTERACTIVE);
    check assertFromDatabase(cl, K1, []);

    check assertAllMessages(store, K1, []);
    check assertSystemMessage(store, K1, ());
    check assertInteractiveMessages(store, K1, []);

    check assertFromDatabase(cl, K2, [], SYSTEM);
    check assertFromDatabase(cl, K2, [], INTERACTIVE);
    check assertFromDatabase(cl, K2, []);

    check assertAllMessages(store, K2, []);
    check assertSystemMessage(store, K2, ());
    check assertInteractiveMessages(store, K2, []);
}

@test:Config {
    before: dropTable
}
function testRemovingSubsetOfInteractiveMessages() returns error? {
    postgresql:Client cl = getClient();
    ShortTermMemoryStore store = check new (cl);

    check store.put(K1, K1SM1);
    check store.put(K1, K1M1);
    check store.put(K1, k1m2);
    check store.put(K1, K1M3);
    check store.put(K1, K1M4);

    check store.removeChatInteractiveMessages(K1, 2);

    check assertFromDatabase(cl, K1, [K1SM1], SYSTEM);
    check assertFromDatabase(cl, K1, [K1M3, K1M4], INTERACTIVE);
    check assertFromDatabase(cl, K1, [K1SM1, K1M3, K1M4]);

    check assertSystemMessage(store, K1, K1SM1);
    check assertInteractiveMessages(store, K1, [K1M3, K1M4]);
    check assertAllMessages(store, K1, [K1SM1, K1M3, K1M4]);
}

@test:Config {
    before: dropTable
}
function testSystemMessageOverwrite() returns error? {
    postgresql:Client cl = getClient();
    ShortTermMemoryStore store = check new (cl);

    check store.put(K1, K1SM1);
    check store.put(K1, K1M1);
    check store.put(K1, k1m2);

    check assertSystemMessage(store, K1, K1SM1);
    check assertInteractiveMessages(store, K1, [K1M1, k1m2]);
    check assertAllMessages(store, K1, [K1SM1, K1M1, k1m2]);

    check assertFromDatabase(cl, K1, [K1SM1], SYSTEM);
    check assertFromDatabase(cl, K1, [K1M1, k1m2], INTERACTIVE);
    check assertFromDatabase(cl, K1, [K1SM1, K1M1, k1m2]);

    final readonly & ai:ChatSystemMessage k1sm2 = {
        role: ai:SYSTEM,
        content: "You are a helpful assistant that is aware of sports."
    };
    check store.put(K1, k1sm2);

    check assertSystemMessage(store, K1, k1sm2);
    check assertInteractiveMessages(store, K1, [K1M1, k1m2]);
    check assertAllMessages(store, K1, [k1sm2, K1M1, k1m2]);

    check assertFromDatabase(cl, K1, [k1sm2], SYSTEM);
    check assertFromDatabase(cl, K1, [K1M1, k1m2], INTERACTIVE);
    check assertFromDatabase(cl, K1, [k1sm2, K1M1, k1m2]);

    stream<DatabaseRecord, error?> fromDb = cl->query(
        `SELECT message_json FROM chat_messages WHERE message_key = ${K1} AND message_role = 'system'`);
    DatabaseRecord[] records = check from DatabaseRecord dbRecord in fromDb
        select dbRecord;
    test:assertEquals(records.length(), 1);
    ChatSystemMessageDatabaseMessage dbSystemMessage = check records[0].message_json.fromJsonStringWithType();
    assertChatMessageEquals(transformFromSystemMessageDatabaseMessage(dbSystemMessage), k1sm2);
}

@test:Config {
    before: dropTable
}
function testSystemMessageOverwriteWithPutAll() returns error? {
    postgresql:Client cl = getClient();
    ShortTermMemoryStore store = check new (cl);

    final readonly & ai:ChatSystemMessage k1sm2 = {
        role: ai:SYSTEM,
        content: "You are a helpful assistant that is aware of sports."
    };
    check store.put(K1, [K1SM1, K1M1, k1m2, k1sm2]);
    check assertSystemMessage(store, K1, k1sm2);
    check assertFromDatabase(cl, K1, [k1sm2, K1M1, k1m2]);

    stream<DatabaseRecord, error?> fromDb = cl->query(
        `SELECT message_json FROM chat_messages WHERE message_key = ${K1} AND message_role = 'system'`);
    DatabaseRecord[] records = check from DatabaseRecord dbRecord in fromDb
        select dbRecord;
    test:assertEquals(records.length(), 1);
    ChatSystemMessageDatabaseMessage dbSystemMessage = check records[0].message_json.fromJsonStringWithType();
    assertChatMessageEquals(transformFromSystemMessageDatabaseMessage(dbSystemMessage), k1sm2);
}

@test:Config {
    before: dropTable
}
function testPutWithDifferentMessageKinds() returns error? {
    postgresql:Client cl = getClient();
    ShortTermMemoryStore store = check new (cl);

    final readonly & ai:ChatFunctionMessage funcMessage = {
        role: "function",
        name: "getWeather",
        id: "func1"
    };

    check store.put(K1, K1SM1);
    check store.put(K1, K1M1);
    check store.put(K1, k1m2);
    check store.put(K1, funcMessage);

    check assertFromDatabase(cl, K1, [K1SM1], SYSTEM);
    check assertFromDatabase(cl, K1, [K1M1, k1m2, funcMessage], INTERACTIVE);
    check assertFromDatabase(cl, K1, [K1SM1, K1M1, k1m2, funcMessage]);

    check assertSystemMessage(store, K1, K1SM1);
    check assertInteractiveMessages(store, K1, [K1M1, k1m2, funcMessage]);
    check assertAllMessages(store, K1, [K1SM1, K1M1, k1m2, funcMessage]);
}

@test:Config {
    before: dropTable
}
function testUpdateWithSystemMessageWhenInteractiveMessagesPresentInDbOnStart() returns error? {
    postgresql:Client cl = getClient();
    ShortTermMemoryStore store = check new (cl, 5);

    _ = check cl->batchExecute([
        `INSERT INTO chat_messages (message_key, message_role, message_json) VALUES
        (${K1}, ${K1M1.role}, ${K1M1.toJsonString()})`,
        `INSERT INTO chat_messages (message_key, message_role, message_json) VALUES
        (${K1}, ${k1m2.role}, ${k1m2.toJsonString()})`
    ]);

    check store.put(K1, K1SM1);

    check assertFromDatabase(cl, K1, [K1SM1], SYSTEM);
    check assertFromDatabase(cl, K1, [K1M1, k1m2], INTERACTIVE);
    check assertFromDatabase(cl, K1, [K1M1, k1m2, K1SM1]);

    check assertSystemMessage(store, K1, K1SM1);
    check assertInteractiveMessages(store, K1, [K1M1, k1m2]);
    check assertAllMessages(store, K1, [K1SM1, K1M1, k1m2]);
}

function assertAllMessages(ShortTermMemoryStore store, string key, ai:ChatMessage[] expected) returns error? {
    ai:ChatMessage[] actual = check store.getAll(key);
    int actualLength = actual.length();
    test:assertEquals(actualLength, expected.length());
    foreach var index in 0 ..< actualLength {
        assertChatMessageEquals(actual[index], expected[index]);
    }
}

function assertSystemMessage(ShortTermMemoryStore store, string key, ai:ChatSystemMessage? expected) returns error? {
    ai:ChatSystemMessage? actual = check store.getChatSystemMessage(key);
    if expected is () && actual is () {
        return;
    }

    if expected is () || actual is () {
        test:assertFail("Actual and expected ChatSystemMessage do not match");
    }

    assertChatMessageEquals(actual, expected);
}

function assertInteractiveMessages(ShortTermMemoryStore store, string key, ai:ChatInteractiveMessage[] expected) returns error? {
    ai:ChatInteractiveMessage[] actual = check store.getChatInteractiveMessages(key);
    int actualLength = actual.length();
    test:assertEquals(actualLength, expected.length());
    foreach var index in 0 ..< actualLength {
        assertChatMessageEquals(actual[index], expected[index]);
    }
}

enum MessageType {
    SYSTEM,
    INTERACTIVE,
    ALL
}

function assertFromDatabase(postgresql:Client cl, string key, ai:ChatMessage[] expected, MessageType messageType = ALL) returns error? {
    sql:ParameterizedQuery[] selectQuery = [`SELECT message_json FROM chat_messages WHERE message_key = ${key}`];
    if messageType == SYSTEM {
        selectQuery.push(` AND message_role = 'system'`);
    } else if messageType == INTERACTIVE {
        selectQuery.push(` AND message_role != 'system'`);
    }
    selectQuery.push(` ORDER BY id ASC`);
    stream<DatabaseRecord, error?> databaseRecords = cl->query(sql:queryConcat(...selectQuery));
    ai:ChatMessage[] actualMessages = check toChatMessages(databaseRecords);
    int actualLength = actualMessages.length();
    test:assertEquals(actualLength, expected.length());
    foreach var index in 0 ..< actualLength {
        assertChatMessageEquals(actualMessages[index], expected[index]);
    }
}

function toChatMessages(stream<DatabaseRecord, error?> databaseRecords) returns ai:ChatMessage[]|error =>
    from DatabaseRecord databaseRecord in databaseRecords
select transformFromDatabaseMessage(check toChatMessage(databaseRecord));

function toChatMessage(DatabaseRecord databaseRecord) returns ChatMessageDatabaseMessage|error =>
    databaseRecord.message_json.fromJsonStringWithType();

isolated function assertChatMessageEquals(ai:ChatMessage actual, ai:ChatMessage expected) {
    if (actual is ai:ChatUserMessage && expected is ai:ChatUserMessage) ||
            (actual is ai:ChatSystemMessage && expected is ai:ChatSystemMessage) {
        test:assertEquals(actual.role, expected.role);
        assertContentEquals(actual.content, expected.content);
        test:assertEquals(actual.name, expected.name);
        return;
    }

    if actual is ai:ChatFunctionMessage && expected is ai:ChatFunctionMessage {
        test:assertEquals(actual.role, expected.role);
        test:assertEquals(actual.name, expected.name);
        test:assertEquals(actual.id, expected.id);
        test:assertEquals(actual.content, expected.content);
        return;
    }

    if actual is ai:ChatAssistantMessage && expected is ai:ChatAssistantMessage {
        test:assertEquals(actual.role, expected.role);
        test:assertEquals(actual.name, expected.name);
        test:assertEquals(actual.content, expected.content);
        test:assertEquals(actual.toolCalls, expected.toolCalls);
        return;
    }

    test:assertFail("Actual and expected ChatMessage types do not match");
}

isolated function assertContentEquals(ai:Prompt|string actual, ai:Prompt|string expected) {
    if actual is string && expected is string {
        test:assertEquals(actual, expected);
        return;
    }

    if actual is ai:Prompt && expected is ai:Prompt {
        test:assertEquals(actual.strings, expected.strings);
        test:assertEquals(actual.insertions, expected.insertions);
        return;
    }

    test:assertFail("Actual and expected content do not match");
}

@test:Config {
    before: dropTable
}
function testBasicStoreWithCache() returns error? {
    postgresql:Client cl = getClient();
    cache:CacheConfig cacheConfig = {
        capacity: 10,
        evictionFactor: 0.2
    };
    ShortTermMemoryStore store = check new (cl, cacheConfig = cacheConfig);

    check store.put(K1, K1SM1);
    check store.put(K1, K1M1);
    check store.put(K1, k1m2);
    check store.put(K2, K2M1);

    // First retrieval - should load from database and cache
    check assertAllMessages(store, K1, [K1SM1, K1M1, k1m2]);
    check assertInteractiveMessages(store, K1, [K1M1, k1m2]);

    // Second retrieval - should use cache (verify by checking results still match)
    check assertAllMessages(store, K1, [K1SM1, K1M1, k1m2]);
    check assertInteractiveMessages(store, K1, [K1M1, k1m2]);

    check assertAllMessages(store, K2, [K2M1]);
    check assertInteractiveMessages(store, K2, [K2M1]);
}

@test:Config {
    before: dropTable
}
function testBasicStoreWithCacheWithPutAll() returns error? {
    postgresql:Client cl = getClient();
    cache:CacheConfig cacheConfig = {
        capacity: 10,
        evictionFactor: 0.2
    };
    ShortTermMemoryStore store = check new (cl, cacheConfig = cacheConfig);

    check store.put(K1, [K1SM1, K1M1, k1m2]);
    check store.put(K2, K2M1);

    // First retrieval - should load from database and cache
    check assertAllMessages(store, K1, [K1SM1, K1M1, k1m2]);
    check assertInteractiveMessages(store, K1, [K1M1, k1m2]);

    // Second retrieval - should use cache (verify by checking results still match)
    check assertAllMessages(store, K1, [K1SM1, K1M1, k1m2]);
    check assertInteractiveMessages(store, K1, [K1M1, k1m2]);

    check assertAllMessages(store, K2, [K2M1]);
    check assertInteractiveMessages(store, K2, [K2M1]);
}

@test:Config {
    before: dropTable
}
function testCacheUpdateOnPut() returns error? {
    postgresql:Client cl = getClient();
    cache:CacheConfig cacheConfig = {
        capacity: 10,
        evictionFactor: 0.2
    };
    ShortTermMemoryStore store = check new (cl, cacheConfig = cacheConfig);

    check store.put(K1, K1SM1);
    check store.put(K1, K1M1);

    // Load into cache
    check assertAllMessages(store, K1, [K1SM1, K1M1]);

    // Add more messages - cache should be updated
    check store.put(K1, k1m2);
    check store.put(K1, K1M3);

    // Verify cache reflects the updates
    check assertAllMessages(store, K1, [K1SM1, K1M1, k1m2, K1M3]);
    check assertInteractiveMessages(store, K1, [K1M1, k1m2, K1M3]);
}

@test:Config {
    before: dropTable
}
function testCacheUpdateWithPutAll() returns error? {
    postgresql:Client cl = getClient();
    cache:CacheConfig cacheConfig = {
        capacity: 10,
        evictionFactor: 0.2
    };
    ShortTermMemoryStore store = check new (cl, cacheConfig = cacheConfig);

    check store.put(K1, [K1SM1, K1M1]);
    check assertAllMessages(store, K1, [K1SM1, K1M1]);

    // Add more messages - cache should be updated
    check store.put(K1, [k1m2, K1M3]);

    // Verify cache reflects the updates
    check assertAllMessages(store, K1, [K1SM1, K1M1, k1m2, K1M3]);
    check assertInteractiveMessages(store, K1, [K1M1, k1m2, K1M3]);
}

@test:Config {
    before: dropTable
}
function testCacheSystemMessageUpdate() returns error? {
    postgresql:Client cl = getClient();
    cache:CacheConfig cacheConfig = {
        capacity: 10,
        evictionFactor: 0.2
    };
    ShortTermMemoryStore store = check new (cl, cacheConfig = cacheConfig);

    check store.put(K1, K1SM1);
    check store.put(K1, K1M1);

    // Load into cache
    check assertSystemMessage(store, K1, K1SM1);
    check assertAllMessages(store, K1, [K1SM1, K1M1]);

    // Update system message
    final readonly & ai:ChatSystemMessage k1sm2 = {
        role: ai:SYSTEM,
        content: "You are a helpful assistant that is aware of sports."
    };
    check store.put(K1, k1sm2);

    // Verify cache reflects the system message update
    check assertSystemMessage(store, K1, k1sm2);
    check assertAllMessages(store, K1, [k1sm2, K1M1]);
}

@test:Config {
    before: dropTable
}
function testCacheSystemMessageUpdateOnPutAll() returns error? {
    postgresql:Client cl = getClient();
    cache:CacheConfig cacheConfig = {
        capacity: 10,
        evictionFactor: 0.2
    };
    ShortTermMemoryStore store = check new (cl, cacheConfig = cacheConfig);

    check store.put(K1, [K1SM1, K1M1]);

    // Load into cache
    check assertSystemMessage(store, K1, K1SM1);
    check assertAllMessages(store, K1, [K1SM1, K1M1]);

    // Update system message
    final readonly & ai:ChatSystemMessage k1sm2 = {
        role: ai:SYSTEM,
        content: "You are a helpful assistant that is aware of sports."
    };
    check store.put(K1, [k1sm2, k1m2]);

    // Verify cache reflects the system message update
    check assertSystemMessage(store, K1, k1sm2);
    check assertAllMessages(store, K1, [k1sm2, K1M1, k1m2]);
}

@test:Config {
    before: dropTable
}
function testCacheInvalidationOnRemoveAll() returns error? {
    postgresql:Client cl = getClient();
    cache:CacheConfig cacheConfig = {
        capacity: 10,
        evictionFactor: 0.2
    };
    ShortTermMemoryStore store = check new (cl, cacheConfig = cacheConfig);

    check store.put(K1, K1SM1);
    check store.put(K1, K1M1);
    check store.put(K1, k1m2);

    // Load into cache
    check assertAllMessages(store, K1, [K1SM1, K1M1, k1m2]);

    // Remove all messages
    check store.removeAll(K1);

    // Verify cache is invalidated and returns empty
    check assertAllMessages(store, K1, []);
    check assertSystemMessage(store, K1, ());
    check assertInteractiveMessages(store, K1, []);
}

@test:Config {
    before: dropTable
}
function testCacheInvalidationOnRemoveInteractiveMessages() returns error? {
    postgresql:Client cl = getClient();
    cache:CacheConfig cacheConfig = {
        capacity: 10,
        evictionFactor: 0.2
    };
    ShortTermMemoryStore store = check new (cl, cacheConfig = cacheConfig);

    check store.put(K1, K1SM1);
    check store.put(K1, K1M1);
    check store.put(K1, k1m2);
    check store.put(K1, K1M3);

    // Load into cache
    check assertAllMessages(store, K1, [K1SM1, K1M1, k1m2, K1M3]);

    // Remove all interactive messages
    check store.removeChatInteractiveMessages(K1);

    // Verify cache reflects the removal
    check assertAllMessages(store, K1, [K1SM1]);
    check assertSystemMessage(store, K1, K1SM1);
    check assertInteractiveMessages(store, K1, []);
}

@test:Config {
    before: dropTable
}
function testCacheInvalidationOnRemoveSubsetOfInteractiveMessages() returns error? {
    postgresql:Client cl = getClient();
    cache:CacheConfig cacheConfig = {
        capacity: 10,
        evictionFactor: 0.2
    };
    ShortTermMemoryStore store = check new (cl, cacheConfig = cacheConfig);

    check store.put(K1, K1SM1);
    check store.put(K1, K1M1);
    check store.put(K1, k1m2);
    check store.put(K1, K1M3);
    check store.put(K1, K1M4);

    // Load into cache
    check assertAllMessages(store, K1, [K1SM1, K1M1, k1m2, K1M3, K1M4]);

    // Remove first 2 interactive messages
    check store.removeChatInteractiveMessages(K1, 2);

    // Verify cache reflects the partial removal
    check assertAllMessages(store, K1, [K1SM1, K1M3, K1M4]);
    check assertInteractiveMessages(store, K1, [K1M3, K1M4]);
}

@test:Config {
    before: dropTable
}
function testCacheUpdateOnRemoveSystemMessage() returns error? {
    postgresql:Client cl = getClient();
    cache:CacheConfig cacheConfig = {
        capacity: 10,
        evictionFactor: 0.2
    };
    ShortTermMemoryStore store = check new (cl, cacheConfig = cacheConfig);

    check store.put(K1, K1SM1);
    check store.put(K1, K1M1);
    check store.put(K1, k1m2);

    // Load into cache
    check assertAllMessages(store, K1, [K1SM1, K1M1, k1m2]);
    check assertSystemMessage(store, K1, K1SM1);

    // Remove system message
    check store.removeChatSystemMessage(K1);

    // Verify cache reflects the system message removal
    check assertAllMessages(store, K1, [K1M1, k1m2]);
    check assertSystemMessage(store, K1, ());
    check assertInteractiveMessages(store, K1, [K1M1, k1m2]);
}

@test:Config {
    before: dropTable
}
function testCacheWithMultipleKeys() returns error? {
    postgresql:Client cl = getClient();
    cache:CacheConfig cacheConfig = {
        capacity: 10,
        evictionFactor: 0.2
    };
    ShortTermMemoryStore store = check new (cl, cacheConfig = cacheConfig);

    // Add messages for K1
    check store.put(K1, K1SM1);
    check store.put(K1, K1M1);
    check store.put(K1, k1m2);

    // Add messages for K2
    check store.put(K2, K2M1);

    // Load both into cache
    check assertAllMessages(store, K1, [K1SM1, K1M1, k1m2]);
    check assertAllMessages(store, K2, [K2M1]);

    // Remove K1
    check store.removeAll(K1);

    // Verify K1 is cleared but K2 is still in cache
    check assertAllMessages(store, K1, []);
    check assertAllMessages(store, K2, [K2M1]);
}

@test:Config {
    before: dropTable
}
function testCacheWithSmallCapacity() returns error? {
    postgresql:Client cl = getClient();
    cache:CacheConfig cacheConfig = {
        capacity: 2,
        evictionFactor: 0.5
    };
    ShortTermMemoryStore store = check new (cl, cacheConfig = cacheConfig);

    check store.put(K1, K1M1);
    check store.put(K2, K2M1);
    check store.put(K3, K1M3);

    // Load K1 and K2 into cache
    check assertAllMessages(store, K1, [K1M1]);
    check assertAllMessages(store, K2, [K2M1]);

    // Load K3 - may evict older entries due to capacity
    check assertAllMessages(store, K3, [K1M3]);

    // All keys should still be retrievable (from cache or database)
    check assertAllMessages(store, K1, [K1M1]);
    check assertAllMessages(store, K2, [K2M1]);
    check assertAllMessages(store, K3, [K1M3]);
}

@test:Config {
    before: dropTable
}
function testSystemMessageRetrievalDoesNotPopulateCache() returns error? {
    postgresql:Client cl = getClient();
    cache:CacheConfig cacheConfig = {
        capacity: 10,
        evictionFactor: 0.2
    };
    ShortTermMemoryStore store = check new (cl, cacheConfig = cacheConfig);

    check store.put(K1, K1SM1);
    check store.put(K1, K1M1);
    check store.put(K1, k1m2);

    // Retrieve only system message - should NOT populate cache
    check assertSystemMessage(store, K1, K1SM1);

    // Add more messages
    check store.put(K1, K1M3);

    // Retrieve all messages - should load from database and include K1M3
    check assertAllMessages(store, K1, [K1SM1, K1M1, k1m2, K1M3]);
}

function dropCustomTable() returns error? {
    postgresql:Client cl = getClient();
    _ = check cl->execute(`DROP TABLE IF EXISTS custom_chat_messages`);
}

@test:Config {
    before: dropTable
}
function testDatabaseConfigurationConstructor() returns error? {
    DatabaseConfiguration config = {
        host: DB_HOST,
        username: DB_USER,
        password: DB_PASSWORD,
        database: DB_NAME
    };
    ShortTermMemoryStore store = check new (config);

    check store.put(K1, K1SM1);
    check store.put(K1, K1M1);
    check store.put(K1, k1m2);

    check assertSystemMessage(store, K1, K1SM1);
    check assertInteractiveMessages(store, K1, [K1M1, k1m2]);
    check assertAllMessages(store, K1, [K1SM1, K1M1, k1m2]);
}

@test:Config {}
function testInvalidTableName() {
    postgresql:Client cl = getClient();
    ShortTermMemoryStore|Error store = new (cl, tableName = "invalid-table-name");
    if store !is Error {
        test:assertFail("Expected an error for an invalid table name");
    }
    test:assertTrue(store.message().includes("Invalid table name"));
}

@test:Config {}
function testInvalidMaxMessagesPerKey() {
    postgresql:Client cl = getClient();
    ShortTermMemoryStore|Error store = new (cl, 0);
    if store !is Error {
        test:assertFail("Expected an error for an invalid 'maxMessagesPerKey'");
    }
    test:assertTrue(store.message().includes("maxMessagesPerKey"));
}

@test:Config {
    before: dropCustomTable,
    after: dropCustomTable
}
function testCustomTableName() returns error? {
    postgresql:Client cl = getClient();
    ShortTermMemoryStore store = check new (cl, tableName = CUSTOM_TABLE);

    check store.put(K1, K1SM1);
    check store.put(K1, K1M1);
    check store.put(K1, k1m2);

    check assertSystemMessage(store, K1, K1SM1);
    check assertInteractiveMessages(store, K1, [K1M1, k1m2]);
    check assertAllMessages(store, K1, [K1SM1, K1M1, k1m2]);

    // The data must reside in the custom table, not the default one.
    record {|int count;|} row = check cl->queryRow(
        `SELECT COUNT(*)::int AS count FROM custom_chat_messages WHERE message_key = ${K1}`);
    test:assertEquals(row.count, 3);
}

@test:Config {
    before: dropTable
}
function testCapacityAndIsFull() returns error? {
    postgresql:Client cl = getClient();
    ShortTermMemoryStore store = check new (cl, 3);

    test:assertEquals(store.getCapacity(), 3);
    test:assertFalse(check store.isFull(K1));

    check store.put(K1, K1M1);
    check store.put(K1, k1m2);
    test:assertFalse(check store.isFull(K1));

    check store.put(K1, K1M3);
    test:assertTrue(check store.isFull(K1));

    // The system message does not count towards the interactive-message capacity.
    check store.put(K1, K1SM1);
    test:assertTrue(check store.isFull(K1));
}

@test:Config {
    before: dropTable
}
function testRemoveInteractiveMessagesInvalidCount() returns error? {
    postgresql:Client cl = getClient();
    ShortTermMemoryStore store = check new (cl);
    check store.put(K1, K1M1);

    Error? zeroResult = store.removeChatInteractiveMessages(K1, 0);
    test:assertTrue(zeroResult is Error);

    Error? negativeResult = store.removeChatInteractiveMessages(K1, -1);
    test:assertTrue(negativeResult is Error);

    // The message must remain untouched after the rejected calls.
    check assertInteractiveMessages(store, K1, [K1M1]);
}

@test:Config {
    before: dropTable
}
function testPutAllPreservesOrder() returns error? {
    postgresql:Client cl = getClient();
    ShortTermMemoryStore store = check new (cl);

    // All interactive messages of one `putAll` are inserted in a single transaction and thus
    // share a `created_at` value; ordering must remain deterministic regardless.
    ai:ChatMessage[] batch = [K1SM1, K1M1, k1m2, K1M3, K1M4];
    check store.put(K1, batch);

    check assertInteractiveMessages(store, K1, [K1M1, k1m2, K1M3, K1M4]);
    check assertAllMessages(store, K1, [K1SM1, K1M1, k1m2, K1M3, K1M4]);
    check assertFromDatabase(cl, K1, [K1M1, k1m2, K1M3, K1M4], INTERACTIVE);
}

@test:Config {
    before: dropTable
}
function testPromptContent() returns error? {
    postgresql:Client cl = getClient();
    ShortTermMemoryStore store = check new (cl);

    string name = "Alice";
    string city = "Seattle";
    ai:Prompt prompt = `My name is ${name} and I live in ${city}.`;
    ai:ChatUserMessage userMessage = {role: ai:USER, content: prompt};

    check store.put(K1, userMessage);

    ai:ChatInteractiveMessage[] messages = check store.getChatInteractiveMessages(K1);
    test:assertEquals(messages.length(), 1);
    assertChatMessageEquals(messages[0], userMessage);
}

@test:Config {
    before: dropTable
}
function testAssistantMessageWithToolCalls() returns error? {
    postgresql:Client cl = getClient();
    ShortTermMemoryStore store = check new (cl);

    ai:ChatAssistantMessage assistantMessage = {
        role: ai:ASSISTANT,
        content: (),
        toolCalls: [{name: "getWeather", arguments: {"city": "Seattle"}, id: "call_1"}]
    };

    check store.put(K1, assistantMessage);

    ai:ChatInteractiveMessage[] messages = check store.getChatInteractiveMessages(K1);
    test:assertEquals(messages.length(), 1);
    assertChatMessageEquals(messages[0], assistantMessage);
}

@test:Config {
    before: dropTable
}
function testAssistantAndFunctionMessageContent() returns error? {
    postgresql:Client cl = getClient();
    ShortTermMemoryStore store = check new (cl);

    ai:ChatAssistantMessage assistantMessage = {
        role: ai:ASSISTANT,
        content: "Sure, let me check the weather in Seattle for you.",
        name: "weatherBot"
    };
    ai:ChatFunctionMessage functionMessage = {
        role: "function",
        name: "getWeather",
        id: "call_1",
        content: "{\"temperature\": 58, \"condition\": \"cloudy\"}"
    };

    check store.put(K1, assistantMessage);
    check store.put(K1, functionMessage);

    // The non-nil `content` of both message kinds must survive the database round-trip.
    check assertInteractiveMessages(store, K1, [assistantMessage, functionMessage]);
    check assertFromDatabase(cl, K1, [assistantMessage, functionMessage], INTERACTIVE);
}

@test:Config {
    before: dropTable
}
function testTrimCountEqualAndGreaterThanTotal() returns error? {
    postgresql:Client cl = getClient();
    ShortTermMemoryStore store = check new (cl);

    // A count exactly equal to the number of interactive messages removes all of them.
    check store.put(K1, [K1M1, k1m2]);
    check store.removeChatInteractiveMessages(K1, 2);
    check assertInteractiveMessages(store, K1, []);
    check assertFromDatabase(cl, K1, [], INTERACTIVE);

    // A count greater than the number of interactive messages removes all, without an error.
    check store.put(K2, K2M1);
    check store.removeChatInteractiveMessages(K2, 10);
    check assertInteractiveMessages(store, K2, []);
    check assertFromDatabase(cl, K2, [], INTERACTIVE);
}

@test:Config {
    before: dropTable
}
function testTrimCountGreaterThanTotalWithCache() returns error? {
    postgresql:Client cl = getClient();
    cache:CacheConfig cacheConfig = {
        capacity: 10,
        evictionFactor: 0.2
    };
    ShortTermMemoryStore store = check new (cl, cacheConfig = cacheConfig);

    check store.put(K1, K1SM1);
    check store.put(K1, K1M1);
    check store.put(K1, k1m2);

    // Load the entry into the cache.
    check assertAllMessages(store, K1, [K1SM1, K1M1, k1m2]);

    // A count exceeding the two interactive messages must drop all of them from the cache too,
    // while leaving the system message intact.
    check store.removeChatInteractiveMessages(K1, 5);
    check assertInteractiveMessages(store, K1, []);
    check assertSystemMessage(store, K1, K1SM1);
    check assertAllMessages(store, K1, [K1SM1]);
}

@test:Config {
    before: dropTable
}
function testTrimOnEmptyKey() returns error? {
    postgresql:Client cl = getClient();
    ShortTermMemoryStore store = check new (cl);

    // Trimming a key that has no messages must be a no-op, not an error.
    check store.removeChatInteractiveMessages(K1);
    check store.removeChatInteractiveMessages(K1, 3);
    check assertInteractiveMessages(store, K1, []);
}

@test:Config {
    before: dropTable
}
function testRepeatedTrimByOne() returns error? {
    postgresql:Client cl = getClient();
    ShortTermMemoryStore store = check new (cl);

    // Inserted via `putAll`, so all rows share a `created_at` value; each single-message trim
    // must still remove the oldest remaining message by insertion order.
    check store.put(K1, [K1M1, k1m2, K1M3, K1M4]);

    check store.removeChatInteractiveMessages(K1, 1);
    check assertInteractiveMessages(store, K1, [k1m2, K1M3, K1M4]);

    check store.removeChatInteractiveMessages(K1, 1);
    check assertInteractiveMessages(store, K1, [K1M3, K1M4]);

    check store.removeChatInteractiveMessages(K1, 1);
    check assertInteractiveMessages(store, K1, [K1M4]);

    check store.removeChatInteractiveMessages(K1, 1);
    check assertInteractiveMessages(store, K1, []);
}

@test:Config {
    before: dropTable
}
function testTrimThenPutCycle() returns error? {
    postgresql:Client cl = getClient();
    ShortTermMemoryStore store = check new (cl);

    check store.put(K1, [K1M1, k1m2, K1M3]);

    // Evict the oldest message, then append a new one - the classic overflow cycle.
    check store.removeChatInteractiveMessages(K1, 1);
    check store.put(K1, K1M4);
    check assertInteractiveMessages(store, K1, [k1m2, K1M3, K1M4]);
    check assertFromDatabase(cl, K1, [k1m2, K1M3, K1M4], INTERACTIVE);

    check store.removeChatInteractiveMessages(K1, 1);
    check store.put(K1, K1M1);
    check assertInteractiveMessages(store, K1, [K1M3, K1M4, K1M1]);
    check assertFromDatabase(cl, K1, [K1M3, K1M4, K1M1], INTERACTIVE);
}

@test:Config {
    before: dropTable
}
function testOverflowTrimmingOnUpdate() returns error? {
    postgresql:Client cl = getClient();
    ShortTermMemoryStore store = check new (cl, 3);
    ai:ShortTermMemory memory = check new (store, {trimCount: 1});

    check memory.update(K1, OM1);
    check memory.update(K1, OM2);
    check memory.update(K1, OM3);
    // Capacity (3) is now reached; each further update must trim the oldest message.
    check memory.update(K1, OM4);
    check memory.update(K1, OM5);

    ai:ChatMessage[] fromMemory = check memory.get(K1);
    test:assertEquals(fromMemory.length(), 3);
    assertChatMessageEquals(fromMemory[0], OM3);
    assertChatMessageEquals(fromMemory[1], OM4);
    assertChatMessageEquals(fromMemory[2], OM5);

    // The store itself must agree with what the memory layer reports.
    check assertInteractiveMessages(store, K1, [OM3, OM4, OM5]);
}

@test:Config {
    before: dropTable
}
function testOverflowTrimmingWithTrimCount() returns error? {
    postgresql:Client cl = getClient();
    ShortTermMemoryStore store = check new (cl, 3);
    ai:ShortTermMemory memory = check new (store, {trimCount: 2});

    check memory.update(K1, OM1);
    check memory.update(K1, OM2);
    check memory.update(K1, OM3);
    // Overflow with `trimCount` 2 removes the two oldest messages each time the limit is hit.
    check memory.update(K1, OM4);
    check memory.update(K1, OM5);
    check memory.update(K1, OM6);

    ai:ChatMessage[] fromMemory = check memory.get(K1);
    test:assertEquals(fromMemory.length(), 2);
    assertChatMessageEquals(fromMemory[0], OM5);
    assertChatMessageEquals(fromMemory[1], OM6);

    check assertInteractiveMessages(store, K1, [OM5, OM6]);
}

@test:Config {
    before: dropTable
}
function testOverflowTrimmingOnBatchUpdate() returns error? {
    postgresql:Client cl = getClient();
    ShortTermMemoryStore store = check new (cl, 3);
    ai:ShortTermMemory memory = check new (store, {trimCount: 1});

    // A single batch update larger than the capacity must trim down to the most recent messages.
    check memory.update(K1, [OM1, OM2, OM3, OM4, OM5]);

    ai:ChatMessage[] fromMemory = check memory.get(K1);
    test:assertEquals(fromMemory.length(), 3);
    assertChatMessageEquals(fromMemory[0], OM3);
    assertChatMessageEquals(fromMemory[1], OM4);
    assertChatMessageEquals(fromMemory[2], OM5);

    check assertInteractiveMessages(store, K1, [OM3, OM4, OM5]);
}
