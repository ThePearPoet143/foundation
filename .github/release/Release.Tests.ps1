BeforeAll {
    . "$PSScriptRoot\Release.ps1"
}

Describe 'Get-ReleaseVersion' {
    It 'returns the one version pr-rules.yml calls the foundation at' {
        $workflow = @(
            '#       uses: ThePearPoet143/foundation/.github/workflows/pr-rules.yml@v0.2.0'
            '      - uses: ThePearPoet143/foundation/.github/actions/text-check@v0.2.0'
            '      - uses: actions/checkout@v7.0.1'
            '      - uses: ThePearPoet143/foundation/.github/actions/size@v0.2.0'
        ) -join "`n"
        Get-ReleaseVersion $workflow | Should -Be 'v0.2.0'
    }
    It 'fails when the calls name more than one version' {
        $workflow = "uses: ThePearPoet143/foundation/.github/actions/size@v0.2.0`nuses: ThePearPoet143/foundation/.github/actions/branch@v0.1.1"
        { Get-ReleaseVersion $workflow } | Should -Throw '*v0.1.1, v0.2.0*'
    }
    It 'fails when nothing calls the foundation' {
        { Get-ReleaseVersion 'uses: actions/checkout@v7.0.1' } | Should -Throw '*no version*'
    }
}

Describe 'Get-ReleaseTitle' {
    It 'turns the release PR title into the release name' {
        Get-ReleaseTitle 'chore(release): v0.2.0, the review pack (SUS-33)' 'v0.2.0' | Should -Be 'v0.2.0: the review pack'
    }
    It 'fails a release PR whose title names another version' {
        { Get-ReleaseTitle 'chore(release): v0.1.9, the review pack (SUS-33)' 'v0.2.0' } | Should -Throw '*v0.1.9*v0.2.0*'
    }
    It 'fails a title that is not a release title' {
        { Get-ReleaseTitle 'feat(size): a new label (SUS-50)' 'v0.2.0' } | Should -Throw '*chore(release)*'
    }
}

Describe 'Get-ReleaseNote' {
    It 'is the release PR''s What and why, without the model line' {
        $body = "## What and why`n`nReleases v0.2.0: the review pack.`n`nIssues released: SUS-33.`n`n## Proven`n`n- foundation#9`n`nmodel line"
        Get-ReleaseNote $body | Should -Be "Releases v0.2.0: the review pack.`n`nIssues released: SUS-33."
    }
    It 'leaves out the model line when What and why is the last section' {
        $body = "## What and why`n`nReleases v0.2.0: the review pack.`n`nIssues released: SUS-33.`n`nmodel line"
        Get-ReleaseNote $body | Should -Be "Releases v0.2.0: the review pack.`n`nIssues released: SUS-33."
    }
    It 'fails a body with no What and why' {
        { Get-ReleaseNote 'nothing here' } | Should -Throw '*What and why*'
    }
}
