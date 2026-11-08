# Verified behaviour on Windows 10/11 hosts

The values in `UpinelBetterRDP.reg` date back to the RemoteFX era of Windows 7 / Windows Server 2008 R2 SP1 and Windows 8 / Windows Server 2012. This document records what they actually do on a current Windows host, measured on a real machine, and separates the entries that are still read from the ones that have had no consumer for years.

It is meant as a companion to the README, not a replacement.

## Test setup

| | |
|---|---|
| Host | Windows 11 Pro for Workstations, build 26300 (26H2), client SKU, single-session RDP host — **no RD Session Host role** |
| GPU | NVIDIA GeForce GTX 1660 (Turing), driver 32.0.16.2101 |
| Session | 1920 × 1080, client = Windows `mstsc` over IPv6 WAN, RTT 20–35 ms, loss 0.5–3 % |
| Motion source | testufo.com full screen; the browser reports 66 Hz inside the session |
| Counters | `\RemoteFX Graphics(*)\Input Frames/Second`, `Output Frames/Second`, `Average Encoding Time`, `Frame Quality`, `Frames Skipped/Second - Insufficient {Server,Network,Client} Resources`, `\RemoteFX Network(*)\Total Sent Rate` (bit/s), `Loss Rate`, `Current UDP RTT`; encoder utilisation from `nvidia-smi` |

## Measured result of the minimal set

Only these five values were applied:

```
HKLM\SOFTWARE\Policies\Microsoft\Windows NT\Terminal Services
  AVC444ModePreferred        = 1
  AVCHardwareEncodePreferred = 1
  bEnumerateHWBeforeSW       = 1
  GraphicsProfile            = 2
HKLM\SYSTEM\CurrentControlSet\Control\Terminal Server\WinStations
  DWMFRAMEINTERVAL           = 15
```

| Metric | Before | After |
|---|---|---|
| Remote display refresh reported by the adapter | 32 Hz | **66 Hz** |
| `Output Frames/Second` (motion) | 31.6 | **41.8** (peak 59.5) |
| `Input Frames/Second` | 32.0 | 43.6 |
| `Average Encoding Time` | 1 ms | 7.8–9.8 ms (peak 25 ms) |
| `Frame Quality` | 100 % | 90 % |
| Client-side frame skips | 0.3/s | 0.3/s |
| Outgoing bandwidth | — | 12.0 Mbit/s |
| NVENC utilisation | 0 % | 20–24 % |

`DWMFRAMEINTERVAL` is the entry that lifts the 30 fps ceiling: the remote display adapter reports 66 Hz, which is exactly `1000 / 15`. Nothing else in the file can raise the ceiling; the other entries decide *how* frames are encoded once the ceiling is gone.

A static desktop reports 10–20 frames/s even with all settings applied. That is expected — RDP only produces frames when pixels change.

## `AVC444ModePreferred = 0` does not select AVC 4:2:0

Disabling it does not fall back to a cheaper H.264 profile; it disables the H.264/AVC path altogether and returns to RemoteFX (bitmap) encoding.

| Metric | `AVC444ModePreferred = 1` | `AVC444ModePreferred = 0` |
|---|---|---|
| NVENC utilisation | 20–24 % | **0 %** |
| `Frame Quality` | 90 % | **100 %** |
| `Output Frames/Second` | 41.8 | **58.3** |
| Client-side frame skips | 0.3/s | **6.4/s** |
| Outgoing bandwidth | 12.0 Mbit/s | **45.1 Mbit/s** |
| Host CPU | 5–8 % | 33 % |

Reverting to `1` reproduced the first column within measurement noise, so the comparison is repeatable.

The trade-off is therefore: 4:4:4 AVC hardware encoding at ~12 Mbit/s and ~42 fps, or RemoteFX bitmap encoding at ~45 Mbit/s and ~58 fps with the client dropping ~11 % of the frames.

## Which entries still have a consumer

Checked against the `TerminalServer.admx` shipped with the host (`C:\Windows\PolicyDefinitions`).

