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
        let lastComponent = FilePath.Component("\(prefix).tmp-\(pid)-\(String(UInt64.random(in: 0 ... .max), radix: 16))")!
        return dirPath.appending(lastComponent)

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
                    openOptions: .init(access: .readWrite(), creation: .assertMissing)
                )
                return .init(path: tmpPath, handle: handle)
            } catch let error where error.kind == .alreadyExists {
                // try again
                continue
            }

        }

        throw .init(kind: .alreadyExists)

        #else

        var pathBuffer = (dirPath.string + "/\(prefix).tmp-XXXXXX").utf8CString

        let fd = pathBuffer.withUnsafeMutableBufferPointer { strPtr in 
            mkstemp(strPtr.baseAddress!)
        }

        guard fd >= 0 else {
            try LowLevelError.assertError()
        }

        let tmpPath = pathBuffer.withUnsafeBufferPointer { FilePath(platformString: $0.baseAddress!) }

        return .init(path: tmpPath, handle: .init(owningRawHandle: fd))

        #endif 

    }


    package static func makeTmpFile(baseOn path: FilePath) throws(LowLevelError) -> TmpFileResult {

        assert(path.lastComponent != nil, "base path for temp file must not be empty")
        return try makeTmpFile(in: path.removingLastComponent(), prefix: path.lastComponent!)

    }

}