# NetworkHealth Signal Expansion — Phased Implementation Plan

**Target package:** `Networking` (github.com/grantbrooksgoodman/networking)
**Baseline:** the implemented NetworkHealth module (`Sources/Modules/Health/`) and its instrumentation seams in `CoreDatabase`/`CoreStorage`. This plan extends that implementation; it does not restate it. All symbol names below are verified against the implemented source.
**Audience:** Claude Code, with full local access to the package source and all resolved dependencies.

This is a **clean-room implementation**. Do not source, reference, or reconstruct any external implementation of a similar concept.

---

## 1. Purpose

Broaden the evidence base of the health estimator beyond the two existing measurement channels (Database latency, Storage throughput). Seven additions, in descending value-per-effort order:

1. **Jitter** — a second-moment (variance) EWMA per channel; high dispersion penalizes the score even when the mean looks fine.
2. **Failure rate** — a smoothed success/failure ratio derived from evidence the seams already produce.
3. **Connection stability** — a passive observer on Firebase RTDB's `.info/connected` client state; socket flaps are evidence no per-operation sample can capture.
4. **Transfer progress & stall detection** — mid-flight throughput samples and "no progress" negative evidence from storage transfers, instead of learning only at completion.
5. **URLSession task metrics on existing Gemini traffic** — handshake-level timing (DNS, connect, TLS) from requests the package already sends.
6. **Radio access technology prior** — CoreTelephony's coarse RAT (EDGE vs LTE vs NR) as a score cap on legacy cellular, not a measurement.
7. **Active probing (opt-in, default off)** — demand-driven, rate-limited HEAD probes to fill the idle-confidence gap. This is the only item that generates traffic; it reverses the module's "no traffic of its own" contract and therefore requires explicit app opt-in.

## 2. Global Constraints

These apply to every phase.

- **No tests.** Do not create a test target, test files, or test instructions. The package contains only `Sources/`; keep it that way.
- **No new third-party dependencies.** `Network`, `CoreTelephony`, and `UIKit` are system frameworks and permitted.
- **No behavior change for existing callers.** Everything ships either always-on-and-passive (pure math, zero traffic), passive-with-a-side-effect (opt-out where noted), or opt-in (probing). Public API is additive only.
- **Platform guards.** `Package.swift` declares `.iOS(.v18)` **and** `.macOS(.v13)`. CoreTelephony and UIKit do not exist on macOS — wrap their use in `#if canImport(CoreTelephony)` / `#if canImport(UIKit)` and design the fallbacks to be no-ops.
- **Protocol evolution must be source-compatible.** `NetworkHealthDelegate` is public with custom-conformance support. New requirements are added via a *single* extensible entry point with a no-op default implementation (see §3), never as bare new requirements.
- **`Networking.config` access stays lazy** (read at use time inside method bodies; never during static/type construction — `Config.shared` fatal-errors before `Networking.initialize()`).
- **Recording stays fire-and-forget.** No instrumentation may add latency, ordering constraints, or failure modes to the operation it observes. Follow the existing pattern: synchronous seam → `Networking.config.healthDelegate.record…` → `Task` into the `HealthEstimator` actor.
- **Conventions:** exact file headers, `/* Native */ / /* Proprietary */ / /* 3rd-party */` import groups, Apple-voice DocC on all public symbols, `LockIsolated` for shared mutable state, strict-concurrency-clean under Swift 6 with zero new warnings.
- **Documentation per phase:** each phase updates the README Health section and DocC for whatever it adds, and extends `NetworkHealthService.debugSummary()` (the Dev Mode inspection surface) with its new state. Phase 8 consolidates.

## 3. Shared Groundwork (Phase 1)

Everything later phases need from the core types, done once.

**Files:** `Sources/Modules/Health/Models/Internal/HealthChannel.swift`, `Models/Public/NetworkHealthEvent.swift` (new), `Protocols/NetworkHealthDelegate.swift`, `Services/NetworkHealthService.swift`, `Models/Public/NetworkHealthConfiguration.swift`.

