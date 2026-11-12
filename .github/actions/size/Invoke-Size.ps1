# Runs the size check (SUS-28) in CI: counts the PR's effective changed lines, sets its size label (and review:ai from
# size:M), and fails size:XL and size:XXL unless the PR is labelled size-exempt. Reads the PR from environment variables.
param(
    [string]$Base = $env:BASE_SHA,
    [string]$Head = $env:HEAD_SHA,
    [string]$Pr = $env:PR_NUMBER,
    [string]$Labels = $env:PR_LABELS,
    [string[]]$ExtraIgnored = @(($env:EXTRA_IGNORED -split '[,\n]') | ForEach-Object { $_.Trim() } | Where-Object { $_ })
)
. "$PSScriptRoot\Size.ps1"

$lines = Get-EffectiveLine @(git diff --numstat "$Base...$Head") $ExtraIgnored
$label = Get-SizeLabel $lines
$current = @($Labels | ConvertFrom-Json | ForEach-Object { $_.name })
$verdict = Get-SizeVerdict $label ($current -contains 'size-exempt')

# The labels, created once per repo; --force updates a label that already exists.
$sizes = @{ 'size:XS' = '0e8a16'; 'size:S' = '5ebd3e'; 'size:M' = 'fbca04'; 'size:L' = 'fe7d37'; 'size:XL' = 'd93f0b'; 'size:XXL' = 'b60205' }
foreach ($name in $sizes.Keys) { gh label create $name --color $sizes[$name] --description 'Effective changed lines (foundation size check)' --force | Out-Null }
gh label create 'review:ai' --color '1d76db' --description 'Size M or larger: an AI review is due' --force | Out-Null
gh label create 'size-exempt' --color 'ededed' --description 'Over 500 lines on purpose; the description says why' --force | Out-Null

$remove = @($current | Where-Object { $_ -like 'size:*' -and $_ -ne $label })
if (-not $verdict.ReviewAi -and $current -contains 'review:ai') { $remove += 'review:ai' }
foreach ($name in $remove) { gh pr edit $Pr --remove-label $name | Out-Null }
$add = @($label) + @(if ($verdict.ReviewAi) { 'review:ai' })
gh pr edit $Pr --add-label ($add -join ',') | Out-Null

$summary = "Size check: $lines effective changed lines. $($verdict.Message)" + $(if ($verdict.ReviewAi) { ' An AI review is due (review:ai).' } else { '' })
Write-Output $summary
if ($env:GITHUB_STEP_SUMMARY) { Add-Content $env:GITHUB_STEP_SUMMARY $summary }
if (-not $verdict.Pass) { exit 1 }