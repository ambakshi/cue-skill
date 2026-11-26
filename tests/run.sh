#!/usr/bin/env bash
# Checks the skill's examples against the installed cue.
# Usage: tests/run.sh            (uses `cue` on PATH)
#        CUE="mise exec cue@0.18.0 -- cue" tests/run.sh
set -uo pipefail

root=$(cd "$(dirname "$0")/.." && pwd)
# Resolve the real binary from the repo root so a mise shim keeps the
# mise.toml pin when the tests cd into a temp copy.
CUE=${CUE:-$( (cd "$root" && mise which cue 2>/dev/null) || command -v cue)}
ex="$root/cue/examples"
fail=0

pass() { printf 'ok   %s\n' "$1"; }
bad() { printf 'FAIL %s\n' "$1"; fail=1; }

expect_ok() { # name, dir, cmd...
	local name=$1 dir=$2; shift 2
	if out=$(cd "$dir" && $CUE "$@" 2>&1); then pass "$name"; else bad "$name"; printf '%s\n' "$out"; fi
}

expect_err() { # name, dir, pattern, cmd...
	local name=$1 dir=$2 pat=$3; shift 3
	if out=$(cd "$dir" && $CUE "$@" 2>&1); then
		bad "$name (expected failure, got success)"
	elif grep -qE -- "$pat" <<<"$out"; then
		pass "$name"
	else
		bad "$name (missing /$pat/)"; printf '%s\n' "$out"
	fi
}

$CUE version | grep -q 'cue version v0\.18\.' || { echo "need cue v0.18.x, have: $($CUE version | head -1)"; exit 2; }

v="$ex/validate"
expect_ok  "validate: fmt clean"        "$v" fmt --check .
expect_ok  "validate: good.yaml passes" "$v" vet -c . good.yaml
expect_err "validate: bad regex name"   "$v" 'Bad_Name.name: invalid value'      vet -c . bad.yaml
expect_err "validate: bad enum"         "$v" 'Bad_Name.tier: .*empty disjunction' vet -c . bad.yaml
expect_err "validate: bad bound"        "$v" 'out of bound <=10'                 vet -c . bad.yaml
expect_err "validate: missing required" "$v" 'noimage.image: field is required'  vet -c . bad.yaml
expect_err "validate: matchIf worker"   "$v" 'queue: .*matchIf'                  vet -c . bad.yaml

t="$ex/template"
expect_ok  "template: fmt clean"  "$t" fmt --check .
expect_ok  "template: vet"        "$t" vet -c .
if out=$(cd "$t" && $CUE export . -t env=prod -e 'k8s.deployments.api.spec.replicas' 2>&1) && [[ $out == 3 ]]; then
	pass "template: env tag sets default replicas"
else bad "template: env tag (got: $out)"; fi
if out=$(cd "$t" && $CUE export . -e stream --out text 2>&1) && [[ $(grep -c '^kind:' <<<"$out") == 4 ]]; then
	pass "template: stream has 4 documents"
else bad "template: stream"; printf '%s\n' "$out"; fi
tmp=$(mktemp -d)
cp -r "$t/." "$tmp/"
if (cd "$tmp" && $CUE cmd gen >/dev/null 2>&1) && [[ $(ls "$tmp/out" | wc -l) == 4 ]]; then
	pass "template: cue cmd gen writes 4 files"
else bad "template: cue cmd gen"; fi
rm -rf "$tmp"

exit $fail
