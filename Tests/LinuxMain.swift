import XCTest

import HttpServerTests

var tests = [XCTestCaseEntry]()
tests += HttpServerTests.allTests()
XCTMain(tests)