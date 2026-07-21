// Copyright (c) 2026 WSO2 LLC (http://www.wso2.com).
// Licensed under the Apache License, Version 2.0.

import ballerina/mcp;

# A declarative PostgreSQL MCP listener.
#
# Declaring this as a Ballerina `listener` starts the MCP server with the module lifecycle. The listener owns the
# PostgreSQL MCP service and closes its database client when the listener stops.
public isolated class PostgresMcpListener {
    private final mcp:Listener mcpListener;
    private final PostgresMcpService mcpService;

    # Initializes the listener and attaches the PostgreSQL MCP service.
    # + connectionConfig - Configuration for connecting to PostgreSQL.
    # + serviceConfig - Configuration for the PostgreSQL MCP tools.
    # + serverConfig - Configuration for the MCP listener.
    # + return - An error if the service cannot be initialized or attached.
    public function init(ConnectionConfig connectionConfig, ServiceConfig serviceConfig = {},
            ServerConfig serverConfig = {}) returns error? {
        self.mcpService = check new (connectionConfig, serviceConfig);
        mcp:Listener|error mcpTransportListener = new (serverConfig.port, {...serverConfig.listenerConfig.clone()});
        if mcpTransportListener is error {
            check self.mcpService.close();
            return mcpTransportListener;
        }
        self.mcpListener = mcpTransportListener;
        error? attachError = self.mcpListener.attach(self.mcpService, serverConfig.path);
        if attachError is error {
            check self.mcpService.close();
            return attachError;
        }
    }

    # Attaches an additional MCP service to this listener.
    public isolated function attach(mcp:Service|mcp:AdvancedService mcpService,
            string[]|string? name = ()) returns mcp:Error? {
        return self.mcpListener.attach(mcpService, name);
    }

    # Detaches an MCP service from this listener.
    public isolated function detach(mcp:Service|mcp:AdvancedService mcpService) returns mcp:Error? {
        return self.mcpListener.detach(mcpService);
    }

    # Starts the listener.
    public isolated function 'start() returns mcp:Error? {
        return self.mcpListener.'start();
    }

    # Gracefully stops the listener and closes the PostgreSQL client.
    public isolated function gracefulStop() returns error? {
        error? listenerError = self.mcpListener.gracefulStop();
        error? closeError = self.mcpService.close();
        if listenerError is error {
            return listenerError;
        }
        return closeError;
    }

    # Immediately stops the listener and closes the PostgreSQL client.
    public isolated function immediateStop() returns error? {
        error? listenerError = self.mcpListener.immediateStop();
        error? closeError = self.mcpService.close();
        if listenerError is error {
            return listenerError;
        }
        return closeError;
    }
}
