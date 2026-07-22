# NetworkHealth — Refined Implementation Plan

**Target package:** `Networking` (github.com/grantbrooksgoodman/networking)
**Foundation:** `AppSubsystem` (github.com/grantbrooksgoodman/app-subsystem)
**Audience:** Claude Code, with full local access to this package and its resolved dependencies.

This document is a source-verified revision of the original NetworkHealth scaffold. Every claim about the Networking package below has been checked against the code; file/line references point at the exact seams to use. Claims about AppSubsystem internals that could not be confirmed from this repository are collected in §12 — verify them against the AppSubsystem checkout before coding, but do not treat them as open design questions; the fallback for each is specified.

This is a **clean-room implementation**. Do not source, reference, or reconstruct any external implementation of a similar concept.

---

## 1. Purpose

Add a passive network-quality estimation service to Networking. The service observes the byte transfers and operation round-trips the package already performs — it generates **no traffic of its own** — and maintains a continuously updated **health score in [0.0, 1.0]** describing the current usability of the network.

The flagship consumer is **adaptive cache behavior**: when health is poor, database reads opting in can automatically prefer cached data. Secondary consumers (timeout scaling, Gemini model selection) are out of scope but must not be precluded.

## 2. Non-Goals

- No active probing, speed-test endpoints, or synthetic requests.
- No URLSession/`URLSessionTaskMetrics` integration. Instrumentation happens at the operation boundaries this package controls (the Firebase-backed default implementations).
- No persistence of the score across launches. A fresh launch starts at `.unknown`.
- No new third-party dependencies.
- Translation/Gemini modules are **not** instrumented in this pass (they have their own retry machinery; their samples would double-count Database traffic they generate).

## 3. Verified Codebase Facts

These are confirmed against source; rely on them.

1. **Module layout** is `Sources/Modules/<Name>/` with `Protocols/`, `Services/`, `Models/Public/`, `Models/Internal/`, `Extensions/Public/`, `Extensions/Internal/`, `Dependencies/`, `Constants/` subdivisions (used as needed per module). Everything compiles into the single `Networking` library target (`Package.swift:36-49`); Swift 6 language mode is on.
2. **File headers** are exactly:
   ```
   //
   //  <FileName>.swift
   //
   //  Created by Grant Brooks Goodman.
   //  Copyright © NEOTechnica Corporation. All rights reserved.
   //
   ```
   followed by grouped imports under `/* Native */`, `/* Proprietary */`, `/* 3rd-party */` comments. Public symbols carry Apple-voice DocC comments (see `CacheStrategy.swift`, `DatabaseDelegate.swift` for tone and density).
