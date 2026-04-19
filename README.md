# Networking

A framework for integrating backend services into iOS apps through a unified, delegate-based interface.

Networking provides authentication, database access, cloud storage, and hosted translation – backed by Firebase and configurable through protocol conformances. Default implementations are supplied for every service. Override only what your app requires.

---

## Table of Contents

- [Overview](#overview)
- [Requirements](#requirements)
- [Installation](#installation)
- [Getting Started](#getting-started)
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

---

## Getting Started

### Initialization

Call `Networking.initialize()` once at app launch, after configuring AppSubsystem:

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

This single call configures the Firebase backend, registers developer mode actions for environment switching and activity indicator toggling, and begins monitoring read/write enablement status. It must be called before accessing `Networking.config`.

### Accessing Services

After initialization, use the `@Dependency` property wrapper to access networking services through [`NetworkServices`](Sources/Modules/Common/Models/Public/NetworkServices.swift):

```swift
@Dependency(\.networking) var networking: NetworkServices

let getValuesResult = await networking.database.getValues(
    at: "users/123"
)
```

Each property on [`NetworkServices`](Sources/Modules/Common/Models/Public/NetworkServices.swift) returns the currently registered delegate for that service – [`AuthDelegate`](Sources/Modules/Auth/Protocols/AuthDelegate.swift), [`DatabaseDelegate`](Sources/Modules/Database/Protocols/DatabaseDelegate.swift), [`HostedTranslationDelegate`](Sources/Modules/Translation/Protocols/HostedTranslationDelegate.swift), or [`StorageDelegate`](Sources/Modules/Storage/Protocols/StorageDelegate.swift).

### Environment Management

Networking supports three server environments – development, staging, and production – represented by the [`NetworkEnvironment`](Sources/Modules/Common/Models/Public/NetworkEnvironment.swift) enum. The active environment defaults to production and persists across launches:

```swift
Networking.config.setEnvironment(.development)
```

Database and storage paths are automatically prefixed with the active environment by default, isolating data across environments without requiring changes to your path logic.

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

#### Protocols

| Protocol | Purpose |
|---|---|
| [`NetworkActivityIndicatorDelegate`](Sources/Modules/Common/Protocols/NetworkActivityIndicatorDelegate.swift) | Customizes the appearance and behavior of the network activity indicator overlay. |
| [`Serializable`](Sources/Modules/Common/Protocols/SerializableProtocol.swift) | Defines a two-way encoding/decoding contract for types that are stored in the backend. |
| [`Updatable`](Sources/Modules/Common/Protocols/UpdatableProtocol.swift) | Enables granular, key-based updates to individual properties of a remotely stored value. |
| [`Validatable`](Sources/Modules/Common/Protocols/ValidatableProtocol.swift) | Declares an `isWellFormed` property for types that can verify their own structural integrity. |

#### Models

| Type | Purpose |
|---|---|
| [`CacheStrategy`](Sources/Modules/Common/Models/Public/CacheStrategy.swift) | Controls how cached data is used during network operations. |
| [`DataSample`](Sources/Modules/Common/Models/Public/DataSample.swift) | A time-stamped snapshot of data with configurable expiration. |
| [`EnhancedTranslationStatusVerbosity`](Sources/Modules/Common/Models/Public/EnhancedTranslationStatusVerbosity.swift) | Controls the detail level of AI translation status messages. |
| [`NetworkEnvironment`](Sources/Modules/Common/Models/Public/NetworkEnvironment.swift) | Represents the active server environment (development, staging, or production). |
| [`NetworkPath`](Sources/Modules/Common/Models/Public/NetworkPath.swift) | A type-safe reference to a backend resource location. |
| [`NetworkServices`](Sources/Modules/Common/Models/Public/NetworkServices.swift) | An aggregate container providing access to all registered service delegates. |

#### Network Activity Indicator

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

Networking builds on two companion packages:

| Package | Purpose |
|---|---|
| [AppSubsystem](https://github.com/grantbrooksgoodman/app-subsystem) | Foundation framework providing dependency injection, persistence, logging, and developer tools. |
| [Firebase](https://github.com/firebase/firebase-ios-sdk) | Backend services for authentication, database, and storage. |

---

&copy; NEOTechnica Corporation. All rights reserved.
