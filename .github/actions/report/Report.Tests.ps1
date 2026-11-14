# Tests for the checks' report comment (Pester 5). Run: Invoke-Pester .github\actions\report
BeforeAll {
    . "$PSScriptRoot\Report.ps1"
    function Need([string]$Result, [string]$Summary = '') {
        [pscustomobject]@{ result = $Result; outputs = [pscustomobject]@{ summary = $Summary } }
    }
}

Describe 'Get-CheckRow' {
    It 'marks a passing check with what it said, its prefix left out' {
        $row = Get-CheckRow 'text' (Need 'success' 'Text check: passes.')
        $row.Mark | Should -Be '✓'
        $row.Found | Should -Be 'passes.'
    }
    It 'marks a failing check with each problem' {
        $row = Get-CheckRow 'text' (Need 'failure' "Text check: Title: 76 characters, over 72`nText check: no 🤖 line")
        $row.Mark | Should -Be '✗'
        $row.Found | Should -Be 'Title: 76 characters, over 72<br>no 🤖 line'
    }
    It 'marks a check that passed with warnings, such as the guardrails check in test mode' {
        $row = Get-CheckRow 'guardrails' (Need 'success' "::warning::Guardrails (dry-run) would fail: Commit: names SUS-52, not SUS-71")
        $row.Mark | Should -Be '⚠'
        $row.Found | Should -Match '^would fail: Commit: names SUS-52'
    }
    It 'marks a skipped check, saying it did not run' {
        $row = Get-CheckRow 'guardrails' (Need 'skipped')
        $row.Mark | Should -Be '–'
        $row.Found | Should -Be 'not run here'
    }
}

Describe 'Format-CheckReport' {
    It 'lists every check that ran or was skipped, in a table, under the marker' {
        $needs = [pscustomobject]@{
            text       = Need 'success' 'Text check: passes.'
            guardrails = Need 'failure' 'Guardrails: Linear: SUS-60 is in Backlog'
        }
        $report = Format-CheckReport $needs 'abc1234'
        $report | Should -Match ([regex]::Escape($ReportMarker))
        $report | Should -Match '\| ✓ \| text \| passes\. \|'
        $report | Should -Match '\| ✗ \| guardrails \| Linear: SUS-60 is in Backlog \|'
        $report | Should -Match 'abc1234'
    }
    It 'says plainly when everything passed, and when something failed' {
        Format-CheckReport ([pscustomobject]@{ text = Need 'success' 'Text check: passes.' }) 'a' | Should -Match 'All checks pass'
        Format-CheckReport ([pscustomobject]@{ text = Need 'failure' 'Text check: x' }) 'a' | Should -Match '1 check failed'
    }
    It 'keeps a pipe inside a finding from breaking the table' {
        Format-CheckReport ([pscustomobject]@{ text = Need 'failure' 'Text check: a | b' }) 'a' | Should -Match 'a \\\| b'
    }
}

Describe 'Get-ReportCommentId' {
    It "finds the comment carrying the marker, so it's edited rather than posted again" {
        $comments = @(
            [pscustomobject]@{ id = 1; body = 'a person' }
            [pscustomobject]@{ id = 2; body = "$ReportMarker`nold report" }
        )
        Get-ReportCommentId $comments | Should -Be 2
    }
    It 'is empty when there is none yet' {
        Get-ReportCommentId @([pscustomobject]@{ id = 1; body = 'a person' }) | Should -BeNullOrEmpty
    }
}
