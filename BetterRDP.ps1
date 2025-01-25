# BetterRDP PowerShell Script
# Original Author: Nova Upinel Chow <dev@upinel.com>
# License: Apache 2.0
# Source: https://github.com/Upinel/BetterRDP

# References for optimizations:
# - Flow Control & System Responsiveness settings:
#   https://www.reddit.com/r/killerinstinct/comments/4fcdhy/an_excellent_guide_to_optimizing_your_windows_10/
# - DWM Frame Interval setting:
#   https://support.microsoft.com/en-us/help/2885213/frame-rate-is-limited-to-30-fps-in-windows-8-and-windows-server-2012-r

class RegistryState {
    [string]$Path
    [string]$Name
    [object]$Value
    [string]$Type
    [bool]$Exists
    [bool]$ParentExists
}

function Get-RegistryState {
    param (
        [Parameter(Mandatory=$true)]
        [string]$Path,
        [Parameter(Mandatory=$true)]
        [string]$Name
    )
    
    $state = [RegistryState]::new()
    $state.Path = $Path
    $state.Name = $Name
    
    # Debug info
    Write-Host "Checking path: $Path" -ForegroundColor DarkGray
    $regPath = $Path -replace 'HKLM:\\', 'HKLM\'
    Write-Host "Converted path: $regPath" -ForegroundColor DarkGray
    
    # Store reg.exe output for inspection
    $regOutput = reg.exe query $regPath 2>&1
    $state.ParentExists = $LASTEXITCODE -eq 0
    
    Write-Host "reg.exe exit code: $LASTEXITCODE" -ForegroundColor DarkGray
    Write-Host "reg.exe output: $regOutput" -ForegroundColor DarkGray
    Write-Host "ParentExists: $($state.ParentExists)" -ForegroundColor DarkGray
    
    if ($state.ParentExists) {
        $property = Get-ItemProperty -Path $Path -Name $Name -ErrorAction SilentlyContinue
        $state.Exists = $null -ne $property
        if ($state.Exists) {
            $state.Value = $property.$Name
            $state.Type = (Get-ItemProperty -Path $Path -Name $Name).PSObject.Properties[$Name].TypeNameOfValue
        }
    }
    
    return $state
}

function Backup-RegistrySettings {
    $backupFile = ".\rdp_settings_backup.json"
    $backup = @{}

    $settings = @{
        "HKLM:\SOFTWARE\Policies\Microsoft\Windows NT\Terminal Services" = @(
            "SelectTransport",
            "fEnableVirtualizedGraphics",
            "fEnableRemoteFXAdvancedRemoteApp",
            "MaxCompressionLevel",
            "VisualExperiencePolicy",
            "GraphicsProfile",
            "bEnumerateHWBeforeSW",
            "AVC444ModePreferred",
            "AVCHardwareEncodePreferred",
            "VGOptimization_CaptureFrameRate",
            "VGOptimization_CompressionRatio",
            "ImageQuality"
        )
        "HKLM:\SYSTEM\CurrentControlSet\Services\TermDD" = @(
            "FlowControlDisable",
            "FlowControlDisplayBandwidth",
            "FlowControlChannelBandwidth",
            "FlowControlChargePostCompression"
        )
        "HKLM:\SOFTWARE\Microsoft\Windows NT\CurrentVersion\Multimedia\SystemProfile" = @(
            "SystemResponsiveness"
        )
        "HKLM:\SYSTEM\CurrentControlSet\Control\Terminal Server\WinStations" = @(
            "DWMFRAMEINTERVAL"
        )
        "HKLM:\SYSTEM\CurrentControlSet\Control\Terminal Server\WinStations\RDP-Tcp" = @(
            "InteractiveDelay"
        )
        "HKLM:\SYSTEM\CurrentControlSet\Services\LanmanWorkstation\Parameters" = @(
            "DisableBandwidthThrottling",
            "DisableLargeMtu"
        )
    }

    foreach ($path in $settings.Keys) {
        $backup[$path] = @{}
        foreach ($name in $settings[$path]) {
            $backup[$path][$name] = Get-RegistryState -Path $path -Name $name
        }
    }

    $backup | ConvertTo-Json -Depth 10 | Set-Content $backupFile
    return $backupFile
}

