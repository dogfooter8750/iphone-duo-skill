---
name: iphone-duo
description: Prepare, audit, and fix an iOS app (SwiftUI or UIKit) for iPhone Duo, Apple's foldable iPhone (announced 2026-09-09, ships 2026-10-23). Use when the user mentions iPhone Duo, foldable iPhone, inner/outer display, size classes vs orientation, UIScreen.main, vertical bars, reserved regions, ArrangementView, hinge, Split View on iPhone, scene accessories, Device Hub, or asks whether an app is ready for the foldable. Also use when modernizing layout code for resizable windows in general.
---

# iPhone Duo readiness

Everything here comes from Apple's own developer material published 2026-09-09 (six Tech Talks, the HIG chapter "Designing for iPhone Duo", and WWDC26 session 278). Sources with dates are in `references/sources.md`. Where a statement summarizes Apple's wording rather than quoting it, it is marked *(paraphrase)*.

Existing apps run on iPhone Duo without changes. What changes is how much of the inner display they get and whether their bars follow the new vertical layout. That depends on the SDK they were built with and on how they lay out.

## 1. What is different on iPhone Duo

| Thing | Outer display | Inner display |
|---|---|---|
| Size | 5.4 in, wider and shorter than a standard iPhone | 7.6 in |
| Size classes | Same as other iPhones (compact width) | **Regular in both dimensions** (room for sidebars) |
| Orientation | Normal | **Does not honor `supportedInterfaceOrientations`**. Use size classes, not orientation |
| Camera | Front camera in the corner, always present; expands into the Dynamic Island for Live Activities | Under the display; a reserved region only while the camera is active |
| Bars (nav / toolbar / tab) | Vertical, on the side | Vertical on the side in landscape; standard horizontal bars in portrait |
| Fold | n/a | When partially open, a **division region** splits the display into two usable areas |

SDK behavior on the inner display (Apple, "Prepare your app for iPhone Duo"):

| Built with | Result |
|---|---|
| iOS 27 SDK | App extends to the left of the status bar |
| iOS 27.1 SDK | App reaches the screen edge; standard navigation and toolbar buttons are laid out vertically |

Poses Apple designs for: partially folded like a book (division region active), propped on a table (top half for viewing, bottom half for controls), flat (division region has zero width), standing on its edges.

Tooling: **Xcode 27.1** ships the iPhone Duo simulator with **Device Hub** (on-screen buttons to open, close, rotate, fold) and the **App Resizability** skill (the WWDC26 "app modernization" skill, renamed, now with SwiftUI and iPhone Duo support). That skill converts `UIScreen.main` calls to trait or scene-bounds checks, replaces orientation checks with size classes, and moves apps to the scene lifecycle. `xcrun agent skills export` writes Xcode's skills out as Markdown for use in other agents.

## 2. Workflow

Run these three steps in order. Do not skip the audit; the fixes are mechanical once the audit lists the sites.

### Step 1: Audit

```bash
bash scripts/audit.sh <path-to-project>
```

The script greps Swift sources and Info.plist for the anti-patterns below and prints a Markdown report grouped by category with `file:line`. It needs only `grep` and `find`. Read every hit; it is deliberately noisy on hard-coded widths.

If the script is unavailable, grep for these by hand:

| Category | Pattern | Why it breaks on Duo |
|---|---|---|
| Screen | `UIScreen.main`, `UIScreen.screens` | Two displays; "main" is ambiguous |
| Orientation | `UIDevice.current.orientation`, `interfaceOrientation`, `isLandscape`, `isPortrait`, `UIInterfaceOrientationMask` used for layout | Inner display ignores interface orientations |
| Idiom | `userInterfaceIdiom`, `.pad` / `.phone` checks that pick a layout | Inner display is regular×regular on a phone |
| Safe area | `safeAreaInsets.left * 2`, `.right * 2`, any symmetric assumption | Bars sit on one side; insets are asymmetric |
| Custom bars | `UIToolbar(`, `UINavigationBar(`, `UITabBar(` instantiated directly | Not considered for the vertical bar layout |
| Fixed widths | 320 / 375 / 390 / 393 / 402 / 414 / 428 / 430 / 440 next to `width`, `frame`, `CGSize` | Tied to a specific display |
| Windows | `UIApplication.shared.keyWindow`, `.windows.first` | Multiple scenes; pick the window from the scene |
| Info.plist | `UIRequiresFullScreen`, missing `UIApplicationSceneManifest` | Split View and multiple scenes need the scene lifecycle |

### Step 2: Fix, by category

Apply in this order. Each block gives SwiftUI and UIKit forms; use whichever the file already uses. Keep the change minimal and idiomatic to the surrounding code.

