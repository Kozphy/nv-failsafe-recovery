#Requires -Version 5.1
<#
.SYNOPSIS
    NV-Failsafe Recovery toolkit - main CLI entry point.

.DESCRIPTION
    Evidence-first detection, classification, policy-gated remediation, and audit for
    NVIDIA NV-Failsafe / 640x480 display fallback states on Windows.
#>

[CmdletBinding()]
param(
    [ValidateSet('Detect', 'Fix', 'Report', 'Verify', 'Doctor')]
    [string]$Mode = 'Detect',

    [ValidateSet('none', 'safe', 'monitor', 'adapter')]
    [string]$FixLevel = 'none',

    [switch]$Apply,
    [switch]$Force,

    [string]$OutputPath = '.\nv-failsafe-report.json',
    [string]$AuditPath = '.\nv-failsafe-audit.jsonl',
    [string]$BaselineReportPath = '',

    [switch]$Json,
    [switch]$Quiet
)

Set-StrictMode -Version Latest
$ErrorActionPreference = 'Stop'

$scriptRoot = Split-Path -Parent $MyInvocation.MyCommand.Path
$moduleRoot = Split-Path -Parent $scriptRoot

. (Join-Path $moduleRoot 'src\Utilities.ps1')
. (Join-Path $moduleRoot 'src\Evidence.ps1')
. (Join-Path $moduleRoot 'src\Classifier.ps1')
. (Join-Path $moduleRoot 'src\Policy.ps1')
. (Join-Path $moduleRoot 'src\Audit.ps1')
. (Join-Path $moduleRoot 'src\Remediation.ps1')
. (Join-Path $moduleRoot 'src\Reporting.ps1')

function Invoke-NvDetectPhase {
    param(
        [string]$RunMode
    )

    $evidence = Get-FullEvidenceBundle
    $classification = Get-NvFailsafeClassification -Evidence $evidence
  $isAdmin = Test-IsAdministrator

    $effectiveFixLevel = if ($RunMode -in @('Fix', 'Doctor') -and $FixLevel -eq 'none') { 'safe' } else { $FixLevel }
    $policyPlan = $null
    if ($RunMode -in @('Fix', 'Doctor', 'Verify')) {
        $policyPlan = Get-FixPlan -FixLevel $effectiveFixLevel -Apply:$Apply -Force:$Force -IsAdministrator $isAdmin -Classification $classification
    }

    $report = New-NvFailsafeReport -Evidence $evidence -Classification $classification -Mode $RunMode -PolicyPlan $policyPlan
    return $report
}

function Write-SessionAuditEvent {
    param(
        [string]$EventType,
        [string]$Result,
        [string]$ErrorMessage = ''
    )

    $effectiveFixLevel = if ($script:NvFixLevel) { $script:NvFixLevel } else { 'none' }
    Write-AuditEvent -AuditPath $script:NvAuditPath -EventType $EventType -Mode $script:NvMode `
        -Result $Result -Error $ErrorMessage -FixLevel $effectiveFixLevel `
        -ApplyUsed ([bool]$script:NvApply) -ForceUsed ([bool]$script:NvForce)
}

$script:NvAuditPath = $AuditPath
$script:NvMode = $Mode
$script:NvFixLevel = $FixLevel
$script:NvApply = $Apply.IsPresent
$script:NvForce = $Force.IsPresent

Write-SessionAuditEvent -EventType 'session_start' -Result 'started'

