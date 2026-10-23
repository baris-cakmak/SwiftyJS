import Foundation
import JavaScriptCore
import SwiftyJS
import XCTest

struct BridgeConfig: Codable, Equatable {
    let enabled: Bool
    let count: Int64
    let names: [String]
}

struct BridgeModel: Codable {
    let createdAt: Date
    let message: String
}

@SwiftyJS
protocol RuntimePlugin {
    var config: [BridgeConfig] { get throws }
    func update(message: String) throws -> String
    func dateMessage(model: BridgeModel) throws -> String
    func asyncMessage(message: String) async throws -> String
}

final class RuntimeTests: XCTestCase {
    func testMacroConfigurationAndFunctionRunInJavaScriptCore() throws {
        let plugin = RuntimePluginJSBridge()
        plugin.loadFrom(jsCode: """
        var config = [{enabled:true, count:5000000000, names:['one','two']}];
        function update(message) { return config[0].names[0] + ':' + message; }
        """)
        XCTAssertEqual(try plugin.config, [.init(enabled: true, count: 5_000_000_000, names: ["one", "two"])])
        try plugin.setConfig([.init(enabled: false, count: 6_000_000_000, names: ["changed"])])
        XCTAssertEqual(try plugin.config, [.init(enabled: false, count: 6_000_000_000, names: ["changed"])])
        XCTAssertEqual(try plugin.update(message: "İstanbul ❤️"), "changed:İstanbul ❤️")
    }

    func testDatesRemainNativeAndJavaScriptErrorsThrow() throws {
        let plugin = RuntimePluginJSBridge()
        plugin.loadFrom(jsCode: """
        function dateMessage(model) { return (model.createdAt instanceof Date) + ':' + model.createdAt.getTime() + ':' + model.message; }
        function update(message) { throw new Error('plugin failed'); }
        """)
        XCTAssertEqual(try plugin.dateMessage(model: .init(createdAt: Date(timeIntervalSince1970: 1_700_000_000), message: "body")), "true:1700000000000:body")
        XCTAssertThrowsError(try plugin.update(message: "test")) { error in
            XCTAssertTrue(error.localizedDescription.contains("plugin failed"))
        }
    }

    func testGeneratedAsyncBridgeResolvesPromise() async throws {
        let plugin = RuntimePluginJSBridge()
        plugin.loadFrom(jsCode: "async function asyncMessage(message) { return 'async:' + message; }")
        let result = try await plugin.asyncMessage(message: "test")
        XCTAssertEqual(result, "async:test")
    }
}
