# AGENTS

<skills_system priority="1">

## Available Skills

<!-- SKILLS_TABLE_START -->
<usage>
When users ask you to perform tasks, check if any of the available skills below can help complete the task more effectively. Skills provide specialized capabilities and domain knowledge.

How to use skills:
- Invoke: `npx openskills read <skill-name>` (run in your shell)
  - For multiple: `npx openskills read skill-one,skill-two`
- The skill content will load with detailed instructions on how to complete the task
- Base directory provided in output for resolving bundled resources (references/, scripts/, assets/)

Usage notes:
- Only use skills listed in <available_skills> below
- Do not invoke a skill that is already loaded in your context
- Each skill invocation is stateless
</usage>

<available_skills>

<skill>
<name>axiom-accessibility-diag</name>
<description>Use when fixing VoiceOver issues, Dynamic Type violations, color contrast failures, touch target problems, keyboard navigation gaps, or Reduce Motion support - comprehensive accessibility diagnostics with WCAG compliance, Accessibility Inspector workflows, and App Store Review preparation for iOS/macOS</description>
<location>project</location>
</skill>

<skill>
<name>axiom-alarmkit-ref</name>
<description>Use when implementing alarm functionality, scheduling wake alarms, or integrating AlarmKit with Live Activities. Covers AlarmKit authorization, alarm configuration, SwiftUI views, and Live Activity integration.</description>
<location>project</location>
</skill>