3. **Config surface**: `Networking.Config` (`Sources/Networking.swift:148`) stores delegates in `@LockIsolated package private(set) var` properties, with one aggregate `register(...)` method (all-optional parameters, assertion if all nil) plus per-delegate `registerXDelegate(_:)` conveniences. `Config.shared`'s private init `fatalError`s unless `Networking.initialize()` ran first (`Networking.swift:211-215`) — this matters for testing (§9).
4. **Aggregate**: `NetworkServices` (`Sources/Modules/Common/Models/Public/NetworkServices.swift`) is a struct of `let` delegate properties with a public memberwise init; `NetworkServicesDependency.resolve` builds it from `Networking.config` (`Sources/Modules/Common/Dependencies/NetworkServicesDependency.swift:17-24`).
5. **Database funnel**: all four bulk operations (`getValues`, `queryValues`, `setValue`, `updateChildValues`) flow through `CoreDatabase.performOperation` → coalescer → `_performOperation` (`Sources/Modules/Database/Services/CoreDatabase.swift:400-513`). `increment` (`:241`) and `runTransaction` (`:518`) have their own paths, each with the same `Timeout` pattern.
6. **Timeouts are a distinct code path, not an error to classify.** Every timeout fires inside a `Timeout(after: duration) { ... }` closure that produces `Exception.timedOut` (`CoreDatabase.swift:458-462`, `:278-285`, `:555-562`; `CoreStorage.swift:124-128`). The underlying operation keeps running after a timeout fires; the once-only `OperationCompletion` / `didResume` guards swallow the late completion. **Instrument the timeout handler directly** — no `Exception`-matching taxonomy is needed to detect a timeout.
7. **Cache short-circuits** happen inside `CoreDatabase.getValues`/`queryValues` (`:621-624`, `:709-712`) *before* the network-only inner calls, and inside `CoreStorage.downloadItem` (`:406-411`) before `_downloadItem`. Instrumenting the inner calls therefore automatically excludes cache hits.
8. **Coalescing**: `KeyedCoalescer` dedupes identical concurrent operations above `_performOperation`. Instrumenting below it yields exactly one sample per real network round-trip, regardless of caller fan-in. Correct — keep the seam below the coalescer.
9. **Offline primitive exists**: `@Dependency(\.build.isOnline)` (AppSubsystem `Build`) is already the package's authority on connectivity — `CoreDatabase` (`:255`), `CoreStorage` (`:117`), and `Auth` (`:33`) all fail fast with `.internetConnectionOffline` when it is false. The health score's hard zero must key off this same primitive so the score agrees with the operations' own behavior.
10. **Default timeout is NOT configuration.** There is no runtime timeout setting anywhere. `.seconds(10)` is a hard-coded default parameter value repeated across the `DatabaseDelegate` and `StorageDelegate` protocol-extension convenience overloads (15 sites, e.g. `DatabaseDelegate.swift:400`). The original plan's instruction to "read the timeout from wherever the Database configuration defines it so the ramp tracks runtime timeout changes" is **not implementable as stated**. See §5.3 for the corrected anchoring.
11. **Observables pattern**: `extension Observables { static let isNetworkActivityOccurring = Observable<Bool>(false) }` (`Sources/Modules/Common/Extensions/Internal/Observables+CommonExtensions.swift`). Values are read/written via `.value` (`NetworkActivityIndicatorDelegate.swift:76`); observation uses AppSubsystem's `Observer` protocol (`observedValues` + `onChange(of:)`, see `NetworkActivityIndicatorObserver.swift`).
12. **Logger domains are declared, not registered.** `LoggerDomain.Networking.*` are plain `static let` constants (`Sources/Modules/Common/Extensions/Public/LoggerDomain+CommonExtensions.swift`). The original plan's "registered wherever Networking registers its other domains" is a misnomer — just add a constant. (Verify against AppSubsystem whether new domains must also be enabled anywhere; nothing in this repo suggests so.)
13. **Dev Mode pattern**: static `DevModeAction` factories in an internal `DevModeAction` extension (`Sources/Modules/Common/Extensions/Internal/DevModeAction+CommonExtensions.swift`) using AlertKit (`AKAlert`/`AKActionSheet`), inserted in `Networking.initialize()` via `DevModeService.insertAction(_:at:)` (`Networking.swift:117-118`).
14. **Shared-service precedent**: `HostedTranslationService.shared` is the local pattern for a stateful default delegate (`Config.hostedTranslationDelegate = HostedTranslationService.shared`). `Database()`/`Storage()` are stateless structs; the health service must follow the `.shared` pattern because it owns long-lived state.
15. **Storage byte counts are obtainable**: uploads have `data.count` at the seam (`CoreStorage.upload`, `:229`); downloads complete via `writeAsync(toFile:)` (`:529-545`), after which the local file can be stat'ed via the existing `@Dependency(\.fileManager)` (`:22`).
16. **There is no test target.** The package contains only `Sources/`; `Package.swift` declares no `.testTarget` and no test directory exists. The original plan's "follow the package's existing test structure and `TestSupport` conventions" has nothing to follow *in this package*. See §9.
17. **`AppException` catalog**: networking error identities are catalogued as 4-hex-digit `AppException` constants compared via `exception.isEqual(to:)` (`Sources/Modules/Common/Extensions/Public/AppException+CommonExtensions.swift`). `Exception.timedOut` and `.internetConnectionOffline` come from AppSubsystem; their `AppException` identities (if needed) live there.

## 4. Placement & Naming

