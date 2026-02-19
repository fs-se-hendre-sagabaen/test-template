#!/usr/bin/env bash
# Curl-based API test suite (example)
# Usage:
#   BASE_URL=http://localhost:3000 ./server/tests.sh

set -u

# T E S T  S U I T E
#################################################################################################################
BASE_URL=${BASE_URL:-http://localhost:3000}
PASS=0
FAIL=0
RED='\033[0;31m'
GREEN='\033[0;32m'
NC='\033[0m' # No Color

ok() { printf "${GREEN}[  OK  ]${NC} %s\n" "$1"; PASS=$((PASS+1)); }
err() { printf "${RED}[ FAIL ]${NC} %s\n" "$1"; FAIL=$((FAIL+1)); }

# Helper: perform HTTP request and split body/status
request() {
    local method=$1 path=$2 data=${3:-}
    if [ -n "$data" ]; then
        resp=$(curl -s -w "\n%{http_code}" -H "Content-Type: application/json" -X "$method" "$BASE_URL$path" -d "$data")
    else
        resp=$(curl -s -w "\n%{http_code}" -X "$method" "$BASE_URL$path")
    fi
    status=$(printf "%s" "$resp" | tail -n1)
    body=$(printf "%s" "$resp" | sed '$d')
}

#################################################################################################################

# Try to extract an `id` from JSON using jq if available, otherwise a regexp fallback
extract_id() {
    local json=$1
    if command -v jq >/dev/null 2>&1; then
        printf "%s" "$json" | jq -r '.id // .data.id // empty'
    else
        # loose regex match for "id": "..." or "id": 123
        printf "%s" "$json" | sed -n 's/.*"id"[[:space:]]*:[[:space:]]*"\?\([^",}]*\)\"\?.*/\1/p' | head -n1
    fi
}

echo "API test suite -> BASE_URL=$BASE_URL"

# 1) Health check
request GET /health
if [ "$status" = "200" ]; then
    ok "GET /health returned 200"
else
    err "GET /health expected 200, got $status"
fi

# 2) Create an item (POST /items)
payload='{"name":"test item","description":"created by integration test"}'
request POST /items "$payload"
if [ "$status" = "201" ] || [ "$status" = "200" ]; then
    item_id=$(extract_id "$body")
    if [ -n "$item_id" ]; then
        ok "POST /items created id=$item_id"
    else
        err "POST /items returned success but no id found in response"
    fi
else
    err "POST /items expected 201/200, got $status"
fi

# 3) List items (GET /items)
request GET /items
if [ "$status" = "200" ]; then
    if printf "%s" "$body" | grep -q "test item"; then
        ok "GET /items contains created item"
    else
        err "GET /items returned 200 but item not found in body"
    fi
else
    err "GET /items expected 200, got $status"
fi

# 4) Get single item by id (if we have one)
if [ -n "${item_id-}" ]; then
    request GET "/items/$item_id"
    if [ "$status" = "200" ]; then
        ok "GET /items/$item_id returned 200"
    else
        err "GET /items/$item_id expected 200, got $status"
    fi
fi

# 5) Update item (PUT /items/:id)
if [ -n "${item_id-}" ]; then
    update='{"name":"updated name"}'
    request PUT "/items/$item_id" "$update"
    if [ "$status" = "200" ]; then
        ok "PUT /items/$item_id returned 200"
    else
        err "PUT /items/$item_id expected 200, got $status"
    fi
fi

# 6) Delete item
if [ -n "${item_id-}" ]; then
    request DELETE "/items/$item_id"
    if [ "$status" = "204" ] || [ "$status" = "200" ]; then
        ok "DELETE /items/$item_id returned $status"
    else
        err "DELETE /items/$item_id expected 204/200, got $status"
    fi
fi

echo
echo "Summary: Passed=$PASS  Failed=$FAIL"
if [ "$FAIL" -ne 0 ]; then
    echo "One or more tests failed." >&2
    exit 1
else
    echo "All tests passed."
    exit 0
fi