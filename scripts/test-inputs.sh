#!/bin/bash
# Reject bad inputs before any download or check runs.
set -euo pipefail

root=$(cd "$(dirname "$0")/.." && pwd)
fail() {
  echo "FAIL $*" >&2
  exit 1
}

for bad in '' v0.3 v0.3.1-rc.1 'v0.3.1/extra' 'v0.3.1;rm' latest; do
  set +e
  STAGEPROOF_VERSION="$bad" bash "$root/scripts/install.sh" >/tmp/sp-action-out 2>/tmp/sp-action-err
  code=$?
  set -e
  if [ "$code" -ne 2 ]; then
    fail "version [${bad}] exited ${code}"
  fi
done

fake=$(mktemp -d)
printf '%s\n' '#!/bin/sh' 'echo CALLED >&2' 'exit 9' > "${fake}/stageproof"
chmod 755 "${fake}/stageproof"

run_check() {
  PATH="${fake}:${PATH}" \
    GITHUB_BASE_REF="${1}" \
    STAGEPROOF_CURRENT_K8S="${2}" \
    STAGEPROOF_API_SERVER="${3:-auto}" \
    STAGEPROOF_VALUES_PROOF="${4:-default}" \
    STAGEPROOF_OFFLINE="${5:-false}" \
    STAGEPROOF_LIVE="${6:-false}" \
    STAGEPROOF_REQUIRE="${7:-false}" \
    STAGEPROOF_COMMENT="${8:-true}" \
    STAGEPROOF_SARIF="${9:-false}" \
    bash "$root/scripts/check.sh" >/tmp/sp-action-out 2>/tmp/sp-action-err
}

set +e
run_check main '1.35;rm'
code=$?
set -e
if [ "$code" -ne 2 ] || grep -q CALLED /tmp/sp-action-err; then
  fail "bad current-k8s reached the binary (exit ${code})"
fi

set +e
run_check '' '1.35'
code=$?
set -e
if [ "$code" -ne 2 ] || grep -q CALLED /tmp/sp-action-err; then
  fail "empty base ref reached the binary (exit ${code})"
fi

set +e
run_check main '1.35' maybe
code=$?
set -e
if [ "$code" -ne 2 ] || grep -q CALLED /tmp/sp-action-err; then
  fail "bad api-server reached the binary (exit ${code})"
fi

sums=$(mktemp)
printf '%s\n' \
  'aaa  stageproof_0.3.1_linux_amd64.tar.gz' \
  'bbb  stageproof_0.3.1_linux_amd64.tar.gz.sbom.json' > "$sums"
line=$(awk -v name='stageproof_0.3.1_linux_amd64.tar.gz' '$2 == name { print }' "$sums")
if [ "$line" != 'aaa  stageproof_0.3.1_linux_amd64.tar.gz' ]; then
  fail "checksum line matched ${line}"
fi

echo "input checks passed"
