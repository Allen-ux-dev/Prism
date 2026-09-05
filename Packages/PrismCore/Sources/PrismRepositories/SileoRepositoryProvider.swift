import Foundation
import PrismDomain

public enum RepositoryNormalizationError: Error, Equatable {
    case missingField(package: String?, field: String)
}

public struct SileoRepositoryProvider: RepositoryNormalizer, Sendable {
    private let parser = DebianControlParser()

    public init() {}

    public func normalizeRepository(
        metadata: Data,
        packagesIndex: Data,
        baseURL: URL
    ) throws -> PrismRepositorySnapshot {
        let releaseFields = try parser.parse(metadata).first ?? [:]
        let packageParagraphs = try parser.parse(packagesIndex)
        let repositoryID = releaseFields["Origin"] ?? canonicalRepositoryID(baseURL)

        var warnings: [RepositoryNormalizationWarning] = []
        var packages: [PrismPackage] = []
        packages.reserveCapacity(packageParagraphs.count)

        for fields in packageParagraphs {
            let identifier = try required("Package", fields: fields, package: nil)
            let version = try required("Version", fields: fields, package: identifier)
            let architecture = try required("Architecture", fields: fields, package: identifier)

            let dependencyResult = parseDependencyGroups(
                fields["Depends"],
                packageIdentifier: identifier,
                fieldName: "Depends",
                warnings: &warnings
            )
            let conflicts = parseDependencyField(
                fields["Conflicts"],
                packageIdentifier: identifier,
                fieldName: "Conflicts",
                warnings: &warnings
            )

            packages.append(
                PrismPackage(
                    identifier: identifier,
                    name: fields["Name"] ?? identifier,
                    version: DebianVersion(version),
                    architecture: architecture,
                    author: fields["Author"],
                    description: fields["Description"] ?? "",
                    repositoryID: repositoryID,
                    dependencies: dependencyResult.singles,
                    dependencyGroups: dependencyResult.groups,
                    conflicts: conflicts,
                    requirements: [.init(identifier: "legacyDebCompatibility")],
                    distribution: .deb,
                    installationState: .unknown,
                    metadata: fields,
                    iconURL: resolvedURL(fields["Icon"], relativeTo: baseURL)
                )
            )
        }

        let repository = PrismRepository(
            identity: repositoryID,
            baseURL: baseURL,
            metadata: releaseFields,
            providerIdentifier: "sileo-apt",
            packages: packages,
            refreshState: .ready,
            trustState: .unknown,
            lastRefresh: nil,
            displayName: releaseFields["Label"] ?? releaseFields["Origin"] ?? baseURL.host ?? baseURL.absoluteString,
            iconURLs: normalizedRepositoryIconURLs(releaseFields: releaseFields, baseURL: baseURL),
            summary: releaseFields["Description"],
            compatibility: .compatible,
            providerMetadata: normalizedProviderMetadata(releaseFields)
        )

        return PrismRepositorySnapshot(repository: repository, packages: packages, warnings: warnings)
    }

    private func resolvedURL(_ raw: String?, relativeTo baseURL: URL) -> URL? {
        guard let raw = raw?.trimmingCharacters(in: .whitespacesAndNewlines), !raw.isEmpty else { return nil }
        if let absolute = URL(string: raw), absolute.scheme != nil { return absolute }
        return URL(string: raw, relativeTo: baseURL)?.absoluteURL
    }

    private func normalizedRepositoryIconURLs(releaseFields: [String: String], baseURL: URL) -> [URL] {
        var candidates: [URL] = []
        if let explicit = resolvedURL(releaseFields["Icon"], relativeTo: baseURL) { candidates.append(explicit) }
        candidates.append(baseURL.appendingPathComponent("CydiaIcon.png"))
        candidates.append(baseURL.appendingPathComponent("icon.png"))
        candidates.append(baseURL.appendingPathComponent("favicon.ico"))
        var seen = Set<String>()
        return candidates.filter { seen.insert($0.absoluteString).inserted }
    }

