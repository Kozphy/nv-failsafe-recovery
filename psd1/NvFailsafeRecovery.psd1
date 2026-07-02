@{
    RootModule        = 'NvFailsafeRecovery.ps1'
    ModuleVersion     = '1.1.0'
    GUID              = 'a4f8c2e1-9b3d-4f6a-8c7e-1d2e3f4a5b6c'
    Author            = 'NV-Failsafe Recovery Contributors'
    CompanyName       = 'Kozphy'
    Copyright         = '(c) 2026 NV-Failsafe Recovery Contributors'
    Description       = 'Evidence-first NVIDIA NV-Failsafe / 640x480 recovery toolkit for Windows.'
    PowerShellVersion = '5.1'

    FunctionsToExport = @(
        'Get-FullEvidenceBundle'
        'Get-NvFailsafeClassification'
        'Get-RemediationPolicyDecision'
        'Test-ActionAllowed'
        'New-NvFailsafeReport'
        'Write-HumanSummary'
        'Write-JsonReport'
        'Compare-NvFailsafeReports'
        'Write-AuditEvent'
    )

    PrivateData = @{
        PSData = @{
            Tags       = @('NVIDIA', 'Display', 'NV-Failsafe', 'Windows', 'SRE', 'Diagnostics')
            LicenseUri = 'https://opensource.org/licenses/MIT'
            ProjectUri = 'https://github.com/Kozphy/nv-failsafe-recovery'
        }
    }
}