- New module: `Sources/Modules/Health/` with:
  - `Protocols/NetworkHealthDelegate.swift`
  - `Services/NetworkHealthService.swift` (the default delegate; owns the actor)
  - `Models/Public/NetworkHealth.swift` (score/tier/unknown representation)
  - `Models/Public/NetworkHealthConfiguration.swift`
  - `Models/Internal/` — estimator state, sample types, channel math, classifier, cache-strategy resolver, path-monitor plumbing
  - `Extensions/Internal/Observables+HealthExtensions.swift`, `DevModeAction+HealthExtensions.swift`
  - `Extensions/Public/LoggerDomain+HealthExtensions.swift`
- Naming follows local convention: protocol `NetworkHealthDelegate`, service `NetworkHealthService`, aggregate property `health` → `@Dependency(\.networking.health)`.
- Mirror the file-header, import-grouping, access-control, and DocC conventions exactly (§3.2). Match the existing swiftlint/swiftformat inline-directive style where needed.

## 5. Core Design

### 5.1 Signals

Two independent channels feed the estimator:

1. **Throughput samples** — Storage module. Each completed upload/download yields `(byteCount, wallClockDuration)`.
   - Upload seam: around `putDataAsync` in `CoreStorage.upload` (`CoreStorage.swift:243-255`); `byteCount = data.count`.
   - Download seam: around the `writeAsync` call in `CoreStorage._downloadItem` (`:529-545`); `byteCount` = downloaded file size on disk (stat via `\.fileManager` after success). This sits below both the cache short-circuit in `downloadItem` and the coalescer — cache hits and deduped callers never produce samples.
   - **Do not** instrument `downloadAllItems`/`deleteAllItems`/listing/metadata operations for throughput — the per-item seams above already capture each real transfer, and metadata round-trips are not bandwidth.
   - **Storage timeouts feed nothing.** The storage `Timeout` wraps entire (possibly recursive, multi-item) operations, not a single transfer, so it is not evidence about any one round-trip. This is a deliberate deviation from a literal reading of the original plan.