function Validate-Backup {
    param (
        [Parameter(Mandatory=$true)]
        [string]$BackupFile
    )
    
    if (-not (Test-Path $BackupFile)) {
        Write-Error "Backup file not found!"
        return $false
    }

    try {
        $null = Get-Content $BackupFile | ConvertFrom-Json
        return $true
    } catch {
        Write-Error "Invalid backup file format!"
        return $false
    }
}

function Restore-RegistrySettings {
    param (
        [Parameter(Mandatory=$true)]
        [string]$BackupFile
    )

    $backup = Get-Content $BackupFile | ConvertFrom-Json
    $typeMap = @{
        'System.Int32' = 'DWord'
        'System.Int64' = 'QWord'
        'System.String' = 'String'
        'System.String[]' = 'MultiString'
        'System.Byte[]' = 'Binary'
    }

    foreach ($pathObj in $backup.PSObject.Properties) {
        $path = $pathObj.Name
        $settings = $pathObj.Value
        
        foreach ($nameObj in $settings.PSObject.Properties) {
            $state = $nameObj.Value
            
			if (-not $state.ParentExists) {
				# Instead of skipping, check if value exists now and delete it
				if (Test-Path $state.Path) {
					$existing = Get-ItemProperty -Path $state.Path -Name $state.Name -ErrorAction SilentlyContinue
					if ($null -ne $existing) {
						Remove-ItemProperty -Path $state.Path -Name $state.Name -Force
						Write-Host "Removed $($state.Path)\$($state.Name) as it did not exist in backup" -ForegroundColor Yellow
					}
				}
				continue
			}

            if ($state.Exists -and $null -ne $state.Value) {
                if (-not (Test-Path $state.Path)) {
                    New-Item -Path $state.Path -Force | Out-Null
                }
                
                $regType = if ($state.Type -and $typeMap.ContainsKey($state.Type)) {
                    $typeMap[$state.Type]
                } else {
                    Write-Warning "Unknown type $($state.Type) for $($state.Path)\$($state.Name), defaulting to DWord"
                    'DWord'
                }
                
                Set-ItemProperty -Path $state.Path -Name $state.Name -Value $state.Value -Type $regType
                Write-Host "Restored $($state.Path)\$($state.Name) to $($state.Value)" -ForegroundColor Green
            }
            else {
                if ((Test-Path $state.Path)) {
                    $existing = Get-ItemProperty -Path $state.Path -Name $state.Name -ErrorAction SilentlyContinue
                    if ($null -ne $existing) {
                        Remove-ItemProperty -Path $state.Path -Name $state.Name -Force
                        Write-Host "Removed $($state.Path)\$($state.Name) as it did not exist in backup" -ForegroundColor Yellow
                    }
                }
            }
        }
    }
}

