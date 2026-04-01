# magic-mouse-touch

A free, open-source macOS menu-bar app that brings **tap-to-click** to the Apple Magic Mouse — no paid software required.

> The Magic Mouse has a full multitouch surface but macOS never shipped tap-to-click for it (only for trackpads). This app fills that gap by reading raw touch data from the private `MultitouchSupport.framework` and injecting the corresponding click events.

---

## Features

- **Single tap** → Left click
- **Right click** — choose your mode:
  - *2-finger tap* → Right click
  - *Right-side tap* → Right click, left-side tap → Left click (like a physical mouse)
- **Double tap** → Double click (zero added latency — no wait-and-see delay)
- **Tap and hold** → Click & drag
- **Pressure threshold** — only real taps register; accidental brushes and resting fingers are ignored using capacitive contact area (`zTotal`)
- **Edge rejection** — ignore touches near the left/right edges
- **Tap duration limit** — ignore touches that are too long to be intentional taps
- Lives in the **menu bar only** — no Dock icon, no window

---

## Requirements

- macOS 13 Ventura or later
- Apple Magic Mouse (any generation with a multitouch surface)
- App Sandbox **disabled** (required to `dlopen` a private framework — see [How it works](#how-it-works))

---

## Installation

### Download (recommended)

Download the latest release from the [Releases](../../releases) page, unzip, and move `magic-mouse-touch.app` to `/Applications`.

### Build from source

1. Clone the repo:
   ```bash
   git clone https://github.com/yourusername/magic-mouse-touch.git
   cd magic-mouse-touch
   ```
2. Open `magicmousetouchcontrols/magicmousetouchcontrols.xcodeproj` in Xcode.
3. Select your team in **Signing & Capabilities** if needed.
4. Build and run (**⌘R**).

> **Note:** App Sandbox must remain **disabled** (`ENABLE_APP_SANDBOX = NO` in Build Settings). This is intentional — it is required to load `MultitouchSupport.framework` at runtime.

---

## Permissions

The app will prompt for two permissions on first launch. Both are required:

| Permission | Why |
|---|---|
| **Accessibility** | To post synthetic mouse click events via `CGEventPost` |
| **Input Monitoring** | To receive raw touch data from the Magic Mouse |

If the Accessibility prompt doesn't appear, go to **System Settings → Privacy & Security → Accessibility**, remove the app if it's already listed, and re-add it.

---

## Settings

Click the menu bar icon to open the settings panel.

### Gestures

| Setting | Description |
|---|---|
| **Right click mode** | `2-finger tap` or `Right-side tap` |
| Right-side split point | Horizontal threshold (30–70%) for side-tap mode |
| **Double tap** | Enable double-click via two quick taps |
| Double-tap window | How long the second tap can follow the first (ms) |
| **Tap and hold** | Hold after a tap to start click-and-drag |
| Hold delay | How long to hold before drag begins (ms) |

### Tap Sensitivity

| Setting | Description |
|---|---|
| **Tap pressure** | Minimum peak contact area to count as a tap. Use the live readout in the panel to calibrate — tap the mouse and see your actual values. `0` = off. |
| **Tap duration limit** | Maximum touch duration to be treated as a tap (not a rest) |
| **Edge rejection** | Dead zone on the left and right edges (mm) |

### Calibrating tap pressure

Open the settings panel and tap the mouse with different pressures while watching the **"Last tap peak"** readout:

- It shows green when the tap passes your current threshold
- It shows gray when the tap is rejected

Typical values on a Magic Mouse:
| Touch type | Approximate `zTotal` |
|---|---|
| Accidental brush / resting finger | < 1.0 |
| Light intentional tap | ~1.0–1.1 |
| Normal tap | ~1.1–1.2 |
| Firm tap | ~1.25 |

The default threshold is **1.0**, which rejects accidental contact while accepting any intentional tap.

---

## How it works

### Touch data

macOS exposes multitouch data from the Magic Mouse through the private `MultitouchSupport.framework`. The app loads it at runtime via `dlopen` (no link-time dependency) and registers a per-device callback using `MTRegisterContactFrameCallbackWithRefcon`.

Each callback frame delivers an array of `MTTouch` structs containing:
- Normalised position (`0.0–1.0`) and velocity
- Touch lifecycle stage (`4` = touching, `7` = lifted)
- `zTotal` — capacitive contact area, used as a pressure proxy

The callback fires on a high-priority framework thread at ~60 fps while fingers are present. `MultitouchBridge` throttles intermediate frames to ~20 fps and marshals everything to the main thread via `dispatch_async`.

### Tap detection (`TouchManager`)

A tap is recognised when:
1. One or more fingers touch the surface (tracking begins)
2. The fingers lift within the **tap duration limit** (default 200 ms)
3. No finger moved more than **12%** of the surface width
4. The peak `zTotal` during the touch meets the **pressure threshold**
5. Enough time has passed since the last tap (debounce, 50 ms) — unless this looks like the second tap of a double-click, in which case the debounce is bypassed

### Click injection (`ClickInjector`)

Clicks are posted as `CGEvent` pairs (mouseDown + mouseUp) via `CGEventPost(.cghidEventTap)`. The `clickCount` field is set to `2` for the second tap of a double-click, matching what macOS itself produces.


## License

MIT — see [LICENSE](LICENSE).
