# Runs the Guardrails check (SUS-71) in CI on a pull request into dev. Reads the PR from environment variables, its
# commits and log rows from git, and its issue's state from Linear's API. ENFORCE "true" fails on a problem; anything
# else only warns (dry-run).
param(
    [string]$Title = $env:PR_TITLE,
    [string]$BaseSha = $env:BASE_SHA,
    [string]$HeadSha = $env:HEAD_SHA,
    [string]$IssuePrefix = $env:ISSUE_PREFIX,
    [string]$Enforce = $env:ENFORCE,
    [string]$LinearKey = $env:LINEAR_API_KEY
)
. "$PSScriptRoot\Guardrails.ps1"
[Console]::OutputEncoding = [Text.Encoding]::UTF8

$key = Get-PrIssueKey $Title $IssuePrefix
$problems = @()
if (-not $key) {
    # The text check already fails a title without its key; this check has nothing to follow.
    $problems += "Title: names no $IssuePrefix issue, so there's no issue to check"
} else {
    foreach ($subject in @(git log --format=%s "$BaseSha..$HeadSha")) { $problems += Test-CommitIssue $subject $key }
    foreach ($row in @(Get-AddedLogRow @(git diff --unified=0 "$BaseSha...$HeadSha"))) { $problems += Test-LogRowIssue $row $key }
    if (-not $LinearKey) {
        $problems += 'Linear: no LINEAR_API_KEY secret, so the issue state is unchecked'
    } else {
        # Linear's GraphQL API: "Authorization: <API_KEY>" for a personal key, and issue(id:) takes the key, "BLA-123"
        # (https://linear.app/developers/graphql).
        $body = @{ query = 'query($id: String!) { issue(id: $id) { state { type } } }'; variables = @{ id = $key } } | ConvertTo-Json -Compress
        try {
            $response = Invoke-RestMethod -Uri 'https://api.linear.app/graphql' -Method Post -ContentType 'application/json' -Headers @{ Authorization = $LinearKey } -Body $body
            $problems += Test-IssueState ([string]$response.data.issue.state.type) $key
        } catch {
            $problems += "Linear: couldn't be reached ($($_.Exception.Message))"
        }
    }
}

$result = Format-GuardrailResult $problems ($Enforce -eq 'true')
$result.Lines | ForEach-Object { Write-Output $_ }
if (-not $result.Pass) { exit 1 }
exit 0