| Value | Policy / support in the template | Verdict on current Windows |
|---|---|---|
| `SelectTransport` | Windows 8+; enum offers `1` (TCP only) and `2` (UDP or TCP). `0` is the Windows 7 formulation | `0` is not a defined value on Windows 8+; the policy falls back to its default |
| `MaxCompressionLevel` | `TS_SERVER_COMPRESSOR`, Vista SP1+; `0` none, `1` MPPC, `2` NCRUSH, `3` XCRUSH | Valid, but selects a legacy compressor rather than "less compression" |
| `VisualExperiencePolicy` | `TS_SERVER_VISEXP`, Windows 7 / 2008 R2 only, marked deprecated from Windows 8 | Inert |
| `VGOptimization_CaptureFrameRate`, `VGOptimization_CompressionRatio` | `TS_RemoteDesktopVirtualGraphics` ("Optimize visual experience when using RemoteFX"), Windows 7 / 2008 R2 only; enums are `1`/`2`/`3`, **not** frames per second | Inert; `60` is outside the documented enum |
| `fEnableVirtualizedGraphics` | Maps to `TS_EnableVirtualGraphics` and `TS_SERVER_LEGACY_RFX`; both RemoteFX-era | Inert — RemoteFX vGPU was disabled by default in July 2020 and removed in April 2021 |
| `fEnableRemoteFXAdvancedRemoteApp` | RemoteApp Hi-Def only | No effect on full-desktop sessions |
| `bEnumerateHWBeforeSW` | `TS_DX_USE_FULL_HWGPU`, Windows 8+ | Still read by the graphics pipeline |
| `GraphicsProfile` | `TS_SERVER_PROFILE` ("Configure RemoteFX Adaptive Graphics"), Windows 8+ | Still read; `2` = let the system adapt to network conditions |
| `ImageQuality` | `TS_SERVER_IMAGE_QUALITY`, Windows 8+ | Still read |
| `AVC444ModePreferred`, `AVCHardwareEncodePreferred` | Windows 10+ | Still read; required for H.264/AVC hardware encoding |
| `FlowControl*` (4 values) | No policy; read by `TermDD` | Inert — `termdd.sys` and the `HKLM\SYSTEM\CurrentControlSet\Services\TermDD` key no longer exist on current builds |
| `InteractiveDelay` | Not documented; already present with value `50` on Windows 11 | Unverified |
| `SystemResponsiveness` | MMCSS, global | Valid, but affects the whole system rather than RDP specifically |
| `DisableBandwidthThrottling`, `DisableLargeMtu` | SMB client tunables (`LanmanWorkstation\Parameters`) | These tune SMB file transfer; `DisableLargeMtu = 0` is already the default |

## Reproduce

```powershell
# sample the counters while a full-screen animation (testufo, a game, a video) runs
Get-Counter -Counter @(
  '\RemoteFX Graphics(*)\Input Frames/Second',
  '\RemoteFX Graphics(*)\Output Frames/Second',
  '\RemoteFX Graphics(*)\Average Encoding Time',
  '\RemoteFX Graphics(*)\Frame Quality',
  '\RemoteFX Graphics(*)\Frames Skipped/Second - Insufficient Server Resources',
  '\RemoteFX Graphics(*)\Frames Skipped/Second - Insufficient Client Resources',
  '\RemoteFX Network(*)\Total Sent Rate',
  '\RemoteFX Network(*)\Loss Rate'
) -SampleInterval 1 -MaxSamples 10
```

`Total Sent Rate` is in bits per second, not bytes.

## Caveats

- These numbers come from a single machine. The AVC 4:4:4 encoder throughput depends on the GPU and on session resolution; at 1080p this host sustains ~43 fps. Lowering the session resolution is the only remaining lever for more frames, and it is a client-side setting.
- `H.264 4:4:4` encoding on consumer NVIDIA GPUs is CAVLC-only, which explains the comparatively high bitrate of the 4:4:4 stream.
- The RDSH-oriented entries were validated on a client SKU acting as an RDP host; behaviour on a real Session Host may differ.

---

Measurements collected with [DeepSeek Harness](https://github.com/deepseek-ai/deepseek-harness).

[![](https://img.shields.io/badge/powered_by-dsh-4D6BFE?style=flat-square&logo=deepseek&logoColor=white)](https://github.com/deepseek-ai/deepseek-harness)
