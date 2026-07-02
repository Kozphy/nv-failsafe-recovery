#Requires -Version 5.1
<#
.SYNOPSIS
    Evidence collection for NV-Failsafe Recovery toolkit.
#>

Set-StrictMode -Version Latest

. "$PSScriptRoot\Utilities.ps1"

function Test-IsAdministrator {
    [CmdletBinding()]
    param()

    $identity = [Security.Principal.WindowsIdentity]::GetCurrent()
    $principal = New-Object Security.Principal.WindowsPrincipal($identity)
    return $principal.IsInRole([Security.Principal.WindowsBuiltInRole]::Administrator)
}

function Get-ResolutionRisk {
    [CmdletBinding()]
    param(
        [int]$Width,
        [int]$Height
    )

    $is640x480 = ($Width -eq 640 -and $Height -eq 480)
    $isSuspiciouslyLow = ($Width -le 800 -and $Height -le 600)

    $riskLevel = 'normal'
    if ($is640x480) {
        $riskLevel = 'critical'
    }
    elseif ($isSuspiciouslyLow) {
        $riskLevel = 'elevated'
    }

    return [PSCustomObject]@{
        width               = $Width
        height              = $Height
        is640x480           = $is640x480
        isSuspiciouslyLow   = $isSuspiciouslyLow
        riskLevel           = $riskLevel
        resolutionString    = "${Width}x${Height}"
    }
}

function Get-SystemEvidence {
    [CmdletBinding()]
    param()

    $osProbe = Invoke-SafeCommand -Source 'Win32_OperatingSystem' -ScriptBlock {
        $os = Get-CimInstance -ClassName Win32_OperatingSystem -ErrorAction Stop | Select-Object -First 1
        [PSCustomObject]@{
            caption        = $os.Caption
            version        = $os.Version
            buildNumber    = $os.BuildNumber
            osArchitecture = $os.OSArchitecture
            lastBootUpTime = if ($os.LastBootUpTime) { $os.LastBootUpTime.ToUniversalTime().ToString('o') } else { $null }
        }
    }

    $adminProbe = New-EvidenceProbeResult -Status 'ok' -Source 'SecurityPrincipal' -Data @{
        isAdministrator = Test-IsAdministrator
    }

    return [PSCustomObject]@{
        hostname          = $env:COMPUTERNAME
        username          = $env:USERNAME
        timestamp         = (Get-Date).ToUniversalTime().ToString('o')
        powershellVersion = $PSVersionTable.PSVersion.ToString()
        toolkitVersion    = Get-ToolkitVersion
        operatingSystem   = $osProbe
        adminStatus       = $adminProbe
    }
}

function Get-DisplayEvidence {
    [CmdletBinding()]
    param()

    $displayProbe = Invoke-SafeCommand -Source 'Win32_VideoController.Display' -ScriptBlock {
        $controllers = Get-CimInstance -ClassName Win32_VideoController -ErrorAction Stop
        $active = $controllers | Where-Object { $_.CurrentHorizontalResolution -and $_.CurrentVerticalResolution } | Select-Object -First 1
        if (-not $active) {
            $active = $controllers | Select-Object -First 1
        }

        $width = [int]($active.CurrentHorizontalResolution)
        $height = [int]($active.CurrentVerticalResolution)

        [PSCustomObject]@{
            activeResolution = Get-ResolutionRisk -Width $width -Height $height
            currentVideoMode = [PSCustomObject]@{
                name           = $active.VideoModeDescription
                adapterRamMB   = if ($active.AdapterRAM) { [math]::Round($active.AdapterRAM / 1MB, 2) } else { $null }
                driverDate     = if ($active.DriverDate) { $active.DriverDate.ToUniversalTime().ToString('o') } else { $null }
                driverVersion  = $active.DriverVersion
                videoProcessor = $active.VideoProcessor
                status         = $active.Status
            }
            controllerCount = @($controllers).Count
        }
    }

    return $displayProbe
}

function Get-GpuEvidence {
    [CmdletBinding()]
    param()

    $gpuProbe = Invoke-SafeCommand -Source 'Win32_VideoController.GPU' -ScriptBlock {
        $controllers = Get-CimInstance -ClassName Win32_VideoController -ErrorAction Stop
        $nvidia = $controllers | Where-Object {
            $_.Name -match 'NVIDIA' -or $_.PNPDeviceID -match 'VEN_10DE'
        }

        $adapters = foreach ($gpu in $controllers) {
            [PSCustomObject]@{
                name          = $gpu.Name
                status        = $gpu.Status
                pnpDeviceId   = $gpu.PNPDeviceID
                driverVersion = $gpu.DriverVersion
                isNvidia      = ($gpu.Name -match 'NVIDIA' -or $gpu.PNPDeviceID -match 'VEN_10DE')
                availability  = $gpu.Availability
                adapterRamMB  = if ($gpu.AdapterRAM) { [math]::Round($gpu.AdapterRAM / 1MB, 2) } else { $null }
            }
        }

        [PSCustomObject]@{
            adapters            = $adapters
            nvidiaAdapterCount  = @($nvidia).Count
            nvidiaAdapterPresent = (@($nvidia).Count -gt 0)
            primaryGpuName      = ($adapters | Select-Object -First 1).name
        }
    }

    return $gpuProbe
}