#### 2.1 Screen references

```swift
// Before
let scale = UIScreen.main.scale
let bounds = UIScreen.main.bounds

// After (UIKit)
let screen = view.window?.windowScene?.screen
let scale = traitCollection.displayScale
let bounds = view.window?.windowScene?.coordinateSpace.bounds ?? view.bounds
```

In SwiftUI use `GeometryReader` or `containerRelativeFrame`; never read `UIScreen`.

#### 2.2 Orientation → size classes

```swift
// SwiftUI
@Environment(\.horizontalSizeClass) private var horizontalSizeClass
@Environment(\.verticalSizeClass) private var verticalSizeClass
// horizontalSizeClass == .regular  → two-column layout is fine

// UIKit
traitCollection.horizontalSizeClass
traitCollection.verticalSizeClass
// re-evaluate in registerForTraitChanges / traitCollectionDidChange
```

Outer display: compact width, like every iPhone. Inner display: regular width and regular height. Design one layout per size-class combination, not per orientation or per device.

#### 2.3 Safe areas (asymmetric)

```swift
// Before: assumes equal insets on both sides
let width = view.bounds.width - view.safeAreaInsets.left * 2

// After: honor each side
let content = view.bounds.inset(by: view.safeAreaInsets)
foreground.frame = content          // interactive content stays inside
backgroundView.frame = view.bounds  // decorative content may extend under bars
```

SwiftUI: interactive content uses the default safe area; only backgrounds get `.ignoresSafeArea()`. Corner-hugging shapes: `ConcentricRectangle()` (SwiftUI, iOS 26+) or `UICornerConfiguration` (UIKit).

#### 2.4 Bars: navigation, toolbar, tab bar

Bars move to the side automatically **only** for system containers:

- SwiftUI: `NavigationStack` / `NavigationSplitView` with `.toolbar { }`, `TabView`
- UIKit: `UINavigationController`, `UITabBarController`

Custom `UIToolbar`, `UINavigationBar`, `UITabBar` instances are not considered. Replace them with the containers above.

Then tune the vertical bar:

| Goal | SwiftUI | UIKit |
|---|---|---|
| Symbol-only items go vertical; text-only stay horizontal | give items a symbol; use `.badge()` for counts | `item.badge = .count(7)` |
| Force an item horizontal (a "$99" cart button, Select/Done with text) | `.axisBehavior(.horizontalOnly)` | `item.axisBehavior = .horizontalOnly` |
| Prefer vertical for a custom view item | `.axisBehavior(.verticalPreferred)` | `item.axisBehavior = .verticalPreferred` |
| Keep an item out of overflow as long as possible | `.visibilityPriority(.high)` | `item.visibilityPriority = .high` |
| When space is short, keep toolbar items over tab bar | `.toolbarVerticalCompressionBehavior(.prefersToolbarItems)` | `navigationItem.verticalBarCompressionBehavior = .prefersBarItems` |
| Put custom overflow actions in the system menu | `ToolbarOverflowMenu { Button("Scan") {…} }` | `navigationItem.additionalOverflowItems = UIDeferredMenuElement { … }` |
| Detect which edge the vertical bar is on | `@Environment(\.toolbarVerticalEdge)` | `traitCollection.verticalBarEdge` |
| Opt out (single-page apps like Calculator, minimal sheets only) | `.toolbarVerticalBehavior(.disabled)` | `override var preferredVerticalBarBehavior: UIVerticalBarBehavior { .disabled }` |
| Sidebar tab placement on the inner display | `TabView { … }.defaultTabBarPlacement(.sidebar)` | `tabBarController.sidebar.preferredPlacement = .sidebar` |

Ordering in the vertical bar is system-defined: back/close pinned at the top, prominent actions (Done) next, remaining groups in their original order, overflow flows bottom-to-top. Do not override placement. Group with `ToolbarItemGroup` / `UIBarButtonItemGroup`, not manual spacers. Give every non-text item both a title and a symbol.

#### 2.5 The fold: reserved regions and arrangements

Reserved regions (iOS 27.1) tell you where the hinge and cameras are.

```swift
// SwiftUI
GeometryReader { proxy in
  let hinge = proxy.reservedRegions(kind: .division)                 // active only while folded
  let all   = proxy.reservedRegions(kind: .division, options: .includeInactive)
  let cams  = proxy.reservedRegions(kind: .occlusion)                // front cameras
  let frames = hinge.map(\.frame)
}

// UIKit
let regions = view.reservedRegions(kind: .division)   // [UIViewReservedRegion]
let frames = regions.map(\.frame)
```

