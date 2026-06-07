# macOS RDP Client: 60 FPS Troubleshooting

## The Problem

Users connecting from macOS (via Microsoft Remote Desktop or the newer "Windows App") may experience frame rates capped around 30-32 FPS even after applying all server-side BetterRDP optimizations.

## Root Cause

The macOS RDP client has a different rendering pipeline than the Windows client:

1. **UDP Disabled by Default**: As of Windows App v11.2.7 (2025), UDP transport (RDP Shortpath) is **disabled by default** on macOS while Microsoft works on reliability fixes. Without UDP, RDP falls back to TCP, which introduces head-of-line blocking that throttles frame delivery.

2. **Display Sync**: The macOS compositor may limit the rendering refresh to match the local display's refresh rate, which can interact poorly with RDP's frame scheduling.

3. **No RemoteFX Client-Side**: While RemoteFX/GPU acceleration is server-side and fully functional, the macOS client's software decoder may not keep up with the encoded stream at 60 FPS in all scenarios.

## Fixes & Workarounds

### Fix 1: Re-enable UDP Transport (Recommended)

On the macOS client machine, run this command in Terminal:

```bash
defaults write com.microsoft.rdc.macos ClientSettings.EnableAvdUdpSideTransport -bool true
```

Then restart the Windows App. This restores UDP transport which is essential for high frame rates.

### Fix 2: Check Client Display Settings

In Windows App → Edit PC → **Display** tab:

- Set **Resolution** to the actual resolution you need (not "Native" if on Retina — this forces unnecessary high-DPI rendering)
- Under **Optimize for**, choose:
  - **Video playback / animations** for highest frame rate
  - Avoid "Best quality" which prioritizes image fidelity over smoothness
- Uncheck "Start session in full screen" while testing — windowed mode can have fewer rendering quirks

### Fix 3: Disable Retina Rendering

Retina displays double the rendering workload. Test with lower resolution:

```
Connection settings → Display → Resolution: 1920x1080 (not "Native")
```

### Fix 4: Alternative RDP Clients

If Microsoft's client remains capped, third-party clients often have better macOS performance:

- **[FreeRDP](https://www.freerdp.com/)** (`brew install freerdp`): Open-source, supports `/gfx-h264` and `/rfx` modes, often achieves higher frame rates on macOS
- **[Royal TSX](https://www.royalapps.com/ts/mac/features)**: Commercial client with fine-grained performance controls

Example FreeRDP command with 60fps tuning:
```bash
xfreerdp /v:your-server /u:username /gfx-h264 /gfx:AVC444 /network:lan /rfx /frame-ack:0 +async-channels +async-transport +async-update +async-input +fonts +clipboard
```

### Fix 5: Verify Server-Side Settings

Confirm BetterRDP optimizations are applied on the server:

```powershell
# Run on Windows Server
Get-ItemProperty -Path "HKLM:\SYSTEM\CurrentControlSet\Control\Terminal Server\WinStations" -Name "DWMFRAMEINTERVAL"
# Should return: 15 (0x0f in hex = ~60fps)

Get-ItemProperty -Path "HKLM:\SOFTWARE\Policies\Microsoft\Windows NT\Terminal Services" -Name "VGOptimization_CaptureFrameRate"
# Should return: 60 (0x3c)
```

### Other Network Considerations

- **WiFi vs Ethernet**: WiFi jitter significantly impacts RDP frame delivery. Use Ethernet when possible.
- **Local network only**: Test with server and Mac on the same LAN first — WAN/VPN introduces latency that can mask the 60fps benefit.
- **MTU**: Ensure no MTU fragmentation between Mac and server. Run `ping -D -s 1472 your-server` from macOS to test.

## Still Capped?

If all above fail, the current macOS RDP client may genuinely have a rendering cap in certain configurations. This is a known issue tracked by Microsoft — the UDP re-enable fix (Fix 1) resolves it for most users. If it doesn't:

1. File feedback via Windows App → Help → Report an Issue
2. Monitor the [Windows App known issues page](https://learn.microsoft.com/en-us/windows-app/troubleshoot-known-issues-limitations)
3. Use FreeRDP as a stopgap for 60fps workflows

## References

- [Microsoft Q&A: RDP Frame Rate Limitation on M1 MacBook Air](https://learn.microsoft.com/en-us/answers/questions/2082846/)
- [Windows App Known Issues (UDP disabled on macOS)](https://learn.microsoft.com/en-us/windows-app/troubleshoot-known-issues-limitations)
- [Microsoft: Frame rate limited to 30 FPS in remote sessions](https://learn.microsoft.com/en-us/troubleshoot/windows-server/remote/frame-rate-limited-to-30-fps)
