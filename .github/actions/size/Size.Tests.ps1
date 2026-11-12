# Tests for the size check (Pester 5). Run: Invoke-Pester .github\actions\size
BeforeAll {
    . "$PSScriptRoot\Size.ps1"
}

Describe 'Get-EffectiveLine' {
    It 'adds the added and removed lines of each file' {
        Get-EffectiveLine @("10`t5`tsrc/app.ts", "3`t0`tREADME.md") | Should -Be 18
    }
    It 'leaves out lockfiles, generated and vendored files, and change logs' {
        $numstat = @(
            "2`t1`tsrc/app.ts",
            "900`t800`tpackage-lock.json",
            "50`t0`tpnpm-lock.yaml",
            "40`t0`tmise/mise.lock",
            "300`t0`tdist/bundle.js",
            "70`t0`tvendor/lib.js",
            "12`t0`tchanges/PC-1.md"
        )
        Get-EffectiveLine $numstat | Should -Be 3
    }
    It 'leaves out tests when other files change too' {
        Get-EffectiveLine @("4`t0`tsrc/app.ts", "200`t0`tsrc/app.test.ts", "90`t0`tdoctor/checks.Tests.ps1") | Should -Be 4
    }
    It 'counts tests when a PR changes only tests' {
        Get-EffectiveLine @("20`t5`tsrc/app.test.ts") | Should -Be 25
    }
    It 'skips binary files, which numstat shows as -' {
        Get-EffectiveLine @("-`t-`tdocs/shot.png", "1`t1`tsrc/app.ts") | Should -Be 2
    }
    It 'leaves out extra patterns a repo adds' {
        Get-EffectiveLine @("5`t0`tsrc/app.ts", "80`t0`tsnapshots/a.snap") @('snapshots/**') | Should -Be 5
    }
}

Describe 'Get-SizeLabel' {
    It 'uses Kubernetes'' thresholds' {
        Get-SizeLabel 0 | Should -Be 'size:XS'
        Get-SizeLabel 9 | Should -Be 'size:XS'
        Get-SizeLabel 10 | Should -Be 'size:S'
        Get-SizeLabel 30 | Should -Be 'size:M'
        Get-SizeLabel 100 | Should -Be 'size:L'
        Get-SizeLabel 500 | Should -Be 'size:XL'
        Get-SizeLabel 1000 | Should -Be 'size:XXL'
    }
}

Describe 'Get-SizeVerdict' {
    It 'passes up to L, asking for a review from M' {
        (Get-SizeVerdict 'size:S' $false).Pass | Should -BeTrue
        (Get-SizeVerdict 'size:S' $false).ReviewAi | Should -BeFalse
        (Get-SizeVerdict 'size:M' $false).ReviewAi | Should -BeTrue
        (Get-SizeVerdict 'size:L' $false).Pass | Should -BeTrue
    }
    It 'fails XL and XXL, saying to split or exempt' {
        $verdict = Get-SizeVerdict 'size:XL' $false
        $verdict.Pass | Should -BeFalse
        $verdict.Message | Should -Match 'size-exempt'
        (Get-SizeVerdict 'size:XXL' $false).Pass | Should -BeFalse
    }
    It 'passes XL once the PR is labelled size-exempt' {
        (Get-SizeVerdict 'size:XL' $true).Pass | Should -BeTrue
    }
}
