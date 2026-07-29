import protocol Foundation.ContiguousBytes
import struct SwiftFileSystem.WriteFileHandle
import struct SwiftFileSystem.ReadWriteFileHandle
import struct SwiftFileSystem.PlatformError
import struct SwiftFileSystem.LowLevelError
import func SwiftFileSystem.catchLowLevelError

#if canImport(WinSDK)
import struct SwiftFileSystem.WindowsOverlapped
#endif



extension WriteFileHandle {
    
    public func write(_ data: some ContiguousBytes, toOffset offset: Int64?) throws(PlatformError) -> Int64 {
        
        #if canImport(WinSDK)
        
        return try data.withUnsafeBytesTypedThrow { (bufferPtr) throws(PlatformError) in
            let currentOffset = try self.currentOffset    // On Windows, accessing the currentOffset is not a blocking FS operation
            let bytesWritten = try catchLowLevelError(operation: .writeHandle(originalPath: path)) { () throws(LowLevelError) in
                try withUnsafeSystemHandle { (handle) throws(LowLevelError) in
                    if let offset {
                        var overlapped = WindowsOverlapped(offset: offset)
                        let pendingOverlapped = try handle.write(contentsOf: bufferPtr, overlapped: &overlapped)
                        return try handle.waitForOverlappedResult(pendingOverlapped)
                    } else {
                        var overlapped = WindowsOverlapped(offset: currentOffset)
                        let pendingOverlapped = try handle.write(contentsOf: bufferPtr, overlapped: &overlapped)
                        let bytesWritten = try handle.waitForOverlappedResult(pendingOverlapped)
                        return Int64(bytesWritten)
                    }
                }
            }
            if offset == nil {
                try seek(to: Int64(bytesWritten), relativeTo: .current)     // On Windows, this `seek` operation is not a blocking FS operation
            }
            return bytesWritten
        }
        
        #else
        
        return try data.withUnsafeBytesTypedThrow { bufferPtr throws(PlatformError) in
            try catchLowLevelError(operation: .writeHandle(originalPath: path)) { () throws(LowLevelError) in
                try withUnsafeSystemHandle { (handle) throws(LowLevelError) in
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
            let currentOffset = try self.currentOffset    // On Windows, accessing the currentOffset is not a blocking FS operation
            let bytesWritten = try catchLowLevelError(operation: .writeHandle(originalPath: path)) { () throws(LowLevelError) in
                try withUnsafeSystemHandle { (handle) throws(LowLevelError) in
                    if let offset {
                        var overlapped = WindowsOverlapped(offset: offset)
                        let pendingOverlapped = try handle.write(contentsOf: bufferPtr, overlapped: &overlapped)
                        return try handle.waitForOverlappedResult(pendingOverlapped)
                    } else {
                        var overlapped = WindowsOverlapped(offset: currentOffset)
                        let pendingOverlapped = try handle.write(contentsOf: bufferPtr, overlapped: &overlapped)
                        let bytesWritten = try handle.waitForOverlappedResult(pendingOverlapped)
                        return Int64(bytesWritten)
                    }
                }
            }
            if offset == nil {
                try seek(to: Int64(bytesWritten), relativeTo: .current)     // On Windows, this `seek` operation is not a blocking FS operation
            }
            return bytesWritten
        }
        
        #else
        
        return try data.withUnsafeBytesTypedThrow { bufferPtr throws(PlatformError) in
            try catchLowLevelError(operation: .writeHandle(originalPath: path)) { () throws(LowLevelError) in
                try withUnsafeSystemHandle { (handle) throws(LowLevelError) in
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
