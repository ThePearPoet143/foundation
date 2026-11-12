# The text check (SUS-27): the rules every PR's title and description, and every Linear issue, must meet.
# Saved as UTF-8 with a BOM: Windows PowerShell 5.1 reads a file without one as ANSI, which breaks the 🤖 below.

# Conventional Commits types: feat and fix, plus those @commitlint/config-conventional recommends ("build:, chore:,
# ci:, docs:, style:, refactor:, perf:, test:"; https://www.conventionalcommits.org/en/v1.0.0/, item 4).
$PrTypes = 'feat', 'fix', 'docs', 'chore', 'refactor', 'test', 'ci', 'build', 'perf', 'style'
$Robot = [char]::ConvertFromUtf32(0x1F916)

# Words and numbers count; marks such as ✓, ✗ and — don't.
function Get-WordCount([string]$Text) {
    @([regex]::Matches($Text, '[\p{L}\p{N}][\p{L}\p{N}''\u2019.\-_/]*')).Count
}

function Get-PrType([string]$Title) {
    if ($Title -match '^([a-z]+)(\([a-z0-9.\-]+\))?!?: ') { $Matches[1] }
}

function Test-PrTitle([string]$Title, [string]$IssuePrefix) {
    $type = Get-PrType $Title
    if (-not $type -or $PrTypes -notcontains $type) {
        "Title: start with a type ($($PrTypes -join ', ')), an optional (scope), then ': ', e.g. 'feat(doctor): ...'"
    }
    if ($Title -notmatch "\($IssuePrefix-\d+\)$") { "Title: end with the issue key in brackets, e.g. ($IssuePrefix-123)" }
    if ($Title.Length -gt 72) { "Title: $($Title.Length) characters, over 72" }
}

# A section's text: from its "## Heading" (or a heading that starts with it) to the next heading.
function Get-Section([string]$Body, [string]$Heading) {
    $m = [regex]::Match($Body, "(?ms)^##\s+$([regex]::Escape($Heading))[^\n]*\n(.*?)(?=^##\s|\z)")
    if ($m.Success) { $m.Groups[1].Value.Trim() } else { $null }
}

function Test-PrBody([string]$Type, [string]$Body) {
    $lines = $Body.TrimEnd() -split "`r?`n"
    $last = $lines[-1].Trim()
    # The sections end before the model line.
    $sections = ($lines | Select-Object -SkipLast 1) -join "`n"
    $whatAndWhy = Get-Section $sections 'What and why'
    if ($null -eq $whatAndWhy) { 'Description: needs a "## What and why" section' }
    elseif (($n = Get-WordCount $whatAndWhy) -gt 120) { "What and why: $n words, over 120" }

    if ($Type -eq 'fix') {
        $tests = Get-Section $sections 'Tests'
        if ($null -eq $tests) { 'A fix needs a "## Tests" section, with the test that failed first' }
        elseif ($tests -notmatch '(?i)\bRed\b') { 'Tests: name the Red step, the test that failed before the fix' }
    }
    if ($Type -eq 'feat' -and $null -eq (Get-Section $sections 'Proven')) {
        'A feat needs a "## Proven" section: where it was shown to work'
    }

    if (-not $last.StartsWith($Robot)) { "Last line: $Robot, then the model and its version, e.g. '$Robot Claude Opus 5.5'" }
    elseif ($last -notmatch '\d') { "Last line: name the model's version, e.g. '$Robot Claude Opus 5.5'" }
}

function Test-IssueText([string]$Title, [string]$Body) {
    if ($Title.Length -gt 60) { "Issue title: $($Title.Length) characters, over 60" }
    if (($n = Get-WordCount $Body) -gt 80) { "Issue body: $n words, over 80" }
    if ($Body -notmatch '(?i)\bDone when\b') { 'Issue body: needs a "Done when"' }
}