# Deploying BetterRDP via Group Policy

You can deploy all BetterRDP registry optimizations centrally using Group Policy instead of manually editing the registry on each server. There are two approaches:

## Method 1: Group Policy Preferences (Recommended)

Group Policy Preferences (GPP) Registry Extension is the simplest way to push registry keys.

### Step-by-step

1. Open **Group Policy Management Console** (gpmc.msc)
2. Create or edit a GPO linked to the OU containing your RDP servers
3. Navigate to: **Computer Configuration → Preferences → Windows Settings → Registry**
4. Right-click → **New → Registry Wizard**
5. Select "Local Computer" and browse to each key below, or import the .reg file directly

### Keys to deploy

All values are DWORD (REG_DWORD):

| Registry Path | Value Name | Data (Decimal) |
|---|---|---|
| `HKLM\SOFTWARE\Policies\Microsoft\Windows NT\Terminal Services` | `SelectTransport` | 0 |
| | `fEnableVirtualizedGraphics` | 1 |
| | `fEnableRemoteFXAdvancedRemoteApp` | 1 |
| | `MaxCompressionLevel` | 2 |
| | `VisualExperiencePolicy` | 1 |
| | `GraphicsProfile` | 2 |
| | `bEnumerateHWBeforeSW` | 1 |
| | `AVC444ModePreferred` | 1 |
| | `AVCHardwareEncodePreferred` | 1 |
| | `VGOptimization_CaptureFrameRate` | 60 |
| | `VGOptimization_CompressionRatio` | 2 |
| | `ImageQuality` | 3 |
| `HKLM\SYSTEM\CurrentControlSet\Services\TermDD` | `FlowControlDisable` | 1 |
| | `FlowControlDisplayBandwidth` | 16 |
| | `FlowControlChannelBandwidth` | 144 |
| | `FlowControlChargePostCompression` | 0 |
| `HKLM\SOFTWARE\Microsoft\Windows NT\CurrentVersion\Multimedia\SystemProfile` | `SystemResponsiveness` | 0 |
| `HKLM\SYSTEM\CurrentControlSet\Control\Terminal Server\WinStations` | `DWMFRAMEINTERVAL` | 15 |
| `HKLM\SYSTEM\CurrentControlSet\Control\Terminal Server\WinStations\RDP-Tcp` | `InteractiveDelay` | 0 |
| `HKLM\SYSTEM\CurrentControlSet\Services\LanmanWorkstation\Parameters` | `DisableBandwidthThrottling` | 1 |
| | `DisableLargeMtu` | 0 |

### GPP Common Tab settings

For each registry item, on the **Common** tab:
- ✅ **Run in logged-on user's security context** — **UNCHECK** (must run as SYSTEM)
- ✅ **Item-level targeting** — target only Windows Server OS, or specific server groups
- ✅ **Remove this item when it is no longer applied** — optional (allows rollback by unlinking GPO)

## Method 2: Startup Script via GPO

Deploy `BetterRDP.ps1` as a computer startup script:

1. Copy `BetterRDP.ps1` to `\\domain\SYSVOL\...\scripts\`
2. In GPMC: **Computer Configuration → Policies → Windows Settings → Scripts → Startup**
3. Add PowerShell script: `powershell.exe -ExecutionPolicy Bypass -File BetterRDP.ps1`

**Note:** Ensure PowerShell execution policy allows script execution on target machines.

## Testing

Before wide deployment:
1. Link the GPO to a test OU with one or two servers
2. Run `gpupdate /force` on test machines
3. Reboot and verify with `Validate-Optimizations` (option 5 in BetterRDP.ps1)
4. Check `rsop.msc` or `gpresult /h report.html` to confirm GPO applied

## Requirements

- Windows Server 2012 R2 or later
- Domain-joined machines
- Group Policy Management Console access
- Target machines must be in an OU where the GPO is linked
