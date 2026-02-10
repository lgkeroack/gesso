//
//  GessoCoreTests.swift
//  GessoCoreTests
//
//  Tests for GessoCore
//

import XCTest
@testable import GessoCore

final class GessoCoreTests: XCTestCase {
    func testVersion() {
        XCTAssertEqual(GessoCore.version, "1.0.0")
    }
}
