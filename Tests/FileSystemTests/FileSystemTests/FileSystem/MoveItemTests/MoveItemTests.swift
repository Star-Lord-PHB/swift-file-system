import Testing
import SystemPackage
import Foundation
@testable import SwiftFileSystem
@testable import FileSystemCore



extension FileSystemTest {

    final class MoveItemTest: FSIsolatedTestCase {}

}



extension FileSystemTest.MoveItemTest {

    /// Exclusions for an expectation whose item replaces an existing destination.
    ///
    /// On Windows, NTFS file-name tunneling can nondeterministically give the new entry
    /// the replaced entry's creation time, so replace moves do not pin it there.
    var replacedItemExclusions: ExpectationCriterias {
        #if canImport(WinSDK)
        [.creationTime]
        #else
        []
        #endif
    }

}