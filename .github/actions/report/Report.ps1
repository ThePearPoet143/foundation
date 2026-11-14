# The checks' report (SUS-73): one comment on each pull request, edited in place on every push, saying in plain words
# what each of the foundation's checks found, so nobody has to open a log to learn why. As pingdotgg/t3code's review
# bots do, the result is read where people look.

# Marks the foundation's own comment, so a push edits it rather than adding another.
$ReportMarker = '<!-- foundation-checks -->'

# One check's row: its mark and what it found, from its job's result and the lines it printed (its summary output).
function Get-CheckRow([string]$Name, $Need) {
    if ($Need.result -in 'skipped', 'cancelled') { return [pscustomobject]@{ Name = $Name; Mark = '–'; Found = 'not run here' } }
    $warned = $false
    $found = foreach ($line in ([string]$Need.outputs.summary -split "`r?`n" | Where-Object { $_.Trim() })) {
        if ($line -match '^::warning::(.*)$') { $warned = $true; $line = $Matches[1] }
        $line -replace '^(Text check|Size check|Branch and commit checks|Guardrails)( \(dry-run\))?:? ', ''
    }
    $mark = if ($Need.result -eq 'failure') { '✗' } elseif ($warned) { '⚠' } else { '✓' }
    $text = if ($found) { (@($found) -join '<br>') -replace '\|', '\|' } else { 'passes' }
    [pscustomobject]@{ Name = $Name; Mark = $mark; Found = $text }
}

# $Needs: the report job's `needs` context, one property per check job. $Sha: the commit checked.
function Format-CheckReport($Needs, [string]$Sha) {
    $rows = @(foreach ($property in $Needs.PSObject.Properties) { Get-CheckRow $property.Name $property.Value })
    $failed = @($rows | Where-Object { $_.Mark -eq '✗' }).Count
    $warned = @($rows | Where-Object { $_.Mark -eq '⚠' }).Count
    $headline = if ($failed) { "**$failed check$(if ($failed -gt 1) { 's' }) failed**" } else { '**All checks pass**' }
    if ($warned) { $headline += ", $warned with warnings" }
    $lines = @($ReportMarker, '### Foundation checks', '', "$headline at ``$Sha``.", '', '| | Check | What it found |', '| --- | --- | --- |')
    $lines += $rows | ForEach-Object { "| $($_.Mark) | $($_.Name) | $($_.Found) |" }
    $lines += '', '<sub>Updated on every push by ThePearPoet143/foundation. The full logs are in the Checks tab.</sub>'
    $lines -join "`n"
}

# The id of the foundation's comment among a pull request's comments (GitHub's issue comments), if there is one.
function Get-ReportCommentId($Comments) {
    ($Comments | Where-Object { ([string]$_.body).StartsWith($ReportMarker) } | Select-Object -First 1).id
}
