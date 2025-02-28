//
// Copyright Amazon.com Inc. or its affiliates.
// All Rights Reserved.
//
// SPDX-License-Identifier: Apache-2.0
//

import Foundation

/// A `Stream` that wraps a `FileHandle`.
/// - Note: This class is thread-safe.
class FileStream: Stream {
    /// Returns the length of the stream, if known
    var length: Int? {
        guard let len = try? fileHandle.length() else {
            return nil
        }
        return Int(len)
    }

    let fileHandle: FileHandle

    /// Returns the current position of the stream.
    var position: Data.Index

    /// Returns true if length is zero, false otherwise.
    var isEmpty: Bool {
        return length == 0
    }

    /// Returns true if the stream is seekable, false otherwise
    let isSeekable: Bool = true

    private let lock = NSRecursiveLock()

    /// Initializes a new `FileStream` instance.
    init(fileHandle: FileHandle) {
        self.fileHandle = fileHandle
        self.position = fileHandle.availableData.startIndex
    }

    /// Reads up to `count` bytes from the stream.
    /// - Parameter count: The maximum number of bytes to read.
    /// - Returns: Data read from the stream, or nil if the stream is closed and no data is available.
    func read(upToCount count: Int) throws -> Data? {
        try lock.withLockingClosure {
            let data: Data?
            if #available(macOS 11, tvOS 13.4, iOS 13.4, watchOS 6.2, *) {
                data = try fileHandle.read(upToCount: count)
            } else {
                data = fileHandle.readData(ofLength: count)
            }
            position = position.advanced(by: data?.count ?? 0)
            return data
        }
    }

    func readAsync(upToCount count: Int) async throws -> Data? {
        try await withCheckedThrowingContinuation { continuation in
            do {
                let data = try read(upToCount: count)
                continuation.resume(returning: data)
            } catch {
                continuation.resume(throwing: error)
            }
        }
    }

    /// Reads all remaining bytes from the stream.
    /// - Returns: Data read from the stream, or nil if the stream is closed and no data is available.
    func readToEnd() throws -> Data? {
        try lock.withLockingClosure {
            let data: Data?
            if #available(macOS 11, tvOS 13.4, iOS 13.4, watchOS 6.2, *) {
                data = try fileHandle.readToEnd()
            } else {
                data = fileHandle.readDataToEndOfFile()
            }
            position = position.advanced(by: data?.count ?? 0)
            return data
        }
    }

    func readToEndAsync() async throws -> Data? {
        try await withCheckedThrowingContinuation { continuation in
            do {
                let data = try readToEnd()
                continuation.resume(returning: data)
            } catch {
                continuation.resume(throwing: error)
            }
        }
    }

    /// Seeks to the specified offset in the stream.
    /// - Parameter offset: The offset to seek to.
    func seek(toOffset offset: Int) throws {
        try lock.withLockingClosure {
            if #available(macOS 11, tvOS 13.4, iOS 13.4, watchOS 6.2, *) {
                try fileHandle.seek(toOffset: UInt64(offset))
            } else {
                fileHandle.seek(toFileOffset: UInt64(offset))
            }
            position = offset
        }
    }

    /// Writes the specified data to the stream.
    /// - Parameter data: The data to write.
    func write(contentsOf data: Data) throws {
        try lock.withLockingClosure {
            if #available(macOS 11, tvOS 13.4, iOS 13.4, watchOS 6.2, *) {
                try fileHandle.write(contentsOf: data)
            } else {
                fileHandle.write(data)
            }
        }
    }

    /// Closes the stream.
    func close() throws {
       try lock.withLockingClosure {
           if #available(macOS 11, tvOS 13.4, iOS 13.4, watchOS 6.2, *) {
               try fileHandle.close()
           } else {
               fileHandle.closeFile()
           }
        }
    }
}
