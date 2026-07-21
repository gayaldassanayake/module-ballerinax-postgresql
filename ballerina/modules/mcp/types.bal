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
// KIND, either express or implied. See the License for the
// specific language governing permissions and limitations
// under the License.

import ballerina/sql;
import ballerina/mcp;
import ballerinax/postgresql;

# Configuration for the PostgreSQL client owned by the MCP service.
public type ConnectionConfig record {|
    # PostgreSQL server hostname.
    string host = "localhost";
    # Database username.
    string? username = "postgres";
    # Database password.
    string? password = ();
    # Database name.
    string? database = ();
    # PostgreSQL server port.
    int port = 5432;
    # PostgreSQL client options.
    postgresql:Options? options = ();
    # PostgreSQL connection pool settings.
    sql:ConnectionPool? connectionPool = ();
|};

# Configuration for PostgreSQL MCP tool behavior.
public type ServiceConfig record {|
    # Enables only read tools when true.
    boolean readOnly = true;
|};

# Configuration for the streamable HTTP MCP server.
public type ServerConfig record {|
    int port = 8080;
    string path = "/mcp";
    mcp:ListenerConfiguration listenerConfig = {};
|};
