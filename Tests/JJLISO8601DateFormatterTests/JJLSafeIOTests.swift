// Copyright (c) 2018 Michael Eisel. All rights reserved.

import XCTest
import Foundation
import JJLInternal

// MARK: - SafeRead Tests

/// Test state shared with C callbacks
private let gReadData: [CChar] = [49, 50, 51, 52, 53, 0]  // "12345\0"
private let gReadDataLength = 6
private var gTotalAmountRead: Int = 0
private var gReadIndex: Int = 0
private let gUnrecoverableError: Int32 = EIO

private enum ReadBehavior {
    case normal
    case half
    case error
    case interrupted
}

private var gReadBehaviors: [ReadBehavior] = []

// The C callback for read injection
private let gNextRead: JJLReadFunction = { fd, buffer, nbytes in
    precondition(gReadIndex < gReadBehaviors.count, "Went too far in read sequence")
    let behavior = gReadBehaviors[gReadIndex]
    gReadIndex += 1
    
    switch behavior {
    case .normal:
        var bytesToRead = Int(nbytes)
        if bytesToRead + gTotalAmountRead > gReadDataLength {
            bytesToRead = gReadDataLength - gTotalAmountRead
        }
        if bytesToRead > 0, let buf = buffer {
            gReadData.withUnsafeBufferPointer { dataPtr in
                memcpy(buf, dataPtr.baseAddress! + gTotalAmountRead, bytesToRead)
            }
        }
        gTotalAmountRead += bytesToRead
        return ssize_t(bytesToRead)
        
    case .half:
        let bytesToRead = gReadDataLength / 2
        if let buf = buffer {
            gReadData.withUnsafeBufferPointer { dataPtr in
                memcpy(buf, dataPtr.baseAddress! + gTotalAmountRead, bytesToRead)
            }
        }
        gTotalAmountRead += bytesToRead
        return ssize_t(bytesToRead)
        
    case .error:
        errno = gUnrecoverableError
        return -1
        
    case .interrupted:
        errno = EINTR
        return -1
    }
}

final class JJLSafeReadTests: XCTestCase {
    
    override func setUp() {
        super.setUp()
        gTotalAmountRead = 0
        gReadIndex = 0
        gReadBehaviors = []
    }
    
    private func testWithReads(_ behaviors: [ReadBehavior], expectedErrno: Int32) {
        gReadBehaviors = behaviors
        gReadIndex = 0
        gTotalAmountRead = 0
        
        var buffer = [CChar](repeating: 0, count: gReadDataLength)
        
        buffer.withUnsafeMutableBufferPointer { bufferPtr in
            _ = JJLSafeReadInjection(0, bufferPtr.baseAddress, gReadDataLength, gNextRead)
        }
        
        XCTAssertEqual(gReadIndex, gReadBehaviors.count, "Not all reads were consumed")
        
        if expectedErrno == 0 {
            XCTAssertEqual(buffer, gReadData, "Buffer content mismatch")
        } else {
            XCTAssertEqual(errno, expectedErrno, "Errno mismatch")
        }
    }
    
    func testSafeRead() {
        // Test: half read + half read + normal read (returns 0 since all data read)
        testWithReads([.half, .half, .normal], expectedErrno: 0)
        
        // Test: normal read + normal read
        testWithReads([.normal, .normal], expectedErrno: 0)
        
        // Test: half read + interrupted + half read + normal read
        testWithReads([.half, .interrupted, .half, .normal], expectedErrno: 0)
        
        // Test: error read
        testWithReads([.error], expectedErrno: gUnrecoverableError)
        
        // Test: half read + error read
        testWithReads([.half, .error], expectedErrno: gUnrecoverableError)
    }
}

// MARK: - SafeOpen Tests

final class JJLSafeOpenTests: XCTestCase {
    
    private static let unrecoverableError: Int32 = EIO
    
    private static var openIndex: Int = 0
    private static var opens: [() -> Int32] = []
    
    override func setUp() {
        super.setUp()
        Self.openIndex = 0
        Self.opens = []
    }
    
    // Mock open functions
    private static func successfulOpen() -> Int32 {
        return 3 // A valid file descriptor
    }
    
    private static func interruptedOpen() -> Int32 {
        errno = EINTR
        return -1
    }
    
    private static func errorOpen() -> Int32 {
        errno = unrecoverableError
        return -1
    }
    
    // The C callback that dispatches to our mock functions
    private static let nextOpen: JJLOpenFunctionNonVariadic = { path, mode in
        precondition(openIndex < opens.count, "Went too far")
        let result = opens[openIndex]()
        openIndex += 1
        return result
    }
    
    private func testWithOpens(_ openFunctions: [() -> Int32], expectedErrno: Int32) {
        Self.opens = openFunctions
        Self.openIndex = 0
        
        let fd = JJLSafeOpenInjectionNonVariadic("", 0, Self.nextOpen)
        
        XCTAssertEqual(Self.openIndex, Self.opens.count)
        
        if expectedErrno == 0 {
            XCTAssertGreaterThan(fd, 0)
        } else {
            XCTAssertEqual(errno, expectedErrno)
        }
    }
    
    func testSafeOpen() {
        // Test: successful open
        testWithOpens([Self.successfulOpen], expectedErrno: 0)
        
        // Test: interrupted + successful
        testWithOpens([Self.interruptedOpen, Self.successfulOpen], expectedErrno: 0)
        
        // Test: interrupted + interrupted + error
        testWithOpens([Self.interruptedOpen, Self.interruptedOpen, Self.errorOpen], expectedErrno: Self.unrecoverableError)
        
        // Test: error
        testWithOpens([Self.errorOpen], expectedErrno: Self.unrecoverableError)
    }
}
