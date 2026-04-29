//
//  Networking.swift
//
//  Created by Grant Brooks Goodman.
//  Copyright © NEOTechnica Corporation. All rights reserved.
//

/* Native */
import Foundation

/* Proprietary */
import AppSubsystem

/* 3rd-party */
import FirebaseCore

// MARK: - Networking

/// A framework for integrating backend services into
/// iOS apps.
///
/// Networking provides a unified interface for
/// authentication, database access, cloud storage,
/// and hosted translation – backed by Firebase and
/// configurable through delegate protocols.
///
/// ## Bootstrapping
///
/// Call ``initialize()`` once at app launch, typically
/// inside your `App` initializer, after configuring
/// AppSubsystem:
///
/// ```swift
/// @main
/// struct MyApp: App {
///     init() {
///         AppSubsystem.initialize(...)
///         Networking.initialize()
///     }
///
///     var body: some Scene { ... }
/// }
/// ```
///
/// ## Accessing Services
///
/// After initialization, use the ``@Dependency``
/// property wrapper to access networking services:
///
/// ```swift
/// @Dependency(\.networking) var networking: NetworkServices
///
/// let getValuesResult = await networking.database.getValues(
///     at: "users/123"
/// )
/// ```
///
/// ## Customization via Delegates
///
/// Default behavior can be replaced by registering
/// custom delegates on ``config``. Sensible defaults
/// are provided out of the box for all services:
///
/// ```swift
/// Networking.config.register(
///     databaseDelegate: myDatabaseDelegate,
///     storageDelegate: myStorageDelegate
/// )
/// ```
public enum Networking {
    /* MARK: Properties */

    /// The shared configuration for the Networking
    /// framework.
    ///
    /// Use this property to register custom delegates,
    /// read the current environment, or configure
    /// translation settings. The configuration is
    /// available as soon as ``initialize()`` has been
    /// called.
    public static let config = Config.shared

    private static let _didInitialize = LockIsolated<Bool>(wrappedValue: false)

    /* MARK: Computed Properties */

    private static var didInitialize: Bool {
        get { _didInitialize.wrappedValue }
        set { _didInitialize.wrappedValue = newValue }
    }

    /* MARK: Initialize */

    /// Configures the framework and prepares all
    /// internal services for use.
    ///
    /// Call this method once at app launch. It
    /// configures the Firebase backend, registers
    /// Developer Mode actions, and begins monitoring
    /// read/write enablement status.
    ///
    /// - Important: This method must be called on the
    ///   main actor. Accessing ``config`` before calling
    ///   this method results in a fatal error.
    @MainActor
    public static func initialize() {
        FirebaseApp.configure()
        didInitialize = true
        DevModeService.insertAction(.switchEnvironmentAction, at: 0)
        DevModeService.insertAction(.toggleNetworkActivityIndicatorAction, at: 1)

        Task.background { @MainActor in
            ReadWriteEnablementStatusService.shared.listenForReadWriteEnablementStatusChanges()
        }
    }
}

// MARK: - Config

public extension Networking {
    /// The configuration object for the Networking
    /// framework.
    ///
    /// Access the shared instance through
    /// ``Networking/config``. The configuration manages
    /// the active network environment, delegate
    /// registrations, and translation enhancement
    /// settings.
    ///
    /// Delegates with sensible defaults are provided
    /// automatically. To supply a custom conformance,
    /// use ``register(activityIndicatorDelegate:authDelegate:databaseDelegate:geminiAPIKeyDelegate:hostedTranslationDelegate:storageDelegate:)``
    /// or one of the individual registration methods:
    ///
    /// ```swift
    /// Networking.config.registerDatabaseDelegate(
    ///     myDatabaseDelegate
    /// )
    /// ```
    final class Config: @unchecked Sendable {
        /* MARK: Properties */

        fileprivate static let shared = Config()

        /// A Boolean value that indicates whether system
        /// dialog translations are enhanced with
        /// artificial intelligence.
        ///
        /// When this value is `true`, dialogs presented
        /// through AlertKit use AI-enhanced translations
        /// powered by the Gemini API. The default is
        /// `false`.
        ///
        /// To change this value, call
        /// ``setIsEnhancedDialogTranslationEnabled(_:)``.
        @LockIsolated public private(set) var isEnhancedDialogTranslationEnabled = false

