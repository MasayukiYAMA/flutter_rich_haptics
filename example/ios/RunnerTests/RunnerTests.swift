import Flutter
import UIKit
import XCTest

@testable import flutter_rich_haptics

class RunnerTests: XCTestCase {

  func testSupportsHaptics() {
    let plugin = FlutterRichHapticsPlugin()

    let call = FlutterMethodCall(methodName: "supportsHaptics", arguments: [])

    let resultExpectation = expectation(description: "result block must be called.")
    plugin.handle(call) { result in
      XCTAssertNotNil(result)
      resultExpectation.fulfill()
    }
    waitForExpectations(timeout: 1)
  }

}
