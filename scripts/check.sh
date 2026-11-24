#!/bin/bash
# Run stageproof check-pr and keep its exit code. The comment is best-effort.
set -euo pipefail

die() {
  echo "stageproof: $*" >&2
  exit 2
}

k8s_ok() {
  printf '%s\n' "$1" | grep -Eq '^[0-9]+\.[0-9]+$'
}

bool_ok() {
  [ "$1" = "true" ] || [ "$1" = "false" ]
}

current="${STAGEPROOF_CURRENT_K8S:-}"
k8s_ok "$current" || die "current-k8s must look like 1.35"

next="${STAGEPROOF_NEXT_K8S:-}"
if [ -n "$next" ]; then
  k8s_ok "$next" || die "next-k8s must look like 1.36"
fi

api="${STAGEPROOF_API_SERVER:-auto}"
case "$api" in
  auto | off | require) ;;
  *) die "api-server must be auto, off, or require" ;;
esac

proof="${STAGEPROOF_VALUES_PROOF:-default}"
case "$proof" in
  default | full) ;;
  *) die "values-proof must be default or full" ;;
esac

offline="${STAGEPROOF_OFFLINE:-false}"
live="${STAGEPROOF_LIVE:-false}"
require="${STAGEPROOF_REQUIRE:-false}"
comment="${STAGEPROOF_COMMENT:-true}"
sarif="${STAGEPROOF_SARIF:-false}"
bool_ok "$offline" || die "offline must be true or false"
bool_ok "$live" || die "live must be true or false"
bool_ok "$require" || die "require-rehearsal must be true or false"
bool_ok "$comment" || die "comment must be true or false"
bool_ok "$sarif" || die "sarif must be true or false"

if [ -z "${GITHUB_BASE_REF:-}" ]; then
  die "this action checks a pull request, and github.base_ref is empty"
fi

args=(
  check-pr
  --current-git "origin/${GITHUB_BASE_REF}"
  --current-k8s "$current"
  --api-server "$api"
  --comment-file stageproof-comment.md
  --out stageproof-report.json
)
if [ -n "$next" ]; then
  args+=(--next-k8s "$next")
fi
if [ "$proof" = "full" ]; then
  args+=(--values-proof full)
fi
if [ "$offline" = "true" ]; then
  args+=(--offline)
fi
if [ "$live" = "true" ]; then
  args+=(--live)
fi
if [ "$require" = "true" ]; then
  args+=(--require-rehearsal)
fi
if [ "$sarif" = "true" ]; then
  args+=(--format sarif)
fi

set +e
if [ "$sarif" = "true" ]; then
  stageproof "${args[@]}" > stageproof.sarif
  result=$?
else
  stageproof "${args[@]}"
  result=$?
fi
set -e

if [ -n "${GITHUB_STEP_SUMMARY:-}" ] && [ -f stageproof-comment.md ]; then
  cat stageproof-comment.md >> "$GITHUB_STEP_SUMMARY"
fi

post=0
if [ "$comment" = "true" ] && [ -f stageproof-comment.md ]; then
  stageproof comment --file stageproof-comment.md --best-effort || post=$?
fi

if [ -n "${GITHUB_OUTPUT:-}" ]; then
  echo "result=${result}" >> "$GITHUB_OUTPUT"
fi

if [ "$result" -ne 0 ]; then
  exit "$result"
fi
exit "$post"
