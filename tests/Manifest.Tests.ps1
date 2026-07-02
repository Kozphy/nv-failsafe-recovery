#Requires -Version 5.1

BeforeAll {
    . (Join-Path $PSScriptRoot 'TestHelpers.ps1')
}

Describe 'Module manifest PowerShell version requirement' {
    It 'documents string comparison false positive for future major versions' {
        '10.0' -lt '5.1' | Should -Be $true
    }

    It 'accepts PowerShell 10+ with numeric version comparison' {
        Test-PowerShellVersionMeetsMinimum -Version '10.0' -MinimumVersion '5.1' | Should -Be $true
        Test-PowerShellVersionMeetsMinimum -Version '7.4' -MinimumVersion '5.1' | Should -Be $true
    }

    It 'rejects versions below the minimum' {
        Test-PowerShellVersionMeetsMinimum -Version '5.0' -MinimumVersion '5.1' | Should -Be $false
        Test-PowerShellVersionMeetsMinimum -Version '4.0' -MinimumVersion '5.1' | Should -Be $false
    }

    It 'accepts the exact minimum version' {
        Test-PowerShellVersionMeetsMinimum -Version '5.1' -MinimumVersion '5.1' | Should -Be $true
    }
}