try {
    switch ($Mode) {
        'Detect' {
            $report = Invoke-NvDetectPhase -RunMode 'Detect'
            if ($Json) {
                ($report | ConvertTo-Json -Depth 20)
            }
            else {
                $null = Write-HumanSummary -Report $report -Quiet:$Quiet
            }
        }

        'Report' {
            $report = Invoke-NvDetectPhase -RunMode 'Report'
            Write-JsonReport -Report $report -OutputPath $OutputPath
            if (-not $Quiet) {
                Write-Output "Report written to $OutputPath"
                $null = Write-HumanSummary -Report $report -Quiet:$false
            }
        }

        'Doctor' {
            $report = Invoke-NvDetectPhase -RunMode 'Doctor'
            if (-not $Quiet) {
                Write-Output '=== NV-Failsafe Recovery Doctor ==='
                $null = Write-HumanSummary -Report $report -Quiet:$false
                Write-Output ''
                Write-Output 'Likely cause (evidence-based):'
                if ($report.classification.explanation) {
                    Write-Output "  $($report.classification.explanation)"
                }
                foreach ($item in $report.classification.evidence) {
                    Write-Output "  - $item"
                }
                Write-Output ''
                Write-Output 'Manual next steps:'
                foreach ($step in $report.classification.manualSteps) {
                    Write-Output "  - $step"
                }
                Write-Output ''
                Write-Output 'Automated next steps:'
                foreach ($step in $report.classification.automatedSteps) {
                    Write-Output "  - $step"
                }
            }

            if ($Apply) {
                $effectiveFixLevel = if ($FixLevel -eq 'none') { 'safe' } else { $FixLevel }
                $results = Invoke-RemediationPlan -Plan $report.policyPlan -Apply:$true -Force:$Force -AuditPath $AuditPath -Mode 'Doctor' -Classification $report.classification.classification -FixLevel $effectiveFixLevel
                $report.remediationResults = $results
            }
            elseif (-not $Quiet) {
                Write-Output ''
                Write-Output 'Doctor mode did not change system state (no -Apply).'
            }

            if ($Json) {
                ($report | ConvertTo-Json -Depth 20)
            }
        }

        'Fix' {
            $before = Invoke-NvDetectPhase -RunMode 'Fix'
            $effectiveFixLevel = if ($FixLevel -eq 'none') { 'safe' } else { $FixLevel }
            $before.policyPlan = Get-FixPlan -FixLevel $effectiveFixLevel -Apply:$Apply -Force:$Force -IsAdministrator (Test-IsAdministrator) -Classification $before.classification

            if (-not $Apply) {
                if (-not $Quiet) {
                    Write-Output '=== Fix Preview (no system changes) ==='
                    $null = Write-HumanSummary -Report $before -Quiet:$false
                }
                Write-AuditEvent -AuditPath $AuditPath -EventType 'fix_preview' -Mode 'Fix' -Classification $before.classification.classification -Result 'preview' -FixLevel $effectiveFixLevel -ApplyUsed:$false -ForceUsed:$Force.IsPresent -ExecutionMode 'preview'
            }
            else {
                $results = Invoke-RemediationPlan -Plan $before.policyPlan -Apply:$true -Force:$Force -AuditPath $AuditPath -Mode 'Fix' -Classification $before.classification.classification -FixLevel $effectiveFixLevel
                $after = Invoke-NvDetectPhase -RunMode 'Verify'
                $verification = Compare-NvFailsafeReports -BeforeReport $before -AfterReport $after
                $after.verification = $verification
                $after.remediationResults = $results
                $before = $after

                if (-not $Quiet) {
                    Write-Output '=== Fix Applied - Verification Summary ==='
                    Write-Output "Resolution changed: $($verification.resolutionChanged) ($($verification.resolutionBefore) -> $($verification.resolutionAfter))"
                    Write-Output "Classification changed: $($verification.classificationChanged) ($($verification.classificationBefore) -> $($verification.classificationAfter))"
                    Write-Output "Improved: $($verification.improved)"
                }
            }

            if ($Json) {
                ($before | ConvertTo-Json -Depth 20)
            }
            elseif (-not $Quiet -and $Apply) {
                $null = Write-HumanSummary -Report $before -Quiet:$false
            }
        }

        'Verify' {
            $current = Invoke-NvDetectPhase -RunMode 'Verify'
            if ([string]::IsNullOrWhiteSpace($BaselineReportPath)) {
                $BaselineReportPath = $OutputPath
            }

            if (-not (Test-Path -LiteralPath $BaselineReportPath)) {
                throw "Baseline report not found: $BaselineReportPath"
            }

            $baseline = Get-Content -LiteralPath $BaselineReportPath -Raw | ConvertFrom-Json
            $comparison = Compare-NvFailsafeReports -BeforeReport $baseline -AfterReport $current

            $current.verification = $comparison
            if (-not $Quiet) {
                Write-Output '=== Verify Comparison ==='
                Write-Output ($comparison | ConvertTo-Json -Depth 6)
                $null = Write-HumanSummary -Report $current -Quiet:$false
            }

            if ($Json) {
                ($current | ConvertTo-Json -Depth 20)
            }
        }

        default {
            $unhandledMode = $Mode
            throw "Unhandled mode: $unhandledMode"
        }
    }

    Write-SessionAuditEvent -EventType 'session_complete' -Result 'success'
}
catch {
    Write-SessionAuditEvent -EventType 'session_error' -Result 'error' -ErrorMessage $_.Exception.Message
    Write-Error $_.Exception.Message
    exit 1
}
