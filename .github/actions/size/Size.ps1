# The size check (SUS-28): a PR's size by its effective changed lines, with Kubernetes' thresholds (S 10, M 30, L 100,
# XL 500, XXL 1000; kubernetes-sigs/prow, pkg/plugins/size/size.go, lines 41-45), the same T3 Code uses.

# Changes that aren't someone's work to review: lockfiles, generated and vendored files, change logs.
$IgnoredPaths = @(
    'package-lock.json', 'pnpm-lock.yaml', 'yarn.lock', '*.lock', 'Cargo.lock', 'go.sum',
    'dist/**', 'build/**', 'vendor/**', 'node_modules/**', '**/*.min.js', '**/*.generated.*',
    'changes/**'
)
# Tests count only when a PR changes nothing else (T3 Code: "test files excluded in mixed PRs").
$TestPaths = @('**/*.test.*', '**/*.spec.*', '**/*.Tests.ps1', '**/__tests__/**', '**/test/**', '**/tests/**')

# A glob as a regular expression: ** crosses folders, * and ? stay within one. A pattern without a / matches a file
# name in any folder.
function ConvertTo-PathRegex([string]$Glob) {
    $re = [regex]::Escape($Glob) -replace '\\\*\\\*/', '(.*/)?' -replace '\\\*\\\*', '.*' -replace '\\\*', '[^/]*' -replace '\\\?', '[^/]'
    if ($Glob -notmatch '/') { $re = "(.*/)?$re" }
    "^$re$"
}

function Test-PathMatch([string]$Path, [string[]]$Globs) {
    foreach ($glob in $Globs) { if ($Path -match (ConvertTo-PathRegex $glob)) { return $true } }
    $false
}

# Lines from `git diff --numstat`: added, removed, path, tab-separated; a binary file shows "-" for both.
function Get-EffectiveLine([string[]]$Numstat, [string[]]$ExtraIgnored = @()) {
    $files = foreach ($line in $Numstat) {
        $added, $removed, $path = $line -split "`t", 3
        if ($added -eq '-' -or -not $path) { continue }
        if (Test-PathMatch $path ($IgnoredPaths + $ExtraIgnored)) { continue }
        [pscustomobject]@{ Path = $path; Lines = [int]$added + [int]$removed; Test = Test-PathMatch $path $TestPaths }
    }
    $files = @($files)
    $counted = if (@($files | Where-Object { -not $_.Test }).Count -gt 0) { $files | Where-Object { -not $_.Test } } else { $files }
    [int](($counted | Measure-Object Lines -Sum).Sum)
}

function Get-SizeLabel([int]$Lines) {
    if ($Lines -ge 1000) { return 'size:XXL' }
    if ($Lines -ge 500) { return 'size:XL' }
    if ($Lines -ge 100) { return 'size:L' }
    if ($Lines -ge 30) { return 'size:M' }
    if ($Lines -ge 10) { return 'size:S' }
    'size:XS'
}

# What a size calls for: from size:M a review (review:ai); size:XL and size:XXL fail unless labelled size-exempt.
function Get-SizeVerdict([string]$Label, [bool]$Exempt) {
    $big = $Label -in 'size:XL', 'size:XXL'
    [pscustomobject]@{
        Pass     = (-not $big) -or $Exempt
        ReviewAi = $Label -notin 'size:XS', 'size:S'
        Message  = if ($big -and -not $Exempt) {
            "$Label is over 500 changed lines: split it, or label it size-exempt and say why in the description."
        } elseif ($big) { "$Label, labelled size-exempt." } else { "$Label." }
    }
}