# stageproof/action

Check a Helm chart upgrade on a pull request. The action downloads the released Stageproof binary, checks `checksums.txt`, and runs `stageproof check-pr`.

Exit 0 is `PASSED` or `PROVEN`. Exit 1 is `BLOCKED`. Exit 2 is `NOT CHECKED`. The job uses that exit code.

```yaml
name: stageproof
on:
  pull_request:
permissions:
  contents: read
  pull-requests: write
jobs:
  check:
    runs-on: ubuntu-latest
    steps:
      - uses: stageproof/action@v1
        with:
          current-k8s: "1.35"
          api-server: auto
          comment: "true"
          live: "false"
```

`v1` is the major tag. It points at the latest `v1.x.x` release.

The action checks out the pull request with full git history. A caller checkout is not required. `pull-requests: write` lets `stageproof comment` post one comment, or update the comment that already contains `<!-- stageproof-comment -->`. A fork pull request often has a read-only token. The comment step treats HTTP 403 as success and still returns the check exit code.

Do not run this action from `pull_request_target`. That event checks out the base branch with a write token.

## Inputs

| Input | Default | Meaning |
|---|---|---|
| `version` | `v0.4.0` | Release tag. The action accepts only `v` plus three numbers. |
| `current-k8s` | required | Kubernetes version the cluster runs, such as `1.35`. |
| `next-k8s` | empty | Also check this next Kubernetes version. |
| `api-server` | `auto` | `auto`, `off`, or `require`. |
| `values-proof` | `default` | `default` or `full`. |
| `offline` | `false` | `true` skips container registry lookups. |
| `live` | `false` | `true` rehearses the upgrade in a temporary kind cluster. |
| `require-rehearsal` | `false` | `true` exits 2 unless that rehearsal ran and passed. |
| `comment` | `true` | Post or update one pull request comment. |
| `sarif` | `false` | Write SARIF and upload it. The job needs `security-events: write`. |
| `working-directory` | `.` | Directory that contains the chart checkout. |

`live: true` also installs kind v0.33.0 and kubectl v1.35.10 on Linux x86_64, after checking their checksums. The rehearsal needs a runner that can start containers.

The Markdown report is added to the job summary before the comment is posted.
