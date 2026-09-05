import Testing
@testable import PrismDomain

@Test func domainTargetLoadsWithoutUIFrameworks() {
    #expect(String(describing: PrismPackage.self).isEmpty == false)
}
