import PrismDomain
import PrismEnvironment

public struct InstallPlanner: InstallPlanning, Sendable {
    public init() {}

    public func plan(
        request: InstallRequest,
        catalog: PackageCatalogSnapshot,
        installed: PackageStateSnapshot,
        environment: PrismEnvironment
    ) throws -> InstallPlan {
        var selected: [String: PrismPackage] = [:]
        var visiting: [String] = []
        var visited: Set<String> = []
        var requested: [PrismPackage] = []

        for identifier in request.packageIDs.sorted() {
            guard let package = catalog.candidates(for: identifier).first else {
                throw ResolutionError.packageNotFound(identifier)
            }
            requested.append(package)
            try resolve(
                package,
                catalog: catalog,
                installed: installed,
                selected: &selected,
                visiting: &visiting,
                visited: &visited
            )
        }

        var installs: [PrismPackage] = []
        var upgrades: [PackageUpgrade] = []
        var conflicts: [PackageConflict] = []
        var unmetCapabilities: Set<EnvironmentCapability> = []

        for package in selected.values.sorted(by: { $0.identifier < $1.identifier }) {
            if package.distribution == .debianDeb {
                let required: Set<EnvironmentCapability> = [.packageInstall, .apt, .dpkg]
                unmetCapabilities.formUnion(required.subtracting(environment.capabilities))
            } else if package.distribution == .prismSource {
                if !environment.capabilities.contains(.sourceBuild) { unmetCapabilities.insert(.sourceBuild) }
            } else if !environment.capabilities.contains(.packageInstall) {
                unmetCapabilities.insert(.packageInstall)
            }

            if let installedVersion = installed.installedVersions[package.identifier] {
                if installedVersion < package.version {
                    upgrades.append(PackageUpgrade(fromVersion: installedVersion, package: package))
                }
            } else {
                installs.append(package)
            }

            for requirement in package.requirements {
                if let capability = EnvironmentCapability(rawValue: requirement.identifier),
                   !environment.capabilities.contains(capability) {
                    unmetCapabilities.insert(capability)
                }
            }

            for conflict in package.conflicts {
                if let installedVersion = installed.installedVersions[conflict.packageIdentifier],
                   conflict.isSatisfied(by: installedVersion) {
                    conflicts.append(
                        PackageConflict(
                            packageIdentifier: package.identifier,
                            conflictingPackageIdentifier: conflict.packageIdentifier
                        )
                    )
                }
            }
        }

        return InstallPlan(
            requested: requested.sorted(by: { $0.identifier < $1.identifier }),
            installs: installs.sorted(by: { $0.identifier < $1.identifier }),
            upgrades: upgrades.sorted(by: { $0.package.identifier < $1.package.identifier }),
            removals: [],
            unresolvedConflicts: conflicts.sorted {
                if $0.packageIdentifier == $1.packageIdentifier {
                    return $0.conflictingPackageIdentifier < $1.conflictingPackageIdentifier
                }
                return $0.packageIdentifier < $1.packageIdentifier
            },
            unmetCapabilities: unmetCapabilities
        )
    }

    private func resolve(
        _ package: PrismPackage,
        catalog: PackageCatalogSnapshot,
        installed: PackageStateSnapshot,
        selected: inout [String: PrismPackage],
        visiting: inout [String],
        visited: inout Set<String>
    ) throws {
        if visited.contains(package.identifier) {
            if let existing = selected[package.identifier], package.version > existing.version {
                selected[package.identifier] = package
            }
            return
        }

        if let cycleStart = visiting.firstIndex(of: package.identifier) {
            let cycle = Array(visiting[cycleStart...]) + [package.identifier]
            throw ResolutionError.dependencyCycle(cycle)
        }

        visiting.append(package.identifier)
        selected[package.identifier] = maxVersion(selected[package.identifier], package)

        let groups = package.dependencyGroups.isEmpty
            ? package.dependencies.map { PackageDependencyGroup(alternatives: [$0]) }
            : package.dependencyGroups

        for group in groups {
            if group.alternatives.contains(where: { dependency in
                installed.installedVersions[dependency.packageIdentifier].map { dependency.isSatisfied(by: $0) } ?? false
            }) { continue }

            var selectedCandidate: PrismPackage?
            for dependency in group.alternatives {
                if let candidate = catalog.candidates(for: dependency.packageIdentifier)
                    .first(where: { dependency.isSatisfied(by: $0.version) }) {
                    selectedCandidate = candidate
                    break
                }
            }
            guard let candidate = selectedCandidate else {
                throw ResolutionError.unsatisfiedDependency(
                    package: package.identifier,
                    dependency: group.alternatives.map(\.packageIdentifier).joined(separator: " | ")
                )
            }

            try resolve(
                candidate,
                catalog: catalog,
                installed: installed,
                selected: &selected,
                visiting: &visiting,
                visited: &visited
            )
        }

        _ = visiting.popLast()
        visited.insert(package.identifier)
    }

    private func maxVersion(_ lhs: PrismPackage?, _ rhs: PrismPackage) -> PrismPackage {
        guard let lhs else { return rhs }
        return rhs.version > lhs.version ? rhs : lhs
    }
}