2. **Latency samples** — Database module. Each read/write round-trip yields a wall-clock duration. Payloads are small; never treat these as throughput.
   - Success/failure seam: the network-only inner calls in `CoreDatabase` — `_getValues(at:)` (`:657-698`), the `query.getData()` section of `queryValues` (`:727-746`), `setValue` (`:786-795`), `updateChildValues` (`:827-836`), plus the Firebase completion blocks in `increment` (`:287-304`) and `runTransaction` (`:564-599`). All of these are below the cache short-circuits and the coalescer (§3.7, §3.8).
   - **Timeout seam (censored samples):** record directly inside the `Timeout(after:)` handlers at `_performOperation` (`:458-462`), `increment` (`:278-285`), and `runTransaction` (`:555-562`) — a latency observation folded in *at the timeout value* (true latency unknown, bounded below by it). This is the strongest single piece of negative evidence the channel receives, and because the censored sample is recorded at the operation's *actual* configured timeout, per-call timeout overrides are honored automatically.
   - **Once-only guard:** a timed-out operation keeps running and may complete later. Give each instrumented operation a small probe token (mirror `OperationCompletion`'s `@LockIsolated didComplete` pattern, `OperationCompletion.swift:14-45`) so exactly one of {success sample, censored timeout sample, discard} is recorded per operation. Do not record the late completion after a timeout has already been recorded.

**Failure classification** — centralize in one internal function (e.g. `HealthEvidence.classify(...)`) so it cannot drift across call sites:

| Outcome at the inner seam | Evidence |
|---|---|
| Success | Latency sample at elapsed wall-clock time. |
| "No value exists at the specified key path" (`AppException.Networking.Database.noValueExists`) | **Latency sample at elapsed time.** The server responded; the round-trip completed. Excluding it would be survivorship bias in reverse. |
| Timeout (the `Timeout` handler fired) | Censored latency sample at the timeout value. |
| `.internetConnectionOffline`, `.readWriteAccessDisabled` | No sample. These are thrown before any network work (`CoreDatabase.swift:445-455`) and say nothing about latency. Offline is handled by the hard-zero rule instead. |
| Encoding/validation failures (`invalidType`), permission/auth errors, cancellations, anything else | No sample. |
| Typecast failures | Never reach the seam — they are thrown in the `Database` wrapper *after* `performOperation` returns (`Database.swift:147-154`), by which point the success sample was already correctly recorded. No handling needed. |

Non-timeout transport failures (socket drops, etc.) default to **no sample** in this pass: the local `Exception` surface does not reliably distinguish them from server-side rejections. If, on inspection, AppSubsystem's `Exception` preserves the underlying `NSError` domain/code, you may extend the classifier to fold URLError-domain failures in as censored samples at elapsed time — but only inside the single classifier function, and note it in the summary.

**Instrumentation constraints:**
- Only the default (Firebase-backed) implementations are instrumented. Custom registered delegates are not; document this on the protocol.
- Recording must be fire-and-forget (a detached `Task` into the actor, or an actor-bound nonisolated method): it must never add latency, ordering constraints, or failure modes to the instrumented operation.
- **Trust gate:** discard throughput samples below `NetworkHealthConfiguration.minimumThroughputSampleBytes` (default 50 KB) — small transfers measure latency, not bandwidth. Latency samples need no size gate; cache-hit exclusion falls out of the seam placement.

### 5.2 Estimator

No fixed-count FIFO window. One **time-decayed, irregular-interval EWMA per channel**:

- Throughput channel: EWMA over `log2(bytesPerSecond)`; convert out of log-domain only when scoring.
- Latency channel: EWMA over round-trip seconds.
- On each new sample at time `t`: `w = 2^(-(t - tLast) / halfLife)`; `mean = (mean * weight * w + sample) / (weight * w + 1)`; `weight = weight * w + 1`; `tLast = t`. Decay is a function of elapsed wall-clock time (`halfLife` configurable, default 90 s), never sample count.
- The decayed `weight` doubles as the channel's **confidence**; when read (for scoring), apply the decay-to-now first so long idle periods degrade confidence without new samples.
- State per channel: mean, weight, last-update timestamp. No collections, no linked structures.

### 5.3 Score

`score` maps estimator state to [0.0, 1.0] continuously — no buckets:

- **Hard zero when offline**, sourced from the same primitive the operations use: `@Dependency(\.build.isOnline)` (§3.9). Do not add a second Bool source of truth for offline-ness.
- Otherwise blend the two channels: smooth monotone ramps (piecewise-linear is fine; logistic acceptable) from log-throughput → [0,1] and latency → [0,1], mixed by configurable channel weights. When one channel's confidence is negligible, the other carries the score (weight the blend by per-channel confidence).
- **Latency ramp anchoring (corrected from the original plan):** there is no timeout configuration to read (§3.10). Instead:
  1. Introduce one shared public constant as the single source of truth, e.g. `public extension Networking { static var defaultOperationTimeout: Duration { .seconds(10) } }`, and replace the 15 hard-coded `.seconds(10)` default-parameter literals in `DatabaseDelegate`/`StorageDelegate` extensions with it. (Default arguments of public functions must reference public symbols, hence `public`. Behavior is unchanged — this is a refactor, not a semantic change.)
  2. `NetworkHealthConfiguration.latencyCeiling` defaults to that constant: latency at/beyond it maps to ~0 for the channel; the upper anchor (`latencyFloor`, the latency mapping to ~1) is a configurable fraction of it (default 5% → 0.5 s).
  3. Per-call timeout overrides are already reflected through censored samples (§5.1), which is the honest channel for "what 'too slow' means right now."
- A small configurable multiplicative penalty (not a hard cap) when the current path `isConstrained` and/or `isExpensive` (from the path monitor, §5.5).
- All constants — half-life, ramp anchors, channel weights, penalties, trust-gate size, adaptive threshold, confidence threshold — live in one `Sendable`, `Codable`, `Equatable` struct `NetworkHealthConfiguration` with a `static let default`, settable at runtime via `Networking.config.setNetworkHealthConfiguration(_:)` (mirror `setEnhancedTranslationStatusVerbosity`'s style, backed by `LockIsolated`).

**Representation** (resolves original plan's deferred decision #4): a small public enum, matching the package's enum-heavy public model style:

```swift
public enum NetworkHealth: Equatable, Sendable {
    case unknown
    case measured(score: Double, tier: NetworkHealthTier)
}

public enum NetworkHealthTier: String, Equatable, Sendable {
    case poor, fair, good
}
```

The tier is always *derived from* the score against the active configuration's tier boundaries at publish time — a projection for consumers wanting discrete behavior, never independent state. Convenience accessors (`var score: Double?`, `var isUnknown: Bool`) are fine.

### 5.4 Invalidation & `.unknown`

- **Path change invalidates history.** On any interface transition (Wi-Fi ↔ cellular ↔ wired), reset both channels' confidence to zero. Correctness requirement, not an optimization.
- When aggregate confidence is below `NetworkHealthConfiguration.minimumConfidence` (fresh launch, post-transition, long idle), report `.unknown` — never a fabricated number. Consumers must be able to distinguish "network is bad" from "we don't know yet."
- Adaptive cache behavior treats `.unknown` as healthy (never degrade UX on ignorance).

### 5.5 Concurrency & lifecycle

- One `actor` owns all mutable estimator state. No second actor for a sample store.
- The actor maintains a `LockIsolated<NetworkHealth>` **snapshot** of the latest published value, updated whenever it recomputes. This gives the delegate's current-value property and the cache-strategy resolver cheap synchronous reads (both need sync access; the local API style is synchronous properties — see `Config`). The `Observables.networkHealth` observable is updated from the same recompute path.
- **Clock injection:** the estimator takes a `now` provider (default `{ Date.now }`; check AppSubsystem's dependency values for an existing date/clock dependency and prefer it if one exists) so decay math is deterministic under test.
- **Path monitor:** first check whether AppSubsystem's `Build.isOnline` implementation exposes an observable `NWPathMonitor`/path publisher you can reuse for transition events and `isConstrained`/`isExpensive`. If it only exposes the Bool, add an internal `NWPathMonitor` owned by the health service with explicit `start()`/`stop()` so non-shared instances (tests) don't leak monitors or queues. Tests use a stubbed path source either way.
- Recording is fire-and-forget into the actor; instrumented operations never await the estimator.
- Startup: wire into the existing `Networking.initialize()` flow (`Networking.swift:112-123`) — start the shared service's monitoring there (it's `@MainActor`, non-async; a `Task` hop is fine, matching the existing `Task.background` usage). No new app-facing call.

## 6. Public API Surface

Keep it lean:

- **`NetworkHealthDelegate`** (protocol, public):
  - `var health: NetworkHealth { get }` — synchronous current value.
  - Sample-recording requirements (`recordLatencySample(...)`, `recordThroughputSample(...)`, `recordTimeout(...)` — or a single `record(_ evidence:)` taking an internal-shaped-but-public evidence enum). *Deviation from the original plan's "resist making internals public," with rationale:* the instrumentation sites in `CoreDatabase`/`CoreStorage` report to the *registered* delegate; putting the recording surface on the protocol is what makes the delegate overridable/spy-able exactly like every other delegate in the customization table. Keep the EWMA math itself internal.
  - Lifecycle: `startMonitoring()` / `stopMonitoring()`.
- **Broadcast:** `extension Observables { public static let networkHealth = Observable<NetworkHealth>(.unknown) }` in the Health module's extensions — AppSubsystem's `Observable` is the canonical cross-feature broadcast mechanism; do not invent an AsyncStream multicast. (Note the existing `isNetworkActivityOccurring` is internal; this one must be public for consumers. If `Observable`'s API prevents public exposure for some reason, fall back to exposing it via a static on `Networking`.) An `AsyncSequence` accessor is optional, not required.
- **Aggregate:** add `public let health: NetworkHealthDelegate` to `NetworkServices`. To keep the existing public memberwise init source-compatible, keep the current 4-parameter init as an overload (its body defaults `health` from `Networking.config.healthDelegate` — bodies may reference package-level symbols; default *arguments* may not) and add a 5-parameter init. Update `NetworkServicesDependency.resolve` to pass `Networking.config.healthDelegate`.
- **Config:** `@LockIsolated package private(set) var healthDelegate: NetworkHealthDelegate = NetworkHealthService.shared`; add `healthDelegate:` to the aggregate `register(...)` (defaulted nil, added to the all-nil assertion list and the DocC method reference in the `Config` class comment) plus `registerHealthDelegate(_:)`; add `networkHealthConfiguration` + `setNetworkHealthConfiguration(_:)`.
- Everything else — estimator math, channel state, classifier, monitor plumbing, resolver — is `internal`.

## 7. Adaptive Cache Integration

Resolves the original plan's deferred decision #2: **add an enum case**, not a resolver type.

- Add `case adaptive` to `CacheStrategy` (`Sources/Modules/Common/Models/Public/CacheStrategy.swift`), with a `rawValue` of `"adaptive"` (the internal `rawValue` switch is the only exhaustive switch over this type in the package; `CacheStrategy` is input-only — no public API returns it — so client exhaustive switches are unlikely. Record this rationale in the summary. If you find a reason this is untenable, the fallback is a wrapper type, but the case is the local-style answer.)
- **Resolution point:** resolve `.adaptive` to a concrete strategy at the top of `CoreDatabase.performOperation` and `CoreStorage.performOperation`, *before* the coalescer key is computed and before `globalCacheStrategy` fallback is applied inside `_performOperation`. Compute `effective = globalCacheStrategy ?? perOperation`; if `effective == .adaptive`, replace it with the resolved concrete strategy and thread that concrete value through the coalescer key, the cache checks, and the operation. This keeps coalescing and caching operating exclusively on concrete strategies, while two calls under different health states correctly coalesce separately.
- **Resolution semantics**, centralized in one internal pure function (health snapshot + configuration in, concrete strategy out) so it is directly testable:
  - `.measured(score:_, ...)` with `score < adaptiveScoreThreshold` (config, default 0.3) → `.returnCacheFirst`
  - `.measured` at/above threshold → `.returnCacheOnFailure`
  - `.unknown` → `.returnCacheOnFailure`
- `setGlobalCacheStrategy(.adaptive)` works by the same resolution (it flows through the same `effective` computation).
- **Default behavior of the package is unchanged**: nothing resolves to `.adaptive` unless a caller passes it. Note the existing read default is already `.returnCacheFirst`; `.adaptive` serves callers who normally want fresh data but accept cache under bad network.

## 8. Ecosystem Integration

- **Logging:** add `public static let health = LoggerDomain("health")` to the `LoggerDomain.Networking` namespace (`LoggerDomain+CommonExtensions.swift` pattern — declaration only; there is no registration step). Log **tier transitions** (including to/from `.unknown`) — not every sample.
- **Developer Mode:** add a `DevModeAction` (internal extension, AlertKit presentation, matching `DevModeAction+CommonExtensions.swift`) surfacing current score, tier, per-channel means and confidences, and path flags. Insert it in `Networking.initialize()` via `DevModeService.insertAction(_:at: 2)` after the two existing insertions. Pre-release gating is inherent to `DevModeService`.
- **Initialization:** start the shared health service's monitoring inside `Networking.initialize()` (§5.5). No new app-facing call.

## 9. Testing

**Corrected from the original plan:** this package has **no test target and no tests** (§3.16). Therefore:

- Create `Tests/NetworkingTests/` and add a `.testTarget(name: "NetworkingTests", dependencies: ["Networking"], path: "Tests/NetworkingTests")` to `Package.swift`. Check whether AppSubsystem ships a `TestSupport` product and mirror its conventions if so; otherwise use Swift Testing (tools version 6.0 supports it) with plain, dependency-injected construction. The package's platforms already include macOS 13, so `swift test` is viable; if the Firebase dependency makes host-side testing intractable in practice, note it and keep the tests compiling for iOS test hosts.
- **Hard constraint discovered in source:** `Networking.config` `fatalError`s unless `Networking.initialize()` ran, and `initialize()` calls `FirebaseApp.configure()` — neither is viable in unit tests. Consequently every health type under test must be constructible **without touching `Networking.config` or Firebase**: the actor/service takes `(configurationProvider: @Sendable () -> NetworkHealthConfiguration, now: @Sendable () -> Date, pathSource: <stub-able abstraction>, isOnlineProvider: @Sendable () -> Bool)` at init, with production defaults that read `Networking.config` lazily *at use time*, never at type-construction time. Tests construct instances directly with stubs. The `CoreDatabase`/`CoreStorage` instrumentation seams themselves are exercised only via the estimator-facing recording API, not via Firebase.

Priority coverage, all deterministic via the injected clock and stubbed path source:

1. EWMA decay math: irregular intervals, half-life correctness, confidence decay during idle reads.
2. Trust gate: sub-threshold throughput samples ignored (cache-hit exclusion is structural — by seam placement — and is not unit-testable here; assert it in a code comment at the seam instead).
3. Timeout evidence: a censored sample at the timeout bound depresses the score; the once-only probe prevents double-recording (timeout then late success records exactly one sample); classifier excludes offline/read-write-disabled/validation failures; `noValueExists` counts as a normal latency sample; censored samples at non-default per-call timeouts are honored.
4. Path-transition reset → `.unknown` → recovery as samples arrive.
5. Offline → hard zero regardless of channel state; constrained/expensive penalties applied and bounded.
6. Score continuity and monotonicity: better inputs never lower the score; no discontinuities at ramp anchors.
7. Adaptive strategy resolution (the pure function): below/at/above threshold, and `.unknown` → `.returnCacheOnFailure`.
8. Concurrency: interleaved recording from many tasks yields a consistent final state (actor isolation makes this mostly a smoke test; still write it).
9. Tier derivation: tiers are a pure projection of score + config boundaries.

## 10. Documentation

- DocC comments on all public symbols, matching the package's Apple-style voice (§3.2).
- README: add **Health** to the module list in Overview and Table of Contents, a full module section (concept, accessing via `@Dependency(\.networking.health)`, observing via `Observables.networkHealth`, adaptive cache usage with `.adaptive`, configuration via `Networking.config.setNetworkHealthConfiguration`), a row in the Delegate Customization table (`NetworkHealthDelegate` | Passive network-quality estimation. | Built-in EWMA-based estimator.), and a mention of the `.adaptive` case in the existing Cache Strategy table.

## 11. Acceptance Checklist

- [ ] Builds under Swift 6 strict concurrency with zero new warnings.
- [ ] No public API removed; existing call sites compile unchanged (`NetworkServices` 4-arg init retained; `.seconds(10)` defaults refactored to the shared constant with identical value; no behavior change for existing `CacheStrategy` cases).
- [ ] Score is continuous; zero when `\.build.isOnline` is false; `.unknown` when confidence is insufficient.
- [ ] History resets on interface transition.
- [ ] Throughput channel ignores sub-gate transfers; latency channel structurally excludes cache hits and coalesced duplicates.
- [ ] Timeout handlers record censored samples exactly once per operation; late completions after timeout are not double-counted.
- [ ] Service reachable via `@Dependency(\.networking.health)`; overridable via `Networking.config.registerHealthDelegate(_:)`.
- [ ] Broadcast via `Observables.networkHealth`; `.adaptive` cache strategy works end to end through both funnels and `setGlobalCacheStrategy`.
- [ ] Dev Mode inspection action inserted; `LoggerDomain.Networking.health` declared; tier transitions logged.
- [ ] New test target added; §9 tests pass deterministically; README and DocC updated.

## 12. Verify Against AppSubsystem Before Coding

The implementer has AppSubsystem checked out locally; these could not be confirmed from the Networking repository alone. Each has a specified fallback — resolve, don't redesign:

1. **`Build.isOnline` backing**: if it wraps an observable `NWPathMonitor`/publisher, reuse it for path-transition events and `isConstrained`/`isExpensive`; else add an internal `NWPathMonitor` (§5.5).
2. **`Observable` public exposure**: confirm a `public static let` in an `Observables` extension works for external consumers; fallback in §6.
3. **Clock/date dependency**: if `DependencyValues` already has a date/now provider (alongside the confirmed `\.currentCalendar`), use it as the default `now`; else default to `{ Date.now }`.
4. **`Exception` underlying-error introspection**: only relevant if extending the classifier to transport failures (§5.1); default is not to.
5. **`TestSupport` product / test framework convention** (§9).
6. **`DevModeService.insertAction` index semantics** beyond the observed usage (insert at 2 after the two existing actions).

Document each resolution in the implementation summary you produce, alongside the deviations already called out: storage timeouts feed nothing (§5.1), `noValueExists` counts as success latency (§5.1), latency anchoring via shared constant instead of nonexistent timeout config (§5.3), recording surface on the delegate protocol (§6), enum case over resolver (§7), and the new test target (§9).
