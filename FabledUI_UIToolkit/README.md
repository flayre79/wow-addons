# FabledUI - UIToolkit
**Shared Runtime UI Foundation (SVC-005)**

UIToolkit is the suite's dependency spine and design system. It owns the window
shell, the theme palette, frame persistence and the shared visual effects that
every other FabledUI addon builds on.

Five addons declare it as a hard `## Dependencies` (Crafty, Nemesis, Nexus,
Poseidon, Villa); the rest take it as an `## OptionalDeps`, which still
guarantees load order when both are enabled.

> **Bisect warning.** Disabling UIToolkit force-disables its five hard
> dependants, so a bisect that turns it off is really turning off six addons.
> That is what made the 2026-09-03 Housing UI hunt point at the wrong addon.

## Modules

| Module | Entry points | Notes |
| --- | --- | --- |
| `T.Themes` | `Resolve` `Apply` `ApplyPanel` `ApplyFont` `ApplyTitleText` `ApplyBodyText` `StyleFlatButton` `StyleCloseButton` `ApplyTextureColor` `GetList` `GetNextTheme` | Token palette. **The panel styler is `ApplyPanel`** — there is no `ApplyPanelChrome` or `StyleFrame`. |
| `T.Effects` | `StyleWindow` `AddNeonBorder` `AddOuterGlow` `AddSeam` `RoundedFill` `RoundedStroke` `StyleNeonButton` `StyleProgressBar` `StyleCheckbox` `Spectrum` `Luminance` `InkFor` | FableNeon chrome. |
| `T.Shell` | `CreateWindow` | Canonical framed window: title bar, accent strip, close/minimize, status bar, resize, ribbon integration. |
| `T.Ribbon` | `Attach` | Collapse-to-ribbon companion bar. Attached by `Shell`, not called directly. |
| `T.WindowState` | `Ensure` `Apply` `Capture` `ApplyRibbon` `CaptureRibbon` `GetDisplayState` `SetDisplayState` `Reset` | Frame persistence (point, size, scale, alpha, display mode). |
| `T.Components` | `CreateButton` `CreateDropdown` `CreateToggle` `CreateSegmented` `CreateSearchBox` `CreateTabStrip` `CreateProgressBar` `CreateTag` `ShowGallery` | Themed widgets. |
| `T.Preview` | `Show` `Hide` `IsShown` | Item/decor model popup. Frames models from `T.CameraPresets`. |
| `T.CameraPresets` | `Apply` `GetByItemID` `GetByFileID` `HasItemID` `HasFileID` | 726 harvested model framings. **Use `Apply`** — see below. |
| `T.RadarHUD` | `CreateRadar` `StartSession` `EndSession` `GetSessionStats` `AddGather` | Gathering radar shared by Harvest and Crafty's lumber module. |
| `T.Toast` | `Show` | Transient stacked notifications. |
| `T.FrameDistributor` | `CreateNew` / callable | Deferred iteration across frames. **Intentionally unconsumed** — see below. |
| Core / `T.ModuleRegistry` | `RegisterModule` `GetModule` `RegisterDevTool` `GetDevTool` `GetDevTools` `ForEachModule` `ForEachDevTool` `Print` `IsAvailable` | Registry used by the Asset Browser dev tools. |

## Camera presets

`Data/CameraPresetData.lua` carries 726 per-model framings harvested from
HomeBound (421, keyed by model file id) and HousingCraftTracker (305, keyed by
item id).

**Always go through `T.CameraPresets:Apply(model, itemID, fileID)`.** The two
donors share the field name `zoom` and nothing else:

* HomeBound's `zoom` is a real camera distance (`SetCameraDistance`).
* HCT's `zoom` is the **depth argument to `SetPosition`** and is frequently
  negative — meaningless as a camera distance.

`Apply` replays each donor's own call sequence and tries the item id first, so
callers never have to know which table a preset came from. The lookups return
deliberately disjoint shapes (`{zoom, modelX, modelZ, cameraY}` vs
`{depth, x, y, pitch, scale, noRotate, facing}`) so the two cannot be confused;
`tests/camera_presets.lua` enforces that.

## Intentionally unconsumed

`T.FrameDistributor` has no callers today and is kept on purpose: it is the
lifted fix for Crafty's single-frame scans stalling the UI, and that migration
is still open. Do not retire it as dead code without closing or dropping that
work.

## Recommended pattern

- `T.Shell:CreateWindow(...)` for framed tools and trackers
- `T.Ribbon` for compact always-nearby tracker mode
- `T.WindowState` for all frame persistence
- `T.Themes` for palette and widget styling

## Changelog

### v1.5.0 — 2026-09-05 (toolkit pass)
* `T.CameraPresets:Apply()` added, and `Preview.lua` now frames decor models
  from the harvested presets instead of a hardcoded camera distance. The data
  had shipped with nothing calling it.
* Corrected the preset lookup shapes. `GetByFileID` no longer reports
  HomeBound's `model_z` as a `scale`, and `GetByItemID` no longer presents HCT's
  position depth as `zoom`.
* Quarantined `Widgets.lua`, `Discovery.lua` and `ScrollBox.lua` — zero
  consumers; see `_to_delete/2026-09-05-uitoolkit-dead-surface/`.
* Documented the full module surface (this file listed 8 of 14).

### v1.4.0
* Added `WindowState.lua` for shared frame persistence.
* Added `Ribbon.lua` for collapsible tracker ribbons.
* Added `Shell.lua` for reusable framed windows.
* Expanded `Themes.lua` into a token-based visual service.
* Refit Asset Browser to consume the shared shell/ribbon runtime as the first
  proving-ground consumer.