1. **Extend `HealthChannel` with a second moment.** Add `private(set) var secondMoment: Double = 0`, updated in `record(sample:at:halfLife:)` with the *same* decay factor as `mean` (`secondMoment = (secondMoment * decayedWeight + sample * sample) / (decayedWeight + 1)`), seeded to `sample * sample` on first record, cleared in `reset()`. Add computed helpers:
   - `var variance: Double { max(secondMoment - mean * mean, 0) }`
   - `var standardDeviation: Double { variance.squareRoot() }`
   The struct stays a value type; no collections.
2. **Add an extensible event entry point to the delegate protocol.** One new public enum and one new requirement *with a no-op default implementation* so existing custom conformances keep compiling:
   ```swift
   public enum NetworkHealthEvent: Sendable {
       case connectionFlap
       case connectionRestored(afterSeconds: TimeInterval)
       case handshake(seconds: TimeInterval)
       case probeFailure(timeoutSeconds: TimeInterval)
       case transferStall
   }

   // In NetworkHealthDelegate:
   func record(_ event: NetworkHealthEvent)

   public extension NetworkHealthDelegate {
       func record(_ event: NetworkHealthEvent) {}
   }
   ```
   Future signal types extend the enum (source-compatible for conformers because the requirement is defaulted; document that the enum may grow). `NetworkHealthService` implements it for real, forwarding into the estimator actor.
3. **New estimator channels** inside `HealthEstimator` (the private actor in `NetworkHealthService.swift`), both reusing `HealthChannel`:
   - `failureChannel` — samples are `1` (failure) or `0` (success); `mean` is the decayed failure fraction.
   - `flapChannel` — records `1` per flap event; its **decayed weight** (not mean) is the decayed flap count, which is the statistic used for scoring.
4. **Score composition.** Refactor `computeHealth` so the final score is the existing confidence-weighted blend of latency/throughput channel scores, multiplied by an ordered chain of bounded penalty factors, each clamped to `[0, 1]` before applying, final score clamped as today:
   ```
   score = blendedBase
         × (1 − failureRatePenalty)        // Phase 2
         × (1 − stabilityPenalty)          // Phase 3
         × constrainedPenalty (existing, if constrained)
         × expensivePenalty  (existing, if expensive)
   score = min(score, legacyRadioScoreCap) // Phase 6, cellular-legacy only
   ```
   Jitter (Phase 2) applies *inside* each channel's `channelScore`, not in this chain. Penalty channels never *create* a `.measured` state: confidence continues to come exclusively from the latency and throughput channels, so `.unknown` semantics are unchanged.
5. **Configuration additions** land per phase (each new stored property gets a defaulted `init` parameter, keeping the memberwise init source-compatible; `Codable`/`Equatable`/`Sendable` synthesis must keep working — nested config types conform explicitly).

**Acceptance:** builds clean; behavior identical to baseline (new channels exist but nothing feeds them yet; `record(_:)` defaults to no-op; `computeHealth` produces bit-identical scores when all new penalties are zero).

## 4. Phase 2 — Jitter & Failure Rate (pure math, zero new traffic)

**Files:** `NetworkHealthService.swift`, `NetworkHealthConfiguration.swift`. No seam changes at all.

1. **Failure channel feeding, derived inside the service** — the existing delegate calls already carry the needed information, so no instrumentation site changes:
   - `recordLatencySample(seconds:)` → also `failureChannel.record(sample: 0, …)`.
   - `recordCensoredLatencySample(seconds:)` → also `failureChannel.record(sample: 1, …)` (a timeout is the failure signal).
   - Later phases add `1`s via events (`probeFailure`, `transferStall`); flaps feed their own channel, not this one.
