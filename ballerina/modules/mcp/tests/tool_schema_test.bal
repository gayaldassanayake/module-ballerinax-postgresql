// Copyright (c) 2026 WSO2 LLC.
// Licensed under the Apache License, Version 2.0.

import ballerina/mcp;
import ballerina/test;

@test:Config {}
function testPostgresToolsExposeInputSchemas() returns error? {
    PostgresMcpListener postgresqlMcpListener = check new (
        {username: "postgres", password: "postgres", database: "postgres"},
        {},
        {port: 9091}
    );
    check postgresqlMcpListener.'start();

    mcp:StreamableHttpClient mcpClient = check new ("http://localhost:9091/mcp");
    check mcpClient->initialize({name: "postgres-mcp-schema-test", version: "1.0.0"});
    mcp:ListToolsResult result = check mcpClient->listTools();
    check postgresqlMcpListener.gracefulStop();

    test:assertEquals(result.tools.length(), 5);
    foreach mcp:ToolDefinition tool in result.tools {
        map<json> inputSchema = check tool.inputSchema.ensureType();
        test:assertEquals(inputSchema["type"], "object", msg = tool.name + " must expose an object schema");
    }
}
