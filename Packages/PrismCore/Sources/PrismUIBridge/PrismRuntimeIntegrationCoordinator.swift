import PrismDomain

public actor PrismRuntimeIntegrationCoordinator {
    public typealias Handshake = @Sendable () async throws -> Bool

    private let installer: any PrismRuntimeInstallerProtocol
    private let capabilityStates: [CapabilityIdentifier: CapabilityState]
    private let requiredCapabilities: [CapabilityRequirement]
    private let handshake: Handshake
    public private(set) var state: PrismIntegrationState
    public private(set) var lifecycleState: PackageServiceLifecycleState

    public init(
        installer: any PrismRuntimeInstallerProtocol,
        capabilityStates: [CapabilityIdentifier: CapabilityState],
        requiredCapabilities: [CapabilityRequirement] = CapabilityRequirement.managedRuntimeLifecycle,
        handshake: @escaping Handshake
    ) {
        self.installer = installer
        self.capabilityStates = capabilityStates
        self.requiredCapabilities = requiredCapabilities
        self.handshake = handshake
        self.state = .notInstalled
        self.lifecycleState = .idle
    }

    public init(
        installer: any PrismRuntimeInstallerProtocol,
        capabilities: [RuntimeIntegrationCapability: CapabilityAvailability],
        handshake: @escaping Handshake
    ) {
        self.init(
            installer: installer,
            capabilityStates: LegacyCapabilityAdapter.convert(capabilities),
            handshake: handshake
        )
    }

    public func integrate(targetVersion: String) async -> PrismIntegrationState {
        lifecycleState = .activating
        if let missing = firstUnavailableRequiredCapability() {
            lifecycleState = .degraded
            let next = PrismIntegrationState.degraded(reason: "Required runtime capability unavailable: \(capabilityDisplayName(missing))")
            state = next
            return next
        }

        do {
            let installation = try await installer.inspectInstallation()
            switch installation {
            case .notInstalled:
                _ = try await installer.install(request: .init(targetVersion: targetVersion))
                state = .installed
            case .installed:
                state = .installed
            case .outdated(let currentVersion, _, let ownership):
                guard ownership.isRuntimeManaged else {
                    lifecycleState = .degraded
                    let next = PrismIntegrationState.degraded(reason: "Prism update lifecycle is owned by \(ownership.lifecycleOwnerID)")
                    state = next
                    return next
                }
                _ = try await installer.upgrade(request: .init(fromVersion: currentVersion, targetVersion: targetVersion))
                state = .installed
            case .incompatible(let reason):
                let next = PrismIntegrationState.incompatible(reason: reason)
                lifecycleState = .unavailable
                state = next
                return next
            }

            try await installer.registerPrism()
            try await installer.registerPackageService()
            try await installer.registerLifecycle()
            state = .registered

            guard try await handshake() else {
                let next = PrismIntegrationState.incompatible(reason: "Runtime handshake failed")
                lifecycleState = .unavailable
                state = next
                return next
            }

            state = .activating
            try await installer.activate()
            lifecycleState = .active
            state = .ready
            lifecycleState = .finishing
            lifecycleState = .idle
            return .ready
        } catch {
            lifecycleState = .degraded
            let next = PrismIntegrationState.degraded(reason: String(describing: error))
            state = next
            return next
        }
    }

    public func repair() async -> PrismIntegrationState {
        state = .repairing
        lifecycleState = .recovering
        do {
            let result = try await installer.repair()
            state = result.state
            lifecycleState = result.state == .ready ? .idle : .degraded
            return result.state
        } catch {
            lifecycleState = .degraded
            let next = PrismIntegrationState.degraded(reason: String(describing: error))
            state = next
            return next
        }
    }

    public func recover() async -> PrismIntegrationState {
        state = .recovering
        return await repair()
    }

    public func deactivate() async -> PrismIntegrationState {
        do {
            try await installer.deactivate()
            state = .disabled
            return .disabled
        } catch {
            let next = PrismIntegrationState.degraded(reason: String(describing: error))
            state = next
            return next
        }
    }

    public func unregister() async -> PrismIntegrationState {
        do {
            try await installer.unregister()
            state = .notInstalled
            return .notInstalled
        } catch {
            let next = PrismIntegrationState.degraded(reason: String(describing: error))
            state = next
            return next
        }
    }


    private func capabilityDisplayName(_ identifier: CapabilityIdentifier) -> String {
        LegacyCapabilityAdapter.legacyCapability(for: identifier)?.rawValue ?? identifier.rawValue
    }

    private func firstUnavailableRequiredCapability() -> CapabilityIdentifier? {
        CapabilityRequirementEvaluator
            .evaluate(requiredCapabilities, against: capabilityStates)
            .missingRequired
            .first
    }
}
