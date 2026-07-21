// Copyright (c) 2026 WSO2 LLC (http://www.wso2.com).
// Licensed under the Apache License, Version 2.0.

import ballerina/mcp;

# A running PostgreSQL MCP server and its owned resources.
#
# Deprecated: Use `PostgresMcpListener` in a Ballerina `listener` declaration instead.
@deprecated
public isolated class Server {
    private final mcp:Listener mcpListener;
    private final PostgresMcpService mcpService;

    isolated function init(mcp:Listener mcpListener, PostgresMcpService mcpService) {
        self.mcpListener = mcpListener;
        self.mcpService = mcpService;
    }

    # Starts the wrapped MCP listener.
    # + return - An error if the listener cannot be started.
    public isolated function 'start() returns error? {
        return self.mcpListener.'start();
    }

    # Gracefully stops the listener and closes the database client.
    # + return - An error if stopping the listener or closing the database client fails.
    public isolated function gracefulStop() returns error? {
        check self.mcpListener.gracefulStop();
        check self.mcpService.close();
    }

    # Immediately stops the listener and closes the database client.
    # + return - An error if stopping the listener or closing the database client fails.
    public isolated function immediateStop() returns error? {
        check self.mcpListener.immediateStop();
        check self.mcpService.close();
    }
}

# Starts a PostgreSQL MCP server with a service-owned database client.
#
# Deprecated: Use `PostgresMcpListener` in a Ballerina `listener` declaration instead.
# + connectionConfig - Configuration for connecting to the PostgreSQL database.
# + serviceConfig - Configuration for the PostgreSQL MCP service.
# + serverConfig - Configuration for the MCP listener server.
# + return - A `Server` instance on success, or an error if initialization fails.
@deprecated
public function 'start(ConnectionConfig connectionConfig, ServiceConfig serviceConfig = {},
        ServerConfig serverConfig = {}) returns Server|error {
    PostgresMcpService mcpService = check new (connectionConfig, serviceConfig);
    mcp:Listener mcpListener = check new (serverConfig.port, {...serverConfig.listenerConfig.clone()});
    error? attachError = mcpListener.attach(mcpService, serverConfig.path);
    if attachError is error {
        error? closeError = mcpService.close();
        return attachError;
    }
    error? startError = mcpListener.'start();
    if startError is error {
        error? closeError = mcpService.close();
        return startError;
    }
    return new (mcpListener, mcpService);
}
