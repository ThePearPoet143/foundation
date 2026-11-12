# Runs the branch and commit checks (SUS-29) in CI. Fails a PR into main that isn't a release from dev, and a commit
# that doesn't start with the issue key; warns on a release that names no issue. Reads the PR from environment variables.
param(
    [string]$Base = $env:BASE_REF,
    [string]$Head = $env:HEAD_REF,
    [string]$BaseSha = $env:BASE_SHA,
    [string]$HeadSha = $env:HEAD_SHA,
    [string]$Body = $env:PR_BODY,
    [string]$IssuePrefix = $env:ISSUE_PREFIX
)
. "$PSScriptRoot\Branch.ps1"
[Console]::OutputEncoding = [Text.Encoding]::UTF8

$problems = @(Test-PrTarget $Base $Head)
$release = $Base -eq 'main' -and $Head -eq 'dev'
if ($release) {
    # Its commits were checked on their way into dev.
    $warning = Test-ReleaseIssueList $Body $IssuePrefix
    if ($warning) { Write-Output "::warning::$warning" }
} else {
    foreach ($subject in @(git log --format=%s "$BaseSha..$HeadSha")) { $problems += Test-CommitSubject $subject $IssuePrefix }
}
$problems = @($problems | Where-Object { $_ })
if ($problems.Count -eq 0) { Write-Output 'Branch and commit checks: pass.'; exit 0 }
$problems | ForEach-Object { Write-Output "Branch and commit checks: $_" }
exit 1