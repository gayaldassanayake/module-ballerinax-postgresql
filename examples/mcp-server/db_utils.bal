import ballerina/sql;
import ballerinax/postgresql;

// Hand-authored helpers (not derived from the connector's generated API) that adapt the
// postgresql:Client's query-template-based API to the MCP tools' raw-SQL-string inputs.
// See DESIGN.md for why the tools accept a plain string rather than a template + bind params.

// Wraps a runtime SQL string into a single-segment, zero-bind-parameter
// sql:ParameterizedQuery. The same technique used internally by
// ballerinax/persist.sql (persist.sql/utils.bal#stringToParameterizedQuery):
// an empty raw-template literal is a valid ParameterizedQuery, and its
// `strings` field can be reassigned afterwards.
isolated function toRawQuery(string rawSql) returns sql:ParameterizedQuery {
    sql:ParameterizedQuery query = ``;
    query.strings = [rawSql];
    return query;
}

// Same trick for procedure/function calls.
isolated function toRawCallQuery(string rawSql) returns sql:ParameterizedCallQuery {
    sql:ParameterizedCallQuery query = ``;
    query.strings = [rawSql];
    return query;
}

isolated function toSslMode(string mode) returns postgresql:SSLMode {
    match mode.toUpperAscii() {
        "REQUIRE" => {
            return postgresql:REQUIRE;
        }
        "DISABLE" => {
            return postgresql:DISABLE;
        }
        "ALLOW" => {
            return postgresql:ALLOW;
        }
        "VERIFY-CA"|"VERIFY_CA" => {
            return postgresql:VERIFY_CA;
        }
        "VERIFY-FULL"|"VERIFY_FULL" => {
            return postgresql:VERIFY_FULL;
        }
        _ => {
            return postgresql:PREFER;
        }
    }
}