function Get-MonitorEvidence {
    [CmdletBinding()]
    param()

    $monitorProbe = Invoke-SafeCommand -Source 'Win32_DesktopMonitor' -ScriptBlock {
        $monitors = Get-CimInstance -ClassName Win32_DesktopMonitor -ErrorAction SilentlyContinue
        $monitorList = foreach ($monitor in $monitors) {
            [PSCustomObject]@{
                name         = $monitor.Name
                description  = $monitor.Description
                status       = $monitor.Status
                pnpDeviceId  = $monitor.PNPDeviceID
                screenWidth  = $monitor.ScreenWidth
                screenHeight = $monitor.ScreenHeight
                isGeneric    = Test-StringContainsAny -Value $monitor.Name -Patterns @(
                    'Generic',
                    'Non-PnP',
                    'Default Monitor',
                    'NV-Failsafe',
                    '640\s*x\s*480'
                )
            }
        }

        [PSCustomObject]@{
            monitors     = $monitorList
            monitorCount = @($monitorList).Count
            genericCount = @($monitorList | Where-Object { $_.isGeneric }).Count
            hasNvFailsafeName = @($monitorList | Where-Object { $_.name -match 'NV-Failsafe' }).Count -gt 0
        }
    }

    return $monitorProbe
}

function Get-PnpDisplayEvidence {
    [CmdletBinding()]
    param()

    $pnpProbe = Invoke-SafeCommand -Source 'Get-PnpDevice.Display' -UnavailableMessage 'Get-PnpDevice unavailable; using Win32_PnPEntity fallback.' -ScriptBlock {
        $entities = @()
        if (Get-Command -Name Get-PnpDevice -ErrorAction SilentlyContinue) {
            $devices = Get-PnpDevice -Class 'Monitor', 'Display' -ErrorAction SilentlyContinue
            foreach ($device in $devices) {
                $entities += [PSCustomObject]@{
                    friendlyName = $device.FriendlyName
                    status       = $device.Status
                    class        = $device.Class
                    instanceId   = $device.InstanceId
                    problem      = $device.Problem
                    isDisabled   = ($device.Status -eq 'Error' -or $device.Problem -ne 0)
                    isUnknown    = ($device.Status -eq 'Unknown')
                }
            }
        }
        else {
            $cim = Get-CimInstance -ClassName Win32_PnPEntity -ErrorAction Stop |
                Where-Object { $_.PNPClass -in @('Monitor', 'Display') }
            foreach ($device in $cim) {
                $entities += [PSCustomObject]@{
                    friendlyName = $device.Name
                    status       = $device.Status
                    class        = $device.PNPClass
                    instanceId   = $device.PNPDeviceID
                    problem      = $null
                    isDisabled   = ($device.Status -ne 'OK')
                    isUnknown    = ($device.Status -eq 'Unknown')
                }
            }
        }

        [PSCustomObject]@{
            entities          = $entities
            entityCount       = @($entities).Count
            disabledCount     = @($entities | Where-Object { $_.isDisabled }).Count
            unknownCount      = @($entities | Where-Object { $_.isUnknown }).Count
            unstableCount     = @($entities | Where-Object { $_.status -notin @('OK', 'Unknown') }).Count
        }
    }

    return $pnpProbe
}

function Get-FullEvidenceBundle {
    [CmdletBinding()]
    param()

    $system = Get-SystemEvidence
    $display = Get-DisplayEvidence
    $gpu = Get-GpuEvidence
    $monitor = Get-MonitorEvidence
    $pnp = Get-PnpDisplayEvidence

    $probeStatuses = @(
        $display.status
        $gpu.status
        $monitor.status
        $pnp.status
        $system.operatingSystem.status
    ) | Where-Object { $_ }

    $hasErrors = @($probeStatuses | Where-Object { $_ -eq 'error' }).Count -gt 0
    $hasUnavailable = @($probeStatuses | Where-Object { $_ -eq 'unavailable' }).Count -gt 0

  $collectionStatus = 'ok'
    if ($hasErrors) { $collectionStatus = 'error' }
    elseif ($hasUnavailable) { $collectionStatus = 'warning' }

    return [PSCustomObject]@{
        schemaVersion = '1.0.0'
        collectedAt   = (Get-Date).ToUniversalTime().ToString('o')
        collectionStatus = $collectionStatus
        system        = $system
        display       = $display
        gpu           = $gpu
        monitor       = $monitor
        pnpDisplay    = $pnp
    }
}
