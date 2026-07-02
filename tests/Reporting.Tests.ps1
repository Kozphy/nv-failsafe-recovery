#Requires -Version 5.1

$repoRoot = Split-Path -Parent $PSScriptRoot
. (Join-Path $repoRoot 'src\Utilities.ps1')
. (Join-Path $repoRoot 'src\Evidence.ps1')
. (Join-Path $repoRoot 'src\Classifier.ps1')
. (Join-Path $repoRoot 'src\Reporting.ps1')

Describe 'JSON report shape' {
    It 'includes structured report fields required by schema 1.1.0' {
        $evidence = Get-FullEvidenceBundle
        $classification = Get-NvFailsafeClassification -Evidence $evidence
        $report = New-NvFailsafeReport -Evidence $evidence -Classification $classification -Mode 'Report'

        Test-NvFailsafeReportShape -Report $report | Should Be $true
        $report.report.gpu_adapters | Should Not Be $null
        $report.report.suspected_tags | Should Not Be $null
        $report.report.explanation | Should Not BeNullOrEmpty
    }
}

Describe 'Verification comparison' {
    It 'treats NO_ISSUE_DETECTED as improved from NV_FAILSAFE_SUSPECTED' {
        $before = [PSCustomObject]@{
            summary = [PSCustomObject]@{
                activeDisplayResolution = '640x480'
                is640x480 = $true
                classification = 'NV_FAILSAFE_SUSPECTED'
                monitorCount = 1
                gpuStatus = 'OK'
                confidence = 0.82
            }
        }
        $after = [PSCustomObject]@{
            summary = [PSCustomObject]@{
                activeDisplayResolution = '1920x1080'
                is640x480 = $false
                classification = 'NO_ISSUE_DETECTED'
                monitorCount = 1
                gpuStatus = 'OK'
                confidence = 0.8
            }
        }

        $comparison = Compare-NvFailsafeReports -BeforeReport $before -AfterReport $after
        $comparison.improved | Should Be $true
    }
}
