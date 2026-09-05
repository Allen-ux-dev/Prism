import Foundation
import PrismDomain

public enum MockProviderFaultMode: Sendable, Equatable {
    case normal
    case failBeforeExecution
    case failAfterOperation(Int)
    case interruptAfterOperation(Int)
    case degradedBeforeExecution
    case degradedDuringExecution
    case rollbackSucceeds
    case rollbackFails
    case safeAbortSucceeds
    case safeAbortFails
    case reconcileAlreadyApplied
    case reconcilePartiallyApplied
}

public actor MockProviderFaultController {
    private var mode: MockProviderFaultMode

    public init(mode: MockProviderFaultMode = .normal) {
        self.mode = mode
    }

    public func setMode(_ mode: MockProviderFaultMode) {
        self.mode = mode
    }

    public func currentMode() -> MockProviderFaultMode { mode }

    public func providerHealth() -> ProviderHealth {
        switch mode {
        case .degradedBeforeExecution, .degradedDuringExecution:
            return .degraded("Simulated provider degradation")
        default:
            return .healthy
        }
    }
}
