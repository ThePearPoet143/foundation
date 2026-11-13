# Tests for the Guardrails check (Pester 5). Run: Invoke-Pester .github\actions\guardrails
BeforeAll {
    . "$PSScriptRoot\Guardrails.ps1"
}

Describe 'Get-PrIssueKey' {
    It "reads the issue key from the title's end" {
        Get-PrIssueKey 'feat(install): pick your projects (SUS-50)' 'SUS' | Should -Be 'SUS-50'
    }
    It 'is empty when the title names no issue of this repo' {
        Get-PrIssueKey 'feat(install): pick your projects' 'SUS' | Should -BeNullOrEmpty
        Get-PrIssueKey 'feat(x): y (GDS-12)' 'SUS' | Should -BeNullOrEmpty
    }
}

Describe 'Test-CommitIssue' {
    It "passes a commit keyed to the pull request's issue, and GitHub's own merge commits" {
        Test-CommitIssue 'SUS-71: the check' 'SUS-71' | Should -BeNullOrEmpty
        Test-CommitIssue 'Merge pull request #12 from ThePearPoet143/dev' 'SUS-71' | Should -BeNullOrEmpty
    }
    It "fails a commit keyed to another issue, naming both" {
        Test-CommitIssue 'SUS-49: log a removal' 'SUS-71' | Should -Match 'SUS-49.*SUS-71'
    }
}

Describe 'Get-AddedLogRow' {
    It "lists the rows a diff adds to a changes\*.md log, and nothing else" {
        $diff = @(
            'diff --git a/changes/PC1.md b/changes/PC1.md'
            '+++ b/changes/PC1.md'
            '+| 2026-11-13 | SUS-71 | Did a thing | `cmd` | `undo` |'
            ' | 2026-11-12 | SUS-49 | An older row | `cmd` | `undo` |'
            'diff --git a/README.md b/README.md'
            '+++ b/README.md'
            '+| 2026-11-13 | SUS-1 | a README table row | x | y |'
        )
        @(Get-AddedLogRow $diff) | Should -Be @('| 2026-11-13 | SUS-71 | Did a thing | `cmd` | `undo` |')
    }
}

Describe 'Test-LogRowIssue' {
    It "passes a row naming the pull request's issue, or the install's own rows" {
        Test-LogRowIssue '| 2026-11-13 | SUS-71 | Did a thing | x | y |' 'SUS-71' | Should -BeNullOrEmpty
        Test-LogRowIssue '| 2026-11-13 | install | Registered the task | x | y |' 'SUS-71' | Should -BeNullOrEmpty
    }
    It 'fails a row naming another issue, quoting it' {
        Test-LogRowIssue '| 2026-11-13 | SUS-49 | Deleted the backups | x | y |' 'SUS-71' | Should -Match 'SUS-49.*Deleted the backups'
    }
}

Describe 'Test-IssueState' {
    It "passes an issue whose scope is agreed: out of Backlog and not canceled" {
        foreach ($type in 'unstarted', 'started', 'completed') { Test-IssueState $type 'SUS-71' | Should -BeNullOrEmpty }
    }
    It 'fails an issue in Backlog or Triage, saying to agree its scope' {
        Test-IssueState 'backlog' 'SUS-71' | Should -Match 'Backlog.*scope'
        Test-IssueState 'triage' 'SUS-71' | Should -Match 'scope'
    }
    It 'fails a canceled issue, and one Linear does not know' {
        Test-IssueState 'canceled' 'SUS-71' | Should -Match 'canceled'
        Test-IssueState '' 'SUS-71' | Should -Match "doesn't know"
    }
}

Describe 'Format-GuardrailResult' {
    It 'fails with the problems when enforced' {
        $result = Format-GuardrailResult @('a problem') $true
        $result.Pass | Should -BeFalse
        $result.Lines | Should -Contain 'Guardrails: a problem'
    }
    It "passes in dry-run, saying what it would have failed" {
        $result = Format-GuardrailResult @('a problem') $false
        $result.Pass | Should -BeTrue
        ($result.Lines -join ' ') | Should -Match 'dry-run.*would fail.*a problem'
    }
    It 'passes with nothing wrong' {
        (Format-GuardrailResult @() $true).Pass | Should -BeTrue
    }
}
