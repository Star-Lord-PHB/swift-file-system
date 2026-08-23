#if canImport(WinSDK)

import PlatformCLib
import Testing
import SwiftFileSystem



extension FileInfoAPITests.PlatformFileAttributeTests {

    @Suite("Windows")
    struct WindowsTests {}

}



extension FileInfoAPITests.PlatformFileAttributeTests.WindowsTests {

    @Test(
        arguments: [
            (.windows.isReadOnly, DWORD(FILE_ATTRIBUTE_READONLY)),
            (.windows.isHidden, DWORD(FILE_ATTRIBUTE_HIDDEN)),
            (.windows.isSystem, DWORD(FILE_ATTRIBUTE_SYSTEM)),
            (.windows.isDirectory, DWORD(FILE_ATTRIBUTE_DIRECTORY)),
            (.windows.isArchive, DWORD(FILE_ATTRIBUTE_ARCHIVE)),
            (.windows.isDevice, DWORD(FILE_ATTRIBUTE_DEVICE)),
            (.windows.isNormal, DWORD(FILE_ATTRIBUTE_NORMAL)),
            (.windows.isTemporary, DWORD(FILE_ATTRIBUTE_TEMPORARY)),
            (.windows.isSparseFile, DWORD(FILE_ATTRIBUTE_SPARSE_FILE)),
            (.windows.isReparsePoint, DWORD(FILE_ATTRIBUTE_REPARSE_POINT)),
            (.windows.isCompressed, DWORD(FILE_ATTRIBUTE_COMPRESSED)),
            (.windows.isOffline, DWORD(FILE_ATTRIBUTE_OFFLINE)),
            (.windows.isNotContentIndexed, DWORD(FILE_ATTRIBUTE_NOT_CONTENT_INDEXED)),
            (.windows.isEncrypted, DWORD(FILE_ATTRIBUTE_ENCRYPTED)),
            (.windows.isIntegrityStream, DWORD(FILE_ATTRIBUTE_INTEGRITY_STREAM)),
            (.windows.isVirtual, DWORD(FILE_ATTRIBUTE_VIRTUAL)),
            (.windows.isNoScrubData, DWORD(FILE_ATTRIBUTE_NO_SCRUB_DATA)),
            (.windows.isPinned, DWORD(FILE_ATTRIBUTE_PINNED)),
            (.windows.isUnpinned, DWORD(FILE_ATTRIBUTE_UNPINNED)),
            (.windows.recallOnOpen, DWORD(FILE_ATTRIBUTE_RECALL_ON_OPEN)),
            (.windows.recallOnDataAccess, DWORD(FILE_ATTRIBUTE_RECALL_ON_DATA_ACCESS))
        ] as [(PlatformFileAttributes, PlatformInteropTypes.FileAttribute)]
    )
    func `Windows attributes map to native flags`(
        _ attribute: PlatformFileAttributes,
        _ rawValue: PlatformInteropTypes.FileAttribute
    ) {

        #expect(attribute.rawValue == rawValue)

    }


    @Test
    func `All contains every Windows attribute`() {

        let expected: PlatformFileAttributes = [
            .windows.isReadOnly, .windows.isHidden, .windows.isSystem,
            .windows.isDirectory, .windows.isArchive, .windows.isDevice,
            .windows.isNormal, .windows.isTemporary, .windows.isSparseFile,
            .windows.isReparsePoint, .windows.isCompressed, .windows.isOffline,
            .windows.isNotContentIndexed, .windows.isEncrypted,
            .windows.isIntegrityStream, .windows.isVirtual,
            .windows.isNoScrubData, .windows.isPinned, .windows.isUnpinned,
            .windows.recallOnOpen, .windows.recallOnDataAccess
        ]

        #expect(PlatformFileAttributes.all == expected)

    }


    @Test
    func `Current platform namespace matches Windows`() {

        #expect(PlatformFileAttributes.currentPlatform.isHidden == .windows.isHidden)

    }


    @Test
    func `isReadOnly accessor updates Windows flag`() {

        var attributes: PlatformFileAttributes = []

        #expect(attributes.isReadOnly == false)

        attributes.isReadOnly = true

        #expect(attributes.contains(.windows.isReadOnly))
        #expect(attributes.isReadOnly == true)

        let readOnlyAttributes = attributes
        attributes.isReadOnly = nil

        #expect(attributes == readOnlyAttributes)

        attributes.isReadOnly = false

        #expect(!attributes.contains(.windows.isReadOnly))
        #expect(attributes.isReadOnly == false)

    }


    @Test
    func `isImmutable and isAppendOnly accessors return nil and ignore mutations on Windows`() {

        var attributes: PlatformFileAttributes = [.windows.isHidden]
        let original = attributes

        #expect(attributes.isImmutable == nil)
        #expect(attributes.isAppendOnly == nil)

        attributes.isImmutable = true
        attributes.isAppendOnly = true
        #expect(attributes == original)

        attributes.isImmutable = false
        attributes.isAppendOnly = false
        #expect(attributes == original)

        attributes.isImmutable = nil
        attributes.isAppendOnly = nil
        #expect(attributes == original)

    }


    @Test
    func `isCompressed and isEncrypted accessors reflect Windows flags`() {

        var attributes: PlatformFileAttributes = []

        #expect(attributes.isCompressed == false)
        #expect(attributes.isEncrypted == false)

        attributes.insert(.windows.isCompressed)
        attributes.insert(.windows.isEncrypted)

        #expect(attributes.isCompressed == true)
        #expect(attributes.isEncrypted == true)

    }
}

#endif
