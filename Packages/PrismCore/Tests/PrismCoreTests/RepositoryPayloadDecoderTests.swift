import Foundation
import Testing
@testable import PrismRepositories

@Test func gzipPackagesIndexDecodesToControlText() throws {
    let url = Bundle.module.url(forResource: "SileoPackages.fixture", withExtension: "gz")!
    let compressed = try Data(contentsOf: url)
    let decoded = try RepositoryPayloadDecoder().decode(compressed, encoding: .gzip)
    #expect(String(data: decoded, encoding: .utf8)?.contains("Package: dev.prism.demo") == true)
}
