# Writes the checks' report (SUS-73) as one comment on the pull request: edits the foundation's comment if it's there,
# posts it otherwise. Reads the check jobs' results (the `needs` context, as JSON) and the PR from environment variables.
param(
    [string]$NeedsJson = $env:NEEDS_JSON,
    [string]$Sha = $env:HEAD_SHA,
    [string]$Repo = $env:GITHUB_REPOSITORY,
    [string]$Number = $env:PR_NUMBER
)
. "$PSScriptRoot\Report.ps1"
[Console]::OutputEncoding = [Text.Encoding]::UTF8

$body = Format-CheckReport ($NeedsJson | ConvertFrom-Json) $Sha.Substring(0, [Math]::Min(7, $Sha.Length))
Write-Output $body
$file = Join-Path ([IO.Path]::GetTempPath()) 'foundation-report.md'
[IO.File]::WriteAllText($file, $body, (New-Object Text.UTF8Encoding $false))

# GitHub's REST API: "List issue comments", "Update an issue comment", "Create an issue comment" (a PR is an issue).
# --paginate prints each page as its own array, so take one comment per line instead.
$comments = @(gh api --paginate "repos/$Repo/issues/$Number/comments" --jq '.[] | {id, body}' | ForEach-Object { $_ | ConvertFrom-Json })
$id = Get-ReportCommentId $comments
if ($id) { gh api --method PATCH "repos/$Repo/issues/comments/$id" -F "body=@$file" | Out-Null }
else { gh api --method POST "repos/$Repo/issues/$Number/comments" -F "body=@$file" | Out-Null }
if ($LASTEXITCODE -ne 0) { throw "Couldn't write the report comment on #$Number." }
