#!/usr/bin/env bash
# Live API QA pass against http://localhost:3001 — research-based checklist:
# auth/session, RBAC at every endpoint, company-based authorization,
# validation, injection attempts, edge cases.
BASE=http://localhost:3001
PASS=0; FAIL=0
say() { echo "[$1] $2"; }
ok()  { PASS=$((PASS+1)); say PASS "$1"; }
bad() { FAIL=$((FAIL+1)); say FAIL "$1"; }

req() { # req METHOD PATH [TOKEN] [DATA] -> "STATUS|BODY"
  local m=$1 p=$2 t=$3 d=$4
  local args=(-s -m 10 -o /tmp/qa-body.json -w '%{http_code}' -X "$m" "$BASE$p" -H 'Content-Type: application/json')
  [ -n "$t" ] && args+=(-H "Authorization: Bearer $t")
  [ -n "$d" ] && args+=(-d "$d")
  local st; st=$(curl "${args[@]}")
  echo "$st|$(cat /tmp/qa-body.json)"
}

expect() { # expect LABEL EXPECTED_ACTUAL(String) EXPECTED(String)
  if [ "$2" = "$3" ]; then ok "$1"; else bad "$1 (expected $3, got $2)"; fi
}
expect_ne() {
  if [ "$2" != "$3" ]; then ok "$1"; else bad "$1 (got $2)"; fi
}
contains() {
  case "$2" in *"$3"*) ok "$1";; *) bad "$1 (body lacks '$3')";; esac
}

echo "=== 1. AUTH: invalid credentials blocked ==="
R=$(req POST /api/auth/login '' '{"identifier":"hemant","password":"WrongPass1!"}')
expect "wrong password -> 401" "${R%%|*}" 401
contains "generic error (no user enumeration)" "$R" "Invalid username/email or password"

R=$(req POST /api/auth/login '' '{"identifier":"ghost_user","password":"Whatever1!"}')
expect "unknown user -> 401 (same message)" "${R%%|*}" 401
contains "same generic error" "$R" "Invalid username/email or password"

echo "=== 2. VALIDATION: malformed input rejected ==="
R=$(req POST /api/auth/register '' '{"fullName":"","username":"x","email":"bad","password":"short","confirmPassword":"other"}')
expect "blank/invalid register -> 400" "${R%%|*}" 400
contains "email field error present" "$R" "email"

R=$(req POST /api/auth/login '' '{"identifier":"a@b.com"}')
expect "missing password -> 400" "${R%%|*}" 400

echo "=== 3. INJECTION: NoSQL-style payloads rejected ==="
R=$(req POST /api/auth/login '' '{"identifier":{"$gt":""},"password":{"$gt":""}}')
expect_ne "object-as-string payload NOT 200" "${R%%|*}" 200

R=$(req POST /api/auth/login '' '{"identifier":"admin","password":"Admin@123","$where":"1==1"}')
expect_ne "dollar-key payload NOT 200" "${R%%|*}" 200

echo "=== 4. AUTHENTICATED SESSION ==="
R=$(req POST /api/auth/login '' '{"identifier":"hemant","password":"User@123"}')
expect "valid login -> 200" "${R%%|*}" 200
USER_TOKEN=$(echo "$R" | cut -d'|' -f2 | sed -n 's/.*"token":"\([^"]*\)".*/\1/p')
[ -n "$USER_TOKEN" ] && ok "JWT issued" || bad "no token in login response"

R=$(req GET /api/auth/me "$USER_TOKEN")
expect "me with token -> 200" "${R%%|*}" 200
contains "menu limited to USER role" "$R" '"menu":["dashboard","users","settings"]'

R=$(req GET /api/auth/me '')
expect "me without token -> 401" "${R%%|*}" 401
R=$(req GET /api/auth/me "garbage.token.here")
expect "me with garbage token -> 401" "${R%%|*}" 401

echo "=== 5. RBAC: USER blocked from SUPER_ADMIN endpoints ==="
for EP in /api/reports/summary /api/admin/users /api/admin/companies; do
  R=$(req GET "$EP" "$USER_TOKEN")
  expect "USER GET $EP -> 403" "${R%%|*}" 403
done
R=$(req GET /api/admin/users "garbage.token.here")
expect "garbage token on admin route -> 401" "${R%%|*}" 401

echo "=== 6. COMPANY-BASED AUTHORIZATION ==="
R=$(req GET /api/external-users "$USER_TOKEN")
expect "USER list -> 200" "${R%%|*}" 200
COMPANY=$(echo "$R" | cut -d'|' -f2 | sed -n 's/.*"company":{"name":"\([^"]*\)".*/\1/p')
contains "all rows are Romaguera-Crona (server-filtered)" "$R" "Romaguera-Crona"
if echo "$R" | grep -q "Deckow-Crist"; then bad "LEAK: other company visible"; else ok "no other company leaked"; fi

OTHER_ID=$(curl -s -m 10 https://jsonplaceholder.typicode.com/users | sed -n 's/.*"company":{"name":"Deckow-Crist".*"id":\([0-9]*\).*/\1/p' | head -1)
[ -z "$OTHER_ID" ] && OTHER_ID=2  # fallback: user 2 is Deckow-Crist on jsonplaceholder
R=$(req GET "/api/external-users/$OTHER_ID" "$USER_TOKEN")
expect "USER fetches other-company user by id -> 403 (not silent)" "${R%%|*}" 403

echo "=== 7. EDGE CASES ==="
R=$(req GET /api/external-users/99999 "$USER_TOKEN")
expect "nonexistent user -> 404" "${R%%|*}" 404
R=$(req GET /api/external-users/abc "$USER_TOKEN")
expect "non-numeric id -> 400" "${R%%|*}" 400
R=$(req GET /api/nonexistent "$USER_TOKEN")
expect "unknown route -> 404" "${R%%|*}" 404
R=$(req GET /api/health '')
expect "health open (no auth) -> 200" "${R%%|*}" 200

echo "=== 8. ADMIN POWER (positive control) ==="
R=$(req POST /api/auth/login '' '{"identifier":"admin","password":"Admin@123"}')
expect "admin login -> 200" "${R%%|*}" 200
ADMIN_TOKEN=$(echo "$R" | cut -d'|' -f2 | sed -n 's/.*"token":"\([^"]*\)".*/\1/p')
R=$(req GET /api/reports/summary "$ADMIN_TOKEN")
expect "admin GET reports -> 200" "${R%%|*}" 200
R=$(req GET /api/admin/users "$ADMIN_TOKEN")
expect "admin GET users -> 200" "${R%%|*}" 200

echo ""
echo "=============================="
echo "QA RESULT: $PASS passed, $FAIL failed"
echo "=============================="
exit $FAIL
