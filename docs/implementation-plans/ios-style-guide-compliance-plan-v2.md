# iOS & macOS Style Compliance Plan v2

**Date:** 14 Oct 2025  
**Status:** Ready for Implementation  
**Author:** Codex Review  
**Scope:** Yiana for iOS, iPadOS, macOS

---

## Executive Summary
The current analysis flagged missing accessibility, dark mode, and animation polish. This plan expands on those points with actionable work streams aligned to Apple’s latest design language (HIG 2025 + Liquid Glass). The objectives are:

1. Achieve baseline compliance (accessibility, typography, color).
2. Adopt modern platform conventions (edit menus, gestures, contextual actions, Liquid Glass behaviours).
3. Deliver measurable polish (motion, haptics, iconography, performance).

Success is defined as passing Apple’s Accessibility Audit, presenting native-feeling UI on both platforms, and reducing style regressions through automated checks.

---

## Guiding Principles
- **Clarity**: Use legible typography, semantic colors, clear hierarchy.
- **Deference**: Content-first layouts, avoid custom chrome when system components exist.
- **Depth**: Embrace Liquid Glass translucency, consistent motion, and layered visuals.
- **Parity**: Match behaviours across iOS/iPadOS/macOS while respecting each platform’s idioms.

---

## Work Streams & Milestones

### 1. Accessibility & Typography (Sprint 1)
| Deliverable | Actions | Acceptance Criteria |
|-------------|---------|---------------------|
| VoiceOver coverage | Audit all interactive elements, add `.accessibilityLabel`, `.accessibilityHint`, `.accessibilityActions` | VoiceOver rotor traverses every control with descriptive labels |
| Dynamic Type | Replace fixed fonts with `.font(.textStyle)` and `.minimumScaleFactor`, wrap custom text in `.dynamicTypeSize` | Large Accessibility sizes render without truncation |
| Reduced Motion & Contrast | Wrap animations in `if !reduceMotion`, adjust `Color` usage for high contrast | Audit in Accessibility Inspector passes Reduce Motion & Increase Contrast |

**Instrumentation:** Integrate `swiftlint accessibility` (custom rule set) + snapshot UI tests at Small / Accessibility Extra Large dynamic type sizes.

### 2. Visual System & Dark Appearance (Sprint 2)
| Deliverable | Actions | Acceptance Criteria |
|-------------|---------|---------------------|
| Semantic Color Palette | Create asset catalog with light/dark variants (AppBackground, DocumentCard, Accent) | UI Colors drawn from palette only; no hex literals in views |
| Liquid Glass adoption | Rebuild key surfaces (Document list header, modals) using `.background(Material.ultraThin)` and dynamic blur | Visual QA shows depth layering without obscuring content |
| Icon Consistency | Audit SF Symbols usage: ensure weight matches text weight (`.symbolRenderingMode(.hierarchical)`), upgrade to SF Symbols 7 variants where available | All icons sourced from SF Symbols; Sketch/Figma components updated |

**Instrumentation:** Add `swiftlint` regex rule rejecting `Color(red:` etc; screenshot tests in light/dark.

### 3. Interaction & Control Patterns (Sprint 3)
| Area | Actions |
|------|---------|
| Edit menu | Implement UIKit `UIMenuController` / SwiftUI `.contextMenu` entries for cut/copy/paste, ensure distribution to iPad pointer & macOS contextual menu. |
| Clipboard gestures | Add three-finger gestures (`GestureResponder`) on iPad/iPhone (copy, cut, paste, undo, redo). Provide visible cues (toast via `HUD` when gestures executed). |
| Context menus | Expand right-click menus on macOS (duplicate, rename, move) using `NSMenu`. Mirror long-press menus on iOS with `UIContextMenuInteraction`. |
| Touch targets & keyboard shortcuts | Guarantee `.frame(minWidth: 44, minHeight: 44)` for tap controls. Add `Commands` entries for all major actions (duplicating, search, organise) with documented shortcuts. |

### 4. Motion, Haptics & Micro-Interactions (Sprint 4)
| Deliverable | Actions | Metrics |
|-------------|---------|---------|
| Animation Baseline | Centralise durations & curves in `AnimationConstants`. Replace ad-hoc `.animation` calls with constants, wrap in `reduceMotion` checks. | Animation lint ensures only constants used |
| Haptic Feedback | Add `UINotificationFeedbackGenerator` & `UIImpactFeedbackGenerator` for success, warning, drag drop. Respect `UIAccessibility.isHearingDevicePaired`. | Usability test: users perceive feedback on key actions |
| Page Organiser Polish | Apply subtle scale/opacity transition when selecting thumbs, highlight insertion point with Liquid Glass flourish. | No dropped frames during reordering on iPad Pro (measured via Instruments) |

### 5. macOS-Specific Native Feel (Sprint 5)
| Area | Actions |
|------|---------|
| Toolbar density | Convert Page Management toolbar to segmented controls where appropriate; group related actions (copy/cut/paste). |
| Menu bar commands | Ensure all actions accessible from menu bar with proper titles, ellipsis usage, and dynamic enabling/disabling. |
| Windowing & Sidebar | Use `NavigationSplitView` or separate windows rather than iOS-style back buttons; adopt `Liquid Glass` sidebars introduced in macOS 15. |

---

## QA & Tooling
- **Automation:** Add UITests that run VoiceOver (UI Test plan with `XCUIRemote`) and dynamic type checks. Use snapshot tests for dark/light mode.
- **Linting:** Extend SwiftLint with custom rules for color literals, minimum frames, and banned strings (`UIColor.white`, etc.).
- **Design Review:** Schedule monthly design sync referencing Apple’s design kits (Figma) to ensure components mirror system look.
- **Performance:** Use Instruments (Core Animation FPS) during organiser interactions and navigation transitions.

---

## Measurements & Reporting
| KPI | Target |
|-----|--------|
| Accessibility Audit Score | ≥ 95% |
| Dark Mode Issues | 0 open issues in Linear/Jira |
| Crash-free sessions | ≥ 99% (monitor during rollout) |
| User Feedback | Reduce “UI confusing” support tickets by 50% over two releases |

---

## Dependencies & Resources
- **Apple Resources**: HIG 2025, Liquid Glass WWDC sessions, SF Symbols 7, iOS 18/iPadOS 18 design kits.
- **Tools**: SwiftLint (custom rules), Fastlane screenshots, Accessibility Inspector, macOS Design Templates.
- **Team Coordination**: Pair iOS and macOS engineers with Design for consistent semantic palette; QA to own accessibility regression suite.

---

## Next Steps
1. Review this plan with Design & PM; agree on sprint assignments.
2. Add tracking tickets for each work stream (at least one per platform per sprint).
3. Establish weekly cadence to demo new compliance work and update scorecard.

Delivering these improvements will align Yiana with Apple’s current design expectations (including Liquid Glass) and materially improve accessibility, consistency, and polish across platforms.***
