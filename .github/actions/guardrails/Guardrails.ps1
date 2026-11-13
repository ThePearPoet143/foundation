# The Guardrails check (SUS-71): a pull request works on one issue whose scope was agreed. Its commits and the rows it
# adds to a changes\*.md log name that issue, and in Linear the issue is past Backlog: moving it out is how the owner
# agrees its scope. Runs in dry-run, warning only, until the calling repo turns it on, as pingdotgg/t3code's
# pr-limits.yml does (MIT).

# The issue a pull request works on: the key at its title's end, "(SUS-71)".
function Get-PrIssueKey([string]$Title, [string]$IssuePrefix) {
    if ($Title -match "\(($IssuePrefix-\d+)\)\s*$") { $Matches[1] }
}

# GitHub writes "Merge pull request #n from …" when it merges; those carry the PR's own key in its title.
function Test-CommitIssue([string]$Subject, [string]$PrKey) {
    if ($Subject -match '^Merge pull request #\d+ ') { return }
    if ($Subject -notmatch "^$([regex]::Escape($PrKey)): ") {
        $named = if ($Subject -match '^([A-Z]+-\d+):') { $Matches[1] } else { 'no issue' }
        "Commit: names $named, not this pull request's $PrKey`: ""$Subject"""
    }
}

# The rows a diff (git diff --unified=0 output) adds to a changes\*.md log: dated table rows.
function Get-AddedLogRow([string[]]$Diff) {
    $inLog = $false
    foreach ($line in $Diff) {
        if ($line -match '^\+\+\+ b/(.+)$') { $inLog = $Matches[1] -match '(^|/)changes/[^/]+\.md$'; continue }
        if ($inLog -and $line -match '^\+(\| \d{4}-\d{2}-\d{2} \|.*)$') { $Matches[1] }
    }
}

# A log row's issue is its second cell. install.ps1 writes "install" there for the changes it makes.
function Test-LogRowIssue([string]$Row, [string]$PrKey) {
    $issue = ($Row -split '\|')[2].Trim()
    if ($issue -ne $PrKey -and $issue -ne 'install') { "Log row: names $issue, not this pull request's $PrKey`: ""$Row""" }
}

# Linear's workflow state types: triage, backlog, unstarted, started, completed, canceled.
function Test-IssueState([string]$StateType, [string]$PrKey) {
    switch ($StateType) {
        { $_ -in 'unstarted', 'started', 'completed' } { return }
        { $_ -in 'backlog', 'triage' } { return "Linear: $PrKey is in Backlog; agree its scope (move it out of Backlog) before work on it merges" }
        'canceled' { return "Linear: $PrKey is canceled" }
        default { return "Linear doesn't know $PrKey" }
    }
}

# Enforced, the problems fail the check; in dry-run they're warnings and it passes.
function Format-GuardrailResult([string[]]$Problems, [bool]$Enforce) {
    $Problems = @($Problems | Where-Object { $_ })
    if ($Problems.Count -eq 0) { return [pscustomobject]@{ Pass = $true; Lines = @('Guardrails: pass.') } }
    if ($Enforce) { return [pscustomobject]@{ Pass = $false; Lines = @($Problems | ForEach-Object { "Guardrails: $_" }) } }
    [pscustomobject]@{
        Pass  = $true
        Lines = @($Problems | ForEach-Object { "::warning::Guardrails (dry-run) would fail: $_" })
    }
}