        @LockIsolated package private(set) var activityIndicatorDelegate: NetworkActivityIndicatorDelegate = DefaultNetworkActivityIndicatorDelegate()
        @LockIsolated package private(set) var authDelegate: AuthDelegate = Auth()
        @LockIsolated package private(set) var databaseDelegate: DatabaseDelegate = Database()
        @LockIsolated package private(set) var hostedTranslationDelegate: any HostedTranslationDelegate = HostedTranslationService.shared
        @LockIsolated package private(set) var storageDelegate: StorageDelegate = Storage()

        private let _enhancedTranslationStatusVerbosity = LockIsolated<EnhancedTranslationStatusVerbosity?>(wrappedValue: nil)
        private let _geminiAPIKeyDelegate = LockIsolated<GeminiAPIKeyDelegate?>(wrappedValue: nil)

        /* MARK: Computed Properties */

        /// The verbosity level for AI-enhanced
        /// translation status messages.
        ///
        /// When non-`nil`, this value controls the
        /// detail shown in status indicators during
        /// AI-enhanced translations. The default is
        /// `nil`, which disables status messages.
        ///
        /// To change this value, call
        /// ``setEnhancedTranslationStatusVerbosity(_:)``.
        public var enhancedTranslationStatusVerbosity: EnhancedTranslationStatusVerbosity? {
            _enhancedTranslationStatusVerbosity.wrappedValue
        }

        /// The active network environment.
        ///
        /// This value determines which backend
        /// environment the app communicates with. It
        /// persists across launches using
        /// persistent storage. The default is
        /// ``NetworkEnvironment/production``.
        ///
        /// To change the environment, call
        /// ``setEnvironment(_:)``.
        public var environment: NetworkEnvironment {
            @Persistent(.networkEnvironment) var persistedValue: NetworkEnvironment?
            guard let persistedValue else {
                persistedValue = .production
                return .production
            }

            return persistedValue
        }

        package var geminiAPIKeyDelegate: GeminiAPIKeyDelegate? {
            _geminiAPIKeyDelegate.wrappedValue
        }

        /* MARK: Init */

        private init() {
            guard Networking.didInitialize else {
                fatalError("Networking.initialize() must be called at app launch")
            }
        }

        /* MARK: Set Environment */

        /// Sets the active network environment.
        ///
        /// The new value is persisted to storage
        /// and takes effect immediately for subsequent
        /// network operations. Database and storage
        /// paths that use environment-scoped prefixes
        /// will resolve against the new environment.
        ///
        /// - Parameter environment: The environment to
        ///   activate.
        public func setEnvironment(_ environment: NetworkEnvironment) {
            @Persistent(.networkEnvironment) var persistedValue: NetworkEnvironment?
            persistedValue = environment
        }

        /* MARK: Enhanced Translation Configuration */

        /// Sets the verbosity level for AI-enhanced
        /// translation status messages.
        ///
        /// Pass an
        /// ``EnhancedTranslationStatusVerbosity``
        /// value to control the detail shown in status
        /// indicators, or pass `nil` to disable status
        /// messages entirely.
        ///
        /// - Parameter enhancedTranslationStatusVerbosity:
        ///   The verbosity level to use, or `nil` to
        ///   disable status messages.
        public func setEnhancedTranslationStatusVerbosity(_ enhancedTranslationStatusVerbosity: EnhancedTranslationStatusVerbosity?) {
            _enhancedTranslationStatusVerbosity.wrappedValue = enhancedTranslationStatusVerbosity
        }

        /// Sets whether system dialog translations are
        /// enhanced with artificial intelligence.
        ///
        /// - Parameter isEnhancedDialogTranslationEnabled:
        ///   A Boolean value that determines whether
        ///   AI enhancement is applied to dialog
        ///   translations.
        public func setIsEnhancedDialogTranslationEnabled(_ isEnhancedDialogTranslationEnabled: Bool) {
            self.isEnhancedDialogTranslationEnabled = isEnhancedDialogTranslationEnabled
        }

        /* MARK: Delegate Registration */

