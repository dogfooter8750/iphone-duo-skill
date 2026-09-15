# iphone-duo-skill

iOS 앱(SwiftUI·UIKit)을 **iPhone Duo**(애플 첫 폴더블, 2026-09-09 발표, 10-23 출시)에 맞게 점검하고 고치는 에이전트 스킬입니다.

2026-09-09에 애플이 공개한 공식 자료(Tech Talk 6편, HIG "Designing for iPhone Duo", WWDC26 세션 278)를 다음으로 정리했습니다.

- `SKILL.md`: 에이전트가 따르는 절차. **감사 → 항목별 수정 → 검증**. SwiftUI·UIKit 전후 코드 포함
- `scripts/audit.sh`: 의존성 없는 grep 감사. `UIScreen.main`, orientation 기반 레이아웃, idiom 분기, 대칭 safe area 계산, 커스텀 바, 하드코딩 폭, keyWindow 조회, 힌지 오용, Info.plist 플래그를 보고
- `references/api-cheatsheet.md`: 애플이 언급한 API 전부. 주제별(size class, safe area, 세로 바, reserved region, arrangement, 힌지, 씬, 도구)
- `references/sources.md`: 모든 주장의 출처 링크와 확인일

[English README](README.md)

## 애플이 시킨 것 (짧게)

1. **iOS 27.1 SDK**로 다시 빌드 (27 SDK는 안쪽 화면에서 상태바 옆까지만, 27.1이라야 화면 끝까지 + 바 세로 배치)
2. orientation 말고 **size class**. 안쪽 화면은 regular×regular이고 `supportedInterfaceOrientations`를 무시
3. **`UIScreen.main`** 쓰지 않기. 화면이 두 개
4. **시스템 내비게이션 컨테이너** 사용 (`NavigationStack` / `NavigationSplitView` / `TabView`, `UINavigationController` / `UITabBarController`). 바가 자동으로 옆에 붙음
5. **safe area는 비대칭**. `safeAreaInsets.left * 2` 금지
6. **힌지** 위에 컨트롤을 두지 않기. reserved region으로 피하고, 분할·오버레이 레이아웃은 `ArrangementView`
7. **Xcode 27.1 Device Hub**에서 포즈마다, 그리고 Split View에서 확인

## 설치

루트에 `SKILL.md`가 있는 폴더라서 스킬 디렉터리에 clone하면 끝납니다.

**Claude Code** (프로젝트 또는 전역):

```bash
git clone https://github.com/dogfooter8750/iphone-duo-skill .claude/skills/iphone-duo
# 또는
git clone https://github.com/dogfooter8750/iphone-duo-skill ~/.claude/skills/iphone-duo
```

**Codex CLI**:

```bash
git clone https://github.com/dogfooter8750/iphone-duo-skill ~/.codex/skills/iphone-duo
```

`SKILL.md` 프런트매터(name + description)를 읽는 다른 에이전트도 같은 방식으로 씁니다.

## 사용

에이전트에게 이렇게 말합니다.

- "이 앱 iPhone Duo 대비 감사해줘"
- "폴더블 아이폰 대응됐는지 봐줘"
- "iPhone Duo 대비로 orientation 체크를 size class로 바꿔줘"

직접 감사만 돌릴 수도 있습니다.

```bash
bash .claude/skills/iphone-duo/scripts/audit.sh path/to/YourApp
```

출력 예:

```
## Screen references (1)
- `App/LegacyView.swift:5:        let scale = UIScreen.main.scale`
## Symmetric safe-area math (1)
- `App/LegacyView.swift:6:        let w = view.bounds.width - view.safeAreaInsets.left * 2`
## Info.plist
- `App/Info.plist`
  - has `UIRequiresFullScreen`: opts out of resizable multitasking; remove for Split View
```

## 주의

- 2026-09-15, Xcode 27.1 beta가 나오기 전에 애플 영상 대본과 HIG만 보고 썼습니다. beta가 나오면 SDK 헤더와 API 시그니처를 대조하세요. 헤더가 우선입니다.
- iOS 27 미만 SDK로 빌드한 앱이 안쪽 화면에서 어떻게 뜨는지는 1차 출처에 없어 적지 않았습니다.
- Xcode 27.1에는 애플의 **App Resizability** 스킬이 들어가고 같은 종류의 수정을 Xcode 안에서 해줍니다(`xcrun agent skills export`로 내보낼 수도 있습니다). 이 저장소는 Xcode 밖의 에이전트에서, beta 없이도 같은 규칙을 쓰기 위한 것입니다.

## 라이선스

MIT. 애플 문서·영상의 저작권은 애플에 있으며 이 저장소는 API 이름을 인용하고 지침을 요약합니다.
