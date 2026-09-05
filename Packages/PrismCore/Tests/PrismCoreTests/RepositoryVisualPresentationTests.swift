import Foundation
import Testing
@testable import PrismUIBridge

private struct VisualFixtureFetcher: RepositoryDataFetching {
    let payloads: [URL: Data]

    func data(from url: URL) async throws -> Data {
        if let data = payloads[url] { return data }
        throw RepositoryNetworkError.badStatus(404)
    }
}

@Test func repositoryVisualMetadataResolvesDisplayNameAndFallbackIconCandidates() async throws {
    let base = URL(string: "https://repo.example/")!
    let release = Data("""
    Origin: Example Origin
    Label: Example Repository
    Icon: assets/repository.png

    """.utf8)
    let packages = Data("""
    Package: dev.example.demo
    Name: Demo Plugin
    Version: 1.0
    Architecture: iphoneos-arm64
    Icon: icons/demo.png
    Description: Demo

    """.utf8)
    let fetcher = VisualFixtureFetcher(payloads: [
        base.appendingPathComponent("Release"): release,
        base.appendingPathComponent("Packages"): packages,
    ])

    let result = await RepositoryCatalogClient(fetcher: fetcher).load(sourceURLs: [base])
    let source = try #require(result.sourceVisuals[base.absoluteString])

    #expect(source.displayName == "Example Repository")
    #expect(source.iconURLs.first == "https://repo.example/assets/repository.png")
    #expect(source.iconURLs.contains("https://repo.example/CydiaIcon.png"))
    #expect(source.iconURLs.contains("https://repo.example/icon.png"))
    #expect(source.iconURLs.contains("https://repo.example/favicon.ico"))
    #expect(result.packageIconURLs["dev.example.demo"] == "https://repo.example/icons/demo.png")
}

@Test func repositoryVisualMetadataKeepsAbsolutePackageIconURL() async throws {
    let base = URL(string: "https://repo.example/")!
    let packages = Data("""
    Package: dev.example.absolute
    Name: Absolute Icon
    Version: 1.0
    Architecture: iphoneos-arm64
    Icon: https://cdn.example/icon.png
    Description: Demo

    """.utf8)
    let fetcher = VisualFixtureFetcher(payloads: [
        base.appendingPathComponent("Release"): Data(),
        base.appendingPathComponent("Packages"): packages,
    ])

    let result = await RepositoryCatalogClient(fetcher: fetcher).load(sourceURLs: [base])
    #expect(result.packageIconURLs["dev.example.absolute"] == "https://cdn.example/icon.png")
}

@Test func repositoryCommerceProviderFallsBackFromReleaseMetadata() async throws {
    let base = URL(string: "https://paid.example/")!
    let release = Data("""
    Origin: Paid Repo
    Label: Paid Repository
    Commerce-Provider: repo-account-v1

    """.utf8)
    let packages = Data("""
    Package: dev.example.paid
    Name: Paid Plugin
    Version: 1.0
    Architecture: iphoneos-arm64
    Price: 3.99
    Currency: CAD
    Description: Paid demo

    """.utf8)
    let fetcher = VisualFixtureFetcher(payloads: [
        base.appendingPathComponent("Release"): release,
        base.appendingPathComponent("Packages"): packages,
    ])

    let result = await RepositoryCatalogClient(fetcher: fetcher).load(sourceURLs: [base])
    #expect(result.sourceVisuals[base.absoluteString]?.commerceProviderIdentifier == "repo-account-v1")
}
