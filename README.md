# iphone-duo-skill

An agent skill that prepares, audits, and fixes an iOS app (SwiftUI or UIKit) for **iPhone Duo**, Apple's foldable iPhone (announced 2026-09-09, on sale 2026-10-23).

It distills Apple's official developer guidance published on 2026-09-09 (six Tech Talks, the HIG chapter "Designing for iPhone Duo", WWDC26 session 278) into:

- `SKILL.md`: the workflow an agent follows: **Audit → Fix by category → Verify**, with before/after code for SwiftUI and UIKit
- `scripts/audit.sh`: a dependency-free grep audit that reports `UIScreen.main`, orientation-driven layout, idiom checks, symmetric safe-area math, custom bars, hard-coded widths, key-window lookups, hinge misuse, and Info.plist flags
- `references/api-cheatsheet.md`: every API Apple named, grouped by topic (size classes, safe areas, vertical bars, reserved regions, arrangements, hinge, scenes, tooling)
- `references/sources.md`: links and dates for every claim

[한국어 README](README.ko.md)

## What Apple asks you to do (short version)

1. Rebuild with the **iOS 27.1 SDK** (iOS 27 SDK stops at the status bar on the inner display; 27.1 reaches the edge and lays bars out vertically)
2. Use **size classes, not orientation**. The inner display is regular×regular and ignores `supportedInterfaceOrientations`
3. Stop using **`UIScreen.main`**. There are two displays
4. Use **system navigation containers** (`NavigationStack` / `NavigationSplitView` / `TabView`, `UINavigationController` / `UITabBarController`) so bars move to the side automatically
5. Treat **safe areas as asymmetric**. Never `safeAreaInsets.left * 2`
6. Keep controls off the **fold** with reserved regions; use `ArrangementView` for split/overlay layouts
7. Test every pose in **Xcode 27.1 Device Hub** and in Split View

## Install

The skill is a folder with `SKILL.md` at its root, so cloning into a skills directory is enough.

**Claude Code** (project-local or global):

```bash
git clone https://github.com/dogfooter8750/iphone-duo-skill .claude/skills/iphone-duo
# or
git clone https://github.com/dogfooter8750/iphone-duo-skill ~/.claude/skills/iphone-duo
```

**Codex CLI**:

```bash
git clone https://github.com/dogfooter8750/iphone-duo-skill ~/.codex/skills/iphone-duo
```

Any other agent that reads `SKILL.md` front matter (name + description) can load it the same way.

## Use

Ask the agent, for example:

- "Audit this app for iPhone Duo"
- "Is this project ready for the foldable iPhone?"
- "Replace orientation checks with size classes for iPhone Duo"

Or run the audit yourself:

```bash
bash .claude/skills/iphone-duo/scripts/audit.sh path/to/YourApp
```

Sample output:

```
## Screen references (1)
- `App/LegacyView.swift:5:        let scale = UIScreen.main.scale`
## Symmetric safe-area math (1)
- `App/LegacyView.swift:6:        let w = view.bounds.width - view.safeAreaInsets.left * 2`
## Info.plist
- `App/Info.plist`
  - has `UIRequiresFullScreen`: opts out of resizable multitasking; remove for Split View
```

## Caveats

- Written from Apple's transcripts and HIG on 2026-09-15, before the Xcode 27.1 beta shipped. Check API signatures against the SDK headers when it does; the header wins.
- The skill does not state how apps built with SDKs older than iOS 27 behave on the inner display, because the primary sources used here do not.
- Apple's own **App Resizability** skill in Xcode 27.1 does the same class of edits inside Xcode (and `xcrun agent skills export` can export it). This repository exists so the same rules are available to agents outside Xcode and without the beta.

## License

MIT. Apple's documentation and video content belong to Apple; this repository quotes API names and summarizes guidance.