        /// Registers one or more custom delegates in a
        /// single call.
        ///
        /// Each non-`nil` argument replaces the
        /// corresponding default delegate. Arguments
        /// left as `nil` are unchanged.
        ///
        /// ```swift
        /// Networking.config.register(
        ///     authDelegate: myAuthDelegate,
        ///     databaseDelegate: myDatabaseDelegate
        /// )
        /// ```
        ///
        /// For registering a single delegate, you can
        /// also use the corresponding convenience method
        /// – for example,
        /// ``registerAuthDelegate(_:)``.
        ///
        /// - Parameters:
        ///   - activityIndicatorDelegate: A custom
        ///     network activity indicator delegate.
        ///   - authDelegate: A custom authentication
        ///     delegate.
        ///   - databaseDelegate: A custom database
        ///     delegate.
        ///   - geminiAPIKeyDelegate: A custom Gemini
        ///     API key delegate.
        ///   - hostedTranslationDelegate: A custom
        ///     hosted translation delegate.
        ///   - storageDelegate: A custom storage
        ///     delegate.
        ///
        /// - Important: At least one non-`nil` argument must be
        ///   provided. Passing all `nil` values triggers an
        ///   assertion failure in debug builds.
        public func register(
            activityIndicatorDelegate: NetworkActivityIndicatorDelegate? = nil,
            authDelegate: AuthDelegate? = nil,
            databaseDelegate: DatabaseDelegate? = nil,
            geminiAPIKeyDelegate: GeminiAPIKeyDelegate? = nil,
            hostedTranslationDelegate: HostedTranslationDelegate? = nil,
            storageDelegate: StorageDelegate? = nil
        ) {
            guard activityIndicatorDelegate != nil ||
                authDelegate != nil ||
                databaseDelegate != nil ||
                geminiAPIKeyDelegate != nil ||
                hostedTranslationDelegate != nil ||
                storageDelegate != nil else {
                assertionFailure("No delegates provided in arguments.")
                return
            }

            if let activityIndicatorDelegate { self.activityIndicatorDelegate = activityIndicatorDelegate }
            if let authDelegate { self.authDelegate = authDelegate }
            if let databaseDelegate { self.databaseDelegate = databaseDelegate }
            if let geminiAPIKeyDelegate { _geminiAPIKeyDelegate.wrappedValue = geminiAPIKeyDelegate }
            if let hostedTranslationDelegate { self.hostedTranslationDelegate = hostedTranslationDelegate }
            if let storageDelegate { self.storageDelegate = storageDelegate }
        }

        /// Registers a custom network activity indicator
        /// delegate.
        ///
        /// - Parameter activityIndicatorDelegate: The
        ///   delegate to register.
        ///
        /// - SeeAlso: ``NetworkActivityIndicatorDelegate``
        public func registerActivityIndicatorDelegate(_ activityIndicatorDelegate: NetworkActivityIndicatorDelegate) {
            register(activityIndicatorDelegate: activityIndicatorDelegate)
        }

        /// Registers a custom authentication delegate.
        ///
        /// - Parameter authDelegate: The delegate to
        ///   register.
        ///
        /// - SeeAlso: ``AuthDelegate``
        public func registerAuthDelegate(_ authDelegate: AuthDelegate) {
            register(authDelegate: authDelegate)
        }

        /// Registers a custom hosted translation
        /// delegate.
        ///
        /// - Parameter hostedTranslationDelegate: The
        ///   delegate to register.
        ///
        /// - SeeAlso: ``HostedTranslationDelegate``
        public func registerHostedTranslationDelegate(_ hostedTranslationDelegate: HostedTranslationDelegate) {
            register(hostedTranslationDelegate: hostedTranslationDelegate)
        }

        /// Registers a custom database delegate.
        ///
        /// - Parameter databaseDelegate: The delegate
        ///   to register.
        ///
        /// - SeeAlso: ``DatabaseDelegate``
        public func registerDatabaseDelegate(_ databaseDelegate: DatabaseDelegate) {
            register(databaseDelegate: databaseDelegate)
        }

        /// Registers a custom Gemini API key delegate.
        ///
        /// - Parameter geminiAPIKeyDelegate: The
        ///   delegate to register.
        ///
        /// - SeeAlso: ``GeminiAPIKeyDelegate``
        public func registerGeminiAPIKeyDelegate(_ geminiAPIKeyDelegate: GeminiAPIKeyDelegate) {
            register(geminiAPIKeyDelegate: geminiAPIKeyDelegate)
        }

        /// Registers a custom storage delegate.
        ///
        /// - Parameter storageDelegate: The delegate to
        ///   register.
        ///
        /// - SeeAlso: ``StorageDelegate``
        public func registerStorageDelegate(_ storageDelegate: StorageDelegate) {
            register(storageDelegate: storageDelegate)
        }
    }
}