function Get-OptimizationSettings {
    return @{
        "HKLM:\SOFTWARE\Policies\Microsoft\Windows NT\Terminal Services" = @{
            "SelectTransport" = @{ Value = 0; Type = "DWord" }
            "fEnableVirtualizedGraphics" = @{ Value = 1; Type = "DWord" }
            "fEnableRemoteFXAdvancedRemoteApp" = @{ Value = 1; Type = "DWord" }
            "MaxCompressionLevel" = @{ Value = 2; Type = "DWord" }
            "VisualExperiencePolicy" = @{ Value = 1; Type = "DWord" }
            "GraphicsProfile" = @{ Value = 2; Type = "DWord" }
            "bEnumerateHWBeforeSW" = @{ Value = 1; Type = "DWord" }
            "AVC444ModePreferred" = @{ Value = 1; Type = "DWord" }
            "AVCHardwareEncodePreferred" = @{ Value = 1; Type = "DWord" }
            "VGOptimization_CaptureFrameRate" = @{ Value = 0x3c; Type = "DWord" }
            "VGOptimization_CompressionRatio" = @{ Value = 2; Type = "DWord" }
            "ImageQuality" = @{ Value = 3; Type = "DWord" }
        }
        "HKLM:\SYSTEM\CurrentControlSet\Services\TermDD" = @{
            "FlowControlDisable" = @{ Value = 1; Type = "DWord" }
            "FlowControlDisplayBandwidth" = @{ Value = 0x10; Type = "DWord" }
            "FlowControlChannelBandwidth" = @{ Value = 0x90; Type = "DWord" }
            "FlowControlChargePostCompression" = @{ Value = 0; Type = "DWord" }
        }
        "HKLM:\SOFTWARE\Microsoft\Windows NT\CurrentVersion\Multimedia\SystemProfile" = @{
            "SystemResponsiveness" = @{ Value = 0; Type = "DWord" }
        }
        "HKLM:\SYSTEM\CurrentControlSet\Control\Terminal Server\WinStations" = @{
            "DWMFRAMEINTERVAL" = @{ Value = 0x0f; Type = "DWord" }
        }
        "HKLM:\SYSTEM\CurrentControlSet\Control\Terminal Server\WinStations\RDP-Tcp" = @{
            "InteractiveDelay" = @{ Value = 0; Type = "DWord" }
        }
        "HKLM:\SYSTEM\CurrentControlSet\Services\LanmanWorkstation\Parameters" = @{
            "DisableBandwidthThrottling" = @{ Value = 1; Type = "DWord" }
            "DisableLargeMtu" = @{ Value = 0; Type = "DWord" }
        }
    }
}

function Validate-Optimizations {
    $settings = Get-OptimizationSettings
    $mismatches = @()
    $notFound = @()
    $totalSettings = 0
    $correctSettings = 0

    foreach ($path in $settings.Keys) {
        foreach ($name in $settings[$path].Keys) {
            $totalSettings++
            $expected = $settings[$path][$name]
            
            if (Test-Path $path) {
                $property = Get-ItemProperty -Path $path -Name $name -ErrorAction SilentlyContinue
                if ($null -ne $property) {
                    $currentValue = $property.$name
                    if ($currentValue -eq $expected.Value) {
                        $correctSettings++
                    } else {
                        $mismatches += @{
                            Path = $path
                            Name = $name
                            CurrentValue = $currentValue
                            ExpectedValue = $expected.Value
                            Type = $expected.Type
                        }
                    }
                } else {
                    $notFound += @{
                        Path = $path
                        Name = $name
                        ExpectedValue = $expected.Value
                        Type = $expected.Type
                    }
                }
            } else {
                $notFound += @{
                    Path = $path
                    Name = $name
                    ExpectedValue = $expected.Value
                    Type = $expected.Type
                }
            }
        }
    }

    if ($mismatches.Count -eq 0 -and $notFound.Count -eq 0) {
        Write-Host "All optimizations are correctly applied!" -ForegroundColor Green
        return
    }

    if ($mismatches.Count -gt 0) {
        Write-Host "`nMismatched Values:" -ForegroundColor Yellow
        foreach ($mismatch in $mismatches) {
            Write-Host "`nRegistry Key: $($mismatch.Path)" -ForegroundColor Cyan
            Write-Host "Value Name: $($mismatch.Name)"
            Write-Host "Current Value: $($mismatch.CurrentValue)"
            Write-Host "Expected Value: $($mismatch.ExpectedValue)"
            Write-Host "Type: $($mismatch.Type)"
        }
    }

    if ($notFound.Count -gt 0) {
        Write-Host "`nMissing Values:" -ForegroundColor Yellow
        foreach ($missing in $notFound) {
            Write-Host "`nRegistry Key: $($missing.Path)" -ForegroundColor Cyan
            Write-Host "Value Name: $($missing.Name)"
            Write-Host "Expected Value: $($missing.ExpectedValue)"
            Write-Host "Type: $($missing.Type)"
        }
    }

    $percentOptimized = [math]::Round(($correctSettings / $totalSettings) * 100, 1)
    Write-Host "`nOptimization Status: $percentOptimized% optimized" -ForegroundColor Cyan
}

