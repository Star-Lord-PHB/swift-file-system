import Testing



extension FileSystemAPITests {

    @Suite("Move")
    struct MoveTests {}

}



// Helpers shared by more than one move suite.
extension FileSystemAPITests.MoveTests {

    /// Policy for an item that replaced an existing destination entry.
    ///
    /// On Windows, NTFS file-name tunneling can nondeterministically give the new entry
    /// the replaced entry's creation time, so replace moves do not promise it there.
    static var replacedItemPolicy: FileSystemTestSupport.ItemComparisonPolicy {
        #if canImport(WinSDK)
        .movedItem.excluding(.creationTime)
        #else
        .movedItem
        #endif
    }

}
