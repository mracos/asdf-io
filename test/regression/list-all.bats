#!/usr/bin/env bats
# Regression: bin/list-all against the GitHub tags API.
#
# Contract:
#   - Parses both stable and pre-release tag names, oldest to newest.
#   - Sends an Authorization header when OAUTH_TOKEN is set, and none when not.
#   - Fails loudly when the response carries no tags. Unauthenticated
#     api.github.com is 60 requests/hour per IP and the 403 body is JSON, so
#     "parsed nothing" is the shape a rate limit actually arrives in.

load ../helpers

setup() {
    setup_sandbox
    TAGS_JSON="$WORK_DIR/tags.json"
    cat > "$TAGS_JSON" <<'JSON'
[
  { "name": "2019.05.22-alpha", "zipball_url": "https://example.invalid/a" },
  { "name": "2015.11.11", "zipball_url": "https://example.invalid/b" },
  { "name": "2017.09.06", "zipball_url": "https://example.invalid/c" }
]
JSON
    stub_curl "$TAGS_JSON"
}

teardown() { teardown_sandbox; }

@test "lists stable and pre-release tags, oldest first" {
    run bash "$PLUGIN_DIR/bin/list-all"
    [ "$status" -eq 0 ]
    [ "$output" = "2015.11.11 2017.09.06 2019.05.22-alpha" ] \
        || { echo "got: $output"; false; }
}

@test "sends no Authorization header without a token" {
    run bash "$PLUGIN_DIR/bin/list-all"
    [ "$status" -eq 0 ]
    run cat "$CURL_ARGS_LOG"
    [[ "$output" != *"Authorization"* ]] \
        || { echo "leaked an auth header: $output"; false; }
}

@test "sends the token as an Authorization header when OAUTH_TOKEN is set" {
    OAUTH_TOKEN=s3cret run bash "$PLUGIN_DIR/bin/list-all"
    [ "$status" -eq 0 ]
    run cat "$CURL_ARGS_LOG"
    [[ "$output" == *"Authorization: token s3cret"* ]] \
        || { echo "no auth header: $output"; false; }
}

@test "fails when the response carries no tags" {
    printf '%s\n' '{"message":"API rate limit exceeded for 20.1.2.3."}' > "$TAGS_JSON"

    run bash "$PLUGIN_DIR/bin/list-all"
    [ "$status" -ne 0 ] \
        || { echo "exited 0 on a rate-limit body: $output"; false; }
    [[ "$output" == *"no versions found"* ]]
    [[ "$output" == *"OAUTH_TOKEN"* ]]
}

@test "fails when curl reports an HTTP error" {
    CURL_HTTP_FAIL=1 run bash "$PLUGIN_DIR/bin/list-all"
    [ "$status" -ne 0 ]
    [[ "$output" == *"could not reach"* ]]
}
