# Runs one of the foundation's checks and keeps what it printed as the step's `summary` output, so the report job can
# show it (SUS-73). The check's own lines and exit code pass through unchanged.
param([Parameter(Mandatory)][string]$Script)
[Console]::OutputEncoding = [Text.Encoding]::UTF8

$lines = @(& $Script 2>&1 | ForEach-Object { "$_" })
$code = $LASTEXITCODE
$lines | ForEach-Object { Write-Output $_ }
# A multiline output: name<<delimiter, the lines, then the delimiter (GitHub, "Multiline strings" in workflow commands).
$delimiter = "FOUNDATION_$([guid]::NewGuid().ToString('N'))"
Add-Content -Path $env:GITHUB_OUTPUT -Encoding utf8 -Value "summary<<$delimiter", ($lines -join "`n"), $delimiter
exit $code
