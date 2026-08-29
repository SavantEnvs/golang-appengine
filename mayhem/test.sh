#!/usr/bin/env bash
#
# mayhem/test.sh — BEHAVIORAL oracle for golang-appengine. Runs the dynamically-
# linked KAT probe (/mayhem/appengine_kat, built by build.sh) that marshals+decodes
# a fixed remote_api.Response through the real protobuf wire codec (the exact parser
# internal/api.go's Call() runs on the dev-appserver HTTP body), and asserts the
# EXACT decoded field values.
#
# Why not `go test` alone (netnew §4): a Go test binary is statically linked, so the
# gate's LD_PRELOAD sabotage shim cannot neuter it — the suite would survive sabotage
# while proving nothing (the cosign/notary false-green). The KAT probe is cgo-linked
# (dynamic), so when the program is neutered to _exit(0) it prints nothing, every
# assertion below misses, and test.sh FAILS — which is the point (§6.3).
#
# Emits a CTRF summary; exits non-zero iff failed>0.
set -uo pipefail
[ -n "${SOURCE_DATE_EPOCH:-}" ] || unset SOURCE_DATE_EPOCH
cd "${SRC:-/mayhem}"

emit_ctrf() {
  local tool="$1" passed="$2" failed="$3" skipped="${4:-0}" pending="${5:-0}" other="${6:-0}"
  local tests=$(( passed + failed + skipped + pending + other ))
  cat > "${CTRF_REPORT:-${SRC:-/mayhem}/ctrf-report.json}" <<JSON
{
  "results": {
    "tool": { "name": "$tool" },
    "summary": {
      "tests": $tests,
      "passed": $passed,
      "failed": $failed,
      "pending": $pending,
      "skipped": $skipped,
      "other": $other
    }
  }
}
JSON
  printf 'CTRF {"results":{"tool":{"name":"%s"},"summary":{"tests":%d,"passed":%d,"failed":%d,"pending":%d,"skipped":%d,"other":%d}}}\n' \
    "$tool" "$tests" "$passed" "$failed" "$pending" "$skipped" "$other"
  [ "$failed" -eq 0 ]
}

PROBE=/mayhem/appengine_kat
passed=0; failed=0

# Unconditional: a missing probe is a build.sh bug — FAIL loudly, never skip.
if [ ! -x "$PROBE" ]; then
  echo "FAIL: KAT probe $PROBE missing or not executable (build.sh should have produced it)" >&2
  emit_ctrf "appengine-kat" 0 1
  exit 1
fi

OUT="$("$PROBE" 2>/dev/null)"
echo "--- KAT probe output ---"; printf '%s\n' "$OUT"; echo "------------------------"

# Fixed input: Response{Response:"hi", ApplicationError{code:42,detail:"boom"},
# RpcError{code:3,detail:"deadline"}} marshaled then decoded. Assert every decoded
# field against the known answer (values + the exact 28-byte wire length).
assert() { # <desc> <expected-line>
  if printf '%s\n' "$OUT" | grep -qxF "$2"; then
    echo "PASS: $1"; passed=$((passed+1))
  else
    echo "FAIL: $1 (expected exact line: $2)"; failed=$((failed+1))
  fi
}

assert "application_error.code decodes to 42"        "KAT_APPCODE=42"
assert "application_error.detail decodes to boom"    "KAT_APPDETAIL=boom"
assert "rpc_error.code decodes to 3"                 "KAT_RPCCODE=3"
assert "rpc_error.detail decodes to deadline"        "KAT_RPCDETAIL=deadline"
assert "response payload decodes to hi"              "KAT_RESP=hi"
assert "marshaled wire length is 28 bytes"           "KAT_WIRELEN=28"

emit_ctrf "appengine-kat" "$passed" "$failed"
