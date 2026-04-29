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
  - [Database](#database)
  - [Gemini](#gemini)
  - [Storage](#storage)
  - [Translation](#translation)
- [Delegate Customization](#delegate-customization)
- [Dependencies](#dependencies)

---

## Overview

Networking builds on the foundation provided by [AppSubsystem](https://github.com/grantbrooksgoodman/app-subsystem). Where AppSubsystem establishes the core architecture your app is built on – dependency injection, persistence, state management, reactive observation, and developer tools – Networking uses that architecture to deliver a complete backend services layer for iOS apps.

**Your app must initialize AppSubsystem before using Networking.** The two frameworks share a single dependency graph, a single persistence layer, and a single set of developer tools. Networking registers its services, cache domains, logger domains, and Developer Mode actions directly into the infrastructure that AppSubsystem provides. As a result, Networking is _not a standalone framework_ – it requires a fully configured AppSubsystem environment to function.

Networking is organized around six modules, each focused on a specific backend service:

- **Auth.** Phone number authentication with SMS verification, backed by Firebase Authentication.

- **Common.** Shared protocols, models, and extensions used across all modules – including cache strategies, environment management, serialization, and the network activity indicator.

- **Database.** Key-path-based reading, writing, and querying of structured data, backed by Firebase Realtime Database. Operations support configurable caching, timeouts, and environment-scoped paths.

- **Gemini.** AI-enhanced translation powered by the Gemini API, with configurable models, token limits, and contextual prompts.

- **Storage.** File upload, download, deletion, and directory listing for cloud-hosted assets, backed by Firebase Cloud Storage.

- **Translation.** Hosted translation of user-facing strings with local archiving, serializable references, and batch resolution for translated label strings.

All modules are compiled into a single `Networking` library. There are no separate import targets.

---

## Requirements

| Platform | Minimum Version |
| --- | --- |
| iOS | 17.0 |

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
| Reactive observation (`Observable`) | Publishes network activity state for cross-feature observation. |
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

`Networking.initialize()` performs three operations:

1. Configures the Firebase backend by calling `FirebaseApp.configure()`.
2. Registers Developer Mode actions into AppSubsystem's `DevModeService` for environment switching and network activity indicator toggling.
3. Begins monitoring read/write enablement status through AppSubsystem's forced-update delegate system.

> **Important:** `Networking.initialize()` must be called on the main actor. The `Networking.config` property is not available until initialization completes.

### Accessing Services

After initialization, use the `@Dependency` property wrapper to access networking services through [`NetworkServices`](Sources/Modules/Common/Models/Public/NetworkServices.swift). This property wrapper is provided by AppSubsystem's dependency injection system:

```swift
@Dependency(\.networking) var networking: NetworkServices

let getValuesResult = await networking.database.getValues(
    at: "users/123"
)
```

Each property on [`NetworkServices`](Sources/Modules/Common/Models/Public/NetworkServices.swift) returns the currently registered delegate for that service – [`AuthDelegate`](Sources/Modules/Auth/Protocols/AuthDelegate.swift), [`DatabaseDelegate`](Sources/Modules/Database/Protocols/DatabaseDelegate.swift), [`HostedTranslationDelegate`](Sources/Modules/Translation/Protocols/HostedTranslationDelegate.swift), or [`StorageDelegate`](Sources/Modules/Storage/Protocols/StorageDelegate.swift).

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

The [`AuthDelegate`](Sources/Modules/Auth/Protocols/AuthDelegate.swift) protocol defines a two-step phone authentication flow. First, verify the phone number to receive a verification ID. Then, authenticate the user with the verification code they received:

```swift
@Dependency(\.networking.auth) var auth: AuthDelegate

let verifyPhoneNumberResult = await auth.verifyPhoneNumber(
    internationalNumber: "+15551234567",
    languageCode: "en"
)

switch verifyPhoneNumberResult {
case let .success(verificationID):
    let authenticateUserResult = await auth.authenticateUser(
        authID: verificationID,
        verificationCode: "123456"
    )

case let .failure(exception):
    // Handle failure.
}
```

### Common

The Common module provides shared infrastructure used across all other modules.

#### Models

| Type | Purpose |
|---|---|
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
| [`Updatable`](Sources/Modules/Common/Protocols/UpdatableProtocol.swift) | Enables granular, key-based updates to individual properties of a remotely stored value. |
| [`Validatable`](Sources/Modules/Common/Protocols/ValidatableProtocol.swift) | Declares an `isWellFormed` property for types that can verify their own structural integrity. |

#### Network Activity View Modifier

Apply the `indicatesNetworkActivity()` view modifier to any SwiftUI view to overlay a network activity indicator during long-running operations:

```swift
ContentView()
    .indicatesNetworkActivity()
```

### Database

The [`DatabaseDelegate`](Sources/Modules/Database/Protocols/DatabaseDelegate.swift) protocol provides key-path-based access to the backend database. Values can be read, written, queried, and updated:

```swift
@Dependency(\.networking.database) var database: DatabaseDelegate

// Read values at a path.
let getValuesResult = await database.getValues(at: "users/123")

// Write a value.
let exception = await database.setValue(
    "Jane",
    forKey: "users/123/name"
)

// Query children.
let queryResult = await database.queryValues(
    at: "messages",
    strategy: .last(25)
)
```

#### Cache Strategy

Database read operations accept an optional [`CacheStrategy`](Sources/Modules/Common/Models/Public/CacheStrategy.swift) that controls how cached data is used:

| Case | Behavior |
|---|---|
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
let translateResult = await hostedTranslation.translate(
    .init("Hello"),
    with: LanguagePair(from: "en", to: "es"),
    enhance: EnhancementConfiguration(
        additionalContext: "Medical terminology"
    )
)
```

The [`GeminiModel`](Sources/Modules/Gemini/Models/Public/GeminiModel.swift) enum defines the available models for enhancement. The default is `flash25`.

### Storage

The [`StorageDelegate`](Sources/Modules/Storage/Protocols/StorageDelegate.swift) protocol provides file-level access to hosted cloud storage. Upload, download, delete, and inspect files and directories:

```swift
@Dependency(\.networking.storage) var storage: StorageDelegate

// Upload data.
let uploadException = await storage.upload(
    data,
    metadata: HostedItemMetadata("avatars/user123.png")
)

// Download an item to a local path.
let downloadException = await storage.downloadItem(
    at: "avatars/user123.png",
    to: localFileURL
)

// List directory contents.
let getDirectoryListingResult = await storage.getDirectoryListing(
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

The [`HostedTranslationDelegate`](Sources/Modules/Translation/Protocols/HostedTranslationDelegate.swift) protocol translates strings through the hosted translation service:

```swift
@Dependency(\.networking.hostedTranslation) var translator

let translateResult = await translator.translate(
    .init("Hello"),
    with: LanguagePair(from: "en", to: "es")
)
```

Translations can be serialized for database storage using [`TranslationReference`](Sources/Modules/Translation/Models/Public/TranslationReference.swift), a compact codable form that can later be decoded back into a full translation – either from an inline value, the local archive, or the hosted archive.

Use [`TranslationValidator`](Sources/Modules/Translation/Models/Public/TranslationValidator.swift) to check that inputs and language pairs are well-formed before passing them to the translation service.

---

## Delegate Customization

Default behavior can be replaced by registering custom delegates on `Networking.config`. Sensible defaults are provided for every service. Override only what your app requires.

| Delegate | Purpose | Default |
|---|---|---|
| [`AuthDelegate`](Sources/Modules/Auth/Protocols/AuthDelegate.swift) | Phone number authentication. | Firebase Authentication. |
| [`DatabaseDelegate`](Sources/Modules/Database/Protocols/DatabaseDelegate.swift) | Key-path-based data access. | Firebase Realtime Database. |
| [`StorageDelegate`](Sources/Modules/Storage/Protocols/StorageDelegate.swift) | Cloud file operations. | Firebase Cloud Storage. |
| [`GeminiAPIKeyDelegate`](Sources/Modules/Gemini/Protocols/GeminiAPIKeyDelegate.swift) | Gemini API key provider. | None (must be registered to use AI enhancement). |
| [`HostedTranslationDelegate`](Sources/Modules/Translation/Protocols/HostedTranslationDelegate.swift) | String translation. | Built-in hosted translation service. |
| [`NetworkActivityIndicatorDelegate`](Sources/Modules/Common/Protocols/NetworkActivityIndicatorDelegate.swift) | Activity indicator appearance. | Default activity indicator. |

Register delegates individually or in a single call:

```swift
Networking.config.register(
    databaseDelegate: myDatabaseDelegate,
    storageDelegate: myStorageDelegate
)

Networking.config.registerDatabaseDelegate(myDatabaseDelegate)
```

---

## Dependencies

Networking relies on two packages:

| Package | Role |
|---|---|
| [AppSubsystem](https://github.com/grantbrooksgoodman/app-subsystem) | Provides the architectural foundation that Networking builds on – including dependency injection, persistence, state management, logging, caching, reactive observation, and developer tools. AppSubsystem must be initialized before Networking. |
| [Firebase iOS SDK](https://github.com/firebase/firebase-ios-sdk) | Provides the default backend implementations for authentication (FirebaseAuth), real-time data (FirebaseDatabase), and file storage (FirebaseStorage). |

AppSubsystem is _not_ an optional companion – it is a prerequisite. Networking extends AppSubsystem's type system by registering its own dependency keys, persistent storage keys, cache domains, logger domains, and Developer Mode actions. Without AppSubsystem, these registrations have no host system to attach to, and the framework cannot operate.

For information on setting up AppSubsystem in your app, see the [AppSubsystem documentation](https://github.com/grantbrooksgoodman/app-subsystem).

---

&copy; NEOTechnica Corporation. All rights reserved.