<skill>
<name>axiom-analyze-crash</name>
<description>Use when the user has a crash log (.</description>
<location>project</location>
</skill>

<skill>
<name>axiom-analyze-swift-performance</name>
<description>Use when the user mentions Swift performance audit, code optimization, or performance review.</description>
<location>project</location>
</skill>

<skill>
<name>axiom-analyze-swiftui-performance</name>
<description>Use when the user mentions SwiftUI performance, janky scrolling, slow animations, or view update issues.</description>
<location>project</location>
</skill>

<skill>
<name>axiom-analyze-test-failures</name>
<description>Use when the user mentions flaky tests, tests that pass locally but fail in CI, race conditions in tests, or needs to diagnose WHY a specific test fails.</description>
<location>project</location>
</skill>

<skill>
<name>axiom-app-attest</name>
<description>Use when implementing app integrity verification, preventing fraud with DCAppAttestService, validating requests from legitimate app instances, using DeviceCheck for promotional abuse prevention, or needing server-side attestation/assertion validation. Covers key generation, attestation, assertion, rollout strategy, and risk metrics.</description>
<location>project</location>
</skill>

<skill>
<name>axiom-app-composition</name>
<description>Use when structuring app entry points, managing authentication flows, switching root views, handling scene lifecycle, or asking 'how do I structure my @main', 'where does auth state live', 'how do I prevent screen flicker on launch', 'when should I modularize' - app-level composition patterns for iOS 26+</description>
<location>project</location>
</skill>

<skill>
<name>axiom-app-discoverability</name>
<description>Use when making app surface in Spotlight search, Siri suggestions, or system experiences - covers the 6-step strategy combining App Intents, App Shortcuts, Core Spotlight, and NSUserActivity to feed the system metadata for iOS 16+</description>
<location>project</location>
</skill>

<skill>
<name>axiom-app-intents-ref</name>
<description>Use when integrating App Intents for Siri, Apple Intelligence, Shortcuts, Spotlight, or system experiences - covers AppIntent, AppEntity, parameter handling, entity queries, background execution, authentication, and debugging common integration issues for iOS 16+</description>
<location>project</location>
</skill>

<skill>
<name>axiom-app-shortcuts-ref</name>
<description>Use when implementing App Shortcuts for instant Siri/Spotlight availability, configuring AppShortcutsProvider, adding suggested phrases, or debugging shortcuts not appearing - covers complete App Shortcuts API for iOS 16+</description>
<location>project</location>
</skill>

<skill>
<name>axiom-app-store-connect-ref</name>
<description>Use when navigating App Store Connect to find crash data, read TestFlight feedback, interpret metrics dashboards, or export diagnostic logs. Covers crash-free rates, dSYM symbolication, termination types, MetricKit.</description>
<location>project</location>
</skill>

<skill>
<name>axiom-app-store-diag</name>
<description>Use when app is rejected by App Review, submission blocked, or appeal needed - systematic diagnosis from rejection message to fix with guideline-specific remediation patterns and appeal writing</description>
<location>project</location>
</skill>

<skill>
<name>axiom-app-store-ref</name>
<description>Use when looking up ANY App Store metadata field requirement, privacy manifest schema, age rating tier, export compliance decision, EU DSA trader status, IAP review pipeline, or WWDC25 submission change. Covers character limits, screenshot specs, encryption decision tree, account deletion rules.</description>
<location>project</location>
</skill>

<skill>
<name>axiom-app-store-submission</name>
<description>Use when preparing ANY app for App Store submission, responding to App Review rejections, or running a pre-submission audit. Covers privacy manifests, metadata requirements, IAP review, account deletion, SIWA, age ratings, export compliance, first-time developer setup.</description>
<location>project</location>
</skill>

<skill>
<name>axiom-apple-docs</name>
<description>Use when ANY question involves Apple framework APIs, Swift compiler errors, or Xcode-bundled documentation. Covers Liquid Glass, Swift 6.2 concurrency, Foundation Models, SwiftData, StoreKit, 32 Swift compiler diagnostics.</description>
<location>project</location>
</skill>

<skill>
<name>axiom-apple-docs-research</name>
<description>Use when researching Apple frameworks, APIs, or WWDC sessions - provides techniques for retrieving full transcripts, code samples, and documentation using Chrome browser and sosumi.ai</description>
<location>project</location>
</skill>

<skill>
<name>axiom-asc-mcp</name>
<description>Use when automating App Store Connect via MCP — submit builds, manage TestFlight, respond to reviews, triage feedback programmatically</description>
<location>project</location>
</skill>

<skill>
<name>axiom-assume-isolated</name>
<description>Use when needing synchronous actor access in tests, legacy delegate callbacks, or performance-critical code. Covers MainActor.assumeIsolated, @preconcurrency protocol conformances, crash behavior, Task vs assumeIsolated.</description>
<location>project</location>
</skill>

<skill>
<name>axiom-audit-accessibility</name>
<description>Use when the user mentions accessibility checking, App Store submission, code review, or WCAG compliance.</description>
<location>project</location>
</skill>

<skill>
<name>axiom-audit-camera</name>
<description>Use this agent to scan Swift code for camera, video, and audio capture issues including deprecated APIs, missing interruption handlers, threading violations, and permission anti-patterns.</description>
<location>project</location>
</skill>

<skill>
<name>axiom-audit-codable</name>
<description>Use when the user mentions Codable review, JSON encoding/decoding issues, data serialization audit, or modernizing legacy code.</description>
<location>project</location>
</skill>

<skill>
<name>axiom-audit-concurrency</name>
<description>Use when the user mentions concurrency checking, Swift 6 compliance, data race prevention, or async code review.</description>
<location>project</location>
</skill>

<skill>
<name>axiom-audit-core-data</name>
<description>Use when the user mentions Core Data review, schema migration, production crashes, or data safety checking.</description>
<location>project</location>
</skill>

<skill>
<name>axiom-audit-database-schema</name>
<description>Use when the user mentions database schema review, migration safety, GRDB migration audit, or SQLite schema checking.</description>
<location>project</location>
</skill>

<skill>
<name>axiom-audit-energy</name>
<description>Use when the user mentions battery drain, energy optimization, power consumption audit, or pre-release energy check.</description>
<location>project</location>
</skill>

<skill>
<name>axiom-audit-foundation-models</name>
<description>Use when the user mentions Foundation Models review, on-device AI audit, LanguageModelSession issues, @Generable checking, or Apple Intelligence integration review.</description>
<location>project</location>
</skill>

<skill>
<name>axiom-audit-iap</name>
<description>Use when the user mentions in-app purchase review, IAP audit, StoreKit issues, purchase bugs, transaction problems, or subscription management.</description>
<location>project</location>
</skill>

<skill>
<name>axiom-audit-icloud</name>
<description>Use when the user mentions iCloud sync issues, CloudKit errors, ubiquitous container problems, or asks to audit cloud sync.</description>
<location>project</location>
</skill>

<skill>
<name>axiom-audit-liquid-glass</name>
<description>Use when the user mentions Liquid Glass review, iOS 26 UI updates, toolbar improvements, or visual effect migration.</description>
<location>project</location>
</skill>

<skill>
<name>axiom-audit-memory</name>
<description>Use when the user mentions memory leak prevention, code review for memory issues, or proactive leak checking.</description>
<location>project</location>
</skill>

<skill>
<name>axiom-audit-networking</name>
<description>Use when the user mentions networking review, deprecated APIs, connection issues, or App Store submission prep.</description>
<location>project</location>
</skill>

<skill>
<name>axiom-audit-spritekit</name>
<description>Use when the user wants to audit SpriteKit game code for common issues.</description>
<location>project</location>
</skill>

<skill>
<name>axiom-audit-storage</name>
<description>Use when the user mentions file storage issues, data loss, backup bloat, or asks to audit storage usage.</description>
<location>project</location>
</skill>

<skill>
<name>axiom-audit-swiftdata</name>
<description>Use when the user mentions SwiftData review, @Model issues, SwiftData migration safety, or SwiftData performance checking.</description>
<location>project</location>
</skill>

<skill>
<name>axiom-audit-swiftui-architecture</name>
<description>Use when the user mentions SwiftUI architecture review, separation of concerns, testability issues, or "logic in view" problems.</description>
<location>project</location>
</skill>

<skill>
<name>axiom-audit-swiftui-layout</name>
<description>Use when the user mentions SwiftUI layout review, adaptive layout issues, GeometryReader problems, or multi-device layout checking.</description>
<location>project</location>
</skill>

<skill>
<name>axiom-audit-swiftui-nav</name>
<description>Use when the user mentions SwiftUI navigation issues, deep linking problems, state restoration bugs, or navigation architecture review.</description>
<location>project</location>
</skill>

<skill>
<name>axiom-audit-testing</name>
<description>Use when the user wants to audit test quality, find flaky test patterns, speed up test execution, or prepare for Swift Testing migration.</description>
<location>project</location>
</skill>

<skill>
<name>axiom-audit-textkit</name>
<description>Use when the user mentions TextKit review, text layout issues, Writing Tools integration, or UITextView/NSTextView code review.</description>
<location>project</location>
</skill>

<skill>
<name>axiom-audit-ux-flow</name>
<description>Use when the user mentions UX flow issues, dead-end views, dismiss traps, missing empty states, broken user journeys, or wants a UX audit of their iOS app.</description>
<location>project</location>
</skill>

<skill>
<name>axiom-auto-layout-debugging</name>
<description>Use when encountering "Unable to simultaneously satisfy constraints" errors, constraint conflicts, ambiguous layout warnings, or views positioned incorrectly - systematic debugging workflow for Auto Layout issues in iOS</description>
<location>project</location>
</skill>

<skill>
<name>axiom-avfoundation-ref</name>
<description>Reference — AVFoundation audio APIs, AVAudioSession categories/modes, AVAudioEngine pipelines, bit-perfect DAC output, iOS 26+ spatial audio capture, ASAF/APAC, Audio Mix with Cinematic framework</description>
<location>project</location>
</skill>

<skill>
<name>axiom-axe-ref</name>
<description>Use when automating iOS Simulator UI interactions beyond simctl capabilities. Reference for AXe CLI covering accessibility-based tapping, gestures, text input, screenshots, video recording, and UI tree inspection.</description>
<location>project</location>
</skill>

<skill>
<name>axiom-background-processing</name>
<description>Use when implementing BGTaskScheduler, debugging background tasks that never run, understanding why tasks terminate early, or testing background execution - systematic task lifecycle management with proper registration, expiration handling, and Swift 6 cancellation patterns</description>
<location>project</location>
</skill>

<skill>
<name>axiom-background-processing-diag</name>
<description>Symptom-based background task troubleshooting - decision trees for 'task never runs', 'task terminates early', 'works in dev not prod', 'handler not called', with time-cost analysis for each diagnosis path</description>
<location>project</location>
</skill>

<skill>
<name>axiom-background-processing-ref</name>
<description>Complete background task API reference - BGTaskScheduler, BGAppRefreshTask, BGProcessingTask, BGContinuedProcessingTask (iOS 26), beginBackgroundTask, background URLSession, with all WWDC code examples</description>
<location>project</location>
</skill>

<skill>
<name>axiom-build-debugging</name>
<description>Use when encountering dependency conflicts, CocoaPods/SPM resolution failures, "Multiple commands produce" errors, or framework version mismatches - systematic dependency and build configuration debugging for iOS projects. Includes pressure scenario guidance for resisting quick fixes under time constraints</description>
<location>project</location>
</skill>

<skill>
<name>axiom-build-performance</name>
<description>Use when build times are slow, investigating build performance, analyzing Build Timeline, identifying type checking bottlenecks, enabling compilation caching, or optimizing incremental builds - comprehensive build optimization workflows including Xcode 26 compilation caching</description>
<location>project</location>
</skill>

<skill>
<name>axiom-camera-capture</name>
<description>AVCaptureSession, camera preview, photo capture, video recording, RotationCoordinator, session interruptions, deferred processing, capture responsiveness, zero-shutter-lag, photoQualityPrioritization, front camera mirroring</description>
<location>project</location>
</skill>

<skill>
<name>axiom-camera-capture-diag</name>
<description>camera freezes, preview rotated wrong, capture slow, session interrupted, black preview, front camera mirrored, camera not starting, AVCaptureSession errors, startRunning blocks, phone call interrupts camera</description>
<location>project</location>
</skill>

<skill>
<name>axiom-camera-capture-ref</name>
<description>Reference — AVCaptureSession, AVCapturePhotoSettings, AVCapturePhotoOutput, RotationCoordinator, photoQualityPrioritization, deferred processing, AVCaptureMovieFileOutput, session presets, capture device APIs</description>
<location>project</location>
</skill>

<skill>
<name>axiom-cloud-sync</name>
<description>Use when choosing between CloudKit vs iCloud Drive, implementing reliable sync, handling offline-first patterns, or designing sync architecture - prevents common sync mistakes that cause data loss</description>
<location>project</location>
</skill>

<skill>
<name>axiom-cloud-sync-diag</name>
<description>Use when debugging 'file not syncing', 'CloudKit error', 'sync conflict', 'iCloud upload failed', 'ubiquitous item error', 'data not appearing on other devices', 'CKError', 'quota exceeded' - systematic iCloud sync diagnostics for both CloudKit and iCloud Drive</description>
<location>project</location>
</skill>

<skill>
<name>axiom-cloudkit-ref</name>
<description>Use when implementing 'CloudKit sync', 'CKSyncEngine', 'CKRecord', 'CKDatabase', 'SwiftData CloudKit', 'shared database', 'public database', 'CloudKit zones', 'conflict resolution' - comprehensive CloudKit database APIs and modern sync patterns reference</description>
<location>project</location>
</skill>

<skill>
<name>axiom-codable</name>
<description>Use when working with Codable protocol, JSON encoding/decoding, CodingKeys customization, enum serialization, date strategies, custom containers, or encountering "Type does not conform to Decodable/Encodable" errors - comprehensive Codable patterns and anti-patterns for Swift 6.x</description>
<location>project</location>
</skill>

<skill>
<name>axiom-code-signing</name>
<description>Use when setting up code signing, managing certificates, configuring provisioning profiles, debugging signing errors, setting up CI/CD signing, or preparing distribution builds. Covers certificate lifecycle, automatic vs manual signing, entitlements, fastlane match, Keychain management, and App Store distribution signing.</description>
<location>project</location>
</skill>

<skill>
<name>axiom-code-signing-diag</name>
<description>Use when code signing fails during build, archive, or upload — certificate not found, provisioning profile mismatch, errSecInternalComponent in CI, ITMS-90035 invalid signature, ambiguous identity, entitlement mismatch. Covers certificate, profile, keychain, entitlement, and archive signing diagnostics.</description>
<location>project</location>
</skill>

<skill>
<name>axiom-code-signing-ref</name>
<description>Use when needing certificate CLI commands, provisioning profile inspection, entitlement extraction, Keychain management scripts, codesign verification, fastlane match setup, Xcode build settings for signing, or APNs .p8 vs .p12 decision. Covers complete code signing API and CLI surface.</description>
<location>project</location>
</skill>

<skill>
<name>axiom-combine-patterns</name>
<description>Use when working with Combine publishers, AnyCancellable lifecycle, @Published properties, or bridging Combine with async/await. Covers reactive patterns, operator selection, memory management, and migration strategy.</description>
<location>project</location>
</skill>

<skill>
<name>axiom-concurrency-profiling</name>
<description>Use when profiling async/await performance, diagnosing actor contention, or investigating thread pool exhaustion. Covers Swift Concurrency Instruments template, task visualization, actor contention analysis, thread pool debugging.</description>
<location>project</location>
</skill>

<skill>
<name>axiom-contacts</name>
<description>Use when accessing ANY contact data, requesting Contacts permissions, choosing between picker and store access, implementing Contact Access Button, or migrating to iOS 18 limited access. Covers authorization levels, CNContactStore, ContactProvider, key fetching, incremental sync.</description>
<location>project</location>
</skill>

<skill>
<name>axiom-contacts-ref</name>
<description>Use when needing Contacts API details — CNContactStore, CNMutableContact, CNSaveRequest, CNContactFormatter, CNContactVCardSerialization, CNContactPickerViewController, ContactAccessButton, contactAccessPicker, ContactProvider extension, CNChangeHistoryFetchRequest, contact key descriptors, and CNError codes</description>
<location>project</location>
</skill>

<skill>
<name>axiom-core-data</name>
<description>Use when choosing Core Data vs SwiftData, setting up the Core Data stack, modeling relationships, or implementing concurrency patterns - prevents thread-confinement errors and migration crashes</description>
<location>project</location>
</skill>

<skill>
<name>axiom-core-data-diag</name>
<description>Use when debugging schema migration crashes, concurrency thread-confinement errors, N+1 query performance, SwiftData to Core Data bridging, or testing migrations without data loss - systematic Core Data diagnostics with safety-first migration patterns</description>
<location>project</location>
</skill>

<skill>
<name>axiom-core-location</name>
<description>Use for Core Location implementation patterns - authorization strategy, monitoring strategy, accuracy selection, background location</description>
<location>project</location>
</skill>

<skill>
<name>axiom-core-location-diag</name>
<description>Use for Core Location troubleshooting - no location updates, background location broken, authorization denied, geofence not triggering</description>
<location>project</location>
</skill>

<skill>
<name>axiom-core-location-ref</name>
<description>Use for Core Location API reference - CLLocationUpdate, CLMonitor, CLServiceSession, authorization, background location, geofencing</description>
<location>project</location>
</skill>

<skill>
<name>axiom-core-spotlight-ref</name>
<description>Use when indexing app content for Spotlight search, using NSUserActivity for prediction/handoff, or choosing between CSSearchableItem and IndexedEntity - covers Core Spotlight framework and NSUserActivity integration for iOS 9+</description>
<location>project</location>
</skill>

<skill>
<name>axiom-cryptokit</name>
<description>Use when encrypting data, signing payloads, verifying signatures, generating keys, using Secure Enclave, migrating from CommonCrypto, or adopting quantum-secure cryptography. Covers CryptoKit design philosophy, AES-GCM, ECDSA, ECDH, Secure Enclave keys, HPKE, ML-KEM, ML-DSA, and cross-platform interop with Swift Crypto.</description>
<location>project</location>
</skill>

<skill>
<name>axiom-cryptokit-ref</name>
<description>Use when needing CryptoKit API details — hash functions (SHA2/SHA3), HMAC, AES-GCM/ChaChaPoly encryption, ECDSA/EdDSA signatures, ECDH key agreement, ML-KEM/ML-DSA post-quantum algorithms, HPKE encryption, Secure Enclave key types, key representations (raw/DER/PEM/x963), or Swift Crypto cross-platform parity. Covers complete CryptoKit API surface.</description>
<location>project</location>
</skill>

<skill>
<name>axiom-database-migration</name>
<description>Use when adding/modifying database columns, encountering "FOREIGN KEY constraint failed", "no such column", "cannot add NOT NULL column" errors, or creating schema migrations for SQLite/GRDB/SQLiteData - prevents data loss with safe migration patterns and testing workflows for iOS/macOS apps</description>
<location>project</location>
</skill>

<skill>
<name>axiom-debug-tests</name>
<description>Use this agent for closed-loop test debugging - automatically analyzes test failures, suggests fixes, and re-runs tests until passing.</description>
<location>project</location>
</skill>

<skill>
<name>axiom-deep-link-debugging</name>
<description>Use when adding debug-only deep links for testing, enabling simulator navigation to specific screens, or integrating with automated testing workflows - enables closed-loop debugging without production deep link implementation</description>
<location>project</location>
</skill>

<skill>
<name>axiom-display-performance</name>
<description>Use when app runs at unexpected frame rate, stuck at 60fps on ProMotion, frame pacing issues, or configuring render loops. Covers MTKView, CADisplayLink, CAMetalDisplayLink, frame pacing, hitches, system caps.</description>
<location>project</location>
</skill>

<skill>
<name>axiom-energy</name>
<description>Use when app drains battery, device gets hot, users report energy issues, or auditing power consumption - systematic Power Profiler diagnosis, subsystem identification (CPU/GPU/Network/Location/Display), anti-pattern fixes for iOS/iPadOS</description>
<location>project</location>
</skill>

<skill>
<name>axiom-energy-diag</name>
<description>Symptom-based energy troubleshooting - decision trees for 'app at top of battery settings', 'phone gets hot', 'background drain', 'high cellular usage', with time-cost analysis for each diagnosis path</description>
<location>project</location>
</skill>

<skill>
<name>axiom-energy-ref</name>
<description>Complete energy optimization API reference - Power Profiler workflows, timer/network/location/background APIs, iOS 26 BGContinuedProcessingTask, MetricKit monitoring, with all WWDC code examples</description>
<location>project</location>
</skill>

<skill>
<name>axiom-eventkit</name>
<description>Use when working with ANY calendar event, reminder, EventKit permission, or EventKitUI controller. Covers access tiers (no-access, write-only, full), permission migration from pre-iOS 17, store lifecycle, reminder patterns, EventKitUI controller selection, Siri Event Suggestions, virtual conference extensions.</description>
<location>project</location>
</skill>

<skill>
<name>axiom-eventkit-ref</name>
<description>Use when needing EventKit API details — EKEventStore, EKEvent, EKReminder, EventKitUI view controllers, EKCalendarChooser, authorization methods, predicate-based fetching, recurrence rules, Siri Event Suggestions donation, EKVirtualConferenceProvider, location-based reminders, and EKErrorDomain codes</description>
<location>project</location>
</skill>

<skill>
<name>axiom-extensions-widgets</name>
<description>Use when implementing widgets, Live Activities, or Control Center controls - enforces correct patterns for timeline management, data sharing, and extension lifecycle to prevent common crashes and memory issues</description>
<location>project</location>
</skill>

<skill>
<name>axiom-extensions-widgets-ref</name>
<description>Use when implementing widgets, Live Activities, Control Center controls, or app extensions - comprehensive API reference for WidgetKit, ActivityKit, App Groups, and extension lifecycle for iOS 14+</description>
<location>project</location>
</skill>

<skill>
<name>axiom-file-protection-ref</name>
<description>Use when asking about 'FileProtectionType', 'file encryption iOS', 'NSFileProtection', 'data protection', 'secure file storage', 'encrypt files at rest', 'complete protection', 'file security' - comprehensive reference for iOS file encryption and data protection APIs</description>
<location>project</location>
</skill>

<skill>
<name>axiom-fix-build</name>
<description>Use when the user mentions Xcode build failures, build errors, or environment issues.</description>
<location>project</location>
</skill>

<skill>
<name>axiom-foundation-models</name>
<description>Use when implementing on-device AI with Apple's Foundation Models framework — prevents context overflow, blocking UI, wrong model use cases, and manual JSON parsing when @Generable should be used. iOS 26+, macOS 26+, iPadOS 26+, axiom-visionOS 26+</description>
<location>project</location>
</skill>

<skill>
<name>axiom-foundation-models-diag</name>
<description>Use when debugging Foundation Models issues — context exceeded, guardrail violations, slow generation, availability problems, unsupported language, or unexpected output. Systematic diagnostics with production crisis defense.</description>
<location>project</location>
</skill>

<skill>
<name>axiom-foundation-models-ref</name>
<description>Reference — Complete Foundation Models framework guide covering LanguageModelSession, @Generable, @Guide, Tool protocol, streaming, dynamic schemas, built-in use cases, and all WWDC 2025 code examples</description>
<location>project</location>
</skill>

<skill>
<name>axiom-getting-started</name>
<description>Use when first installing Axiom, unsure which skill to use, want an overview of available skills, or need help finding the right skill for your situation — interactive onboarding that recommends skills based on your project and current focus</description>
<location>project</location>
</skill>

<skill>
<name>axiom-grdb</name>
<description>Use when writing raw SQL queries with GRDB, complex joins, ValueObservation for reactive queries, DatabaseMigrator patterns, query profiling under performance pressure, or dropping down from SQLiteData for performance - direct SQLite access for iOS/macOS</description>
<location>project</location>
</skill>

<skill>
<name>axiom-hang-diagnostics</name>
<description>Use when app freezes, UI unresponsive, main thread blocked, watchdog termination, or diagnosing hang reports from Xcode Organizer or MetricKit</description>
<location>project</location>
</skill>

<skill>
<name>axiom-haptics</name>
<description>Use when implementing haptic feedback, Core Haptics patterns, audio-haptic synchronization, or debugging haptic issues - covers UIFeedbackGenerator, CHHapticEngine, AHAP patterns, and Apple's Causality-Harmony-Utility design principles from WWDC 2021</description>
<location>project</location>
</skill>

<skill>
<name>axiom-health-check</name>
<description>Use when the user wants a comprehensive project-wide audit, full health check, or scan across all domains.</description>
<location>project</location>
</skill>

<skill>
<name>axiom-hig</name>
<description>Use when making design decisions, reviewing UI for HIG compliance, choosing colors/backgrounds/typography, or defending design choices - quick decision frameworks and checklists for Apple Human Interface Guidelines</description>
<location>project</location>
</skill>

<skill>
<name>axiom-hig-ref</name>
<description>Reference — Comprehensive Apple Human Interface Guidelines covering colors (semantic, custom, patterns), backgrounds (material hierarchy, dynamic), typography (built-in styles, custom fonts, Dynamic Type), SF Symbols (rendering modes, color, axiom-localization), Dark Mode, accessibility, and platform-specific considerations</description>
<location>project</location>
</skill>

<skill>
<name>axiom-icloud-drive-ref</name>
<description>Use when implementing 'iCloud Drive', 'ubiquitous container', 'file sync', 'NSFileCoordinator', 'NSFilePresenter', 'isUbiquitousItem', 'NSUbiquitousKeyValueStore', 'ubiquitous file sync' - comprehensive file-based iCloud sync reference</description>
<location>project</location>
</skill>

<skill>
<name>axiom-implement-iap</name>
<description>Use when the user wants to add in-app purchases, implement StoreKit 2, or set up subscriptions.</description>
<location>project</location>
</skill>

<skill>
<name>axiom-in-app-purchases</name>
<description>Use when implementing in-app purchases, StoreKit 2, subscriptions, or transaction handling - testing-first workflow with .storekit configuration, StoreManager architecture, transaction verification, subscription management, and restore purchases for consumables, non-consumables, and auto-renewable subscriptions</description>
<location>project</location>
</skill>

<skill>
<name>axiom-ios-accessibility</name>
<description>Use when fixing or auditing ANY accessibility issue - VoiceOver, Dynamic Type, color contrast, touch targets, WCAG compliance, App Store accessibility review.</description>
<location>project</location>
</skill>

<skill>
<name>axiom-ios-ai</name>
<description>Use when implementing ANY Apple Intelligence or on-device AI feature. Covers Foundation Models, @Generable, LanguageModelSession, structured output, Tool protocol, iOS 26 AI integration.</description>
<location>project</location>
</skill>

<skill>
<name>axiom-ios-build</name>
<description>Use when ANY iOS build fails, test crashes, Xcode misbehaves, or environment issue occurs before debugging code. Covers build failures, compilation errors, dependency conflicts, simulator problems, environment-first diagnostics.</description>
<location>project</location>
</skill>

<skill>
<name>axiom-ios-concurrency</name>
<description>Use when writing ANY code with async, actors, threads, or seeing ANY concurrency error. Covers Swift 6 concurrency, @MainActor, Sendable, data races, async/await patterns, performance optimization.</description>
<location>project</location>
</skill>

<skill>
<name>axiom-ios-data</name>
<description>Use when working with ANY data persistence, database, axiom-storage, CloudKit, migration, or serialization. Covers SwiftData, Core Data, GRDB, SQLite, CloudKit sync, file storage, Codable, migrations.</description>
<location>project</location>
</skill>

<skill>
<name>axiom-ios-games</name>
<description>Use when building ANY 2D or 3D game, game prototype, or interactive simulation with SpriteKit, SceneKit, or RealityKit. Covers scene graphs, ECS architecture, physics, actions, game loops, rendering, SwiftUI integration, SceneKit migration.</description>
<location>project</location>
</skill>

<skill>
<name>axiom-ios-graphics</name>
<description>Use when working with ANY GPU rendering, Metal, OpenGL migration, shaders, 3D content, RealityKit, AR, or display performance. Covers Metal migration, shader conversion, RealityKit ECS, RealityView, variable refresh rate, ProMotion.</description>
<location>project</location>
</skill>

<skill>
<name>axiom-ios-integration</name>
<description>Use when integrating ANY iOS system feature - Siri, Shortcuts, widgets, IAP, camera, photo library, audio, ShazamKit, haptics, localization, privacy, alarms, calendar, reminders, contacts. Covers App Intents, WidgetKit, StoreKit, AVFoundation, ShazamKit, Core Haptics, Spotlight, EventKit, Contacts.</description>
<location>project</location>
</skill>

<skill>
<name>axiom-ios-ml</name>
<description>Use when deploying ANY machine learning model on-device, converting models to CoreML, compressing models, or implementing speech-to-text. Covers CoreML conversion, MLTensor, model compression (quantization/palettization/pruning), stateful models, KV-cache, multi-function models, async prediction, SpeechAnalyzer, SpeechTranscriber.</description>
<location>project</location>
</skill>

<skill>
<name>axiom-ios-networking</name>
<description>Use when implementing or debugging ANY network connection, API call, or socket. Covers URLSession, Network.framework, NetworkConnection, deprecated APIs, connection diagnostics, structured concurrency networking.</description>
<location>project</location>
</skill>

<skill>
<name>axiom-ios-performance</name>
<description>Use when app feels slow, memory grows, battery drains, or diagnosing ANY performance issue. Covers memory leaks, profiling, Instruments workflows, retain cycles, performance optimization.</description>
<location>project</location>
</skill>

<skill>
<name>axiom-ios-testing</name>
<description>Use when writing ANY test, debugging flaky tests, making tests faster, or asking about Swift Testing vs XCTest. Covers unit tests, UI tests, fast tests without simulator, async testing, test architecture.</description>
<location>project</location>
</skill>

<skill>
<name>axiom-ios-ui</name>
<description>Use when building, fixing, or improving ANY iOS UI including SwiftUI, UIKit, layout, navigation, animations, design guidelines. Covers view updates, layout bugs, navigation issues, performance, architecture, Apple design compliance.</description>
<location>project</location>
</skill>

<skill>
<name>axiom-ios-vision</name>
<description>Use when implementing ANY computer vision feature - image analysis, object detection, pose detection, person segmentation, subject lifting, hand/body pose tracking.</description>
<location>project</location>
</skill>

<skill>
<name>axiom-keychain</name>
<description>Use when storing credentials, tokens, or secrets securely, debugging SecItem errors (errSecDuplicateItem, errSecItemNotFound, errSecInteractionNotAllowed), managing keychain access groups, or choosing accessibility classes. Covers SecItem API mental model, uniqueness constraints, data protection, biometric access control, sharing between apps, and Mac keychain differences.</description>
<location>project</location>
</skill>

<skill>
<name>axiom-keychain-diag</name>
<description>Use when SecItem calls fail — errSecDuplicateItem from unexpected uniqueness, errSecItemNotFound despite item existing, errSecInteractionNotAllowed in background, keychain items disappearing after app update, access group entitlement errors, or Mac keychain shim issues. Covers systematic error diagnosis with decision trees.</description>
<location>project</location>
</skill>

<skill>
<name>axiom-keychain-ref</name>
<description>Use when needing SecItem function signatures, keychain attribute constants, item class uniqueness constraints, accessibility level details, SecAccessControlCreateFlags, kSecReturn behavior per class, LAContext keychain integration, or OSStatus error codes. Covers complete keychain API surface.</description>
<location>project</location>
</skill>

<skill>
<name>axiom-liquid-glass</name>
<description>Use when implementing Liquid Glass effects, reviewing UI for Liquid Glass adoption, debugging visual artifacts, optimizing performance, or requesting expert review of Liquid Glass implementation - provides comprehensive design principles, API patterns, and troubleshooting guidance from WWDC 2025. Includes design review pressure handling and professional push-back frameworks</description>
<location>project</location>
</skill>

<skill>
<name>axiom-liquid-glass-ref</name>
<description>Use when planning comprehensive Liquid Glass adoption across an app, auditing existing interfaces for Liquid Glass compatibility, implementing app icon updates, or understanding platform-specific Liquid Glass behavior - comprehensive reference guide covering all aspects of Liquid Glass adoption from WWDC 2025</description>
<location>project</location>
</skill>

<skill>
<name>axiom-lldb</name>
<description>Use when ANY runtime debugging is needed — setting breakpoints, inspecting variables, evaluating expressions, analyzing threads, or reproducing crashes interactively with LLDB</description>
<location>project</location>
</skill>

<skill>
<name>axiom-lldb-ref</name>
<description>Complete LLDB command reference — variable inspection, breakpoints, threads, expression evaluation, process control, memory commands, and .lldbinit customization</description>
<location>project</location>
</skill>

<skill>
<name>axiom-localization</name>
<description>Use when localizing apps, using String Catalogs, generating type-safe symbols (Xcode 26+), handling plurals, RTL layouts, locale-aware formatting, or migrating from .strings files - comprehensive i18n patterns for Xcode 15-26</description>
<location>project</location>
</skill>

<skill>
<name>axiom-mapkit</name>
<description>Use when implementing maps, annotations, search, directions, or debugging MapKit display/performance issues - SwiftUI Map, MKMapView, MKLocalSearch, clustering, Look Around</description>
<location>project</location>
</skill>

<skill>
<name>axiom-mapkit-diag</name>
<description>MapKit troubleshooting — annotations not appearing, region jumping, clustering not working, search failures, overlay rendering issues, user location problems</description>
<location>project</location>
</skill>

<skill>
<name>axiom-mapkit-ref</name>
<description>MapKit API reference — SwiftUI Map, MKMapView, Marker, Annotation, MKLocalSearch, MKDirections, Look Around, MKMapSnapshotter, clustering, overlays, GeoToolbox PlaceDescriptor, geocoding</description>
<location>project</location>
</skill>

<skill>
<name>axiom-memory-debugging</name>
<description>Use when you see memory warnings, 'retain cycle', app crashes from memory pressure, or when asking 'why is my app using so much memory', 'how do I find memory leaks', 'my deinit is never called', 'Instruments shows memory growth', 'app crashes after 10 minutes' - systematic memory leak detection and fixes for iOS/macOS</description>
<location>project</location>
</skill>

<skill>
<name>axiom-metal-migration</name>
<description>Use when porting OpenGL/DirectX to Metal - translation layer vs native rewrite decisions, migration planning, anti-patterns</description>
<location>project</location>
</skill>

<skill>
<name>axiom-metal-migration-diag</name>
<description>Use when ANY Metal porting issue occurs - black screen, rendering artifacts, shader errors, wrong colors, performance regressions, GPU crashes</description>
<location>project</location>
</skill>

<skill>
<name>axiom-metal-migration-ref</name>
<description>Use when converting shaders or looking up API equivalents - GLSL to MSL, HLSL to MSL, GL/DirectX to Metal mappings, MTKView setup code</description>
<location>project</location>
</skill>

<skill>
<name>axiom-metrickit-ref</name>
<description>MetricKit API reference for field diagnostics - MXMetricPayload, MXDiagnosticPayload, MXCallStackTree parsing, crash and hang collection</description>
<location>project</location>
</skill>

<skill>
<name>axiom-modernize</name>
<description>Use when the user wants to modernize iOS code to iOS 17/18 patterns, migrate from ObservableObject to @Observable, update @StateObject to @State, or adopt modern SwiftUI APIs.</description>
<location>project</location>
</skill>

<skill>
<name>axiom-network-framework-ref</name>
<description>Reference — Comprehensive Network.framework guide covering NetworkConnection (iOS 26+), NWConnection (iOS 12-25), TLV framing, Coder protocol, NetworkListener, NetworkBrowser, Wi-Fi Aware discovery, and migration strategies</description>
<location>project</location>
</skill>

<skill>
<name>axiom-networking</name>
<description>Use when implementing Network.framework connections, debugging connection failures, migrating from sockets/URLSession streams, or adopting structured concurrency networking patterns - prevents deprecated API usage, reachability anti-patterns, and thread-safety violations with iOS 12-26+ APIs</description>
<location>project</location>
</skill>

<skill>
<name>axiom-networking-diag</name>
<description>Use when debugging connection timeouts, TLS handshake failures, data not arriving, connection drops, performance issues, or proxy/VPN interference - systematic Network.framework diagnostics with production crisis defense</description>
<location>project</location>
</skill>

<skill>
<name>axiom-networking-legacy</name>
<description>This skill should be used when working with NWConnection patterns for iOS 12-25, supporting apps that can't use async/await yet, or maintaining backward compatibility with completion handler networking.</description>
<location>project</location>
</skill>

<skill>
<name>axiom-networking-migration</name>
<description>Network framework migration guides. Use when migrating from BSD sockets to NWConnection, NWConnection to NetworkConnection (iOS 26+), or URLSession StreamTask to NetworkConnection.</description>
<location>project</location>
</skill>

<skill>
<name>axiom-now-playing</name>
<description>Use when Now Playing metadata doesn't appear on Lock Screen/Control Center, remote commands (play/pause/skip) don't respond, artwork is missing/wrong/flickering, or playback state is out of sync - provides systematic diagnosis, correct patterns, and professional push-back for audio/video apps on iOS 18+</description>
<location>project</location>
</skill>

<skill>
<name>axiom-now-playing-carplay</name>
<description>CarPlay Now Playing integration patterns. Use when implementing CarPlay audio controls, CPNowPlayingTemplate customization, or debugging CarPlay-specific issues.</description>
<location>project</location>
</skill>

<skill>
<name>axiom-now-playing-musickit</name>
<description>MusicKit Now Playing integration patterns. Use when playing Apple Music content with ApplicationMusicPlayer and understanding automatic vs manual Now Playing info updates.</description>
<location>project</location>
</skill>

<skill>
<name>axiom-objc-block-retain-cycles</name>
<description>Use when debugging memory leaks from blocks, blocks assigned to self or properties, network callbacks, or crashes from deallocated objects - systematic weak-strong pattern diagnosis with mandatory diagnostic rules</description>
<location>project</location>
</skill>

<skill>
<name>axiom-optimize-build</name>
<description>Use when the user mentions slow builds, build performance, or build time optimization.</description>
<location>project</location>
</skill>

<skill>
<name>axiom-ownership-conventions</name>
<description>Use when optimizing large value type performance, working with noncopyable types, reducing ARC traffic, or using InlineArray/Span for zero-copy memory access. Covers borrowing, consuming, inout modifiers, consume operator, ~Copyable types, InlineArray, Span, value generics.</description>
<location>project</location>
</skill>

<skill>
<name>axiom-passkeys</name>
<description>Use when implementing passkey sign-in, replacing passwords with WebAuthn, configuring ASAuthorizationController, setting up AutoFill-assisted requests, adding automatic passkey upgrades, or migrating from password-based authentication. Covers passkey creation, assertion, cross-device sign-in, credential managers, and the Passwords app.</description>
<location>project</location>
</skill>

<skill>
<name>axiom-performance-profiling</name>
<description>Use when app feels slow, memory grows over time, battery drains fast, or you want to profile proactively - decision trees to choose the right Instruments tool, deep workflows for Time Profiler/Allocations/Core Data, and pressure scenarios for misinterpreting results</description>
<location>project</location>
</skill>

<skill>
<name>axiom-photo-library</name>
<description>PHPicker, PhotosPicker, photo selection, limited library access, presentLimitedLibraryPicker, save to camera roll, PHPhotoLibrary, PHAssetCreationRequest, Transferable, PhotosPickerItem, photo permissions</description>
<location>project</location>
</skill>

<skill>
<name>axiom-photo-library-ref</name>
<description>Reference — PHPickerViewController, PHPickerConfiguration, PhotosPicker, PhotosPickerItem, Transferable, PHPhotoLibrary, PHAsset, PHAssetCreationRequest, PHFetchResult, PHAuthorizationStatus, limited library APIs</description>
<location>project</location>
</skill>

<skill>
<name>axiom-privacy-ux</name>
<description>Use when implementing privacy manifests, requesting permissions, App Tracking Transparency UX, or preparing Privacy Nutrition Labels - covers just-in-time permission requests, tracking domain management, and Required Reason APIs from WWDC 2023</description>
<location>project</location>
</skill>

<skill>
<name>axiom-profile-performance</name>
<description>Use when the user wants automated performance profiling, headless Instruments analysis, or CLI-based trace collection.</description>
<location>project</location>
</skill>

<skill>
<name>axiom-push-notifications</name>
<description>Use when implementing remote or local push notifications, requesting notification permission, managing APNs device tokens, adding notification actions/categories, building service extensions, or debugging push delivery failures. Covers APNs, FCM, Live Activity push transport, broadcast push, communication notifications, Focus interaction.</description>
<location>project</location>
</skill>

<skill>
<name>axiom-push-notifications-diag</name>
<description>Use when push notifications fail to arrive, token registration errors occur, notifications work in development but not production, silent push does not wake app, rich notification media is missing, or Live Activity stops updating via push. Covers APNs errors, environment mismatches, Focus mode filtering, service extension failures, FCM diagnostics.</description>
<location>project</location>
</skill>

<skill>
<name>axiom-push-notifications-ref</name>
<description>Use when needing APNs HTTP/2 transport details, JWT authentication setup, payload key reference, UNUserNotificationCenter API, notification category/action registration, service extension lifecycle, local notification triggers, Live Activity push headers, or broadcast push format. Covers complete push notification API surface.</description>
<location>project</location>
</skill>

<skill>
<name>axiom-realitykit</name>
<description>Use when building 3D content, AR experiences, or spatial computing with RealityKit. Covers ECS architecture, SwiftUI integration, RealityView, AR anchors, materials, physics, interaction, multiplayer, performance.</description>
<location>project</location>
</skill>

<skill>
<name>axiom-realitykit-diag</name>
<description>Use when RealityKit entities not visible, anchors not tracking, gestures not responding, performance drops, materials wrong, or multiplayer sync fails</description>
<location>project</location>
</skill>

<skill>
<name>axiom-realitykit-ref</name>
<description>RealityKit API reference — Entity, Component, System, RealityView, Model3D, anchor types, material system, physics, collision, animation, audio, accessibility</description>
<location>project</location>
</skill>

<skill>
<name>axiom-realm-migration-ref</name>
<description>Use when migrating from Realm to SwiftData - comprehensive migration guide covering pattern equivalents, threading model conversion, schema migration strategies, CloudKit sync transition, and real-world scenarios</description>
<location>project</location>
</skill>

<skill>
<name>axiom-resolve-spm</name>
<description>Use when the user mentions SPM resolution failures, "no such module" errors, duplicate symbol linker errors, version conflicts between packages, or Swift 6 package compatibility issues.</description>
<location>project</location>
</skill>

<skill>
<name>axiom-run-tests</name>
<description>Use when the user wants to run XCUITests, parse test results, view test failures, or export test attachments.</description>
<location>project</location>
</skill>

<skill>
<name>axiom-scan-security-privacy</name>
<description>Use when the user mentions security review, App Store submission prep, Privacy Manifest requirements, hardcoded credentials, or sensitive data storage.</description>
<location>project</location>
</skill>

<skill>
<name>axiom-scenekit</name>
<description>Use when working with SceneKit 3D scenes, migrating SceneKit to RealityKit, or maintaining legacy SceneKit code. Covers scene graph, materials, physics, animation, SwiftUI bridge, migration decision tree.</description>
<location>project</location>
</skill>

<skill>
<name>axiom-scenekit-ref</name>
<description>SceneKit → RealityKit concept mapping, complete API cross-reference for migration, scene graph API, materials, lighting, camera, physics, animation, constraints</description>
<location>project</location>
</skill>

<skill>
<name>axiom-sf-symbols</name>
<description>Use when implementing SF Symbols rendering modes, symbol effects, animations, custom symbols, or troubleshooting symbol appearance - covers the full symbol effects system from iOS 17 through SF Symbols 7 Draw animations in iOS 26</description>
<location>project</location>
</skill>

<skill>
<name>axiom-sf-symbols-ref</name>
<description>Use when you need complete SF Symbols API reference including every rendering mode, symbol effect, configuration option, UIKit equivalent, and platform availability - comprehensive code examples for iOS 17 through iOS 26</description>
<location>project</location>
</skill>

<skill>
<name>axiom-shazamkit</name>
<description>Use when implementing audio recognition, music identification, custom audio matching, second-screen sync, or working with Shazam catalog. Covers SHManagedSession (modern), SHSession (legacy), SHCustomCatalog, SHLibrary, microphone capture, signature generation, Shazam CLI.</description>
<location>project</location>
</skill>

<skill>
<name>axiom-shazamkit-ref</name>
<description>Use when needing ShazamKit API details — SHManagedSession, SHSession, SHCustomCatalog, SHSignatureGenerator, SHMediaItem, SHMatchedMediaItem, SHLibrary, SHMediaLibrary, SHSignature, SHMatch, SHError, SHSessionDelegate, and related types</description>
<location>project</location>
</skill>

<skill>
<name>axiom-shipping</name>
<description>Use when preparing ANY app for submission, handling App Store rejections, writing appeals, or managing App Store Connect. Covers submission checklists, rejection troubleshooting, metadata requirements, privacy manifests, age ratings, export compliance.</description>
<location>project</location>
</skill>

<skill>
<name>axiom-spritekit</name>
<description>Use when building SpriteKit games, implementing physics, actions, scene management, or debugging game performance. Covers scene graph, physics engine, actions system, game loop, rendering optimization.</description>
<location>project</location>
</skill>

<skill>
<name>axiom-spritekit-diag</name>
<description>Use when physics contacts don't fire, objects tunnel through walls, frame rate drops, touches don't register, memory spikes, coordinate confusion, or scene transition crashes</description>
<location>project</location>
</skill>

<skill>
<name>axiom-spritekit-ref</name>
<description>SpriteKit API reference — all node types, physics body creation, action catalog, texture atlases, constraints, scene setup, particles, SKRenderer</description>
<location>project</location>
</skill>

<skill>
<name>axiom-sqlitedata</name>
<description>Use when working with SQLiteData @Table models, CRUD operations, query patterns, CloudKit SyncEngine setup, or batch imports. Covers model definitions, @FetchAll/@FetchOne, upsert patterns, database setup with Dependencies.</description>
<location>project</location>
</skill>

<skill>
<name>axiom-sqlitedata-migration</name>
<description>Use when migrating from SwiftData to SQLiteData — decision guide, pattern equivalents, code examples, CloudKit sharing (SwiftData can't), performance benchmarks, gradual migration strategy</description>
<location>project</location>
</skill>

<skill>
<name>axiom-sqlitedata-ref</name>
<description>SQLiteData advanced patterns, @Selection column groups, single-table inheritance, recursive CTEs, database views, custom aggregates, TableAlias self-joins, JSON/string aggregation</description>
<location>project</location>
</skill>

<skill>
<name>axiom-storage</name>
<description>Use when asking 'where should I store this data', 'should I use SwiftData or files', 'CloudKit vs iCloud Drive', 'Documents vs Caches', 'local or cloud storage', 'how do I sync data', 'where do app files go' - comprehensive decision framework for all iOS storage options</description>
<location>project</location>
</skill>

<skill>
<name>axiom-storage-diag</name>
<description>Use when debugging 'files disappeared', 'data missing after restart', 'backup too large', 'can't save file', 'file not found', 'storage full error', 'file inaccessible when locked' - systematic local file storage diagnostics</description>
<location>project</location>
</skill>

<skill>
<name>axiom-storage-management-ref</name>
<description>Use when asking about 'purge files', 'storage pressure', 'disk space iOS', 'isExcludedFromBackup', 'URL resource values', 'volumeAvailableCapacity', 'low storage', 'file purging priority', 'cache management' - comprehensive reference for iOS storage management and URL resource value APIs</description>
<location>project</location>
</skill>

<skill>
<name>axiom-storekit-ref</name>
<description>Reference — Complete StoreKit 2 API guide covering Product, Transaction, AppTransaction, RenewalInfo, SubscriptionStatus, StoreKit Views, purchase options, server APIs, and all iOS 18.4 enhancements with WWDC 2025 code examples</description>
<location>project</location>
</skill>

<skill>
<name>axiom-swift-concurrency</name>
<description>Use when you see 'actor-isolated', 'Sendable', 'data race', '@MainActor' errors, or asking 'how do I use async/await', 'my app crashes with concurrency errors', 'how do I fix data races'. Covers Swift 6 concurrency, @concurrent, actors.</description>
<location>project</location>
</skill>

<skill>
<name>axiom-swift-concurrency-ref</name>
<description>Swift concurrency API reference — actors, Sendable, Task/TaskGroup, AsyncStream, continuations, isolation patterns, DispatchQueue-to-actor migration with gotcha tables</description>
<location>project</location>
</skill>

<skill>
<name>axiom-swift-modern</name>
<description>Use when reviewing or generating Swift code for modern idiom correctness — catches outdated APIs, pre-Swift 5.5 patterns, and Foundation legacy usage that Claude defaults to</description>
<location>project</location>
</skill>

<skill>
<name>axiom-swift-performance</name>
<description>Use when optimizing Swift code performance, reducing memory usage, improving runtime efficiency, dealing with COW, ARC overhead, generics specialization, or collection optimization</description>
<location>project</location>
</skill>

<skill>
<name>axiom-swift-testing</name>
<description>Use when writing unit tests, adopting Swift Testing framework, making tests run faster without simulator, architecting code for testability, testing async code reliably, or migrating from XCTest - covers @Test/@Suite macros, #expect/#require, parameterized tests, traits, tags, parallel execution, host-less testing</description>
<location>project</location>
</skill>

<skill>
<name>axiom-swiftdata</name>
<description>Use when working with SwiftData - @Model definitions, @Query in SwiftUI, @Relationship macros, ModelContext patterns, CloudKit integration, iOS 26+ features, and Swift 6 concurrency with @MainActor — Apple's native persistence framework</description>
<location>project</location>
</skill>

<skill>
<name>axiom-swiftdata-migration</name>
<description>Use when creating SwiftData custom schema migrations with VersionedSchema and SchemaMigrationPlan - property type changes, relationship preservation (one-to-many, many-to-many), the willMigrate/didMigrate limitation, two-stage migration patterns, and testing migrations on real devices</description>
<location>project</location>
</skill>

<skill>
<name>axiom-swiftdata-migration-diag</name>
<description>Use when SwiftData migrations crash, fail to preserve relationships, lose data, or work in simulator but fail on device - systematic diagnostics for schema version mismatches, relationship errors, and migration testing gaps</description>
<location>project</location>
</skill>

<skill>
<name>axiom-swiftui-26-ref</name>
<description>Use when implementing iOS 26 SwiftUI features - covers Liquid Glass design system, performance improvements, @Animatable macro, 3D spatial layout, scene bridging, WebView/WebPage, AttributedString rich text editing, drag and drop enhancements, and visionOS integration for iOS 26+</description>
<location>project</location>
</skill>

<skill>
<name>axiom-swiftui-animation-ref</name>
<description>Use when implementing SwiftUI animations, understanding VectorArithmetic, using @Animatable macro, zoom transitions, UIKit/AppKit animation bridging, choosing between spring and timing curve animations, or debugging animation behavior - comprehensive animation reference from iOS 13 through iOS 26</description>
<location>project</location>
</skill>

<skill>
<name>axiom-swiftui-architecture</name>
<description>Use when separating logic from SwiftUI views, choosing architecture patterns, refactoring view files, or asking 'where should this code go', 'how do I organize my SwiftUI app', 'MVVM vs TCA vs vanilla SwiftUI', 'how do I make SwiftUI testable' - comprehensive architecture patterns with refactoring workflows for iOS 26+</description>
<location>project</location>
</skill>

<skill>
<name>axiom-swiftui-containers-ref</name>
<description>Reference — SwiftUI stacks, grids, outlines, and scroll enhancements through iOS 26</description>
<location>project</location>
</skill>

<skill>
<name>axiom-swiftui-debugging</name>
<description>Use when debugging SwiftUI view updates, preview crashes, or layout issues - diagnostic decision trees to identify root causes quickly and avoid misdiagnosis under pressure</description>
<location>project</location>
</skill>

<skill>
<name>axiom-swiftui-debugging-diag</name>
<description>Use when SwiftUI view debugging requires systematic investigation - view updates not working after basic troubleshooting, intermittent UI issues, complex state dependencies, or when Self._printChanges() shows unexpected update patterns - systematic diagnostic workflows with Instruments integration</description>
<location>project</location>
</skill>

<skill>
<name>axiom-swiftui-gestures</name>
<description>Use when implementing SwiftUI gestures (tap, drag, long press, magnification, rotation), composing gestures, managing gesture state, or debugging gesture conflicts - comprehensive patterns for gesture recognition, composition, accessibility, and cross-platform support</description>
<location>project</location>
</skill>

<skill>
<name>axiom-swiftui-layout</name>
<description>Use when layouts need to adapt to different screen sizes, iPad multitasking, or iOS 26 free-form windows — decision trees for ViewThatFits vs AnyLayout vs onGeometryChange, size class limitations, and anti-patterns preventing device-based layout mistakes</description>
<location>project</location>
</skill>

<skill>
<name>axiom-swiftui-layout-ref</name>
<description>Reference — Complete SwiftUI adaptive layout API guide covering ViewThatFits, AnyLayout, Layout protocol, onGeometryChange, GeometryReader, size classes, and iOS 26 window APIs</description>
<location>project</location>
</skill>

<skill>
<name>axiom-swiftui-nav</name>
<description>Use when implementing navigation patterns, choosing between NavigationStack and NavigationSplitView, handling deep links, adopting coordinator patterns, or requesting code review of navigation implementation - prevents navigation state corruption, deep link failures, and state restoration bugs for iOS 18+</description>
<location>project</location>
</skill>

<skill>
<name>axiom-swiftui-nav-diag</name>
<description>Use when debugging navigation not responding, unexpected pops, deep links showing wrong screen, state lost on tab switch or background, crashes in navigationDestination, or any SwiftUI navigation failure - systematic diagnostics with production crisis defense</description>
<location>project</location>
</skill>

<skill>
<name>axiom-swiftui-nav-ref</name>
<description>Reference — Comprehensive SwiftUI navigation guide covering NavigationStack (iOS 16+), NavigationSplitView (iOS 16+), NavigationPath, deep linking, state restoration, Tab+Navigation integration (iOS 18+), Liquid Glass navigation (iOS 26+), and coordinator patterns</description>
<location>project</location>
</skill>

<skill>
<name>axiom-swiftui-performance</name>
<description>Use when UI is slow, scrolling lags, animations stutter, or when asking 'why is my SwiftUI view slow', 'how do I optimize List performance', 'my app drops frames', 'view body is called too often', 'List is laggy' - SwiftUI performance optimization with Instruments 26 and WWDC 2025 patterns</description>
<location>project</location>
</skill>

<skill>
<name>axiom-swiftui-search-ref</name>
<description>Use when implementing SwiftUI search — .searchable, isSearching, search suggestions, scopes, tokens, programmatic search control (iOS 15-18). For iOS 26 search refinements (bottom-aligned, minimized toolbar, search tab role), see swiftui-26-ref.</description>
<location>project</location>
</skill>

<skill>
<name>axiom-synchronization</name>
<description>Use when needing thread-safe primitives for performance-critical code. Covers Mutex (iOS 18+), OSAllocatedUnfairLock (iOS 16+), Atomic types, when to use locks vs actors, deadlock prevention with Swift Concurrency.</description>
<location>project</location>
</skill>

<skill>
<name>axiom-test-simulator</name>
<description>Use when the user mentions simulator testing, visual verification, push notification testing, location simulation, or screenshot capture.</description>
<location>project</location>
</skill>

<skill>
<name>axiom-testflight-triage</name>
<description>Use when ANY beta tester reports a crash, ANY crash appears in Organizer or App Store Connect, crash logs need symbolication, app was killed without crash report, or you need to triage TestFlight feedback</description>
<location>project</location>
</skill>

<skill>
<name>axiom-testing-async</name>
<description>Use when testing async code with Swift Testing. Covers confirmation for callbacks, @MainActor tests, async/await patterns, timeout control, XCTest migration, parallel test execution.</description>
<location>project</location>
</skill>

<skill>
<name>axiom-textkit-ref</name>
<description>TextKit 2 complete reference (architecture, migration, Writing Tools, SwiftUI TextEditor) through iOS 26</description>
<location>project</location>
</skill>

<skill>
<name>axiom-timer-patterns</name>
<description>Use when implementing timers, debugging timer crashes (EXC_BAD_INSTRUCTION), Timer stops during scrolling, or choosing between Timer/DispatchSourceTimer/Combine/async timer APIs</description>
<location>project</location>
</skill>

<skill>
<name>axiom-timer-patterns-ref</name>
<description>Timer, DispatchSourceTimer, Combine Timer.publish, AsyncTimerSequence, Task.sleep API reference with lifecycle diagrams, RunLoop modes, and platform availability</description>
<location>project</location>
</skill>

<skill>
<name>axiom-transferable-ref</name>
<description>Use when implementing drag and drop, copy/paste, ShareLink, or ANY content sharing between apps or views - covers Transferable protocol, TransferRepresentation types, UTType declarations, SwiftUI surfaces, and NSItemProvider bridging</description>
<location>project</location>
</skill>

<skill>
<name>axiom-tvos</name>
<description>Use when building ANY tvOS app - covers Focus Engine, Siri Remote input, storage constraints (no Document directory), no WebView, TVUIKit, TextField workarounds, AVPlayer tuning, Menu button state machines, and tvOS-specific gotchas that catch iOS developers</description>
<location>project</location>
</skill>

<skill>
<name>axiom-typography-ref</name>
<description>Apple platform typography reference (San Francisco fonts, text styles, Dynamic Type, tracking, leading, internationalization) through iOS 26</description>
<location>project</location>
</skill>

<skill>
<name>axiom-ui-recording</name>
<description>Use when setting up UI test recording in Xcode 26, enhancing recorded tests for stability, or configuring test plans for multi-configuration replay. Based on WWDC 2025-344 "Record, replay, and review".</description>
<location>project</location>
</skill>

<skill>
<name>axiom-ui-testing</name>
<description>Use when writing UI tests, recording interactions, tests have race conditions, timing dependencies, inconsistent pass/fail behavior, or XCTest UI tests are flaky - covers Recording UI Automation (WWDC 2025), condition-based waiting, network conditioning, multi-factor testing, crash debugging, and accessibility-first testing patterns</description>
<location>project</location>
</skill>

<skill>
<name>axiom-uikit-animation-debugging</name>
<description>Use when CAAnimation completion handler doesn't fire, spring physics look wrong on device, animation duration mismatches actual time, gesture + animation interaction causes jank, or timing differs between simulator and real hardware - systematic CAAnimation diagnosis with CATransaction patterns, frame rate awareness, and device-specific behavior</description>
<location>project</location>
</skill>

<skill>
<name>axiom-uikit-bridging</name>
<description>Use when wrapping UIKit views/controllers in SwiftUI, embedding SwiftUI in UIKit, or debugging UIKit-SwiftUI interop issues. Covers UIViewRepresentable, UIViewControllerRepresentable, UIHostingController, UIHostingConfiguration, coordinators, lifecycle, state binding, memory management.</description>
<location>project</location>
</skill>

<skill>
<name>axiom-using-axiom</name>
<description>Use when starting any iOS/Swift conversation - establishes how to find and use Axiom skills, requiring Skill tool invocation before ANY response including clarifying questions</description>
<location>project</location>
</skill>

<skill>
<name>axiom-ux-flow-audit</name>
<description>Use when auditing user journeys, checking for UX dead ends, dismiss traps, buried CTAs, missing empty/loading/error states, or broken data paths in iOS apps (SwiftUI and UIKit).</description>
<location>project</location>
</skill>

<skill>
<name>axiom-validate-screenshots</name>
<description>Use when the user mentions App Store screenshot validation, screenshot review, checking screenshots before submission, or verifying screenshot dimensions and content.</description>
<location>project</location>
</skill>

<skill>
<name>axiom-vision</name>
<description>subject segmentation, VNGenerateForegroundInstanceMaskRequest, isolate object from hand, VisionKit subject lifting, image foreground detection, instance masks, class-agnostic segmentation, VNRecognizeTextRequest, OCR, VNDetectBarcodesRequest, DataScannerViewController, document scanning, RecognizeDocumentsRequest</description>
<location>project</location>
</skill>

<skill>
<name>axiom-vision-diag</name>
<description>subject not detected, hand pose missing landmarks, low confidence observations, Vision performance, coordinate conversion, VisionKit errors, observation nil, text not recognized, barcode not detected, DataScannerViewController not working, document scan issues</description>
<location>project</location>
</skill>

<skill>
<name>axiom-vision-ref</name>
<description>Use when needing Vision framework API details for hand/body pose, segmentation, text recognition, barcode detection, document scanning, or Visual Intelligence integration. Covers VNRequest types, coordinate conversion, DataScannerViewController, RecognizeDocumentsRequest, SemanticContentDescriptor, IntentValueQuery.</description>
<location>project</location>
</skill>

<skill>
<name>axiom-xclog-ref</name>
<description>Use when capturing iOS simulator console output, diagnosing runtime crashes, viewing print/os_log output, or needing structured app logs for analysis. Reference for xclog CLI covering launch, attach, list modes with JSON output.</description>
<location>project</location>
</skill>

<skill>
<name>axiom-xcode-debugging</name>
<description>Use when encountering BUILD FAILED, test crashes, simulator hangs, stale builds, zombie xcodebuild processes, "Unable to boot simulator", "No such module" after SPM changes, or mysterious test failures despite no code changes - systematic environment-first diagnostics for iOS/macOS projects</description>
<location>project</location>
</skill>

<skill>
<name>axiom-xcode-mcp</name>
<description>Use when connecting to Xcode via MCP, using xcrun mcpbridge, or working with ANY Xcode MCP tool (XcodeRead, BuildProject, RunTests, RenderPreview). Covers setup, tool reference, workflow patterns, troubleshooting.</description>
<location>project</location>
</skill>

<skill>
<name>axiom-xcode-mcp-ref</name>
<description>Reference — all 20 Xcode MCP tools with parameters, return schemas, and examples</description>
<location>project</location>
</skill>

<skill>
<name>axiom-xcode-mcp-setup</name>
<description>Xcode MCP setup — enable mcpbridge, per-client config, permission handling, multi-Xcode targeting, troubleshooting</description>
<location>project</location>
</skill>

<skill>
<name>axiom-xcode-mcp-tools</name>
<description>Xcode MCP workflow patterns — BuildFix loop, TestFix loop, preview verification, window targeting, tool gotchas</description>
<location>project</location>
</skill>

<skill>
<name>axiom-xctest-automation</name>
<description>Use when writing, running, or debugging XCUITests. Covers element queries, waiting strategies, accessibility identifiers, test plans, and CI/CD test execution patterns.</description>
<location>project</location>
</skill>

<skill>
<name>axiom-xctrace-ref</name>
<description>Use when automating Instruments profiling, running headless performance analysis, or integrating profiling into CI/CD - comprehensive xctrace CLI reference with record/export patterns</description>
<location>project</location>
</skill>

</available_skills>
<!-- SKILLS_TABLE_END -->

</skills_system>
