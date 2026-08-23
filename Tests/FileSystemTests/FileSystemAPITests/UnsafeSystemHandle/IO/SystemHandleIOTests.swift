import Testing



extension UnsafeSystemHandleAPITests {

    /// Synchronous I/O on `UnsafeSystemHandle`: read/write and their positional variants across
    /// the three buffer shapes (raw buffer pointer, rebased slice, span), seek/tell, truncation
    /// and fsync.
    ///
    /// Positional I/O is exercised on synchronous handles only: on Windows, `pread`/`pwrite` are
    /// documented as invalid for handles opened with `noBlocking` (FILE_FLAG_OVERLAPPED), whose
    /// I/O lives in the Windows overlapped suite instead.
    @Suite("IO")
    struct IOTests {

        typealias Support = UnsafeSystemHandleAPITests.Support

        let workspace: Support.Workspace


        init() throws {
            workspace = try Support.Workspace()
        }

    }

}
