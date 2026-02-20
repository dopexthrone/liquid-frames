# Apple Dev Kit + Liquid Glass Context

Snapshot date: February 20, 2026

## Core Apple Design/Dev Resources

- Apple Design Resources hub: https://developer.apple.com/design/resources/
- Human Interface Guidelines entry point: https://developer.apple.com/design/human-interface-guidelines/
- Adopting Liquid Glass (technology overview): https://developer.apple.com/documentation/technologyoverviews/adopting-liquid-glass

## Latest Downloadable Design Kits and Tools

- iOS 26 and iPadOS 26 UI kit downloads (Figma + Sketch) are listed on the Apple Design Resources page.
- macOS Tahoe 26 app icon templates (Figma + Sketch) are listed on the Apple Design Resources page.
- SF Symbols 7 is listed on Apple Design Resources with release date September 15, 2025 and requirement macOS Tahoe 26+.
- Icon Composer is listed on Apple Design Resources with release date September 15, 2025 and requirement macOS Tahoe 26+.
- Apple SDK and simulator runtime downloads for Xcode 26 are listed on Apple Design Resources.

## WWDC Sessions To Anchor Implementation

- Meet Liquid Glass (WWDC25): https://developer.apple.com/videos/play/wwdc2025/219/
- Get to know the new design system (WWDC25): https://developer.apple.com/videos/play/wwdc2025/356/
- Build a SwiftUI app with the new design (WWDC25): https://developer.apple.com/videos/play/wwdc2025/323/
- Say hello to the new look of app icons (WWDC25): https://developer.apple.com/videos/play/wwdc2025/220/
- Create icons with Icon Composer (WWDC25): https://developer.apple.com/videos/play/wwdc2025/361/

## High-Signal Guidance Extracted from Official Sources

- Liquid Glass is intended for controls, toolbars, and navigation, not decorative overlays.
- Glass elements are adaptive and should morph based on context, focus, and available space.
- Related controls should be grouped as closed families, with no overlap between independent families.
- Keep hierarchy clear: preserve spacing, consistent corner radii, and concentric nesting.
- Prefer regular-weight text labels and avoid aggressive custom tinting on core navigation surfaces.
- Remove unnecessary bar backgrounds so content can extend behind controls when appropriate.
- Apply platform updates first, then layer custom brand expression and motion.
- Test on real devices across iOS 26, iPadOS 26, and macOS Tahoe 26.

## SwiftUI API Surface Mentioned in Apple Guidance

- `GlassEffectContainer`
- `glassEffectID(...)`
- `toolbarBackgroundVisibility(.hidden, for: ...)`
- `safeAreaInset(...)` for placing controls over content
- `tabBarMinimizeBehavior(.onScrollDown)`
- `backgroundExtensionEffect(...)`

## Source Notes

This file intentionally uses official Apple pages (design resources, documentation, and WWDC videos) to avoid drift from third-party interpretation.
