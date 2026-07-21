// Copyright (c) 2026 WSO2 LLC (http://www.wso2.com).
// Licensed under the Apache License, Version 2.0.

import ballerina/sql;

isolated function toRawQuery(string rawSql) returns sql:ParameterizedQuery {
    sql:ParameterizedQuery query = ``;
    query.strings = [rawSql];
    return query;
}

isolated function toRawCallQuery(string rawSql) returns sql:ParameterizedCallQuery {
    sql:ParameterizedCallQuery query = ``;
    query.strings = [rawSql];
    return query;
}

isolated function readOnlyError() returns error {
    return error("disabled: server is running in READ_ONLY mode; set `readOnly` to false to enable write tools");
}
