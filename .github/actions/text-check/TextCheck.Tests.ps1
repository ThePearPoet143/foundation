# Tests for the text check (SUS-27, Pester 5). Run: Invoke-Pester .github\actions\text-check
BeforeAll {
    . "$PSScriptRoot\TextCheck.ps1"

    function Pr([string]$WhatAndWhy = 'Adds the doctor.', [string]$Extra = '', [string]$Last = '🤖 Claude Opus 5.5') {
        "## What and why`n`n$WhatAndWhy`n`n$Extra`n`n$Last"
    }
}

Describe 'Test-PrTitle' {
    It 'passes a type, a scope, plain words and the issue key last' {
        Test-PrTitle 'feat(doctor): flag other T3 tasks (SUS-25)' 'SUS' | Should -BeNullOrEmpty
    }
    It 'passes without a scope, and with a breaking-change mark' {
        Test-PrTitle 'fix: a slow check no longer blocks (SUS-3)' 'SUS' | Should -BeNullOrEmpty
        Test-PrTitle 'feat(doctor)!: checks run under PowerShell 7 (SUS-30)' 'SUS' | Should -BeNullOrEmpty
    }
    It 'fails an unknown type' {
        Test-PrTitle 'feature(doctor): flag other T3 tasks (SUS-25)' 'SUS' | Should -Match 'type'
    }
    It 'fails a missing or wrong issue key' {
        Test-PrTitle 'feat(doctor): flag other T3 tasks' 'SUS' | Should -Match 'SUS-'
        Test-PrTitle 'feat(doctor): flag other T3 tasks (GDS-25)' 'SUS' | Should -Match 'SUS-'
    }
    It 'fails a title over 72 characters' {
        Test-PrTitle ('feat(doctor): ' + ('x' * 60) + ' (SUS-25)') 'SUS' | Should -Match '72'
    }
}

Describe 'Get-WordCount' {
    It 'counts words and numbers, not marks or symbols' {
        Get-WordCount 'The doctor shows ✓ on 2 PCs — fine.' | Should -Be 7
    }
}

Describe 'Test-PrBody' {
    It 'passes a chore with only "What and why" and the model line' {
        Test-PrBody 'chore' (Pr) | Should -BeNullOrEmpty
    }
    It 'fails without "What and why"' {
        Test-PrBody 'chore' "Did things.`n`n🤖 Claude Opus 5.5" | Should -Match 'What and why'
    }
    It 'fails when "What and why" is over 120 words' {
        Test-PrBody 'chore' (Pr (('word ' * 121).Trim())) | Should -Match '121 words'
    }
    It 'fails a fix without a Tests section that has a Red step' {
        Test-PrBody 'fix' (Pr) | Should -Match 'Tests'
        Test-PrBody 'fix' (Pr -Extra "## Tests`n`n- Green: 3 passed.") | Should -Match 'Red'
        Test-PrBody 'fix' (Pr -Extra "## Tests`n`n- Red: 1 failed first.`n- Green: 3 passed.") | Should -BeNullOrEmpty
    }
    It 'fails a feat without a Proven section' {
        Test-PrBody 'feat' (Pr) | Should -Match 'Proven'
        Test-PrBody 'feat' (Pr -Extra "## Proven so far`n`n- On PC-1: all checks pass.") | Should -BeNullOrEmpty
    }
    It 'fails when the last line isn''t 🤖 and the model with its version' {
        Test-PrBody 'chore' (Pr -Last 'Written with an agent.') | Should -Match '🤖'
        Test-PrBody 'chore' (Pr -Last '🤖 Claude') | Should -Match 'version'
    }
}

Describe 'Test-IssueText' {
    It 'passes a short title and a body with a done-when' {
        Test-IssueText 'Doctor: flag other T3 tasks' "The doctor flags them.`n`nDone when: both PCs show ✓." | Should -BeNullOrEmpty
    }
    It 'fails a title over 60 characters, a body over 80 words, and no done-when' {
        $problems = Test-IssueText ('x' * 61) (('word ' * 81).Trim())
        $problems -join ' | ' | Should -Match '60'
        $problems -join ' | ' | Should -Match '81 words'
        $problems -join ' | ' | Should -Match 'Done when'
    }
}
