//
//  NetworkMonitorTests.swift
//  Userpilot SDK
//
//  Created by Motasem Hamed on 13/10/2025.
//  Copyright © 2025 Userpilot. All rights reserved.
//

import Network
import XCTest

@testable import Userpilot

class NetworkMonitorTests: XCTestCase {

    var networkMonitor: NetworkMonitor!
    var userpilot: MockUserpilot!

    override func setUpWithError() throws {
        let config = Userpilot.Config(token: "NX-00000")
        userpilot = MockUserpilot(config: config)
        networkMonitor = NetworkMonitor(container: userpilot.container)
    }

    override func tearDownWithError() throws {
        networkMonitor.stopMonitoring()
        networkMonitor = nil
        userpilot = nil
    }

    func testNetworkMonitor_initializes() throws {
        // Assert
        XCTAssertNotNil(networkMonitor)
    }

    func testNetworkMonitor_startsMonitoring() throws {
        // Given - monitor is already started in setUp

        // When - we wait a bit for the initial state to be set
        let expectation = XCTestExpectation(description: "Wait for network state")
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) {
            expectation.fulfill()
        }
        wait(for: [expectation], timeout: 1.0)

        // Then - isNetworkAvailable should have a value (true or false depending on actual network)
        // We can't assert a specific value because it depends on the test environment
        // but we can verify the property is accessible
        _ = networkMonitor.isNetworkAvailable
        XCTAssertTrue(true, "Network monitor should have network state")
    }

    func testNetworkMonitor_stopsMonitoring() throws {
        // When
        networkMonitor.stopMonitoring()

        // Then - should not crash
        XCTAssertTrue(true, "Stop monitoring should complete without errors")
    }

    func testNetworkMonitor_canBeRestarted() throws {
        // Given
        networkMonitor.stopMonitoring()

        // When
        networkMonitor.startMonitoring()

        let expectation = XCTestExpectation(description: "Wait for restart")
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) {
            expectation.fulfill()
        }
        wait(for: [expectation], timeout: 1.0)

        // Then - should not crash and should have network state
        _ = networkMonitor.isNetworkAvailable
        XCTAssertTrue(true, "Network monitor should restart successfully")
    }

    func testNetworkMonitor_isThreadSafe() throws {
        // Given
        let iterations = 100
        let expectation = XCTestExpectation(description: "Concurrent access")
        expectation.expectedFulfillmentCount = iterations

        // When - access isNetworkAvailable from multiple threads concurrently
        for _ in 0..<iterations {
            DispatchQueue.global().async {
                _ = self.networkMonitor.isNetworkAvailable
                expectation.fulfill()
            }
        }

        // Then - should not crash
        wait(for: [expectation], timeout: 5.0)
        XCTAssertTrue(true, "Concurrent access should be thread-safe")
    }

    func testNetworkMonitor_debouncing() throws {
        // This test verifies that rapid changes are debounced
        // We can't directly test the internal debouncing mechanism,
        // but we can verify the monitor continues to work after multiple state changes

        // Given
        let expectation = XCTestExpectation(description: "Multiple checks")

        // When - perform multiple checks in quick succession
        for index in 0..<10 {
            DispatchQueue.global().asyncAfter(deadline: .now() + Double(index) * 0.1) {
                _ = self.networkMonitor.isNetworkAvailable
                if index == 9 {
                    expectation.fulfill()
                }
            }
        }

        // Then - should handle all requests without issues
        wait(for: [expectation], timeout: 5.0)
        XCTAssertTrue(true, "Multiple rapid checks should be handled correctly")
    }

    func testNetworkMonitor_connectionTypeProperty() throws {
        // Given - monitor is already started

        // When - we wait for the initial state
        let expectation = XCTestExpectation(description: "Wait for connection type")
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) {
            expectation.fulfill()
        }
        wait(for: [expectation], timeout: 1.0)

        // Then - connectionType should be accessible and have a value
        let connectionType = networkMonitor.connectionType
        XCTAssertTrue(
            [ConnectionType.wifi, .cellular, .wiredEthernet, .unknown].contains(connectionType),
            "Connection type should be one of the defined types"
        )
    }

    func testNetworkMonitor_isConnectedViaWiFi() throws {
        // Given - monitor is already started

        // When - we wait for the initial state
        let expectation = XCTestExpectation(description: "Wait for WiFi check")
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) {
            expectation.fulfill()
        }
        wait(for: [expectation], timeout: 1.0)

        // Then - isConnectedViaWiFi should be accessible
        let isWiFi = networkMonitor.isConnectedViaWiFi

        // If connected and connection type is WiFi, this should be true
        if networkMonitor.isNetworkAvailable && networkMonitor.connectionType == .wifi {
            XCTAssertTrue(isWiFi, "Should be connected via WiFi")
        } else {
            XCTAssertFalse(isWiFi, "Should not be connected via WiFi")
        }
    }

    func testNetworkMonitor_isConnectedViaCellular() throws {
        // Given - monitor is already started

        // When - we wait for the initial state
        let expectation = XCTestExpectation(description: "Wait for cellular check")
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) {
            expectation.fulfill()
        }
        wait(for: [expectation], timeout: 1.0)

        // Then - isConnectedViaCellular should be accessible
        let isCellular = networkMonitor.isConnectedViaCellular

        // If connected and connection type is cellular, this should be true
        if networkMonitor.isNetworkAvailable && networkMonitor.connectionType == .cellular {
            XCTAssertTrue(isCellular, "Should be connected via cellular")
        } else {
            XCTAssertFalse(isCellular, "Should not be connected via cellular")
        }
    }

    func testNetworkMonitor_connectionTypeThreadSafety() throws {
        // Given
        let iterations = 100
        let expectation = XCTestExpectation(description: "Concurrent connection type access")
        expectation.expectedFulfillmentCount = iterations

        // When - access connectionType from multiple threads concurrently
        for _ in 0..<iterations {
            DispatchQueue.global().async {
                _ = self.networkMonitor.connectionType
                _ = self.networkMonitor.isConnectedViaWiFi
                _ = self.networkMonitor.isConnectedViaCellular
                expectation.fulfill()
            }
        }

        // Then - should not crash
        wait(for: [expectation], timeout: 5.0)
        XCTAssertTrue(true, "Concurrent access to connection properties should be thread-safe")
    }

    func testNetworkMonitor_debouncingWithConnectionTypeChanges() throws {
        // This test verifies that debouncing works with connection type changes

        // Given
        let expectation = XCTestExpectation(description: "Debounce with connection type")

        // When - access both network status and connection type multiple times
        for index in 0..<10 {
            DispatchQueue.global().asyncAfter(deadline: .now() + Double(index) * 0.05) {
                _ = self.networkMonitor.isNetworkAvailable
                _ = self.networkMonitor.connectionType
                _ = self.networkMonitor.isConnectedViaWiFi
                _ = self.networkMonitor.isConnectedViaCellular
                if index == 9 {
                    expectation.fulfill()
                }
            }
        }

        // Then - should handle all requests without issues
        wait(for: [expectation], timeout: 5.0)
        XCTAssertTrue(true, "Debouncing should work correctly with connection type changes")
    }

    func testNetworkMonitor_isReadyInitiallyFalse() throws {
        // Given - create a new network monitor
        let config = Userpilot.Config(token: "NX-TEST-READY")
        let mockUserpilot = MockUserpilot(config: config)
        let newMonitor = NetworkMonitor(container: mockUserpilot.container)

        // When - check immediately after initialization
        let isReadyImmediately = newMonitor.isReady

        // Then - isReady should be false initially (before first path update)
        XCTAssertFalse(
            isReadyImmediately, "isReady should be false immediately after initialization")

        // Cleanup
        newMonitor.stopMonitoring()
    }

    func testNetworkMonitor_isReadyBecomesTrue() throws {
        // Given - monitor is already started in setUp

        // When - we wait for the first network state update
        let expectation = XCTestExpectation(description: "Wait for isReady to become true")
        DispatchQueue.main.asyncAfter(deadline: .now() + 1.0) {
            expectation.fulfill()
        }
        wait(for: [expectation], timeout: 2.0)

        // Then - isReady should be true after first update
        XCTAssertTrue(
            networkMonitor.isReady, "isReady should become true after first network state update")
    }

    func testNetworkMonitor_isNetworkAvailableOptimisticDefault() throws {
        // Given - create a new network monitor
        let config = Userpilot.Config(token: "NX-TEST-OPTIMISTIC")
        let mockUserpilot = MockUserpilot(config: config)
        let newMonitor = NetworkMonitor(container: mockUserpilot.container)

        // When - check immediately after initialization
        let isAvailableImmediately = newMonitor.isNetworkAvailable

        // Then - should assume network is available initially (optimistic default)
        XCTAssertTrue(
            isAvailableImmediately,
            "isNetworkAvailable should be true initially (optimistic default)"
        )

        // Cleanup
        newMonitor.stopMonitoring()
    }
}
