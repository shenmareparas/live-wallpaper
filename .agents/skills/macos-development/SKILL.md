---
name: macos-development
description: Comprehensive macOS development guidance including Swift 6+, SwiftUI, SwiftData, architecture patterns, AppKit bridging, and macOS 26 Tahoe / macOS 27 Golden Gate APIs. Use for macOS code review, best practices, UI review, or platform-specific features.
allowed-tools: [Read, Glob, Grep, WebFetch]
---

# macOS Development Expert

Comprehensive guidance for macOS app development. This skill aggregates specialized modules for different aspects of macOS development.

## When This Skill Activates

Use this skill when the user:
- Asks about macOS development best practices
- Wants code review for macOS/Swift projects
- Needs help with SwiftUI, SwiftData, or AppKit
- Is implementing macOS 26 (Tahoe) or macOS 27 (Golden Gate) features
- Wants UI/UX review against HIG
- Needs architecture guidance for macOS apps

## Available Modules

Read relevant module files based on the user's needs:

### coding-best-practices/
Swift 6+ code quality and modern idioms.
- `swift-language.md` - Modern Swift patterns
- `modern-concurrency.md` - async/await, actors, Sendable
- `data-persistence.md` - SwiftData, UserDefaults, Keychain
- `code-organization.md` - Project structure and modularity
- `architecture-principles.md` - Clean architecture patterns

### architecture-patterns/
Software design and architecture.
- `solid-detailed.md` - SOLID principles with Swift examples
- `design-patterns.md` - Common design patterns
- `modular-design.md` - Modular architecture approaches

### swiftdata-architecture/
SwiftData deep dive.
- `schema-design.md` - Model design and relationships
- `query-patterns.md` - Efficient queries and predicates
- `performance.md` - Optimization techniques

### macos-tahoe-apis/
macOS 26 (Tahoe) and macOS 27 (Golden Gate) specific features.
- `golden-gate-features.md` - macOS 27 capabilities and WallpaperAgent integration
- `tahoe-features.md` - macOS 26 capabilities
- `apple-intelligence.md` - AI/ML integration
- `mlx-framework.md` - On-device ML with MLX
- `continuity.md` - Cross-device features
- `xcode16.md` - Xcode 16 tools and features
- `xcode27.md` - Xcode 27 and Swift 6.4 toolchain

### macos-capabilities/
Platform integration.
- `sandboxing.md` - App Sandbox and entitlements
- System integration features

### appkit-swiftui-bridge/
Hybrid development.
- `nsviewrepresentable.md` - Wrapping AppKit views
- State management between frameworks

### ui-review-tahoe/
UI/UX review for macOS 26.
- Liquid Glass design system
- HIG compliance checking
- Accessibility review

### app-planner/
Project planning and analysis.
- New app architecture planning
- Existing app audits

## How to Use

1. Identify user's need from their question
2. Read relevant module files from subdirectories
3. Apply the guidance to their specific context
4. Reference Apple documentation when needed

## Example Workflow

**User asks about SwiftData performance:**
1. Read `swiftdata-architecture/performance.md`
2. Read `swiftdata-architecture/query-patterns.md` if relevant
3. Apply recommendations to their code
