import ballerina/test;

@test:Config {}
function testDefaultServiceConfigIsReadOnly() {
    ServiceConfig config = {};
    test:assertTrue(config.readOnly);
}
