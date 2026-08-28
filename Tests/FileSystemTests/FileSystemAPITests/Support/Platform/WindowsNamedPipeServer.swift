#if canImport(WinSDK)

import WinSDK
import SystemPackage



extension FileSystemTestSupport {

    /// A minimal single-instance byte-mode named-pipe server for streaming-handle tests.
    ///
    /// The pipe name is derived from the given unique token (typically the workspace root's
    /// directory name, which already carries the test name, process ID and an atomic counter).
    /// The server end never goes through the library under test.
    final class WindowsNamedPipeServer {

        struct ServerError: Error {
            let operation: String
            let code: DWORD
        }


        let path: FilePath

        private var serverHandle: HANDLE?


        init(uniqueToken: String) throws {
            let name = #"\\.\pipe\"# + uniqueToken
            let handle = CreateNamedPipeA(
                name,
                DWORD(PIPE_ACCESS_DUPLEX),
                DWORD(PIPE_TYPE_BYTE | PIPE_WAIT),
                1,
                4096,
                4096,
                0,
                nil
            )
            guard let handle, handle != INVALID_HANDLE_VALUE else {
                throw ServerError(operation: "CreateNamedPipe", code: GetLastError())
            }
            self.serverHandle = handle
            self.path = FilePath(name)
        }


        func write(_ bytes: [UInt8]) throws {
            var written = 0 as DWORD
            var bytes = bytes
            guard WriteFile(serverHandle, &bytes, DWORD(bytes.count), &written, nil) else {
                throw ServerError(operation: "WriteFile", code: GetLastError())
            }
        }


        func read(upTo count: Int) throws -> [UInt8] {
            var buffer = [UInt8](repeating: 0, count: count)
            var bytesRead = 0 as DWORD
            let succeeded = buffer.withUnsafeMutableBytes {
                ReadFile(serverHandle, $0.baseAddress, DWORD(count), &bytesRead, nil)
            }
            guard succeeded else {
                throw ServerError(operation: "ReadFile", code: GetLastError())
            }
            return Array(buffer[..<Int(bytesRead)])
        }


        /// Forcefully disconnects the client; a client read then fails with
        /// ERROR_PIPE_NOT_CONNECTED and buffered data is discarded.
        func disconnect() {
            DisconnectNamedPipe(serverHandle)
        }


        /// Closes the server end; a client drains any buffered data and then reads
        /// ERROR_BROKEN_PIPE.
        func close() {
            if let serverHandle {
                CloseHandle(serverHandle)
            }
            serverHandle = nil
        }


        deinit {
            close()
        }

    }

}

#endif
