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
const int DB_PORT = 5432;
const string MISSING_DB = "no_such_database_for_memory_store_tests";
const string CUSTOM_TABLE = "custom_chat_messages";
const string ALT_TABLE = "_alt_chat_messages_1";

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

function dropCustomTable() returns error? {
    postgresql:Client cl = getClient();
    _ = check cl->execute(`DROP TABLE IF EXISTS custom_chat_messages`);
}

function dropAltTable() returns error? {
    postgresql:Client cl = getClient();
    _ = check cl->execute(`DROP TABLE IF EXISTS _alt_chat_messages_1`);
}

function dropProbeTables() returns error? {
    postgresql:Client cl = getClient();
    _ = check cl->execute(`DROP TABLE IF EXISTS probe_invalid_columns`);
    _ = check cl->execute(`DROP TABLE IF EXISTS probe_partial_columns`);
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

@test:Config {
    before: dropTable
}
function testDefaultCapacity() returns error? {
    ShortTermMemoryStore store = check new (getClient());
    test:assertEquals(store.getCapacity(), 20);
}

@test:Config {
    before: dropTable
}
function testFreshKeyReturnsEmptyResults() returns error? {
    ShortTermMemoryStore store = check new (getClient());

    // A key that was never written to must read back as empty rather than erroring.
    check assertAllMessages(store, K3, []);
    check assertSystemMessage(store, K3, ());
    check assertInteractiveMessages(store, K3, []);
    test:assertFalse(check store.isFull(K3));
}

@test:Config {
    before: dropTable
}
function testPutEmptyMessageArray() returns error? {
    postgresql:Client cl = getClient();
    ShortTermMemoryStore store = check new (cl);

    ai:ChatMessage[] noMessages = [];
    check store.put(K1, noMessages);
    check assertAllMessages(store, K1, []);
    check assertFromDatabase(cl, K1, []);

    // An empty batch must also leave already-stored messages untouched.
    check store.put(K1, K1M1);
    check store.put(K1, noMessages);
    check assertInteractiveMessages(store, K1, [K1M1]);
    check assertFromDatabase(cl, K1, [K1M1], INTERACTIVE);
}

@test:Config {
    before: dropTable
}
function testPutAllWithOnlySystemMessages() returns error? {
    postgresql:Client cl = getClient();
    ShortTermMemoryStore store = check new (cl);

    final readonly & ai:ChatSystemMessage k1sm2 = {
        role: ai:SYSTEM,
        content: "You are a helpful assistant that is aware of sports."
    };

    // A batch of system messages only: the last one wins and no interactive rows are written.
    check store.put(K1, [K1SM1, k1sm2]);

    check assertSystemMessage(store, K1, k1sm2);
    check assertInteractiveMessages(store, K1, []);
    check assertAllMessages(store, K1, [k1sm2]);
    check assertFromDatabase(cl, K1, [k1sm2], SYSTEM);
    check assertFromDatabase(cl, K1, [], INTERACTIVE);
}

@test:Config {
    before: dropTable
}
function testMessageNamesSurviveRoundTrip() returns error? {
    postgresql:Client cl = getClient();
    ShortTermMemoryStore store = check new (cl);

    ai:ChatSystemMessage systemMessage = {
        role: ai:SYSTEM,
        content: "You are a helpful assistant.",
        name: "sysBot"
    };
    ai:ChatUserMessage userMessage = {role: ai:USER, content: "Hello!", name: "alice"};
    ai:ChatAssistantMessage assistantMessage = {role: ai:ASSISTANT, content: "Hi Alice!", name: "assistantBot"};

    check store.put(K1, [systemMessage, userMessage, assistantMessage]);

    check assertSystemMessage(store, K1, systemMessage);
    check assertInteractiveMessages(store, K1, [userMessage, assistantMessage]);
    check assertFromDatabase(cl, K1, [systemMessage], SYSTEM);
    check assertFromDatabase(cl, K1, [userMessage, assistantMessage], INTERACTIVE);
}

@test:Config {
    before: dropTable
}
function testSystemMessageWithPromptContent() returns error? {
    postgresql:Client cl = getClient();
    ShortTermMemoryStore store = check new (cl);

    string domain = "weather";
    ai:Prompt prompt = `You are an assistant specialised in ${domain}.`;
    ai:ChatSystemMessage systemMessage = {role: ai:SYSTEM, content: prompt, name: "sysBot"};

    check store.put(K1, systemMessage);

    check assertSystemMessage(store, K1, systemMessage);
    check assertAllMessages(store, K1, [systemMessage]);
    check assertFromDatabase(cl, K1, [systemMessage], SYSTEM);
}

@test:Config {
    before: dropTable
}
function testPromptWithNonStringInsertions() returns error? {
    postgresql:Client cl = getClient();
    ShortTermMemoryStore store = check new (cl);

    int count = 3;
    boolean urgent = true;
    anydata note = ();
    ai:Prompt prompt = `I have ${count} pending items, urgent: ${urgent}, note: ${note}.`;
    ai:ChatUserMessage userMessage = {role: ai:USER, content: prompt};

    check store.put(K1, userMessage);

    check assertInteractiveMessages(store, K1, [userMessage]);
    check assertAllMessages(store, K1, [userMessage]);
    check assertFromDatabase(cl, K1, [userMessage], INTERACTIVE);
}

@test:Config {
    before: dropTable
}
function testSpecialCharacterAndUnicodeContent() returns error? {
    postgresql:Client cl = getClient();
    ShortTermMemoryStore store = check new (cl);

    ai:ChatUserMessage quoted = {
        role: ai:USER,
        content: string `It's a "quoted" value with a backslash \ and a newline
here.`
    };
    ai:ChatUserMessage unicode = {role: ai:USER, content: "こんにちは 🌤 ünïcödé"};
    // Content that looks like SQL must be stored verbatim, since every query is parameterized.
    ai:ChatUserMessage sqlLike = {role: ai:USER, content: "'); DROP TABLE chat_messages; --"};

    check store.put(K1, [quoted, unicode, sqlLike]);

    check assertInteractiveMessages(store, K1, [quoted, unicode, sqlLike]);
    check assertFromDatabase(cl, K1, [quoted, unicode, sqlLike], INTERACTIVE);

    // The table must still exist with all three rows intact.
    record {|int count;|} row = check cl->queryRow(`SELECT COUNT(*)::int AS count FROM chat_messages`);
    test:assertEquals(row.count, 3);
}

@test:Config {
    before: dropTable
}
function testKeysWithSpecialCharacters() returns error? {
    postgresql:Client cl = getClient();
    ShortTermMemoryStore store = check new (cl);

    string quotedKey = "user's-key";
    string unicodeKey = "🔑-キー";
    string longKey = "";
    foreach int _ in 0 ..< 40 {
        longKey += "long_key_segment_";
    }

    check store.put(quotedKey, K1M1);
    check store.put(unicodeKey, K2M1);
    check store.put(longKey, [K1SM1, K1M3]);

    check assertInteractiveMessages(store, quotedKey, [K1M1]);
    check assertInteractiveMessages(store, unicodeKey, [K2M1]);
    check assertSystemMessage(store, longKey, K1SM1);
    check assertInteractiveMessages(store, longKey, [K1M3]);

    // Keys must stay isolated from one another.
    check store.removeAll(quotedKey);
    check assertInteractiveMessages(store, quotedKey, []);
    check assertInteractiveMessages(store, unicodeKey, [K2M1]);
    check assertAllMessages(store, longKey, [K1SM1, K1M3]);
}

@test:Config {}
function testInvalidTableNames() {
    postgresql:Client cl = getClient();
    string[] invalidNames = [
        "",
        "1chat_messages",
        "chat messages",
        "chat-messages",
        "chat.messages",
        "chat_messages;DROP TABLE chat_messages",
        "chat_messages'; --",
        "chát_messages"
    ];

    foreach string name in invalidNames {
        ShortTermMemoryStore|Error store = new (cl, tableName = name);
        if store !is Error {
            test:assertFail(string `Expected an error for the invalid table name: '${name}'`);
        }
        test:assertTrue(store.message().includes("Invalid table name"));
    }
}

@test:Config {
    before: dropAltTable,
    after: dropAltTable
}
function testTableNameWithLeadingUnderscoreAndDigits() returns error? {
    postgresql:Client cl = getClient();
    ShortTermMemoryStore store = check new (cl, tableName = ALT_TABLE);

    check store.put(K1, [K1SM1, K1M1]);

    check assertSystemMessage(store, K1, K1SM1);
    check assertInteractiveMessages(store, K1, [K1M1]);

    record {|int count;|} row = check cl->queryRow(
        `SELECT COUNT(*)::int AS count FROM _alt_chat_messages_1 WHERE message_key = ${K1}`);
    test:assertEquals(row.count, 2);
}

@test:Config {}
function testInvalidNegativeMaxMessagesPerKey() {
    postgresql:Client cl = getClient();
    ShortTermMemoryStore|Error store = new (cl, -5);
    if store !is Error {
        test:assertFail("Expected an error for a negative 'maxMessagesPerKey'");
    }
    test:assertTrue(store.message().includes("maxMessagesPerKey"));
}

@test:Config {
    before: dropTable
}
function testStoreReinitializationOnExistingTable() returns error? {
    postgresql:Client cl = getClient();
    ShortTermMemoryStore store = check new (cl);
    check store.put(K1, [K1SM1, K1M1]);

    // Re-initializing against an existing table must be a no-op that preserves stored messages.
    ShortTermMemoryStore secondStore = check new (cl);
    check assertSystemMessage(secondStore, K1, K1SM1);
    check assertInteractiveMessages(secondStore, K1, [K1M1]);

    // All state lives in the database, so writes through one instance are visible to the other.
    check secondStore.put(K1, k1m2);
    check assertInteractiveMessages(store, K1, [K1M1, k1m2]);

    final readonly & ai:ChatSystemMessage k1sm2 = {
        role: ai:SYSTEM,
        content: "You are a helpful assistant that is aware of sports."
    };
    check secondStore.put(K1, k1sm2);
    check assertSystemMessage(store, K1, k1sm2);
    check assertFromDatabase(cl, K1, [k1sm2], SYSTEM);

    check secondStore.removeAll(K1);
    check assertAllMessages(store, K1, []);
}

@test:Config {
    before: dropTable
}
function testIsFullWithSystemMessageOnlyAndSingleCapacity() returns error? {
    postgresql:Client cl = getClient();
    ShortTermMemoryStore store = check new (cl, 1);
    test:assertEquals(store.getCapacity(), 1);

    // A system message alone never fills the store.
    check store.put(K1, K1SM1);
    test:assertFalse(check store.isFull(K1));

    check store.put(K1, K1M1);
    test:assertTrue(check store.isFull(K1));

    // Trimming the only interactive message frees the store again.
    check store.removeChatInteractiveMessages(K1, 1);
    test:assertFalse(check store.isFull(K1));

    // Other keys are unaffected by K1 being full.
    check store.put(K1, K1M3);
    test:assertTrue(check store.isFull(K1));
    test:assertFalse(check store.isFull(K2));
}

@test:Config {
    before: dropTable
}
function testRemoveOnNonExistentKey() returns error? {
    postgresql:Client cl = getClient();
    ShortTermMemoryStore store = check new (cl);
    check store.put(K1, [K1SM1, K1M1]);

    // Removals against a key that has no rows are no-ops, and must not touch other keys.
    check store.removeAll(K3);
    check store.removeChatSystemMessage(K3);
    check store.removeChatInteractiveMessages(K3);
    check store.removeChatInteractiveMessages(K3, 5);

    check assertSystemMessage(store, K1, K1SM1);
    check assertInteractiveMessages(store, K1, [K1M1]);
    check assertFromDatabase(cl, K1, [K1SM1, K1M1]);
}

@test:Config {
    before: dropTable
}
function testCorruptSystemMessageJsonInDatabase() returns error? {
    postgresql:Client cl = getClient();
    ShortTermMemoryStore store = check new (cl);

    _ = check cl->execute(`INSERT INTO chat_messages (message_key, message_role, message_json)
        VALUES (${K1}, 'system', 'not-valid-json')`);

    ai:ChatSystemMessage|Error? systemMessage = store.getChatSystemMessage(K1);
    if systemMessage !is Error {
        test:assertFail("Expected an error for a corrupt system message row");
    }
    test:assertTrue(systemMessage.message().includes("Failed to parse chat message from database"));

    [ai:ChatSystemMessage, ai:ChatInteractiveMessage...]|ai:ChatInteractiveMessage[]|Error allMessages = store.getAll(K1);
    if allMessages !is Error {
        test:assertFail("Expected an error from 'getAll' for a corrupt system message row");
    }
    test:assertTrue(allMessages.message().includes("Failed to parse chat message from database"));
}

@test:Config {
    before: dropTable
}
function testCorruptInteractiveMessageJsonInDatabase() returns error? {
    postgresql:Client cl = getClient();
    ShortTermMemoryStore store = check new (cl);

    // Valid JSON that does not match any known chat message shape.
    _ = check cl->execute(`INSERT INTO chat_messages (message_key, message_role, message_json)
        VALUES (${K1}, 'user', '{"role":"user"}')`);

    ai:ChatInteractiveMessage[]|Error interactiveMessages = store.getChatInteractiveMessages(K1);
    if interactiveMessages !is Error {
        test:assertFail("Expected an error for a corrupt interactive message row");
    }
    test:assertTrue(interactiveMessages.message().includes("Failed to parse chat message from database"));

    test:assertTrue(store.getAll(K1) is Error);

    // The system message lookup does not read interactive rows, so it stays unaffected.
    check assertSystemMessage(store, K1, ());

    // A failed read must leave the store fully usable: it has to remain acceptable as an
    // `ai:ShortTermMemoryStore` and work normally once the corrupt row is gone.
    check store.removeAll(K1);
    ai:ShortTermMemory memory = check new (store, {trimCount: 1});
    check memory.update(K1, K1M1);
    ai:ChatMessage[] fromMemory = check memory.get(K1);
    test:assertEquals(fromMemory.length(), 1);
    assertChatMessageEquals(fromMemory[0], K1M1);
}

@test:Config {
    before: dropTable,
    after: dropTable
}
function testOperationsFailWhenTableIsMissing() returns error? {
    postgresql:Client cl = getClient();
    ShortTermMemoryStore store = check new (cl);
    check store.put(K1, [K1SM1, K1M1]);

    // Drop the table behind the store's back: every operation must surface an error.
    _ = check cl->execute(`DROP TABLE chat_messages`);

    ai:ChatSystemMessage|Error? systemMessage = store.getChatSystemMessage(K1);
    if systemMessage !is Error {
        test:assertFail("Expected an error from 'getChatSystemMessage' when the table is missing");
    }
    test:assertTrue(systemMessage.message().includes("Failed to retrieve system message"));

    ai:ChatInteractiveMessage[]|Error interactiveMessages = store.getChatInteractiveMessages(K1);
    if interactiveMessages !is Error {
        test:assertFail("Expected an error from 'getChatInteractiveMessages' when the table is missing");
    }
    test:assertTrue(interactiveMessages.message().includes("Failed to retrieve chat messages"));

    test:assertTrue(store.getAll(K1) is Error);
    test:assertTrue(store.isFull(K1) is Error);

    Error? interactivePutResult = store.put(K1, K1M3);
    if interactivePutResult !is Error {
        test:assertFail("Expected an error when adding an interactive message to a missing table");
    }
    test:assertTrue(interactivePutResult.message().includes("Failed to add chat message"));

    Error? systemPutResult = store.put(K1, K1SM1);
    if systemPutResult !is Error {
        test:assertFail("Expected an error when adding a system message to a missing table");
    }
    test:assertTrue(systemPutResult.message().includes("Failed to upsert system message"));

    ai:ChatMessage[] batch = [K1SM1, K1M3];
    Error? batchPutResult = store.put(K1, batch);
    if batchPutResult !is Error {
        test:assertFail("Expected an error when adding a batch of messages to a missing table");
    }
    test:assertTrue(batchPutResult.message().includes("Failed to add chat messages"));

    Error? removeSystemResult = store.removeChatSystemMessage(K1);
    if removeSystemResult !is Error {
        test:assertFail("Expected an error from 'removeChatSystemMessage' when the table is missing");
    }
    test:assertTrue(removeSystemResult.message().includes("Failed to delete existing system message"));

    test:assertTrue(store.removeChatInteractiveMessages(K1) is Error);
    test:assertTrue(store.removeChatInteractiveMessages(K1, 1) is Error);
    test:assertTrue(store.removeAll(K1) is Error);
}

@test:Config {}
function testInitFailureWhenTableCannotBeCreated() {
    DatabaseConfiguration config = {
        host: DB_HOST,
        username: DB_USER,
        password: DB_PASSWORD,
        database: DB_NAME
    };

    // 'select' satisfies the table-name validation but is a reserved SQL keyword, so the
    // 'CREATE TABLE' statement fails. The internally-created client is closed on this path.
    ShortTermMemoryStore|Error store = new (config, tableName = "select");
    if store !is Error {
        test:assertFail("Expected an error when the table cannot be created");
    }
    test:assertTrue(store.message().includes("Failed to create select table"));
}

@test:Config {
    before: dropProbeTables,
    after: dropProbeTables
}
function testInitFailureWhenKeyIndexCannotBeCreated() returns error? {
    postgresql:Client cl = getClient();

    // An existing table of the same name with unrelated columns: 'CREATE TABLE IF NOT EXISTS' is
    // skipped, and creating the (message_key, id) index then fails.
    _ = check cl->execute(`CREATE TABLE probe_invalid_columns (unrelated_column INT)`);

    ShortTermMemoryStore|Error store = new (cl, tableName = "probe_invalid_columns");
    if store !is Error {
        test:assertFail("Expected an error when the key index cannot be created");
    }
    test:assertTrue(store.message().includes("Failed to create index on probe_invalid_columns"));
}

@test:Config {
    before: dropProbeTables,
    after: dropProbeTables
}
function testInitFailureWhenSystemMessageIndexCannotBeCreated() returns error? {
    postgresql:Client cl = getClient();

    // The columns the key index needs exist, but 'message_role' - used by the partial unique index
    // predicate - does not, so only the unique index creation fails.
    _ = check cl->execute(`CREATE TABLE probe_partial_columns (
        id BIGINT GENERATED ALWAYS AS IDENTITY PRIMARY KEY,
        message_key TEXT NOT NULL
    )`);

    ShortTermMemoryStore|Error store = new (cl, tableName = "probe_partial_columns");
    if store !is Error {
        test:assertFail("Expected an error when the unique system message index cannot be created");
    }
    test:assertTrue(store.message().includes("Failed to create unique index on probe_partial_columns"));
}

@test:Config {}
function testInitFailureWithUnknownDatabase() {
    DatabaseConfiguration config = {
        host: DB_HOST,
        username: DB_USER,
        password: DB_PASSWORD,
        database: MISSING_DB
    };

    ShortTermMemoryStore|Error store = new (config);
    if store !is Error {
        test:assertFail("Expected an error when the configured database does not exist");
    }
}

@test:Config {
    before: dropTable
}
function testDatabaseConfigurationWithPortOptionsAndPool() returns error? {
    DatabaseConfiguration config = {
        host: DB_HOST,
        username: DB_USER,
        password: DB_PASSWORD,
        database: DB_NAME,
        port: DB_PORT,
        options: {connectTimeout: 10},
        connectionPool: {maxOpenConnections: 2, maxConnectionLifeTime: 30, minIdleConnections: 1}
    };

    ShortTermMemoryStore store = check new (config, 5);
    test:assertEquals(store.getCapacity(), 5);

    check store.put(K1, [K1SM1, K1M1, k1m2]);
    check assertSystemMessage(store, K1, K1SM1);
    check assertInteractiveMessages(store, K1, [K1M1, k1m2]);
    check assertAllMessages(store, K1, [K1SM1, K1M1, k1m2]);
}
