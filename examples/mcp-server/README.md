# PostgreSQL MCP Server

A Ballerina MCP (Model Context Protocol) server that exposes the
[`ballerinax/postgresql`](https://central.ballerina.io/ballerinax/postgresql/latest) connector's
`Client` operations as MCP tools, so an AI agent can query and (optionally) modify a PostgreSQL
database.

This example uses the reusable `ballerinax/postgresql.mcp` module. Its module-level
`PostgresMcpListener` declaration starts with the Ballerina package lifecycle, so it does not
reserve or modify an application's `main` function. See [`DESIGN.md`](./DESIGN.md) for the
reasoning behind what's included and what's deliberately left out.

## Tools

| Tool | Underlying operation | Notes |
|---|---|---|
| `execute_query` | `Client->query()` | Returns every matching row as JSON. |
| `execute_query_row` | `Client->queryRow()` | Returns a single row as JSON; errors if zero or multiple rows. |
| `execute_statement` | `Client->execute()` | DDL/DML. **Refused in READ_ONLY mode.** |
| `batch_execute_statement` | `Client->execute()` looped per statement* | Runs an array of statements in order, returns per-statement results. **Refused in READ_ONLY mode.** |
| `call_procedure` | `Client->call()` | Stored procedure/function call. **Refused in READ_ONLY mode.** |

Every tool takes a **complete, valid SQL string** as input — there is no bind-parameter
placeholder syntax. The calling model is expected to compose the full statement itself (this
matches how other Postgres MCP servers, e.g. `postgres-mcp` and AWS's Aurora Postgres MCP server,
work).

\* `batch_execute_statement` does not use `Client->batchExecute()` directly: that connector
function requires every statement in the batch to share one query template with only the bind
values differing, which is incompatible with taking independent raw SQL strings. See `DESIGN.md`.

## Setup

1. Start a throwaway Postgres instance, seeded with a small `customers`/`orders` schema:
   ```bash
   docker-compose up -d
   ```
2. Confirm `Config.toml` matches the compose file's credentials (it does, out of the box). For a
   real database, copy `Config.toml.sample` and fill in your own values, or override values on the
   command line (see below) — never hardcode credentials into `.bal` source.

## Run

```bash
bal run
```

The server listens over **streamable HTTP only**, at `http://localhost:<mcpPort>/mcp` (default
`http://localhost:8080/mcp`). Ballerina's `ballerina/mcp` module does not support a stdio
transport, so unlike many local MCP servers this one must be reached over HTTP — see
[`DESIGN.md`](./DESIGN.md).

Override any configurable at the command line, e.g.:

```bash
bal run -- -CreadOnly=false -CdbHost=db.example.internal
```

## The `READ_ONLY` safety flag

The `readOnly` configurable (default `true`) is the app-level safety flag mentioned in the
requirements. When `true`, `execute_statement`, `batch_execute_statement`, and `call_procedure` are
still listed in the MCP tool schema, but calling any of them returns an error immediately without
touching the database. Flip it in `Config.toml` or with `-CreadOnly=false`.

**This flag is defense-in-depth only, not the security boundary.** The strongest control is a
dedicated, least-privilege PostgreSQL role for the connection itself (e.g. a role with only
`SELECT` granted) — configure `dbUsername`/`dbPassword` to point at such a role in any
non-throwaway environment. `readOnly` just adds a second layer on top of that.

## Connecting an MCP client

Any MCP client that speaks streamable HTTP can point directly at
`http://localhost:8080/mcp`.

Claude Desktop's built-in config only launches stdio servers, so bridge it with
[`mcp-remote`](https://www.npmjs.com/package/mcp-remote):

```json
{
  "mcpServers": {
    "postgresql": {
      "command": "npx",
      "args": ["-y", "mcp-remote", "http://localhost:8080/mcp"]
    }
  }
}
```

## Manual verification without a client

```bash
curl -s http://localhost:8080/mcp \
  -H 'Content-Type: application/json' -H 'Accept: application/json, text/event-stream' \
  -d '{"jsonrpc":"2.0","id":1,"method":"initialize","params":{"protocolVersion":"2025-03-26","capabilities":{},"clientInfo":{"name":"curl","version":"0"}}}'

curl -s http://localhost:8080/mcp \
  -H 'Content-Type: application/json' -H 'Accept: application/json, text/event-stream' \
  -d '{"jsonrpc":"2.0","id":2,"method":"tools/list"}'

curl -s http://localhost:8080/mcp \
  -H 'Content-Type: application/json' -H 'Accept: application/json, text/event-stream' \
  -d '{"jsonrpc":"2.0","id":3,"method":"tools/call","params":{"name":"execute_query","arguments":{"sql":"SELECT * FROM customers"}}}'
```

Or use an interactive inspector instead of raw curl:

```bash
npx @modelcontextprotocol/inspector http://localhost:8080/mcp
```

## Known limitations

- **Tool errors aren't flagged with `isError`**: confirmed by testing, `ballerina/mcp`'s simple
  service form returns a failed tool call (READ_ONLY refusal, a bad query, etc.) as normal text
  content — e.g. `error("disabled: ...")` — inside an otherwise successful `CallToolResult`, not
  with the protocol's `isError: true` set. The error text is still clearly readable by a calling
  model, but a client that branches strictly on `isError` rather than reading content text won't
  detect the failure. See `DESIGN.md`.
- **Row typing**: all rows decode to a generic open record and convert to JSON; there's no way for
  a tool caller to supply a typed row shape (MCP tool schemas can't carry a Ballerina `typedesc` at
  runtime). See `DESIGN.md`.
- **Binary/JSON columns pass through as-is**: `bytea` columns serialize as arrays of small
  integers (not base64); Postgres `json`/`jsonb` columns typically decode to a plain string
  containing the raw JSON text, not a nested JSON object. No special-casing is done per column
  type.
- **`call_procedure` has no typed OUT/INOUT parameter support**: since the tool takes a raw SQL
  string rather than typed bind values, only output reachable via a result set or the execution
  summary is returned.
- **No schema-discovery resources** (`list_tables`, `describe_table`, etc.) in this v1 — see
  `DESIGN.md`.