function Apply-RDPOptimizations {
    $tsPath = "HKLM:\SOFTWARE\Policies\Microsoft\Windows NT\Terminal Services"
    New-Item -Path $tsPath -Force | Out-Null
    
    $tsSettings = @{
        "SelectTransport" = 0
        "fEnableVirtualizedGraphics" = 1
        "fEnableRemoteFXAdvancedRemoteApp" = 1
        "MaxCompressionLevel" = 2
        "VisualExperiencePolicy" = 1
        "GraphicsProfile" = 2
        "bEnumerateHWBeforeSW" = 1
        "AVC444ModePreferred" = 1
        "AVCHardwareEncodePreferred" = 1
        "VGOptimization_CaptureFrameRate" = 0x3c
        "VGOptimization_CompressionRatio" = 2
        "ImageQuality" = 3
    }
    
    foreach ($setting in $tsSettings.GetEnumerator()) {
        Set-ItemProperty -Path $tsPath -Name $setting.Key -Value $setting.Value -Type DWord
    }

    $termDDPath = "HKLM:\SYSTEM\CurrentControlSet\Services\TermDD"
    New-Item -Path $termDDPath -Force | Out-Null
    
    $termDDSettings = @{
        "FlowControlDisable" = 1
        "FlowControlDisplayBandwidth" = 0x10
        "FlowControlChannelBandwidth" = 0x90
        "FlowControlChargePostCompression" = 0
    }
    
    foreach ($setting in $termDDSettings.GetEnumerator()) {
        Set-ItemProperty -Path $termDDPath -Name $setting.Key -Value $setting.Value -Type DWord
    }

    Set-ItemProperty -Path "HKLM:\SOFTWARE\Microsoft\Windows NT\CurrentVersion\Multimedia\SystemProfile" `
        -Name "SystemResponsiveness" -Value 0 -Type DWord

    Set-ItemProperty -Path "HKLM:\SYSTEM\CurrentControlSet\Control\Terminal Server\WinStations" `
        -Name "DWMFRAMEINTERVAL" -Value 0x0f -Type DWord

    Set-ItemProperty -Path "HKLM:\SYSTEM\CurrentControlSet\Control\Terminal Server\WinStations\RDP-Tcp" `
        -Name "InteractiveDelay" -Value 0 -Type DWord

    $lanmanPath = "HKLM:\SYSTEM\CurrentControlSet\Services\LanmanWorkstation\Parameters"
    New-Item -Path $lanmanPath -Force | Out-Null
    Set-ItemProperty -Path $lanmanPath -Name "DisableBandwidthThrottling" -Value 1 -Type DWord
    Set-ItemProperty -Path $lanmanPath -Name "DisableLargeMtu" -Value 0 -Type DWord
}

# Main script execution
$ErrorActionPreference = "Stop"

Write-Host "BetterRDP Optimization Script" -ForegroundColor Green
Write-Host "1. Create backup only"
Write-Host "2. Apply RDP optimizations"
Write-Host "3. Restore from backup"
Write-Host "4. Validate optimization status"
Write-Host "5. Exit"

$choice = Read-Host "Please enter your choice (1-5)"

switch ($choice) {
    "1" {
        Write-Host "Creating backup..." -ForegroundColor Yellow
        $backupPath = Backup-RegistrySettings
        
        if (Validate-Backup -BackupFile $backupPath) {
            Write-Host "Backup created successfully at: $backupPath" -ForegroundColor Green
        }
    }
    "2" {
        Write-Host "Applying RDP optimizations..." -ForegroundColor Yellow
        Apply-RDPOptimizations
        Write-Host "Optimizations applied successfully!" -ForegroundColor Green
    }
    "3" {
        $backupPath = ".\rdp_settings_backup.json"
        if (Test-Path $backupPath) {
            Write-Host "Restoring from backup..." -ForegroundColor Yellow
            Restore-RegistrySettings -BackupFile $backupPath
            Write-Host "Restore completed successfully!" -ForegroundColor Green
        } else {
            Write-Host "Backup file not found!" -ForegroundColor Red
        }
    }
    "4" {
        Write-Host "Validating optimization status..." -ForegroundColor Yellow
        Validate-Optimizations
    }
    "5" {
        Write-Host "Exiting script..." -ForegroundColor Yellow
        exit
    }
    default {
        Write-Host "Invalid choice. Exiting script..." -ForegroundColor Red
        exit
    }
}
