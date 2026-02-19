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

# I M P O R T A N T
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

# Health check
request GET /health
if [ "$status" = "200" ]; then
    ok "GET /health returned 200"
else
    err "GET /health expected 200, got $status"
fi

#################################################################################################################

# 1) Register user (POST /user/register)
payload='{"email": "testuser@getfullsuite.com","password": "testpassword"}'
request POST /user/register "$payload"
if [ "$status" = "201" ] || [ "$status" = "200" ]; then
    user_id=$(extract_id "$body")
    if [ -n "$user_id" ]; then
        ok "POST /user/register created id=$user_id"
    else
        err "POST /user/register returned success but no id found in response"
    fi
else
    err "POST /user expected 201/200, got $status"
fi

# 2) Login user (POST /user/login)
payload='{"email": "testuser@getfullsuite.com","password": "testpassword"}'
request POST /user/login "$payload"
if [ "$status" = "201" ] || [ "$status" = "200" ]; then
    user_id=$(extract_id "$body")
    if [ -n "$user_id" ]; then
        ok "POST /user/login created id=$user_id"
    else
        err "POST /user/login returned success but no id found in response"
    fi
else
    err "POST /user expected 201/200, got $status"
fi

# 3) List user (GET /user)
request GET /user
if [ "$status" = "200" ]; then
    if printf "%s" "$body" | grep -q "testuser"; then
        ok "GET /user contains created user"
    else
        err "GET /user returned 200 but user not found in body"
    fi
else
    err "GET /user expected 200, got $status"
fi

# 4) Get single user by id (if we have one)
if [ -n "${user_id-}" ]; then
    request GET "/users/$user_id"
    if [ "$status" = "200" ]; then
        ok "GET /users/$user_id returned 200"
    else
        err "GET /users/$user_id expected 200, got $status"
    fi
fi

# # 5) Update user (PUT /users/:id)
# if [ -n "${user_id-}" ]; then
#     update='{"name":"updated name"}'
#     request PUT "/users/$user_id" "$update"
#     if [ "$status" = "200" ]; then
#         ok "PUT /users/$user_id returned 200"
#     else
#         err "PUT /users/$user_id expected 200, got $status"
#     fi
# fi

echo
echo "Summary: Passed=$PASS  Failed=$FAIL"
if [ "$FAIL" -ne 0 ]; then
    echo "One or more tests failed." >&2
    exit 1
else
    echo "All tests passed."
    exit 0
fi