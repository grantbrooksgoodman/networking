# Networking

A framework for integrating backend services into iOS apps through a unified, delegate-based interface. 

Networking extends the architecture provided by [AppSubsystem](https://github.com/grantbrooksgoodman/app-subsystem), adding authentication, database access, cloud storage, and hosted translation – all backed by Firebase.

---

## Table of Contents

- [Overview](#overview)
- [Requirements](#requirements)
- [Installation](#installation)
- [Getting Started](#getting-started)
  - [Understanding the Relationship to AppSubsystem](#understanding-the-relationship-to-appsubsystem)
  - [Initialization](#initialization)
  - [Accessing Services](#accessing-services)
  - [Environment Management](#environment-management)
- [Modules](#modules)
  - [Auth](#auth)
  - [Common](#common)
    - [Serializable](#serializable)
    - [RemotelyUpdatable](#remotelyupdatable)
    - [Macros](#macros)
  - [Database](#database)
  - [Gemini](#gemini)
  - [Health](#health)
  - [Storage](#storage)
  - [Translation](#translation)
- [Performance](#performance)
  - [Connection Prewarming](#connection-prewarming)
  - [Operation Coalescing](#operation-coalescing)
  - [Adaptive Caching](#adaptive-caching)
- [Delegate Customization](#delegate-customization)
- [Dependencies](#dependencies)

---

## Overview

Networking builds on the foundation provided by [AppSubsystem](https://github.com/grantbrooksgoodman/app-subsystem). Where AppSubsystem establishes the core architecture your app is built on – dependency injection, persistence, state management, reactive observation, and developer tools – Networking uses that architecture to deliver a complete backend services layer for iOS apps.

**Your app must initialize AppSubsystem before using Networking.** The two frameworks share a single dependency graph, a single persistence layer, and a single set of developer tools. Networking registers its services, cache domains, logger domains, and Developer Mode actions directly into the infrastructure that AppSubsystem provides. As a result, Networking is _not a standalone framework_ – it requires a [fully configured AppSubsystem environment](https://github.com/grantbrooksgoodman/app-subsystem#installation) to function.

Networking is organized around seven modules, each focused on a specific backend service:

- **Auth.** User authentication with anonymous sign-in and phone number verification, backed by Firebase Authentication.

- **Common.** Shared protocols, models, and extensions used across all modules – including cache strategies, environment management, serialization, and the network activity indicator.

- **Database.** Key-path-based reading, writing, querying, and real-time observation of structured data, backed by Firebase Realtime Database. Operations support configurable caching, timeouts, and environment-scoped paths.

- **Gemini.** AI-enhanced translation powered by the Gemini API, with configurable models, token limits, and contextual prompts.

- **Health.** Passive network quality estimation based on observed database and storage operations. Produces a continuous health score and tier classification without active probing.

- **Storage.** File upload, download, deletion, and directory listing for cloud-hosted assets, backed by Firebase Cloud Storage.

- **Translation.** Hosted translation of user-facing strings with local archiving, serializable references, and batch resolution for translated label strings.

All modules are compiled into a single `Networking` library. There are no separate import targets.

---

## Requirements

| Platform | Minimum Version |
| --- | --- |
| iOS | 18.0 |

---

## Installation

Networking is distributed as a Swift package. Add it to your project using [Swift Package Manager](https://docs.swift.org/swiftpm/documentation/packagemanagerdocs/).

> **Note:** Because Networking depends on AppSubsystem, adding Networking to your package manifest automatically resolves AppSubsystem as a transitive dependency. However, your app target must still import and initialize AppSubsystem directly – Networking does not perform this step on your behalf.

---

## Getting Started

### Understanding the Relationship to AppSubsystem

Networking relies on AppSubsystem for its core infrastructure. The table below summarizes what Networking uses from AppSubsystem and how:

| AppSubsystem Feature | How Networking Uses It |
|---|---|
| Dependency injection (`@Dependency`) | Exposes all networking services through the shared dependency graph. Your code accesses services using `@Dependency(\.networking)`. |
| Persistence (`@Persistent`) | Persists the active network environment and indicator state across launches using strongly typed storage keys. |
| Reactive observation (`Observable`) | Publishes network activity and network health state for cross-feature observation. |
| Logging (`Logger`, `LoggerDomain`) | Logs operations across database, storage, and translation modules using scoped logger domains. |
| Caching (`CacheDomain`) | Registers networking-specific cache domains that integrate with the system-wide cache clearing provided by AppSubsystem. |
| Developer tools (`DevModeService`) | Registers Developer Mode actions for switching environments and toggling the network activity indicator in pre-release builds. |
| Build information (`Build`) | Reads the current build milestone to determine whether developer-only UI and actions are available. |
| State management (`Reducer`) | Implements the network activity indicator using AppSubsystem's unidirectional data flow. |
| Forced update monitoring | Observes AppSubsystem's forced-update publisher to disable network operations when an update is required. |

Because of this deep integration, Networking **cannot** be used independently. Attempting to call `Networking.initialize()` without a prior call to `AppSubsystem.initialize(...)` results in undefined behavior. Attempting to access `Networking.config` before initialization results in a fatal error.

### Initialization

Initialize AppSubsystem first, then call `Networking.initialize()`. Both calls must occur at app launch, before your app accesses any networking services:

```swift
@main
class AppDelegate: UIResponder, UIApplicationDelegate {
    func application(
        _ application: UIApplication,
        didFinishLaunchingWithOptions launchOptions: [UIApplication.LaunchOptionsKey: Any]?
    ) -> Bool {
        AppSubsystem.initialize(...)
        Networking.initialize()

        return true
    }
}
```

`Networking.initialize()` performs five operations:

1. Configures Firebase App Check, using App Attest on physical devices and a debug provider in the simulator.
2. Configures the Firebase backend by calling `FirebaseApp.configure()`.
3. Registers Developer Mode actions into AppSubsystem's `DevModeService` for environment switching, network activity indicator toggling, and network health inspection.
4. Begins monitoring read/write enablement status through AppSubsystem's forced-update delegate system.
5. Starts the network health monitor, which passively observes operation performance to estimate connection quality.

> **Important:** `Networking.initialize()` must be called on the main actor. The `Networking.config` property is not available until initialization completes.

### Accessing Services

After initialization, use the `@Dependency` property wrapper to access networking services through [`NetworkServices`](Sources/Modules/Common/Models/Public/NetworkServices.swift). This property wrapper is provided by AppSubsystem's dependency injection system:

```swift
@Dependency(\.networking) var networking: NetworkServices

let values: [String: Any] = try await networking.database.getValues(
    at: "users/123"
)
```

Each property on [`NetworkServices`](Sources/Modules/Common/Models/Public/NetworkServices.swift) returns the currently registered delegate for that service – [`AuthDelegate`](Sources/Modules/Auth/Protocols/AuthDelegate.swift), [`DatabaseDelegate`](Sources/Modules/Database/Protocols/DatabaseDelegate.swift), [`NetworkHealthDelegate`](Sources/Modules/Health/Protocols/NetworkHealthDelegate.swift), [`HostedTranslationDelegate`](Sources/Modules/Translation/Protocols/HostedTranslationDelegate.swift), or [`StorageDelegate`](Sources/Modules/Storage/Protocols/StorageDelegate.swift).

### Environment Management

Networking supports three server environments – development, staging, and production – represented by the [`NetworkEnvironment`](Sources/Modules/Common/Models/Public/NetworkEnvironment.swift) enum. The active environment defaults to production and persists across launches using AppSubsystem's `@Persistent` property wrapper:

```swift
Networking.config.setEnvironment(.development)
```

Database and storage paths are automatically prefixed with the active environment by default, isolating data across environments without requiring changes to your path logic.

In pre-release builds with Developer Mode enabled, the environment can also be switched at runtime through the Developer Mode action menu provided by AppSubsystem.

---

## Modules

### Auth

The [`AuthDelegate`](Sources/Modules/Auth/Protocols/AuthDelegate.swift) protocol manages user authentication through two modes: anonymous sign-in and phone number verification.

#### Anonymous Sign-In

Call `signInAnonymously()` at launch to establish a lightweight session before the user completes phone verification. This session satisfies backend security rules that require authentication. If a session already exists – anonymous or phone-verified – the method returns its identifier without creating a new one:

```swift
@Dependency(\.networking.auth) var auth: AuthDelegate

let anonymousUserID = try await auth.signInAnonymously()
```

Firebase persists the session across launches, so subsequent calls on a returning user reuse the existing session rather than creating a new anonymous account.

#### Phone Verification

Phone authentication is a two-step flow. First, verify the phone number to receive a verification ID. Then, authenticate the user with the verification code they received. Both methods use typed throws – they return their result directly and throw an `Exception` on failure:

```swift
let verificationID = try await auth.verifyPhoneNumber(
    internationalNumber: "+15551234567",
    languageCode: "en"
)

let userID = try await auth.authenticateUser(
    authID: verificationID,
    verificationCode: "123456"
)
```

When the current session is anonymous, `authenticateUser(authID:verificationCode:)` links the phone credential to the anonymous session, preserving the existing user identifier. If the phone number is already associated with another account – for example, a returning user on a new device – the method falls back to a standard sign-in and returns the existing account's identifier instead.

#### Sign-Out

Call `signOut()` to end the current authentication session and clear the persisted credential. Subsequent backend requests are unauthenticated until a new session is established:

```swift
try auth.signOut()
```

### Common

The Common module provides shared infrastructure used across all other modules.

#### Models

| Type | Purpose |
|---|---|
| [`Assign`](Sources/Modules/Common/Models/Public/Assign.swift) | A key-path–value pair used to express a single property change inside a builder-based `update` call. |
| [`CacheStrategy`](Sources/Modules/Common/Models/Public/CacheStrategy.swift) | Controls how cached data is used during network operations. |
| [`DataSample`](Sources/Modules/Common/Models/Public/DataSample.swift) | A time-stamped snapshot of data with configurable expiration. |
| [`EnhancedTranslationStatusVerbosity`](Sources/Modules/Common/Models/Public/EnhancedTranslationStatusVerbosity.swift) | Controls the detail level of AI translation status messages. |
| [`NetworkEnvironment`](Sources/Modules/Common/Models/Public/NetworkEnvironment.swift) | Represents the active server environment (development, staging, or production). |
| [`NetworkPath`](Sources/Modules/Common/Models/Public/NetworkPath.swift) | A type-safe reference to a backend resource location. |
| [`NetworkServices`](Sources/Modules/Common/Models/Public/NetworkServices.swift) | An aggregate container providing access to all registered service delegates. |

#### Protocols

| Protocol | Purpose |
|---|---|
| [`NetworkActivityIndicatorDelegate`](Sources/Modules/Common/Protocols/NetworkActivityIndicatorDelegate.swift) | Customizes the appearance and behavior of the network activity indicator overlay. |
| [`Serializable`](Sources/Modules/Common/Protocols/SerializableProtocol.swift) | Defines a two-way encoding/decoding contract for types that are stored on the backend. |
| [`RemotelyUpdatable`](Sources/Modules/Common/Protocols/RemotelyUpdatableProtocol.swift) | Enables granular, key-based updates to individual properties of a remotely stored value. |
| [`Validatable`](Sources/Modules/Common/Protocols/ValidatableProtocol.swift) | Declares an `isWellFormed` property for types that can verify their own structural integrity. |

#### Serializable

The [`Serializable`](Sources/Modules/Common/Protocols/SerializableProtocol.swift) protocol defines how a type converts to and from a serialized representation suitable for network storage.

A conforming type declares one associated type – `Representation` – which specifies the serialized format (typically `[String: Any]` or `String`). It then provides three members:

| Requirement | Purpose |
|---|---|
| `encoded` | A computed property that returns the serialized representation of the instance. |
| `canDecode(from:)` | A static method that performs a lightweight structural check on a payload before decoding. |
| `init(from:)` | An initializer that reconstructs an instance from serialized data. May perform network requests. |

`init(from:)` uses typed throws – it throws an `Exception` directly rather than returning a result wrapper.

**Adopting Serializable**

The simplest approach uses the `@Serializable` and `@Serialized` macros to generate the conformance automatically. Annotate the type with `@Serializable` and mark each serialized property with `@Serialized`:

```swift
@Serializable
struct Document {
    @Serialized let content: String
    let identifier: String
    @Serialized let revision: Int

    init(
        content: String,
        revision: Int
    ) {
        self.content = content
        self.revision = revision
        identifier = UUID().uuidString
    }
}
```

The macro reads the initializer and generates a `SerializableKey` enum, `encoded`, `canDecode(from:)`, and `init(from:)`. Properties without `@Serialized` – like `identifier` above – are excluded from serialization entirely.

To use a key name that differs from the property name, pass it as a string argument:

```swift
@Serialized("fromAccount") let fromAccountID: String
```

The generated conformance uses `[String: Any]` as its `Representation` and supports properties whose types can be extracted from a dictionary using `as?` – typically `String`, `Int`, `Bool`, `Double`, and arrays or optionals thereof.

When a property's Swift type differs from its serialized representation, pass `encodedAs`, `encode`, and `decode` parameters to `@Serialized` to supply a custom transform:

```swift
@Serialized(
    encodedAs: String.self,
    encode: { DateFormatter.timestamp($0) },
    decode: { DateFormatter.date(from: $0) }
)
let lastSignedIn: Date
```

The `encode` closure converts from the property type to the serialized type, and the `decode` closure converts back, returning `nil` on failure. If `decode` returns `nil` for a non-optional property, the generated `init(from:)` throws; for optional properties, the property is set to `nil`. The `encodedAs` parameter tells the macro what type to expect when reading from the dictionary. Custom key names can be combined with transforms by passing both:

```swift
@Serialized(
    "signed_in",
    encodedAs: String.self,
    encode: { DateFormatter.timestamp($0) },
    decode: { DateFormatter.date(from: $0) }
)
let lastSignedIn: Date
```

For types that require dependency injection or nested `Serializable` decoding, write the conformance manually:

```swift
extension Activity: Serializable {
    enum SerializableKey: String {
        case action
        case date
        case userID
    }

    var encoded: [String: Any] {
        [
            SerializableKey.action.rawValue: action.rawValue,
            SerializableKey.date.rawValue: dateFormatter.string(from: date),
            SerializableKey.userID.rawValue: userID,
        ]
    }

    init(
        from data: [String: Any]
    ) async throws(Exception) { /* ... */ }

    static func canDecode(
        from data: [String: Any]
    ) -> Bool { /* ... */ }
}
```

Once a type conforms to `Serializable`, you can write it to the database through the `DatabaseDelegate`:

```swift
@Dependency(\.networking.database) var database: DatabaseDelegate

try await database.setValue(
    document.encoded,
    forKey: "documents/\(document.identifier)"
)
```

And reconstruct it from stored data:

```swift
let data: [String: Any] = try await database.getValues(
    at: "documents/\(document.identifier)"
)

let decoded = try await Document(from: data)
```

Types that only need serialization conform to `Serializable`. Types that also need to push changes to the server conform to `RemotelyUpdatable`, which refines `Serializable`.

#### RemotelyUpdatable

The [`RemotelyUpdatable`](Sources/Modules/Common/Protocols/RemotelyUpdatableProtocol.swift) protocol refines `Serializable` to support key-based property updates. Rather than re-encoding and writing an entire record, conforming types can update a single field using a key path:

```swift
let updated = try await document.update(\.revision, to: 1)
```

The compiler ensures that the value matches the property's type, so type mismatches are caught at build time rather than at runtime. Types that use the `@RemotelyUpdatable` and `@Updatable` macros receive this key-path mapping automatically. Like `init(from:)`, `update(_:to:)` uses typed throws – it returns the updated instance directly and throws an `Exception` on failure.

When multiple properties need to change together, pass a builder closure to `update(_:)` to apply them in a single atomic write:

```swift
let updated = try await document.update {
    Assign(\.content, to: "Updated content")
    Assign(\.revision, to: 2)
}
```

Each [`Assign`](Sources/Modules/Common/Models/Public/Assign.swift) pairs a typed key path with a new value, so the compiler rejects type mismatches at build time. The builder writes all changed fields in a single `updateChildValues` call and supports conditional assignments using `if` and `if`/`else`.

> **Note:** The builder-based `update(_:)` does not invoke the `willWrite` or `didWrite` lifecycle hooks. Only the single-property `update(_:to:)` method calls these hooks.

**Conformance Requirements**

`RemotelyUpdatable` builds on a type's existing `Serializable` conformance. The additional requirements are:

| Requirement | Purpose |
|---|---|
| `identifier` | The identifier string used to construct the full database key path. |
| `networkPath` | The base path for records of this type (for example, `"documents"`). The default lowercases the type name and appends `"s"`. |
| `modifyKey(_:withValue:)` | Returns a modified in-memory copy with the specified key set to the new value, or `nil` on type mismatch. |
| `serializableKey(for:)` | Maps a key path to its serialization key. Required for `update(_:to:)`. The default returns `nil`; `@RemotelyUpdatable` generates this automatically. |

The `SerializableKey` associated type is inferred from the signatures of your protocol requirement implementations – typically `modifyKey(_:withValue:)`. It must be `Hashable` and `RawRepresentable<String>`.

**Adopting RemotelyUpdatable**

The simplest approach combines `@Serializable` with `@RemotelyUpdatable` and `@Updatable`. Add `@RemotelyUpdatable` to the type and mark each updatable property with `@Updatable`:

```swift
@RemotelyUpdatable
@Serializable
struct Document {
    @Serialized let content: String
    let identifier: String
    @Serialized @Updatable let revision: Int

    init(
        content: String,
        revision: Int
    ) {
        self.content = content
        self.revision = revision
        identifier = UUID().uuidString
    }
}
```

`@Serializable` generates the serialization boilerplate. `@RemotelyUpdatable` generates `copying(paramName:)` methods, `modifyKey(_:withValue:)`, and `serializableKey(for:)`. The two macros are independent – if you wrote your `Serializable` conformance manually, apply `@RemotelyUpdatable` on its own.

Then declare the `RemotelyUpdatable` conformance. The `identifier` property is already declared on `Document`, so the compiler satisfies that requirement automatically. The default `networkPath` lowercases the type name and appends `"s"`, so `Document` produces `NetworkPath("documents")`.

If your model uses a different property name for its identifier (for example, `id`), provide a computed property:

```swift
extension Document: RemotelyUpdatable {
    var identifier: String { id }
}
```

When the backend path does not follow the naming convention, override `networkPath`:

```swift
extension Document: RemotelyUpdatable {
    var networkPath: NetworkPath { NetworkPath("docs") }
}
```

You can also declare reusable `NetworkPath` constants as static properties for direct database access. With a constant declared, the hard-coded path strings from earlier can use it as well:

```swift
let data: [String: Any] = try await database.getValues(
    at: "\(NetworkPath.documents.rawValue)/\(document.identifier)"
)
```

The default `update(_:to:)` implementation uses `identifier` and `networkPath` to construct the database key path automatically. For the example above, updating `\.revision` produces the path `"documents/<identifier>/revision"`.

**Lifecycle Hooks**

The default `update(_:to:)` implementation calls two hooks that conformers can override:

- `willWrite(_:forKey:updating:)` – Called before the database write. Return `.proceed` to use the standard encoding ladder, `.encoded(_:)` to write a pre-encoded value, or `.handled(_:)` if the conformer performed the write itself. Throw an `Exception` to abort.
- `didWrite(_:forKey:)` – Called after a successful write to perform side effects. The default implementation returns the updated instance unchanged.

Use `willWrite` when a property requires custom encoding that the standard ladder cannot perform. For example, converting a `Date` to a timestamp string before writing:

```swift
func willWrite(
    _ value: Any,
    forKey key: SerializableKey,
    updating updated: User
) async throws(Exception) -> WriteAction<User> {
    guard let date = value as? Date else { return .proceed }
    return .encoded(Date.timestampFromOptional(date: date))
}
```

#### Macros

| Macro | Purpose |
|---|---|
| [`@Serializable`](Sources/Modules/Common/Models/Public/Macros/SerializableMacro.swift) | Generates a complete `Serializable` conformance – `SerializableKey` enum, `encoded`, `canDecode(from:)`, and `init(from:)` – from `@Serialized` property markers. |
| [`@Serialized`](Sources/Modules/Common/Models/Public/Macros/SerializableMacro.swift) | Marks a stored property for inclusion in the generated `Serializable` conformance. Accepts an optional custom key name and optional encode/decode transforms. |
| [`@RemotelyUpdatable`](Sources/Modules/Common/Models/Public/Macros/RemotelyUpdatableMacro.swift) | Generates `copying(paramName:)` methods for each initializer parameter, and optionally `modifyKey(_:withValue:)` and `serializableKey(for:)` when `@Updatable` markers are present. |
| [`@Updatable`](Sources/Modules/Common/Models/Public/Macros/RemotelyUpdatableMacro.swift) | Marks a stored property as a remotely updatable serialization key. Generates no code on its own – serves as a marker for `@RemotelyUpdatable`. |

**`@Serializable`** reads the type's first initializer and generates a complete `Serializable` conformance from the `@Serialized` property markers. Each `@Serialized` property must have a corresponding initializer parameter with the same name. Properties without the annotation are excluded from serialization. The generated conformance uses `[String: Any]` as its `Representation` and supports types that can be extracted with `as?`. Properties that need custom encoding or decoding can supply transforms through `@Serialized(encodedAs:encode:decode:)` instead of writing the conformance manually. For types that need dependency injection or nested `Serializable` decoding, write the conformance manually.

**`@RemotelyUpdatable`** reads the type's first initializer to determine parameter names, labels, and types. If the type declares more than one initializer, the macro emits a warning and uses the first. It generates a `copying(paramName:)` method for each parameter, returning a new instance with that single property replaced and all others preserved:

```swift
let updated = document.copying(revision: 2)
```

When one or more properties are also annotated with `@Updatable`, the macro generates `modifyKey(_:withValue:)` and `serializableKey(for:)` as well, providing a complete `RemotelyUpdatable` conformance with no hand-written boilerplate. The generated `serializableKey(for:)` maps each updatable property's key path to its `SerializableKey` case, enabling the type-safe `update(_:to:)` API.

The generated signatures reference the serialization key enum by name. By default, the macro uses `SerializableKey`. If your enum has a different name, pass it to the `keyType` parameter:

```swift
@RemotelyUpdatable(keyType: "CodingKey")
```

> **Note:** The `keyType` is a string because the macro cannot see types declared in extensions or other files. When `@Updatable` markers are present, the macro emits a note if no enum with the specified name is found in the type's declaration body – this is informational, not an error, since the enum may be defined elsewhere.

**`@Updatable`** accepts an optional `nilIf` parameter that controls when the generated `modifyKey` implementation sets an optional property to `nil` on the local copy. This affects only the in-memory copy – it does not change what is written to the server.

| `nilIf` value | Behavior |
|---|---|
| `.isEmpty` | Sets the property to `nil` when the collection is empty. |
| `.isBangQualifiedEmpty` | Sets the property to `nil` when the array satisfies `isBangQualifiedEmpty`. |
| `.custom("expression")` | Sets the property to `nil` when the expression evaluates to `true`. Use `$0` for the incoming value. |

```swift
@Updatable(nilIf: .isBangQualifiedEmpty) let blockedUserIDs: [String]?
@Updatable(nilIf: .custom("$0 == Date(timeIntervalSince1970: 0)")) let lastSignedIn: Date?
```

> **Note:** The `.custom` case requires a string literal. The macro reads the expression from source at compile time, so passing a variable or computed property reference does not work.

#### Network Activity View Modifier

Apply the `indicatesNetworkActivity()` view modifier to any SwiftUI view to overlay a network activity indicator during long-running operations:

```swift
ContentView()
    .indicatesNetworkActivity()
```

### Database

The [`DatabaseDelegate`](Sources/Modules/Database/Protocols/DatabaseDelegate.swift) protocol provides key-path-based access to the backend database. Values can be read, written, queried, updated, and observed in real time. All operations use typed throws – they return their result directly (when applicable) and throw an `Exception` on failure:

```swift
@Dependency(\.networking.database) var database: DatabaseDelegate

// Read values at a path.
let values: [String: Any] = try await database.getValues(
    at: "users/123"
)

// Write a value.
try await database.setValue(
    "Jane",
    forKey: "users/123/name"
)

// Query children.
let messages: [String: Any] = try await database.queryValues(
    at: "messages",
    strategy: .last(25)
)
```

Specify the expected return type using a variable annotation so the compiler can determine `T`.

> **Important:** The type cast is performed at runtime. If the value stored at the path does not match the inferred type, the method throws a typecast exception. Ensure that the expected type matches the shape of your stored data.

#### Real-Time Observation

Use `observe(path:)` to receive a stream of values as they change at a given path. The method returns an `AsyncThrowingStream` that emits the current value immediately and again each time it changes on the server:

```swift
let task = Task {
    for try await user: [String: Any] in database.observe(
        path: "users/123"
    ) {
        print(user)
    }
}
```

The observer is automatically removed when the consuming task is cancelled or the iteration ends – no manual cleanup is required. To stop observing, cancel the task:

```swift
task.cancel()
```

Each observed value updates the in-memory cache used by `getValues(at:)`, keeping point-read results consistent with observed state.

#### Cache Strategy

Database read operations accept an optional [`CacheStrategy`](Sources/Modules/Common/Models/Public/CacheStrategy.swift) that controls how cached data is used:

| Case | Behavior |
|---|---|
| `.adaptive` | Resolves to a concrete cache strategy at runtime based on the current network health score. See [Adaptive Caching](#adaptive-caching). |
| `.returnCacheFirst` | Returns cached data immediately when available, without making a network request. |
| `.returnCacheOnFailure` | Fetches from the network first, and falls back to cached data only if the request fails. |
| `.disregardCache` | Ignores any cached data and always fetches from the network. |

#### Core Database Store

[`CoreDatabaseStore`](Sources/Modules/Database/Services/CoreDatabase.swift) manages the in-memory cache that backs the cache strategy system. Use it to inspect or clear cached data directly when needed.

#### Query Strategy

The [`QueryStrategy`](Sources/Modules/Database/Models/Public/QueryStrategy.swift) enum determines which subset of ordered results to return from a query – either the `.first(_:)` or `.last(_:)` entries, up to a specified count.

### Gemini

The Gemini module provides AI-enhanced translation powered by the Gemini API. To enable it, register a [`GeminiAPIKeyDelegate`](Sources/Modules/Gemini/Protocols/GeminiAPIKeyDelegate.swift) that supplies your API key:

```swift
Networking.config.registerGeminiAPIKeyDelegate(
    myGeminiKeyDelegate
)
```

Then pass an [`EnhancementConfiguration`](Sources/Modules/Gemini/Models/Public/EnhancementConfiguration.swift) when translating:

```swift
let translation = try await hostedTranslation.translate(
    .init("Hello"),
    with: LanguagePair(from: "en", to: "es"),
    enhance: EnhancementConfiguration(
        additionalContext: "Medical terminology"
    )
)
```

The [`GeminiModel`](Sources/Modules/Gemini/Models/Public/GeminiModel.swift) enum defines the available models for enhancement. The default is `flash25`.

### Health

The [`NetworkHealthDelegate`](Sources/Modules/Health/Protocols/NetworkHealthDelegate.swift) protocol provides a passive, continuously updated estimate of network quality. Rather than sending probe requests, the health system observes the latency and throughput of database and storage operations that your app already performs.

#### Reading Health

Access the current health value synchronously through the delegate:

```swift
@Dependency(\.networking.health) var health: NetworkHealthDelegate

let currentHealth = health.health
```

[`NetworkHealth`](Sources/Modules/Health/Models/Public/NetworkHealth.swift) is either `.measured(score:tier:)` or `.unknown`. A measured health carries a continuous score in the range [0.0, 1.0] and a discrete [`NetworkHealthTier`](Sources/Modules/Health/Models/Public/NetworkHealth.swift) of `.good`, `.fair`, or `.poor`. Health is `.unknown` until enough operations have been observed to produce a reliable estimate.

#### Observing Changes

For views that need to react to health changes, include `Observables.networkHealth` in your observer's `observedValues` and handle updates in `onChange(of:)`, following the standard AppSubsystem `Observer` pattern:

```swift
struct MyObserver: Observer {
    typealias R = MyReducer

    let observedValues: [any ObservableProtocol] = [Observables.networkHealth]
    let viewModel: ViewModel<MyReducer>

    func onChange(of observable: Observable<Any>) {
        switch observable {
        case Observables.networkHealth:
            guard let health = observable.value as? NetworkHealth else { return }
            send(.networkHealthChanged(health))
        default: ()
        }
    }
}
```

When you only need the current value — for example, to make a branching decision in a service — read it directly from the delegate without setting up an observer.

#### Configuration

Scoring parameters – including tier thresholds, channel weights, and the half-life of the exponentially weighted moving average – can be adjusted through [`NetworkHealthConfiguration`](Sources/Modules/Health/Models/Public/NetworkHealthConfiguration.swift):

```swift
var configuration = NetworkHealthConfiguration()
configuration.goodTierThreshold = 0.8
Networking.config.setNetworkHealthConfiguration(configuration)
```

The default configuration is suitable for most apps. Adjust individual parameters only when you have specific requirements for sensitivity or scoring behavior.

#### Instrumentation

Health estimation is built into the default Firebase-backed database and storage implementations. Database operations contribute latency samples; storage uploads and downloads contribute throughput samples. Cache hits, coalesced operations, and offline failures are automatically excluded.

> **Note:** Only the built-in Firebase implementations are instrumented. Custom delegates registered through `Networking.config` are not observed by the health system.

### Storage

The [`StorageDelegate`](Sources/Modules/Storage/Protocols/StorageDelegate.swift) protocol provides file-level access to hosted cloud storage. Upload, download, delete, and inspect files and directories. All operations use typed throws – they return their result directly (when applicable) and throw an `Exception` on failure:

```swift
@Dependency(\.networking.storage) var storage: StorageDelegate

// Upload data.
try await storage.upload(
    data,
    metadata: HostedItemMetadata("avatars/user123.png")
)

// Download an item to a local path.
try await storage.downloadItem(
    at: "avatars/user123.png",
    to: localFileURL
)

// List directory contents.
let directoryListing = try await storage.getDirectoryListing(
    at: "avatars"
)
```

#### Supporting Types

| Type | Purpose |
|---|---|
| [`DirectoryListing`](Sources/Modules/Storage/Models/Public/DirectoryListing.swift) | A snapshot of file paths and subdirectory names at a given storage path. |
| [`HostedItemMetadata`](Sources/Modules/Storage/Models/Public/HostedItemMetadata.swift) | Metadata for a file upload, including the destination path and optional HTTP headers. |
| [`HostedItemType`](Sources/Modules/Storage/Models/Public/HostedItemType.swift) | Identifies whether a storage item is a file or a directory. |

### Translation

The [`HostedTranslationDelegate`](Sources/Modules/Translation/Protocols/HostedTranslationDelegate.swift) protocol translates strings through the hosted translation service. All operations use typed throws – they return their result directly and throw an `Exception` on failure:

```swift
@Dependency(\.networking.hostedTranslation) var translator

let translation = try await translator.translate(
    .init("Hello"),
    with: LanguagePair(from: "en", to: "es")
)
```

Translations can be serialized for database storage using [`TranslationReference`](Sources/Modules/Translation/Models/Public/TranslationReference.swift), a compact codable form that can later be decoded back into a full translation – either from an inline value, the local archive, or the hosted archive.

Use [`TranslationValidator`](Sources/Modules/Translation/Models/Public/TranslationValidator.swift) to check that inputs and language pairs are well-formed before passing them to the translation service.

---

## Performance

### Connection Prewarming

On a cold start, the first database or storage operation may incur additional latency while the underlying connection to the backend is established. Both [`DatabaseDelegate`](Sources/Modules/Database/Protocols/DatabaseDelegate.swift) and [`StorageDelegate`](Sources/Modules/Storage/Protocols/StorageDelegate.swift) provide a `prewarm()` method that begins connection setup in the background:

```swift
@Dependency(\.networking) var networking: NetworkServices

networking.database.prewarm()
networking.storage.prewarm()
```

Both calls return immediately. Connection establishment proceeds in the background.

### Operation Coalescing

The default database and storage implementations automatically coalesce identical concurrent operations. When multiple callers perform the same operation at the same time, only a single network request is made and all callers receive the same result. Two operations are considered identical when they share the same parameters – including path, cache strategy, and – for write operations – payload.

This deduplication is transparent and requires no additional configuration.

### Adaptive Caching

The `.adaptive` cache strategy ties caching behavior to the current network health score. When the score falls below the configured threshold, `.adaptive` resolves to `.returnCacheFirst`, serving cached data immediately to avoid slow network round-trips. When the score is at or above the threshold, it resolves to `.returnCacheOnFailure`, preferring fresh data while still falling back to the cache on failure:

```swift
let values: [String: Any] = try await database.getValues(
    at: "users/123",
    cacheStrategy: .adaptive
)
```

The resolution threshold defaults to `0.3` and can be adjusted through [`NetworkHealthConfiguration`](Sources/Modules/Health/Models/Public/NetworkHealthConfiguration.swift). Resolution occurs at the point of operation dispatch, so two `.adaptive` operations dispatched at different times may resolve to different concrete strategies if the health score changes between them.

---

## Delegate Customization

Default behavior can be replaced by registering custom delegates on `Networking.config`. Sensible defaults are provided for every service. Override only what your app requires.

| Delegate | Purpose | Default |
|---|---|---|
| [`AuthDelegate`](Sources/Modules/Auth/Protocols/AuthDelegate.swift) | Anonymous sign-in and phone number authentication. | Firebase Authentication. |
| [`DatabaseDelegate`](Sources/Modules/Database/Protocols/DatabaseDelegate.swift) | Key-path-based data access. | Firebase Realtime Database. |
| [`StorageDelegate`](Sources/Modules/Storage/Protocols/StorageDelegate.swift) | Cloud file operations. | Firebase Cloud Storage. |
| [`GeminiAPIKeyDelegate`](Sources/Modules/Gemini/Protocols/GeminiAPIKeyDelegate.swift) | Gemini API key provider. | None (must be registered to use AI enhancement). |
| [`NetworkHealthDelegate`](Sources/Modules/Health/Protocols/NetworkHealthDelegate.swift) | Passive network quality estimation. | Built-in EWMA-based health estimator. |
| [`HostedTranslationDelegate`](Sources/Modules/Translation/Protocols/HostedTranslationDelegate.swift) | String translation. | Built-in hosted translation service. |
| [`NetworkActivityIndicatorDelegate`](Sources/Modules/Common/Protocols/NetworkActivityIndicatorDelegate.swift) | Activity indicator appearance. | Default activity indicator. |

Register delegates individually or in a single call:

```swift
Networking.config.register(
    databaseDelegate: myDatabaseDelegate,
    healthDelegate: myHealthDelegate,
    storageDelegate: myStorageDelegate
)

Networking.config.registerDatabaseDelegate(myDatabaseDelegate)
```

---

## Dependencies

Networking relies on three packages:

| Package | Role |
|---|---|
| [AppSubsystem](https://github.com/grantbrooksgoodman/app-subsystem) | Provides the architectural foundation that Networking builds on – including dependency injection, persistence, state management, logging, caching, reactive observation, and developer tools. AppSubsystem must be initialized before Networking. |
| [Firebase iOS SDK](https://github.com/firebase/firebase-ios-sdk) | Provides the default backend implementations for authentication (FirebaseAuth), real-time data (FirebaseDatabase), file storage (FirebaseStorage), and request attestation (FirebaseAppCheck). |
| [SwiftSyntax](https://github.com/swiftlang/swift-syntax) | Powers the `@Serializable`, `@Serialized`, `@RemotelyUpdatable`, and `@Updatable` macros. Used only at compile time by the macro plugin target and does not contribute to your app's binary size. |

AppSubsystem is a prerequisite – _not_ an optional companion. Networking extends AppSubsystem's type system by registering its own dependency keys, persistent storage keys, cache domains, logger domains, and Developer Mode actions. Without AppSubsystem, these registrations have no host system to attach to, and the framework cannot operate.

For information on setting up AppSubsystem in your app, see the [AppSubsystem documentation](https://github.com/grantbrooksgoodman/app-subsystem).

---

&copy; NEOTechnica Corporation. All rights reserved.
