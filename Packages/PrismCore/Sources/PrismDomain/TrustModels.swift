import Foundation

public enum PackageTrustStatus: String, Codable, Sendable, Hashable {
    case trusted
    case verified
    case unverified
    case invalid
    case unknown
}

public enum RepositoryTrustStatus: String, Codable, Sendable, Hashable {
    case trusted
    case verified
    case unverified
    case invalid
    case unknown
}

public struct PackageProvenance: Codable, Sendable, Equatable, Hashable {
    public let packageID: String
    public let version: String
    public let formatIdentifier: String
    public let repositoryID: String?
    public let providerID: String
    public let providerVersion: String
    public let trustStatus: PackageTrustStatus
    public let metadataRevision: String?

    public init(
        packageID: String,
        version: String,
        formatIdentifier: String,
        repositoryID: String?,
        providerID: String,
        providerVersion: String,
        trustStatus: PackageTrustStatus,
        metadataRevision: String? = nil
    ) {
        self.packageID = packageID
        self.version = version
        self.formatIdentifier = formatIdentifier
        self.repositoryID = repositoryID
        self.providerID = providerID
        self.providerVersion = providerVersion
        self.trustStatus = trustStatus
        self.metadataRevision = metadataRevision
    }
}
