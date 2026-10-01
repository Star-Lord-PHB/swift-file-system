import PlatformCLib
import CFileSystem
import SystemPackage


extension InternalFS {

    package static func makeRandomTmpName(in dirPath: FilePath, prefix: FilePath.Component) -> FilePath {

        #if canImport(WinSDK)
        let pid = GetCurrentProcessId()
        #else 
        let pid = getpid()
        #endif
        // ASCII only: every character is a single code unit in both UTF-8 and UTF-16
        let suffix = ".tmp-\(pid)-\(String(UInt64.random(in: 0 ... .max), radix: 16))"

        #if canImport(WinSDK)
        let path = dirPath.appending(prefix)
        let pathCount = path.length
        let suffixBytes = suffix.utf8Span.span
        return withUnsafeTemporaryAllocation(of: WCHAR.self, capacity: pathCount + suffixBytes.count + 1) { buffer in
            path.withPlatformString { buffer.baseAddress!.initialize(from: $0, count: pathCount) }
            for i in suffixBytes.indices {
                buffer.initializeElement(at: pathCount + i, to: WCHAR(suffixBytes[i]))
            }
            buffer.initializeElement(at: pathCount + suffixBytes.count, to: 0)
            return FilePath(platformString: buffer.baseAddress!)
        }
        #else
        return withCString(dirPath.appending(prefix), appending: suffix) { FilePath(platformString: $0) }
        #endif

    }


    package static func makeRandomTmpName(baseOn path: FilePath) -> FilePath {
        assert(path.lastComponent != nil, "base path for temp file name must not be empty")
        return makeRandomTmpName(in: path.removingLastComponent(), prefix: path.lastComponent!)
    }


    package struct TmpFileResult: ~Copyable {
        package let path: FilePath
        package let handle: UnsafeSystemHandle
        package consuming func takeHandle() -> UnsafeSystemHandle {
            return handle
        }
    }


    package static func makeTmpFile(in dirPath: FilePath, prefix: FilePath.Component) throws(LowLevelError) -> TmpFileResult {

        #if canImport(WinSDK)

        for _ in 0 ..< 24 {
            
            let tmpPath = makeRandomTmpName(in: dirPath, prefix: prefix)

            do {
                let handle = try UnsafeSystemHandle.open(
                    at: tmpPath, 
                    openOptions: .init(access: .readWrite, creation: .assertMissing)
                )
                return .init(path: tmpPath, handle: handle)
            } catch let error where error.kind == .alreadyExists {
                // try again
                continue
            }

        }

        throw .init(kind: .alreadyExists)

        #else

        let (fd, tmpPath) = withCString(dirPath.appending(prefix), appending: ".tmp-XXXXXX") { template in
            let fd = mkstemp(template)
            return (fd, fd >= 0 ? FilePath(platformString: template) : nil)
        }

        guard fd >= 0, let tmpPath else {
            try LowLevelError.assertError()
        }

        return .init(path: tmpPath, handle: .init(owningRawHandle: fd))

        #endif 

    }


    package static func makeTmpFile(baseOn path: FilePath) throws(LowLevelError) -> TmpFileResult {

        assert(path.lastComponent != nil, "base path for temp file must not be empty")
        return try makeTmpFile(in: path.removingLastComponent(), prefix: path.lastComponent!)

    }


    #if !canImport(WinSDK)
    /// Calls `body` with a temporary, mutable C string made of the bytes of `path` copied as-is (keeping
    /// names that are not valid UTF-8 intact), followed by `suffix`.
    private static func withCString<R>(
        _ path: FilePath, 
        appending suffix: String, 
        _ body: (UnsafeMutablePointer<CChar>) -> R
    ) -> R {
        let pathCount = path.length
        let suffixCount = suffix.utf8.count
        return withUnsafeTemporaryAllocation(of: CChar.self, capacity: pathCount + suffixCount + 1) { buffer in
            let str = buffer.baseAddress!
            path.withPlatformString { str.initialize(from: $0, count: pathCount) }
            // the suffix is copied together with its null terminator
            suffix.withCString { (str + pathCount).initialize(from: $0, count: suffixCount + 1) }
            return body(str)
        }
    }
    #endif

}
