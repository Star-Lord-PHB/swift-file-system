import protocol Foundation.ContiguousBytes
import struct SwiftFileSystem.WriteFileHandle
import struct SwiftFileSystem.ReadWriteFileHandle
import struct SwiftFileSystem.PlatformError
import struct SwiftFileSystem.SystemError
import func SwiftFileSystem.catchSystemError



extension WriteFileHandle {
    
    public func write(_ data: some ContiguousBytes, toOffset offset: Int64?) throws(PlatformError) -> Int64 {
        
        #if canImport(WinSDK)
        
        return try data.withUnsafeBytesTypedThrow { (bufferPtr) throws(PlatformError) in
            try catchSystemError(operation: .writeHandle(originalPath: path)) { () throws(SystemError) in
                try withUnsafeSystemHandle { (handle) throws(SystemError) in
                    if let offset {
                        var overlapped = WindowsOverlapped(offset: offset)
                        let pendingOverlapped = try handle.write(contentsOf: bufferPtr, overlapped: &overlapped)
                        return try handle.waitForOverlappedResult(pendingOverlapped)
                    } else {
                        let currentOffset = self.currentOffset    // On Windows, accessing the currentOffset is not a blocking FS operation
                        var overlapped = WindowsOverlapped(offset: currentOffset)
                        let pendingOverlapped = try handle.write(contentsOf: bufferPtr, overlapped: &overlapped)
                        let bytesWritten = try handle.waitForOverlappedResult(pendingOverlapped)
                        try seek(to: Int64(bytesWritten), relativeTo: .current)     // On Windows, this `seek` operation is not a blocking FS operation
                        return Int64(bytesWritten)
                    }
                }
            }
        }
        
        #else
        
        return try data.withUnsafeBytesTypedThrow { bufferPtr throws(PlatformError) in
            try catchSystemError(operation: .writeHandle(originalPath: path)) { () throws(SystemError) in
                try withUnsafeSystemHandle { (handle) throws(SystemError) in
                    if let offset {
                        return try handle.pwrite(contentsOf: bufferPtr, to: offset)
                    } else {
                        return try handle.write(contentsOf: bufferPtr)
                    }
                }
            }
        }
        
        #endif
        
    }
    
    
    public func write(_ data: some ContiguousBytes) throws(PlatformError) -> Int64 {
        try write(data, toOffset: nil)
    }
    
}



extension ReadWriteFileHandle {
    
    public func write(_ data: some ContiguousBytes, toOffset offset: Int64?) throws(PlatformError) -> Int64 {
        
        #if canImport(WinSDK)
        
        return try data.withUnsafeBytesTypedThrow { (bufferPtr) throws(PlatformError) in
            try catchSystemError(operation: .writeHandle(originalPath: path)) { () throws(SystemError) in
                try withUnsafeSystemHandle { (handle) throws(SystemError) in
                    if let offset {
                        var overlapped = WindowsOverlapped(offset: offset)
                        let pendingOverlapped = try handle.write(contentsOf: bufferPtr, overlapped: &overlapped)
                        return try handle.waitForOverlappedResult(pendingOverlapped)
                    } else {
                        let currentOffset = self.currentOffset    // On Windows, accessing the currentOffset is not a blocking FS operation
                        var overlapped = WindowsOverlapped(offset: currentOffset)
                        let pendingOverlapped = try handle.write(contentsOf: bufferPtr, overlapped: &overlapped)
                        let bytesWritten = try handle.waitForOverlappedResult(pendingOverlapped)
                        try seek(to: Int64(bytesWritten), relativeTo: .current)     // On Windows, this `seek` operation is not a blocking FS operation
                        return Int64(bytesWritten)
                    }
                }
            }
        }
        
        #else
        
        return try data.withUnsafeBytesTypedThrow { bufferPtr throws(PlatformError) in
            try catchSystemError(operation: .writeHandle(originalPath: path)) { () throws(SystemError) in
                try withUnsafeSystemHandle { (handle) throws(SystemError) in
                    if let offset {
                        return try handle.pwrite(contentsOf: bufferPtr, to: offset)
                    } else {
                        return try handle.write(contentsOf: bufferPtr)
                    }
                }
            }
        }
        
        #endif
        
    }
    
    
    public func write(_ data: some ContiguousBytes) throws(PlatformError) -> Int64 {
        try write(data, toOffset: nil)
    }
    
}
