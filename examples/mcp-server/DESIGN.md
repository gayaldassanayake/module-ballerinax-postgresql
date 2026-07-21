# Design notes

This is a deliberately scoped v1. The choices below were made explicitly, not by omission —
recorded here so they read as decisions when this work is reviewed internally.

## Why tools only, no resources

`ballerinax/postgresql`'s `Client` has no connector-level operation for schema discovery — there is
no `listTables()` or `describeTable()` remote function. That information only exists by querying
`information_schema`/`pg_catalog`, which means schema-discovery "resources" cannot be mechanically
derived from the connector's function signatures the way, say, a message broker connector's
`getAvailableTopics()` could be turned into a resource almost for free.

Building `postgres://{schema}/tables`-style resources is possible (phase 2), but it means
hand-authoring a small library of canned catalog queries — code that isn't a reflection of the
connector's API surface. If added later, those resources should be clearly marked in code and
docs as **hand-authored additions**, not generator output, so the distinction is visible to anyone
reviewing the work.

Prompts (`audit-table`, `explain-foreign-keys`, `profile-slow-query`) are the same story — useful,
but hand-authored, and out of scope for v1.

## Why raw-SQL-string tool input, not a template + bind-params scheme

The connector's API is generic SQL execution — the model has to supply the actual SQL regardless,
so there's no clean read/write split at the connector-function level, and no way to pre-declare a
parameter schema per tool. Given that, accepting a complete SQL string (the model composes the
whole statement) is simpler than asking the model to produce a placeholder template plus a
separate bind-value array, and matches how other Postgres MCP servers in this space work
(`crystaldba/postgres-mcp`, AWS's Aurora Postgres MCP server). The tradeoff is that there's no
statement/data separation at the tool boundary — mitigated by the `READ_ONLY` flag and, more
importantly, by running the connection as a least-privileged database role (see README).

**This has one concrete consequence for `batch_execute_statement`, confirmed by testing against a
real database**: `Client->batchExecute()` requires every statement in the batch to share one query
*template* (identical `strings` segments, differing only in bind-parameter values) — that's what
"batch" means at the JDBC level underneath it. Wrapping each independent raw SQL string as its own
zero-insertion template (per the pattern above) means any two statements with different literal
text - even the exact same shape with different values - are rejected with `"Batch Execute cannot
contain different SQL commands"`. Verified directly: two byte-identical INSERT statements batch
successfully; the same INSERT with a different `item`/`amount` does not. So `batch_execute_statement`
is implemented as a sequential loop of `Client->execute()` calls, one per statement, rather than a
literal `Client->batchExecute()` call — this is a deliberate deviation from REQ's stated 1:1
tool-to-function mapping for this one tool, made because the literal mapping is not actually usable
for real batched DML under the raw-SQL-string input contract. The tool's external behavior (run N
statements, get back N execution results) is unchanged from what REQ describes; only the underlying
connector call differs.

## Why all 5 tools are always visible, gated at call time

Ballerina's `@mcp:Tool` annotations on a `service mcp:Service` are resolved statically at compile
time — there's no supported way to conditionally register/hide a tool at runtime based on a
config value with this service form (the alternative, `mcp:AdvancedService` with a hand-written
`onListTools`, was considered and rejected: it would mean manually maintaining JSON schemas for
tools whose inputs are already plain scalars/arrays, for no functional benefit here).

So `READ_ONLY` is enforced as a runtime guard at the top of each write tool's body instead: the
tool is always listed, but calling it while `readOnly=true` returns an error immediately. This
mirrors the "defense-in-depth, not the boundary" framing in the requirements — the tool-list
visibility isn't the security control either way; a least-privilege database role is.

**Confirmed by testing against the running server** (not assumed): when a tool's remote function
returns a Ballerina `error` — whether from the READ_ONLY guard, a connector-level `sql:Error`, or
any other `check`-propagated failure — `ballerina/mcp`'s simple `service mcp:Service` form returns
it as ordinary **text content** inside an otherwise successful `CallToolResult`; it does not set
the protocol's `isError: true` flag. The error message text (e.g. `"disabled: server is running in
READ_ONLY mode; ..."`) is still clearly legible to a calling model, so the guard functions
correctly in practice, but a client that specifically branches on `isError` rather than reading the
content text would not detect the failure. Documented as a known limitation in `README.md` rather
than worked around, since fixing it would require switching to `mcp:AdvancedService` with
hand-written `onCallTool`/schema maintenance — the exact complexity tradeoff already rejected
above.

## `call_procedure`'s OUT/INOUT limitation

`Client->call()` supports typed `sql:InOutParameter`/`sql:OutParameter` values normally, but since
this tool's input is a raw SQL string rather than typed bind values, there's no way to thread those
through. v1 only surfaces whatever a procedure returns via a result set or the execution summary.
Procedures relying on true OUT/INOUT parameters for their output aren't fully usable through this
tool yet — a documented v1 boundary, not an oversight.

## CDC / change-data-capture is out of scope

`CdcListener` (`onRead`/`onCreate`/`onUpdate`/`onDelete`) is a push/streaming model — a
long-running listener invoking callbacks per change event — that doesn't map onto MCP's
request/response tool-call shape. This was not forced into a tool. If pursued later, the right
direction is an MCP resource *subscription*, not a tool.
