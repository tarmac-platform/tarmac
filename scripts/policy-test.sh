#!/usr/bin/env bash
# Kyverno policy test suite — the Week 4 CI gate.
#
# Pass fixtures must pass EVERY rule, fail fixtures must fail at least one.
# Uses `kyverno apply` against static manifests; no cluster required.
set -uo pipefail

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
POLICIES=(
  "$ROOT/policies/require-resource-limits.yaml"
  "$ROOT/policies/disallow-latest-tag.yaml"
  "$ROOT/policies/require-non-root.yaml"
  "$ROOT/policies/require-labels.yaml"
)
PASS_DIR="$ROOT/policies/tests/pass"
FAIL_DIR="$ROOT/policies/tests/fail"

failures=0

for fixture in "$PASS_DIR"/*.yaml; do
  name="$(basename "$fixture")"
  result="$(kyverno apply "${POLICIES[@]}" --resource "$fixture" 2>&1)"
  if echo "$result" | grep -q "^pass: 5, fail: 0"; then
    echo "PASS: $name"
  else
    echo "FAIL: $name (expected all rules to pass)"
    echo "$result"
    failures=$((failures + 1))
  fi
done

for fixture in "$FAIL_DIR"/*.yaml; do
  name="$(basename "$fixture")"
  result="$(kyverno apply "${POLICIES[@]}" --resource "$fixture" 2>&1)"
  if echo "$result" | grep -qE "fail: [1-9]"; then
    echo "PASS: $name (correctly rejected)"
  else
    echo "FAIL: $name (expected rejection)"
    echo "$result"
    failures=$((failures + 1))
  fi
done

if [ "$failures" -gt 0 ]; then
  echo "policy-test: $failures fixture(s) failed"
  exit 1
fi
echo "policy-test: all fixtures green"