    private func normalizedProviderMetadata(_ releaseFields: [String: String]) -> [String: String] {
        var metadata: [String: String] = ["repositoryFormat": "apt"]
        if let commerce = releaseFields["Purchase-Provider"] ?? releaseFields["Commerce-Provider"] {
            metadata["commerceProviderIdentifier"] = commerce
        }
        return metadata
    }

    private func required(
        _ key: String,
        fields: [String: String],
        package: String?
    ) throws -> String {
        guard let value = fields[key], !value.isEmpty else {
            throw RepositoryNormalizationError.missingField(package: package, field: key)
        }
        return value
    }

    private func canonicalRepositoryID(_ baseURL: URL) -> String {
        var result = baseURL.absoluteString
        while result.hasSuffix("/") { result.removeLast() }
        return result
    }

    private func parseDependencyGroups(
        _ raw: String?,
        packageIdentifier: String,
        fieldName: String,
        warnings: inout [RepositoryNormalizationWarning]
    ) -> (singles: [PackageDependency], groups: [PackageDependencyGroup]) {
        guard let raw, !raw.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else { return ([], []) }
        var singles: [PackageDependency] = []
        var groups: [PackageDependencyGroup] = []
        for rawGroup in raw.split(separator: ",", omittingEmptySubsequences: true) {
            let alternatives = rawGroup.split(separator: "|", omittingEmptySubsequences: true)
                .compactMap { parseSingleDependency(String($0).trimmingCharacters(in: .whitespacesAndNewlines)) }
            if alternatives.isEmpty {
                warnings.append(.init(packageIdentifier: packageIdentifier, field: fieldName, message: "Dependency group could not be normalized: \(rawGroup)"))
                continue
            }
            groups.append(.init(alternatives: alternatives))
            if alternatives.count == 1 { singles.append(alternatives[0]) }
        }
        return (singles, groups)
    }

    private func parseDependencyField(
        _ raw: String?,
        packageIdentifier: String,
        fieldName: String,
        warnings: inout [RepositoryNormalizationWarning]
    ) -> [PackageDependency] {
        guard let raw, !raw.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else {
            return []
        }

        var result: [PackageDependency] = []
        for group in raw.split(separator: ",", omittingEmptySubsequences: true) {
            let expression = String(group).trimmingCharacters(in: .whitespacesAndNewlines)
            if expression.contains("|") {
                warnings.append(
                    RepositoryNormalizationWarning(
                        packageIdentifier: packageIdentifier,
                        field: fieldName,
                        message: "Alternative dependency preserved as raw metadata: \(expression)"
                    )
                )
                continue
            }

            if let dependency = parseSingleDependency(expression) {
                result.append(dependency)
            } else {
                warnings.append(
                    RepositoryNormalizationWarning(
                        packageIdentifier: packageIdentifier,
                        field: fieldName,
                        message: "Dependency could not be normalized and remains available in raw metadata: \(expression)"
                    )
                )
            }
        }
        return result
    }

    private func parseSingleDependency(_ expression: String) -> PackageDependency? {
        guard !expression.isEmpty else { return nil }

        guard let open = expression.firstIndex(of: "(") else {
            let identifier = expression.trimmingCharacters(in: .whitespacesAndNewlines)
            return identifier.isEmpty ? nil : PackageDependency(packageIdentifier: identifier)
        }
        guard let close = expression.lastIndex(of: ")"), close > open else { return nil }

        let identifier = String(expression[..<open]).trimmingCharacters(in: .whitespacesAndNewlines)
        let constraintStart = expression.index(after: open)
        let constraint = String(expression[constraintStart..<close]).trimmingCharacters(in: .whitespacesAndNewlines)
        let pieces = constraint.split(whereSeparator: { $0.isWhitespace })
        guard !identifier.isEmpty, pieces.count == 2 else { return nil }

        let relation: VersionRelation
        switch pieces[0] {
        case "=": relation = .equal
        case ">", ">>": relation = .greaterThan
        case ">=": relation = .greaterThanOrEqual
        case "<", "<<": relation = .lessThan
        case "<=": relation = .lessThanOrEqual
        default: return nil
        }

        return PackageDependency(
            packageIdentifier: identifier,
            relation: relation,
            requiredVersion: DebianVersion(String(pieces[1]))
        )
    }
}
