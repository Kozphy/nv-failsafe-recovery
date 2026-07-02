#Requires -Version 5.1

$script:RepoRoot = Split-Path -Parent $PSScriptRoot

. (Join-Path $script:RepoRoot 'src\Utilities.ps1')
. (Join-Path $script:RepoRoot 'src\Evidence.ps1')
. (Join-Path $script:RepoRoot 'src\Classifier.ps1')
. (Join-Path $script:RepoRoot 'src\Policy.ps1')
. (Join-Path $script:RepoRoot 'src\Audit.ps1')
. (Join-Path $script:RepoRoot 'src\Remediation.ps1')
. (Join-Path $script:RepoRoot 'src\Reporting.ps1')

function New-MockProbe {
    param([object]$Data, [string]$Status = 'ok')
    return New-EvidenceProbeResult -Status $Status -Source 'mock' -Data $Data
}

function New-MockEvidence {
    param(
        [bool]$Is640x480 = $false,
        [bool]$NvidiaPresent = $true,
        [int]$MonitorCount = 1,
        [int]$GenericCount = 0,
        [bool]$HasNvFailsafeName = $false,
        [string]$GpuStatus = 'OK',
        [string]$VideoMode = '1920 x 1080 x 32 True Color',
        [int]$PnpDisabled = 0,
        [int]$PnpUnknown = 0,
        [string]$DisplayStatus = 'ok',
        [string]$GpuProbeStatus = 'ok',
        [string]$MonitorProbeStatus = 'ok',
        [string]$PnpProbeStatus = 'ok'
    )

    $width = if ($Is640x480) { 640 } else { 1920 }
    $height = if ($Is640x480) { 480 } else { 1080 }

    return [PSCustomObject]@{
        schemaVersion    = '1.1.0'
        collectedAt      = (Get-Date).ToUniversalTime().ToString('o')
        collectionStatus = 'ok'
        system = [PSCustomObject]@{
            hostname          = 'TESTHOST'
            username          = 'testuser'
            timestamp         = (Get-Date).ToUniversalTime().ToString('o')
            powershellVersion = '5.1'
            toolkitVersion    = '1.1.0'
            operatingSystem   = New-MockProbe -Data @{
                caption        = 'Microsoft Windows 11'
                version        = '10.0.26200'
                buildNumber    = '26200'
                lastBootUpTime = (Get-Date).AddHours(-2).ToUniversalTime().ToString('o')
            }
            adminStatus = New-MockProbe -Data @{ isAdministrator = $false }
        }
        display = New-MockProbe -Status $DisplayStatus -Data @{
            activeResolution = Get-ResolutionRisk -Width $width -Height $height
            currentVideoMode = @{ name = $VideoMode; status = 'OK' }
            controllerCount  = 1
        }
        gpu = New-MockProbe -Status $GpuProbeStatus -Data @{
            nvidiaAdapterPresent = $NvidiaPresent
            nvidiaAdapterCount   = if ($NvidiaPresent) { 1 } else { 0 }
            adapters = @(
                [PSCustomObject]@{
                    name          = if ($NvidiaPresent) { 'NVIDIA GeForce RTX 4070' } else { 'Intel UHD Graphics' }
                    status        = $GpuStatus
                    pnpDeviceId   = if ($NvidiaPresent) { 'PCI\VEN_10DE&DEV_2786' } else { 'PCI\VEN_8086' }
                    driverVersion = '31.0.15.4601'
                    isNvidia      = $NvidiaPresent
                }
            )
        }
        monitor = New-MockProbe -Status $MonitorProbeStatus -Data @{
            monitorCount      = $MonitorCount
            genericCount      = $GenericCount
            hasNvFailsafeName = $HasNvFailsafeName
            monitors = @(
                [PSCustomObject]@{
                    name      = if ($HasNvFailsafeName) { 'NV-Failsafe' } elseif ($GenericCount -gt 0) { 'Generic PnP Monitor' } else { 'DELL U2723QE' }
                    status    = 'OK'
                    isGeneric = ($GenericCount -gt 0 -or $HasNvFailsafeName)
                }
            )
        }
        pnpDisplay = New-MockProbe -Status $PnpProbeStatus -Data @{
            disabledCount = $PnpDisabled
            unknownCount  = $PnpUnknown
            entityCount   = $MonitorCount
            entities      = @()
        }
    }
}
