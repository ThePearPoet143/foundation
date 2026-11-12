# Publishes a release when a release PR merges into main (SUS-45): the tag and the GitHub release, which Dependabot
# reads to bring it to every repo. Run by release.yml with GH_TOKEN, SHA and REPO set. A push to main that isn't a
# merged pull request, or a version already released, does nothing.
param([string]$Sha = $env:SHA, [string]$Repo = $env:REPO)
$ErrorActionPreference = 'Stop'
. "$PSScriptRoot\Release.ps1"

$version = Get-ReleaseVersion ([IO.File]::ReadAllText("$PSScriptRoot\..\workflows\pr-rules.yml"))
# Listing the releases fails outright on an auth or network error, rather than reading as "not released yet".
$released = gh release list --repo $Repo --limit 1000 --json tagName --jq '.[].tagName'
if ($LASTEXITCODE -ne 0) { throw 'gh release list failed' }
if (@($released) -contains $version) { Write-Output "$version is already released."; exit 0 }

# GitHub's "List pull requests associated with a commit": the merged PR whose merge commit this is.
$pulls = gh api "repos/$Repo/commits/$Sha/pulls"
if ($LASTEXITCODE -ne 0) { throw "gh api repos/$Repo/commits/$Sha/pulls failed" }
$pr = $pulls | ConvertFrom-Json |
    Where-Object { $_.merge_commit_sha -eq $Sha -and $_.base.ref -eq 'main' } | Select-Object -First 1
if (-not $pr) { Write-Output "No release PR merged as $Sha, so nothing to release."; exit 0 }

$title = Get-ReleaseTitle $pr.title $version
$notes = Join-Path ([IO.Path]::GetTempPath()) 'release-notes.md'
[IO.File]::WriteAllText($notes, (Get-ReleaseNote $pr.body))
# "If a matching git tag does not yet exist, one will automatically get created"; --target is the commit (gh manual).
gh release create $version --repo $Repo --target $Sha --title $title --notes-file $notes
if ($LASTEXITCODE -ne 0) { throw "gh release create $version failed" }
Write-Output "Released $title"