2. **Failure penalty:** `failureRatePenalty = failureRatePenaltyWeight × failureChannel.mean`, with the channel's decayed weight gating it: scale the penalty by `min(decayedWeight / 1.0, 1)` so a single stale failure can't dominate. New config: `failureRatePenaltyWeight` (default `0.5`).
3. **Jitter adjustment, per channel, inside `channelScore`:** compute a normalized dispersion per channel and shave the channel's score by it:
   - Latency channel: `dispersion = standardDeviation / max(mean, 0.001)` (coefficient of variation; the channel stores raw seconds).
   - Throughput channel: `dispersion = standardDeviation` directly (the channel stores log₂ units, which are already relative).
   - `channelScore *= (1 − jitterPenaltyWeight × min(dispersion / jitterCeiling, 1))` using the per-channel ceiling.
   - New config: `jitterPenaltyWeight` (default `0.3`), `latencyJitterCeiling` (default `1.0` — CV of 1 means σ equals the mean), `throughputJitterCeiling` (default `2.0` — σ of two doublings).
4. **Censored samples and jitter:** censored latency samples participate in the second moment exactly as they do in the mean — no special-casing.
5. Extend `debugSummary()` with per-channel dispersion and the failure fraction.

**Hazard to respect:** with few samples, variance estimates are noisy; the `min(…, 1)` clamp plus the weight-gated failure penalty are the guardrails — do not add warm-up special cases.

**Acceptance:** with `jitterPenaltyWeight = 0` and `failureRatePenaltyWeight = 0` the score is bit-identical to baseline; monotonicity holds (a lower-dispersion history never scores worse than a higher-dispersion one with the same means).

## 5. Phase 3 — Connection Stability (`.info/connected`)

The RTDB client's own realtime judgment of its websocket. Passive in the sense of generating no *requests* — but see the hazard below.

**Files:** new `Sources/Modules/Health/Services/ConnectionStabilityObserver.swift`; `NetworkHealthService.swift`; `NetworkHealthConfiguration.swift`; small hook in `CoreDatabase` or reuse of `@Dependency(\.firebaseDatabase)` (the dependency key lives in `Sources/Modules/Database/Dependencies/FirebaseDatabaseDependency.swift` and is internal to the package — usable from the Health module directly).

1. **Observer:** an internal final class owned by `NetworkHealthService`, holding `@Dependency(\.firebaseDatabase)`. On `start()`, attach `firebaseDatabase.child(".info/connected").observe(.value)`; track the previous Bool. Transitions:
   - `true → false` → candidate **flap** event.
   - `false → true` → `record(.connectionRestored(afterSeconds:))` with the measured gap — **logged only**, never fed to the latency channel (reconnect backoff pollutes it).
   On `stop()`, remove the observer handle (mirror the `removeObserver(withHandle:)` pattern in `CoreDatabase.observe`).
2. **Flap filtering — all three of these gates, in order:**
   - Ignore transitions while `@Dependency(\.build.isOnline)` is false: going offline is already the hard-zero path, not a flap.
   - Ignore transitions while the app is backgrounded, and within a grace period (config `flapForegroundGraceSeconds`, default `10`) after returning to foreground: RTDB deliberately drops its socket in the background; that is app lifecycle, not network evidence. Observe `UIApplication.didEnterBackgroundNotification` / `willEnterForegroundNotification` under `#if canImport(UIKit)`; on macOS the gate is a no-op.
   - Ignore the very first observed value (initial state, not a transition).
3. **Scoring:** surviving flaps → `record(.connectionFlap)` → `flapChannel.record(sample: 1, …)`. Penalty: `stabilityPenalty = stabilityPenaltyWeight × min(flapChannel.decayedWeight / stabilityFlapCeiling, 1)`. New config: `stabilityPenaltyWeight` (default `0.4`), `stabilityFlapCeiling` (default `3` — three flaps within one half-life saturates the penalty).
4. **Hazard — the observer itself keeps the RTDB websocket alive.** An active observer prevents the Firebase client from idling its connection; for an app that uses only Storage/Auth, this observer would *create* a persistent connection that otherwise wouldn't exist. Two mandatory mitigations:
   - **Lazy attach:** start the observer only after the first Database latency sample is recorded (evidence the app actually uses RTDB) — trigger from `recordLatencySample`/`recordCensoredLatencySample` via a `LockIsolated` once-flag, not from `startMonitoring()`.
   - **Opt-out:** new config flag `isConnectionStabilityMonitoringEnabled` (default `true`). When false, never attach.
   Document both in DocC and the README.
