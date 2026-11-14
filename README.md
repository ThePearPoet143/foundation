# Foundation

Shared rules and CI for all my repos. A repo calls the foundation's workflow in one step and gets the same checks as
every other repo.

## Use it in a repo

Add `.github/workflows/pr.yml`:

```yaml
name: pr
on:
  pull_request:
    types: [opened, edited, synchronize, reopened]
jobs:
  rules:
    uses: ThePearPoet143/foundation/.github/workflows/pr-rules.yml@v0.3.0
    with:
      issue-prefix: SUS   # the repo's Linear key
```

The foundation is at 0.x: "Major version zero (0.y.z) is for initial development. Anything MAY change at any time"
([Semantic Versioning](https://semver.org/), the specification). So a repo pins an exact version and moves to a newer one in its
own small PR, after reading the release notes. A moving `v1` tag comes when the rules are stable. Each repo keeps its
own CI for its own tests.

Every file here that calls another part of the foundation names the same version as its release (`@v0.3.0`), so a
release's tag points at files that refer to it.

## The guardrails check

`checks: guardrails` checks that a pull request works on one Linear issue whose scope was agreed (SUS-71): every commit,
and every row it adds to a `changes\*.md` log, names the issue in its title; and in Linear the issue is past Backlog,
since moving it out is how its scope is agreed. Releases and Dependabot's pull requests skip it.

It starts in dry-run, warning only, as pingdotgg/t3code's `pr-limits.yml` does (MIT). Set the repository variable
`GUARDRAILS_ENFORCE` to `true` to make it fail, and pass a Linear API key:

```yaml
    with:
      issue-prefix: SUS
      checks: text, size, branch, guardrails
      guardrails-enforce: ${{ vars.GUARDRAILS_ENFORCE }}
    secrets:
      LINEAR_API_KEY: ${{ secrets.LINEAR_API_KEY }}
```

## Where you see what

| What | Where |
| ---- | ----- |
| Each check's pass or fail | The pull request's checks list: green, red, or a yellow warning |
| What each check found, and why | One comment on the pull request, from the `report` job, edited on every push (SUS-73) |
| The full detail | The check's log, in the Checks tab |
| The work's progress | Linear: the pull request links its issue, and merging marks it Done |
| What a release brought | The GitHub release's notes, from the release pull request |

A calling repo grants the report `pull-requests: write`, as it does for the size check's labels.

## Staying current

Dependabot brings each release to the repo: add `.github/dependabot.yml`, and it opens a pull request into the default
branch that bumps the version, "references to actions in a repository's workflow.yml file and reusable workflows used
inside workflows" ([GitHub](https://docs.github.com/en/code-security/dependabot/working-with-dependabot/keeping-your-actions-up-to-date-with-dependabot)).
That pull request runs the new version's checks, so a breaking change shows there before the merge.

```yaml
version: 2
updates:
  - package-ecosystem: github-actions
    directory: /
    schedule:
      interval: weekly
    allow:
      - dependency-name: ThePearPoet143/foundation*
    cooldown:
      exclude:
        - ThePearPoet143/foundation*
```

`cooldown.exclude` lets a release through the day it's out: Dependabot otherwise holds every new version back by a
"default cooldown period of 3 days" (GitHub, Dependabot options reference).

Dependabot's pull requests run only the size check: a bot writes no issue key, sections or 🤖 line, so the text and
branch checks skip them.

## Releasing

A release is a pull request from `dev` into `main`, titled `chore(release): v0.2.0, what it brings (SUS-123)`, after
every call in `pr-rules.yml` has moved to `@v0.2.0`. Merging it releases it: `release.yml` tags the merge `v0.2.0` and
publishes the GitHub release, named from the title, with the pull request's "What and why" as its notes. Then
Dependabot opens the bump in every repo (Staying current). A title that names a different version than `pr-rules.yml`
fails the release instead of tagging it.

## The rules

**Title:** `type(scope): what changed (KEY-123)`, at most 72 characters: plain words saying what's different, the
Linear issue key last. The types are Conventional Commits' `feat` and `fix`, plus `docs`, `chore`, `refactor`, `test`,
`ci`, `build`, `perf` and `style`, which `@commitlint/config-conventional` recommends
([Conventional Commits 1.0.0](https://www.conventionalcommits.org/en/v1.0.0/)). A `!` after the type marks a breaking
change. Commits still start with the issue key (`SUS-27: …`), so Linear links each one.

**Description:**

| Type | Needs |
| ---- | ----- |
| every type | `## What and why`, at most 120 words |
| `fix` | `## Tests`, naming the Red step: the test that failed before the fix |
| `feat` | `## Proven`: where it was shown to work |

**Last line:** 🤖, then the model and its version, e.g. `🤖 Claude Opus 5.5`.

**Linear issues:** title at most 60 characters, body at most 80 words, with a "Done when". Check one before saving:

```
powershell -File .github\actions\text-check\Invoke-TextCheck.ps1 -IssueTitle '…' -IssueBody '…'
```

Words are counted as words and numbers; marks such as ✓ and — don't count.

## Size

`checks: text, size` turns on the size check. It labels each PR by its effective changed lines, with Kubernetes'
thresholds (`kubernetes-sigs/prow`, `pkg/plugins/size/size.go`), the same T3 Code uses:

| Label | Changed lines | What it calls for |
| ----- | ------------- | ----------------- |
| `size:XS` | 0–9 | the text check |
| `size:S` | 10–29 | the text check |
| `size:M` | 30–99 | an AI review: the PR is labelled `review:ai` |
| `size:L` | 100–499 | an AI review, and the owner's |
| `size:XL` | 500–999 | fails: split it, or label it `size-exempt` and say why |
| `size:XXL` | 1,000+ | fails, as `size:XL` |

Lockfiles, generated and vendored files, and `changes/` aren't counted; nor are tests, unless a PR changes only tests.
A repo leaves out more with `size-extra-ignored`. The size check labels the PR, so the calling job grants
`pull-requests: write` and `issues: write` (see the comment in `pr-rules.yml`): a called workflow can't grant itself
more than its caller.

## Branches and commits

`checks: text, size, branch` turns on the branch and commit checks:

- **Target branch:** pull requests go into `dev`. One into `main` must be a release, from `dev`; anything else fails.
- **Commits:** each one starts with its issue key (`SUS-29: …`), so Linear links it. GitHub's own "Merge pull request
  #n" commits pass. A release skips this check: its commits were checked on their way into `dev`.
- **Release:** one that names no issue (`SUS-123`) gets a warning, since Linear moves an issue only when a pull request
  names it.

## Writing PowerShell for both shells

The scripts run in Windows PowerShell 5.1 and PowerShell 7. A `.ps1` file with any character outside ASCII (🤖, ✓, —)
is saved as UTF-8 **with a BOM**: Windows PowerShell 5.1 reads a file without one as ANSI. And PowerShell treats the
typographic quotes ‘ ’ “ ” as quote marks, so write them as `’` and the like inside a string.
