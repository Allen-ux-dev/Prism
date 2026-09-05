import Foundation

public enum AppInstallationSource: String, Codable, Sendable, Hashable {
    case system, jailbreak, trollStoreStyle, prism, unknown
}

public enum AppRegistrationState: String, Codable, Sendable, Hashable {
    case registered, unregistered, unavailable, unknown
}

public struct PrismInstalledApp: Codable, Sendable, Hashable {
    public let bundleIdentifier: String
    public let displayName: String
    public let version: String
    public let architecture: String
    public let minimumOS: String?
    public let installationSource: AppInstallationSource
    public let registrationState: AppRegistrationState

    public init(bundleIdentifier: String, displayName: String, version: String, architecture: String,
                minimumOS: String? = nil, installationSource: AppInstallationSource = .unknown,
                registrationState: AppRegistrationState = .unknown) {
        self.bundleIdentifier = bundleIdentifier
        self.displayName = displayName
        self.version = version
        self.architecture = architecture
        self.minimumOS = minimumOS
        self.installationSource = installationSource
        self.registrationState = registrationState
    }
}

public struct IPAInspectionSnapshot: Codable, Sendable, Hashable {
    public let bundleIdentifier: String
    public let displayName: String
    public let version: String
    public let architectures: Set<String>
    public let minimumOS: String?

    public init(bundleIdentifier: String, displayName: String, version: String, architectures: Set<String>, minimumOS: String? = nil) {
        self.bundleIdentifier = bundleIdentifier
        self.displayName = displayName
        self.version = version
        self.architectures = architectures
        self.minimumOS = minimumOS
    }
}

public enum InjectionArtifactKind: String, Codable, Sendable, Hashable { case dylib, framework, bundle }

public struct InjectionArtifact: Codable, Sendable, Hashable {
    public let identifier: String
    public let displayName: String
    public let kind: InjectionArtifactKind
    public let supportedArchitectures: Set<String>

    public init(identifier: String, displayName: String, kind: InjectionArtifactKind, supportedArchitectures: Set<String>) {
        self.identifier = identifier
        self.displayName = displayName
        self.kind = kind
        self.supportedArchitectures = supportedArchitectures
    }
}
