import ballerinax/postgresql.driver as _;
import ballerinax/postgresql.mcp as pgmcp;

# PostgreSQL connection configuration.
configurable string dbHost = "localhost";
configurable int dbPort = 5432;
configurable string dbUsername = "postgres";
configurable string dbPassword = "postgres";
configurable string dbName = "postgres";

# MCP listener configuration.
configurable int mcpPort = 8080;
configurable string mcpPath = "/mcp";
configurable boolean readOnly = true;

# The listener is registered with the module and starts automatically. The PostgreSQL MCP tool implementations are
# supplied by `ballerinax/postgresql.mcp`; this package does not need to declare them again.
listener pgmcp:PostgresMcpListener postgresqlMcpListener = new (
    {
        host: dbHost,
        port: dbPort,
        username: dbUsername,
        password: dbPassword,
        database: dbName
    },
    {readOnly: readOnly},
    {port: mcpPort, path: mcpPath}
);