Use them for manually laid-out, high-priority controls: keep them clear of the division region. Prefer even column counts in grids so the fold lands on a gutter. Standard containers (`NavigationSplitView`, `UISplitViewController`, `List`, `ScrollView`, `TabView`) already adapt.

For a custom primary/secondary layout use an arrangement instead of hand-rolled geometry:

```swift
// Split: main/detail (player + up-next). Splits horizontally when wider than tall.
NavigationStack {
  ArrangementView { PlayerView() } secondary: { UpNextView() }
    .arrangementViewStyle(.split)                 // or .split.axes(.horizontal)
}

// Overlay: clear foreground/background. Moves side-by-side when the device folds.
ArrangementView { UpNextView() } secondary: { PlayerView() }
  .arrangementViewStyle(.overlay)

// React to stacking order in overlay mode
@Environment(\.overlayArrangementZIndex) private var zIndex   // > 0 → collapsed
```

```swift
// UIKit
let arrangementVC = UIArrangementViewController()
arrangementVC.setViewController(PlayerViewController(), for: .primary)
arrangementVC.setViewController(UpNextViewController(), for: .secondary)
arrangementVC.updateArrangement(.split.axes(.horizontal))
let zIndex = arrangementVC.state(for: .primary)?.zIndex ?? 0
```

Rules: navigation containers go **around** an arrangement, never inside it. Never put an arrangement inside `List` or `ScrollView`. Do not displace continuously scrolling content (feeds, articles). Move only what must move; keep elements that work as a unit together.

Hinge angle is for effects, not layout:

```swift
.onHingeChange { _, context in
  if let hinge = context.hinge, hinge.status == .partiallyOpen { apply(hinge.angle) } else { reset() }
}
// UIKit: UIHingeInteraction. context.hinge == nil means no hinge on this device.
```

#### 2.6 Multitasking, scenes, outer display

- All apps take part in **Split View** on the inner display. Each app's bars go to its outer edge (left app: left edge; right app: right edge). Layout must already be driven by size classes and scene geometry, not device type.
- iPhone Duo is the first iPhone with multiple scenes of one app. Request new scenes through `UIWindowSceneActivation` (the action hides itself when new windows are unavailable) and handle failure. New windows are created on the inner display only.
- Adopt the scene lifecycle (`UIApplicationSceneManifest`, `UIWindowSceneDelegate`) if the app still uses only `UIApplicationDelegate`.
- **Scene accessories** put companion UI on the outer display while the main UI stays on the inner display. `CameraCaptureAccessory` is available only while the app is full-screen on the inner display with an active camera session:

```swift
CameraView(model: model)
  .sceneAccessory {
    CameraCaptureAccessory(isEnabled: $model.isEnabled) { TeleprompterView(model: model) }
      .onAvailabilityChange { model.isAvailable = $0 }
  }
```

#### 2.7 Games

Locking to portrait or landscape is allowed. When the pose changes, fill the screen: change the aspect ratio rather than letterboxing or pillarboxing. If padding is unavoidable, put artwork in it.

### Step 3: Verify

1. Build with the iOS 27.1 SDK in Xcode 27.1 (beta from late September 2026).
2. Run in the iPhone Duo simulator. In Device Hub, check every pose: closed, open flat, open landscape, partially folded (book), propped on a table.
3. Split View on the inner display, both left and right slots. Confirm bars sit on the outer edge and nothing is clipped under them.
4. Confirm that the same functionality is reachable in every pose. Controls may overflow; features may not disappear.
5. Re-run `scripts/audit.sh` and confirm the report is empty except for accepted hits (document each).
6. If Xcode 27.1 is available, also run the App Resizability skill and diff its proposal against yours.

## 3. Report format

When you finish an audit or a fix pass, report:

- counts per category before and after
- each remaining hit with the reason it was kept
- SDK the app is built against, and whether the 27.1 behaviors (edge-to-edge, vertical bars) are therefore active
- what could not be verified without Xcode 27.1

Do not claim "iPhone Duo ready" unless steps 2 and 3 of Verify were actually run on the simulator.

## 4. Caveats

- API names here come from Apple's Tech Talk transcripts and the HIG dated 2026-09-09. Xcode 27.1 beta had not shipped when this skill was written; confirm signatures against the SDK headers once it does, and prefer the header over this file.
- Behavior of apps built with SDKs older than iOS 27 on the inner display is not described in the primary sources used here; do not state it.
- Device measurements (5.4 in / 7.6 in) are from Apple's announcement coverage; they are context, not layout inputs. Never hard-code them.

See `references/api-cheatsheet.md` for the full API list by topic and `references/sources.md` for links.
