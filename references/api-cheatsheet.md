# iPhone Duo API cheatsheet

Grouped by topic. SwiftUI on the left, UIKit on the right. Minimum OS in the last column when Apple stated one. All names are as spoken or shown in Apple's Tech Talks of 2026-09-09; verify against the iOS 27.1 SDK headers when available.

## Size classes and screen

| Purpose | SwiftUI | UIKit | Min |
|---|---|---|---|
| Horizontal size class | `@Environment(\.horizontalSizeClass)` | `traitCollection.horizontalSizeClass` | existing |
| Vertical size class | `@Environment(\.verticalSizeClass)` | `traitCollection.verticalSizeClass` | existing |
| Display scale | (not needed) | `traitCollection.displayScale` | existing |
| Screen for a window | (not needed) | `window?.windowScene?.screen` | existing |
| Do not use | `UIScreen.main` | `UIScreen.main`, `UIScreen.screens` | |

Facts: outer display = compact width like other iPhones. Inner display = regular width **and** regular height. Inner display does not honor `supportedInterfaceOrientations`.

## Safe areas and corners

| Purpose | SwiftUI | UIKit | Min |
|---|---|---|---|
| Interactive content inside safe area | default | `view.bounds.inset(by: view.safeAreaInsets)` | existing |
| Background under bars | `.ignoresSafeArea()` | `backgroundView.frame = view.bounds` | existing |
| Concentric corners | `ConcentricRectangle()` | `UICornerConfiguration` | iOS 26 |
| Safe area insets in SwiftUI | `GeometryProxy.safeAreaInsets` | `UIView.safeAreaInsets` | existing |

Insets are asymmetric on iPhone Duo. Never multiply one side by two.

## Bars (navigation bar, toolbar, tab bar)

Vertical bar layout applies only to system containers: `NavigationStack`, `NavigationSplitView`, `TabView` (SwiftUI); `UINavigationController`, `UITabBarController` (UIKit). Requires building with iOS 27.1 SDK.

| Purpose | SwiftUI | UIKit |
|---|---|---|
| Sidebar placement for tabs | `.defaultTabBarPlacement(.sidebar)` | `tabBarController.sidebar.preferredPlacement = .sidebar` |
| Badge (makes a text+symbol item symbol-only) | `.badge()` | `item.badge = .count(7)` |
| Axis behavior | `.axisBehavior(.verticalPreferred)` / `.axisBehavior(.horizontalOnly)` | `item.axisBehavior = .verticalPreferred` / `.horizontalOnly` |
| Overflow priority | `.visibilityPriority(.high)` | `item.visibilityPriority = .high` |
| Compression preference | `.toolbarVerticalCompressionBehavior(.prefersToolbarItems)` | `navigationItem.verticalBarCompressionBehavior = .prefersBarItems` |
| Custom overflow into system menu | `ToolbarOverflowMenu { … }` | `navigationItem.additionalOverflowItems = UIDeferredMenuElement({ provider in provider(items) })` |
| Which edge the bar is on | `@Environment(\.toolbarVerticalEdge)` | `traitCollection.verticalBarEdge` |
| Opt out of vertical bars | `.toolbarVerticalBehavior(.disabled)` | `override var preferredVerticalBarBehavior: UIVerticalBarBehavior { .disabled }` |
| Grouping | `ToolbarItemGroup` | `UIBarButtonItemGroup` |
| Pinned placements | `cancellationAction`, `topBarPinnedTrailing` | `leftItemsSupplementBackButton = false`, `pinnedTrailingGroup` |
| Visibility priority type | `ToolbarItemVisibilityPriority` | `UIBarButtonItemVisibilityPriority` |

Order in the vertical bar: back/close (pinned top) → prominent actions (Done) → remaining groups in original order → overflow, filling bottom-to-top.

## Reserved regions (iOS 27.1)

| Purpose | SwiftUI | UIKit |
|---|---|---|
| Type | `ReservedRegion` | `UIViewReservedRegion` |
| Query hinge (division) | `proxy.reservedRegions(kind: .division)` | `view.reservedRegions(kind: .division)` |
| Include inactive regions | `proxy.reservedRegions(kind: .division, options: .includeInactive)` | (same option) |
| Query cameras (occlusion) | `proxy.reservedRegions(kind: .occlusion)` | `view.reservedRegions(kind: .occlusion)` |
| Frame | `region.frame` | `region.frame` |

- Division regions divide a larger area into smaller ones (hinge). Active only while folded; width zero when flat.
- Occlusion regions represent front cameras; they occlude rather than divide.
- Inactive regions are still useful for high-level decisions (grid column count).

## Arrangements

| Purpose | SwiftUI | UIKit |
|---|---|---|
| Container | `ArrangementView { primary } secondary: { secondary }` | `UIArrangementViewController` |
| Assign children | trailing closures | `setViewController(_:for: .primary)` / `.secondary` |
| Split style | `.arrangementViewStyle(.split)` | `updateArrangement(.split)` |
| Restrict split axis | `.arrangementViewStyle(.split.axes(.horizontal))` | `updateArrangement(.split.axes(.horizontal))` |
| Overlay style | `.arrangementViewStyle(.overlay)` | `updateArrangement(.overlay)` |
| Overlay stacking | `@Environment(\.overlayArrangementZIndex)` | `state(for: .primary)?.zIndex` |

Split: divides bounds; horizontal when wider than tall, vertical when taller; single view if it cannot split on the primary axis. Overlay: stacks; moves side-by-side when folded.

Do not nest `NavigationSplitView` inside an arrangement. Do not put an arrangement inside `List` / `ScrollView`.

## Hinge

| Purpose | SwiftUI | UIKit |
|---|---|---|
| Observe hinge | `.onHingeChange { _, context in … }` | `UIHingeInteraction` |
| Fields | `context.hinge?.status == .partiallyOpen`, `hinge.angle` | (interaction delegate) |

For effects only. Layout uses arrangements and reserved regions. `hinge == nil` means the device has no hinge.

## Scenes, multitasking, outer display

| Purpose | API |
|---|---|
| New window request | `UIWindowSceneActivation` (action hides itself when unavailable) |
| Scene lifecycle | `UIApplicationSceneManifest` (Info.plist), `UIWindowSceneDelegate` |
| Companion UI on outer display during capture | `.sceneAccessory { CameraCaptureAccessory(isEnabled:) { … } }` |
| Accessory availability | `.onAvailabilityChange { … }` |

- Split View: every app participates; each app's bars sit on its outer edge.
- New windows: inner display only.
- `CameraCaptureAccessory`: only while the app is full-screen on the inner display with an active camera session. Enabled by default; the system may toggle availability at any time.

## Tooling

| Tool | What |
|---|---|
| Xcode 27.1 | iPhone Duo simulator |
| Device Hub | On-screen open / close / rotate / fold controls |
| App Resizability skill | Renamed WWDC26 app modernization skill; SwiftUI + iPhone Duo aware; converts `UIScreen.main`, orientation checks, scene lifecycle |
| `xcrun agent skills export` | Exports Xcode skills as Markdown for other agents |
