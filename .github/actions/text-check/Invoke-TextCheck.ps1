# Runs the text check (SUS-27). In CI the composite action passes the PR's title and description through environment
# variables, never through the command line, so their text can't run as code. By hand, check Linear text before saving:
#   powershell -File Invoke-TextCheck.ps1 -IssueTitle '...' -IssueBody '...'
# Exit 0 when the text passes, 1 with each problem otherwise.
param(
    [string]$Title = $env:PR_TITLE,
    [string]$Body = $env:PR_BODY,
    [string]$IssuePrefix = $env:ISSUE_PREFIX,
    [string]$IssueTitle,
    [string]$IssueBody
)
. "$PSScriptRoot\TextCheck.ps1"
[Console]::OutputEncoding = [Text.Encoding]::UTF8

$problems = if ($PSBoundParameters.ContainsKey('IssueTitle')) {
    @(Test-IssueText $IssueTitle $IssueBody)
} else {
    @(Test-PrTitle $Title $IssuePrefix) + @(Test-PrBody (Get-PrType $Title) $Body)
}
$problems = @($problems | Where-Object { $_ })

if ($problems.Count -eq 0) { Write-Output 'Text check: passes.'; exit 0 }
$problems | ForEach-Object { Write-Output "Text check: $_" }
exit 1