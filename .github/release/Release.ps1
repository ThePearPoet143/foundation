# Release helpers (SUS-45): what a merge into main releases. release.yml runs Invoke-Release.ps1, which uses them.
. "$PSScriptRoot\..\actions\text-check\TextCheck.ps1"

# The version is the one pr-rules.yml calls the foundation's own parts at: every call names the release it ships in
# (README), so a merge into main releases exactly that.
function Get-ReleaseVersion([string]$WorkflowText) {
    $versions = @([regex]::Matches($WorkflowText, 'ThePearPoet143/foundation/[^@\s]+@(v\d+\.\d+\.\d+)') |
            ForEach-Object { $_.Groups[1].Value } | Sort-Object -Unique)
    if ($versions.Count -eq 0) { throw 'pr-rules.yml calls the foundation at no version' }
    if ($versions.Count -gt 1) { throw "pr-rules.yml calls the foundation at more than one version: $($versions -join ', ')" }
    $versions[0]
}

# "chore(release): v0.2.0, the review pack (SUS-33)" names the release "v0.2.0: the review pack".
function Get-ReleaseTitle([string]$PrTitle, [string]$Version) {
    if ($PrTitle -notmatch '^chore\(release\): (v\d+\.\d+\.\d+), (.+?) \([A-Z]+-\d+\)$') {
        throw "A release PR's title is 'chore(release): <version>, <what> (KEY-123)', not '$PrTitle'"
    }
    if ($Matches[1] -ne $Version) { throw "The release PR's title names $($Matches[1]), but pr-rules.yml calls $Version" }
    "${Version}: $($Matches[2])"
}

# The release notes: the release PR's "What and why". Its last line is the model line, so it's left out first, as
# Test-PrBody does; otherwise a What and why that ends the body would end with it.
function Get-ReleaseNote([string]$Body) {
    $sections = ($Body.TrimEnd() -split "`r?`n" | Select-Object -SkipLast 1) -join "`n"
    $note = Get-Section $sections 'What and why'
    if (-not $note) { throw 'The release PR has no "## What and why" section for the notes' }
    $note -replace "`r`n", "`n"
}
