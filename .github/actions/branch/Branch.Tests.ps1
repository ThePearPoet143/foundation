# Tests for the branch and commit checks (Pester 5). Run: Invoke-Pester .github\actions\branch
BeforeAll {
    . "$PSScriptRoot\Branch.ps1"
}

Describe 'Test-PrTarget' {
    It 'passes a PR into dev from any branch' {
        Test-PrTarget 'dev' 'me/sus-29-branch-checks' | Should -BeNullOrEmpty
    }
    It 'passes a release: dev into main' {
        Test-PrTarget 'main' 'dev' | Should -BeNullOrEmpty
    }
    It 'fails anything else into main, saying to target dev' {
        Test-PrTarget 'main' 'me/sus-29-branch-checks' | Should -Match 'dev'
    }
}

Describe 'Test-CommitSubject' {
    It 'passes a commit that starts with the issue key' {
        Test-CommitSubject 'SUS-29: check commit keys' 'SUS' | Should -BeNullOrEmpty
    }
    It 'passes GitHub''s own merge commits' {
        Test-CommitSubject 'Merge pull request #12 from ThePearPoet143/dev' 'SUS' | Should -BeNullOrEmpty
    }
    It 'fails a commit without the key, quoting it' {
        Test-CommitSubject 'fix the thing' 'SUS' | Should -Match 'fix the thing'
        Test-CommitSubject "Merge branch 'dev' into feature" 'SUS' | Should -Match 'SUS-'
    }
    It 'fails another repo''s key' {
        Test-CommitSubject 'GDS-12: something' 'SUS' | Should -Match 'SUS-'
    }
}

Describe 'Test-ReleaseIssueList' {
    It 'passes a release that names its issues' {
        Test-ReleaseIssueList 'Issues released: SUS-21 (mise), SUS-22.' 'SUS' | Should -BeNullOrEmpty
    }
    It 'warns when a release names no issue' {
        Test-ReleaseIssueList 'The first release.' 'SUS' | Should -Match 'Linear'
    }
}