5. Wire `stop()` into `stopMonitoring()`. Extend `debugSummary()` with connected-state, decayed flap count, and last-reconnect duration.

**Acceptance:** no observer attaches in an app that performs no Database operations or sets the flag false; flaps during background are ignored; score degradation appears only after genuine foreground socket drops.

## 6. Phase 4 — Transfer Progress & Stall Detection

Learn about a 30 MB upload while it happens, not 10 seconds after it dies.

**Files:** new `Sources/Modules/Health/Models/Internal/TransferProgressProbe.swift`; `CoreStorage.swift` (the two existing throughput seams); `NetworkHealthConfiguration.swift`.

1. **Firebase APIs:** switch the two instrumented call sites to the progress-reporting overloads — `putDataAsync(_:metadata:onProgress:)` in `CoreStorage.upload` and `writeAsync(toFile:onProgress:)` in `CoreStorage._downloadItem`. Verify the exact overload signatures against the resolved FirebaseStorage checkout; if a given overload is missing in the pinned SDK version, fall back to the task-based API (`putData`/`write` returning `StorageUploadTask`/`StorageDownloadTask` with `.observe(.progress)`) for that call site only, keeping the async completion semantics identical.
2. **`TransferProgressProbe`** — one internal `final class … @unchecked Sendable` instance per transfer, `LockIsolated` state: last-progress timestamp, last byte count, segment accumulator, stall-reported flag. Behavior:
   - **Segment samples:** on each progress callback, accumulate `completedUnitCount` deltas; whenever the accumulated segment reaches `minimumThroughputSampleBytes` (reuse the existing gate — no new config), record a throughput sample for that segment (`bytes: segment, seconds: timeSinceSegmentStart`) and reset the segment accumulator.
   - **Completion:** on transfer success, record the final partial segment *only if* it meets the gate; then mark the probe finished.
   - **No double counting:** the existing whole-transfer `recordThroughputSample` calls at the two seams are **replaced** by the probe (the probe's segments now carry the signal). A transfer smaller than the gate produces exactly what it produces today: one completion-time attempt that the gate discards — preserve that by letting the probe fall back to a single whole-transfer sample when no segment was ever emitted and the total meets the gate.
   - **Stall watchdog:** the probe runs a lightweight repeating check (a `Task` loop sleeping `transferStallCheckInterval`, cancelled on completion — or reuse the package's `Timeout` type re-armed per progress event; pick whichever reads cleaner against the local `Timeout` API). If `now − lastProgress ≥ transferStallSeconds` while the transfer is active: emit `record(.transferStall)` **once per transfer** (flag-guarded), which feeds `failureChannel.record(sample: 1)`. New config: `transferStallSeconds` (default `8`), `transferStallCheckInterval` (default `2`).
   - The probe must hold no strong reference cycles (weak/unowned capture of nothing that outlives the transfer; the seam owns the probe for the transfer's duration) and must be fully inert after completion (watchdog cancelled).
3. **Interaction with the operation `Timeout`:** a stalled transfer will often also time out at the `performOperation` level, which records a censored latency… but storage timeouts deliberately feed nothing (baseline decision). The stall event is therefore the *only* negative evidence from a dying transfer — that is exactly its job. Do not additionally record censored latency for storage.
4. Extend `debugSummary()` with last transfer throughput and stall count.

**Acceptance:** large transfers produce multiple gated throughput samples over their lifetime; a transfer with progress frozen ≥ `transferStallSeconds` degrades the score before its timeout fires; small transfers behave exactly as baseline; no sample is recorded twice for the same bytes.

## 7. Phase 5 — URLSession Task Metrics on Gemini Traffic

Passive enrichment from HTTPS requests the package already sends. **Scope: Gemini only.** The Translation module's traffic flows through the external `Translator` package (opaque, multi-platform fallback and retry semantics that would pollute latency) — explicitly out of scope; note this in the summary.

**Files:** new `Sources/Modules/Health/Models/Internal/HealthTaskMetricsDelegate.swift`; `Sources/Modules/Gemini/Services/GeminiService.swift`; `NetworkHealthConfiguration.swift`.

1. **Seam:** `GeminiService.enhance` currently calls `urlSession.data(for: urlRequest)` via `@Dependency(\.urlSession)`. Use the **per-task delegate** overload — `urlSession.data(for: urlRequest, delegate: metricsDelegate)` — so the shared session dependency and all its behavior are untouched. `HealthTaskMetricsDelegate` is an internal `NSObject, URLSessionTaskDelegate` implementing `urlSession(_:task:didFinishCollecting:)`.
2. **What to record — and the critical exclusion:** Gemini round-trip time is dominated by **model inference**, not the network. Feeding total request duration into the latency channel would poison the estimate. From the last `URLSessionTaskTransactionMetrics` where `resourceFetchType == .networkLoad`:
   - **Handshake sample** — only when the connection was *not* reused (`isReusedConnection == false`): `(domainLookupEnd − domainLookupStart) + (connectEnd − connectStart)` (the connect interval includes TLS via `secureConnection*` inside it; compute defensively with nil-checks, skipping any component whose timestamps are nil). Emit `record(.handshake(seconds:))`; the service feeds it to the **latency channel** — a fresh TCP+TLS handshake is 2–3 RTTs, the same order as a light Database round-trip. Gate: skip absurd values (`> latencyCeiling`) only if the task also failed; otherwise record as-is (slow handshake on success is precisely the evidence we want).
   - **Throughput sample** — from `countOfResponseBodyBytesReceived` over `(responseEnd − responseStart)`, submitted through the normal `recordThroughputSample` path so the existing 50 KB gate applies (it will discard nearly all Gemini responses — correct; occasionally a long generation qualifies).
   - **Failures:** in the existing `catch` around `urlSession.data(for:)`, classify `URLError` codes `.timedOut`, `.networkConnectionLost`, `.cannotConnectToHost`, `.dnsLookupFailed` → `record(.probeFailure(timeoutSeconds:))` with the session's effective timeout (this event feeds `failureChannel` with a `1` and a censored latency at that bound; name reuse with Phase 7 is intentional — it is the same evidence shape). All other errors (HTTP status failures, decoding, cancellation) → nothing.
   - **Nothing else.** No total-duration sample, ever, from Gemini.
3. **Config:** `isURLSessionMetricsEnabled` (default `true` — passive, no new traffic; opt-out for apps that want the estimator fed exclusively by Firebase traffic).
4. The delegate must be allocation-cheap (one instance per request is fine) and must never throw or block; metrics collection failures degrade to silence.

**Acceptance:** Gemini requests on cold connections contribute handshake latency samples; reused-connection requests contribute nothing to latency; total inference time never enters any channel; disabling the flag restores baseline behavior exactly.

## 8. Phase 6 — Radio Access Technology Prior

A coarse system-supplied prior, not a measurement. iOS only.

**Files:** `Sources/Modules/Health/Models/Internal/PathState.swift`; new `Sources/Modules/Health/Models/Internal/RadioTechnology.swift`; `NetworkHealthService.swift`; `NetworkHealthConfiguration.swift`.

1. **Classification:** under `#if canImport(CoreTelephony)`, read `CTTelephonyNetworkInfo().serviceCurrentRadioAccessTechnology` (a `[String: String]` keyed by service identifier; any value counts — take the "best" across services). Map into an internal enum:
   - `legacy` — `CTRadioAccessTechnologyGPRS`, `Edge`, `CDMA1x`
   - `intermediate` — `WCDMA`, `HSDPA`, `HSUPA`, `CDMAEVDORev0/A/B`, `eHRPD`
   - `modern` — `LTE`, `NRNSA`, `NR`
   - `unknown` — nil/empty/unrecognized (future RAT strings must land here, not crash)
   On non-CoreTelephony platforms the type still compiles and always reports `unknown`.
2. **State:** add `radioTechnology` to `PathState` (default `.unknown`). Refresh it (a) inside `handlePathUpdate`, and (b) on `CTServiceRadioAccessTechnologyDidChangeNotification` (observer registered in `startMonitoring()`, removed in `stopMonitoring()`, `#if`-guarded).
3. **Effect — a cap, never a boost:** applied in `computeHealth` *only when* `pathState.interfaceType == .cellular`:
   - `legacy` → `score = min(score, legacyRadioScoreCap)` (new config, default `0.4`)
   - `intermediate` → `score = min(score, intermediateRadioScoreCap)` (new config, default `0.75`)
   - `modern` / `unknown` → no effect. A phone can have excellent 3G and terrible 5G; measurements always speak first, the prior only stops a starved estimator from calling EDGE "good."
   - The cap does **not** affect confidence or the `.unknown` state.
4. **Config:** `isRadioTechnologyPriorEnabled` (default `true`), plus the two caps.
5. Extend `debugSummary()` with the current RAT classification.

**Acceptance:** compiles for macOS (prior inert); on Wi-Fi the caps never apply; on legacy cellular a fully warmed-up estimator cannot report above the cap; disabling the flag restores baseline scoring.

## 9. Phase 7 — Active Probing (Opt-In)

The only phase that generates traffic. Philosophy: a probe exists to cure the idle-confidence gap — the situation where a consumer wants a decision and the estimator has decayed to `.unknown`. It fires **on demand, never on a timer.**

**Files:** new `Sources/Modules/Health/Services/NetworkHealthProber.swift`; new `Sources/Modules/Health/Models/Public/NetworkHealthProbeConfiguration.swift`; `NetworkHealthService.swift`; `NetworkHealthConfiguration.swift`; `Networking.swift` (DocC only).

1. **Opt-in shape:** a nested optional in the main configuration — `probeConfiguration: NetworkHealthProbeConfiguration?`, default `nil` = disabled. There is no boolean that enables probing against a built-in endpoint: **enabling requires supplying a URL**, which forces the operator to choose an endpoint they control. The struct (public, `Codable`, `Equatable`, `Sendable`, defaulted memberwise init):
   - `url: URL` — required, no default. Document that it should be an operator-controlled endpoint returning a small response (an empty 200/204); a `HEAD` against the app's own backend host doubles as connection prewarming.
   - `httpMethod: String = "HEAD"`
   - `timeoutSeconds: TimeInterval = 5`
   - `minimumIntervalSeconds: TimeInterval = 60` — floor between any two probes.
   - `maximumProbesPerHour: Int = 10` — hard budget, sliding window may be approximated by a decayed counter.
   - `allowsConstrainedPaths: Bool = false`, `allowsExpensivePaths: Bool = false`
2. **Trigger points** (both funnel into one `maybeProbe()` on the prober; both are fire-and-forget):
   - The `health` computed property on `NetworkHealthService`: when the value being returned is `.unknown` and probing is configured, kick `maybeProbe()` *after* returning (a `Task`; the read itself stays synchronous and non-blocking).
   - `handlePathUpdate` after an interface-transition reset: one debounced `maybeProbe()` (delay ~2 s to let the path settle).
3. **Guard chain, in order, all must pass** (each is cheap; bail silently): configuration present → `\.build.isOnline` → not backgrounded (`#if canImport(UIKit)` gate as Phase 3) → path not constrained/expensive unless allowed → `ProcessInfo.processInfo.isLowPowerModeEnabled == false` → rate limits (`minimumIntervalSeconds` since last attempt, budget remaining) → no probe currently in flight (`LockIsolated` flag).
4. **Execution:** build the `URLRequest` (method, `timeoutInterval = timeoutSeconds`, no body, no identifying headers beyond defaults), send via `@Dependency(\.urlSession)` with the Phase 5 per-task metrics delegate. Outcomes:
   - Success → full round-trip duration to the **latency channel** via `recordLatencySample` (a HEAD has no inference-time confound — total duration is honest here), plus the Phase 5 handshake/throughput extraction for free.
   - `URLError` in the network family (same code list as Phase 5) → `record(.probeFailure(timeoutSeconds:))` (failure `1` + censored latency at the probe timeout).
   - Any other failure (unexpected status codes are fine for HEAD; treat non-2xx/3xx as success *for network purposes* — the server answered) → latency sample from duration.
   - Every attempt, success or failure, resets the rate-limit clock and decrements the budget.
5. **Logging:** every probe attempt and outcome logs at `LoggerDomain.Networking.health` — probes are the one thing users of the package will want visible in a session log. Extend `debugSummary()` with probe stats (last probe time, outcome, remaining budget) and a clear "probing: disabled" line when unconfigured.
6. **Never**: probe on a timer, probe while `.measured` with adequate confidence, probe in the background, retry a failed probe before the minimum interval, or follow redirects to third-party hosts (set the request's `timeoutInterval` and rely on default redirect handling only for same-host; if the metrics show a cross-host redirect, record nothing and log).

**Acceptance:** with `probeConfiguration == nil` (the default) the package's network behavior is byte-for-byte identical to baseline — zero probes under any circumstances. When configured: a `.unknown` read while idle produces at most one probe per minimum interval; probes stop the moment confidence recovers; Low Power Mode and constrained paths suppress probing; the budget is never exceeded.

## 10. Phase 8 — Consolidation

1. **README:** rewrite the Health module section to present the full signal inventory in three groups — measurements (latency, throughput, handshake, progress segments), derived statistics (jitter, failure rate, stability), and priors/policies (path penalties, RAT caps, offline hard-zero) — plus a dedicated, clearly-flagged subsection for opt-in active probing (what it sends, when, and how to enable it), and the two documented opt-outs (`isConnectionStabilityMonitoringEnabled`, `isURLSessionMetricsEnabled`). Update the configuration table with every new field and default.
2. **DocC pass** over all new public symbols (`NetworkHealthEvent`, `NetworkHealthProbeConfiguration`, all new configuration properties) for voice consistency with the existing module.
3. **Dev Mode:** verify `debugSummary()` renders every signal added across phases in a readable multi-line layout (it is presented in an `AKAlert`; keep lines short).
4. **Final sweep:** confirm the acceptance line of every phase still holds after integration — in particular that all default-configuration behavior deltas versus baseline are limited to: new penalties active (jitter/failure/stability), progress-segment throughput samples, Gemini handshake samples, RAT caps on legacy cellular, and the lazily attached `.info/connected` observer for RTDB-using apps. Anything else observable is a defect.

## 11. Decisions Deferred to You

Resolve against local source; document each choice in your summary:

1. Exact FirebaseStorage progress API shape available in the pinned SDK (`onProgress` overloads vs task-observer fallback) — Phase 4.
2. `Timeout` reuse vs a `Task`-loop for the stall watchdog — Phase 4.
3. Whether `URLSessionTaskTransactionMetrics.isReusedConnection` and the timestamp fields behave as expected through the AppSubsystem-provided `\.urlSession` (verify it is a plain foreground session; if it has a custom delegate wired at session level, confirm per-task delegates still receive `didFinishCollecting`) — Phase 5.
4. The best-across-services reduction for multi-SIM RAT dictionaries — Phase 6.
5. Approximation strategy for the probe budget (sliding window vs decayed counter) — Phase 7.
