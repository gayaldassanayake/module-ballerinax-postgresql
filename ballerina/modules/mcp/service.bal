// Copyright (c) 2026 WSO2 LLC (http://www.wso2.com).
// Licensed under the Apache License, Version 2.0.

import ballerina/mcp;
import ballerina/sql;
import ballerinax/postgresql;

public isolated service class PostgresMcpService {
    *mcp:Service;

    private final postgresql:Client dbClient;
    private final boolean readOnly;

    public isolated function init(ConnectionConfig connectionConfig, ServiceConfig serviceConfig = {}) returns sql:Error? {
        self.dbClient = check new (host = connectionConfig.host, username = connectionConfig.username,
            password = connectionConfig.password, database = connectionConfig.database, port = connectionConfig.port,
            options = connectionConfig.options, connectionPool = connectionConfig.connectionPool);
        self.readOnly = serviceConfig.readOnly;
    }

    @mcp:Tool {
        description: "Run a SQL query and return all matching rows as JSON.",
        schema: {'type: "object", properties: {sql: {'type: "string"}}, required: ["sql"]}
    }
    isolated remote function execute_query(string sql) returns json[]|error {
        stream<record {}, sql:Error?> resultStream = self.dbClient->query(toRawQuery(sql));
        json[] rows = [];
        check from record {} row in resultStream do {
            rows.push(row.toJson());
        };
        check resultStream.close();
        return rows;
    }

    @mcp:Tool {
        description: "Run a SQL query expected to return one row as JSON.",
        schema: {'type: "object", properties: {sql: {'type: "string"}}, required: ["sql"]}
    }
    isolated remote function execute_query_row(string sql) returns json|error {
        record {} row = check self.dbClient->queryRow(toRawQuery(sql));
        return row.toJson();
    }

    @mcp:Tool {
        description: "Execute a DDL or DML statement. Refused in READ_ONLY mode.",
        schema: {'type: "object", properties: {sql: {'type: "string"}}, required: ["sql"]}
    }
    isolated remote function execute_statement(string sql) returns json|error {
        if self.readOnly { return readOnlyError(); }
        sql:ExecutionResult result = check self.dbClient->execute(toRawQuery(sql));
        return result.toJson();
    }

    @mcp:Tool {
        description: "Execute DML statements in order. Refused in READ_ONLY mode.",
        schema: {
            'type: "object",
            properties: {statements: {'type: "array", items: {'type: "string"}}},
            required: ["statements"]
        }
    }
    isolated remote function batch_execute_statement(string[] statements) returns json|error {
        if self.readOnly { return readOnlyError(); }
        if statements.length() == 0 { return error("`statements` must contain at least one SQL statement"); }
        sql:ExecutionResult[] results = [];
        foreach string statement in statements {
            sql:ExecutionResult result = check self.dbClient->execute(toRawQuery(statement));
            results.push(result);
        }
        return results.toJson();
    }

    @mcp:Tool {
        description: "Call a stored procedure or function. Refused in READ_ONLY mode.",
        schema: {'type: "object", properties: {sql: {'type: "string"}}, required: ["sql"]}
    }
    isolated remote function call_procedure(string sql) returns json|error {
        if self.readOnly { return readOnlyError(); }
        sql:ProcedureCallResult result = check self.dbClient->call(toRawCallQuery(sql));
        json[] rows = [];
        stream<record {}, sql:Error?>? queryResult = result.queryResult;
        if queryResult is stream<record {}, sql:Error?> {
            check from record {} row in queryResult do { rows.push(row.toJson()); };
        }
        json executionSummary = result.executionResult is sql:ExecutionResult ? result.executionResult.toJson() : ();
        check result.close();
        return {executionResult: executionSummary, rows: rows};
    }

    public isolated function close() returns sql:Error? {
        return self.dbClient.close();
    }
}
