#if canImport(Glibc) || canImport(Musl)

import CFileSystem
import PlatformCLib
import Testing
import SwiftFileSystem



extension FileInfoAPITests.PlatformFileAttributeTests {

    @Suite("Linux")
    struct LinuxTests {}

}



extension FileInfoAPITests.PlatformFileAttributeTests.LinuxTests {

    @Test(
        arguments: [
            (.linux.isCompressed, .init(STATX_ATTR_COMPRESSED)),
            (.linux.isImmutable, .init(STATX_ATTR_IMMUTABLE)),
            (.linux.isAppendOnly, .init(STATX_ATTR_APPEND)),
            (.linux.noDump, .init(STATX_ATTR_NODUMP)),
            (.linux.isEncrypted, .init(STATX_ATTR_ENCRYPTED)),
            (.linux.isAutoMount, .init(STATX_ATTR_AUTOMOUNT)),
            (.linux.isMountRoot, .init(STATX_ATTR_MOUNT_ROOT)),
            (.linux.isVerityProtected, .init(STATX_ATTR_VERITY)),
            (.linux.isWriteAtomic, .init(STATX_ATTR_WRITE_ATOMIC)),
            (.linux.isDAX, .init(STATX_ATTR_DAX))
        ] as [(PlatformFileAttributes, PlatformInteropTypes.FileAttribute)]
    )
    func `Linux attributes map to statx flags`(
        _ attribute: PlatformFileAttributes,
        _ rawValue: PlatformInteropTypes.FileAttribute
    ) {

        #expect(attribute.rawValue == rawValue)

    }


    @Test
    func `All contains every Linux attribute`() {

        let expected: PlatformFileAttributes = [
            .linux.isCompressed, .linux.isImmutable, .linux.isAppendOnly,
            .linux.noDump, .linux.isEncrypted, .linux.isAutoMount,
            .linux.isMountRoot, .linux.isVerityProtected, .linux.isWriteAtomic,
            .linux.isDAX
        ]

        #expect(PlatformFileAttributes.all == expected)

    }


    @Test
    func `Current platform namespace matches Linux`() {

        #expect(PlatformFileAttributes.currentPlatform.noDump == .linux.noDump)

    }


    @Test
    func `isImmutable accessor updates Linux flag`() {

        var attributes: PlatformFileAttributes = []

        #expect(attributes.isImmutable == false)

        attributes.isImmutable = true

        #expect(attributes.contains(.linux.isImmutable))
        #expect(attributes.isImmutable == true)

        let immutableAttributes = attributes
        attributes.isImmutable = nil

        #expect(attributes == immutableAttributes)

        attributes.isImmutable = false

        #expect(!attributes.contains(.linux.isImmutable))
        #expect(attributes.isImmutable == false)

    }


    @Test
    func `isAppendOnly accessor updates Linux flag`() {

        var attributes: PlatformFileAttributes = []

        #expect(attributes.isAppendOnly == false)

        attributes.isAppendOnly = true

        #expect(attributes.contains(.linux.isAppendOnly))
        #expect(attributes.isAppendOnly == true)

        let appendOnlyAttributes = attributes
        attributes.isAppendOnly = nil

        #expect(attributes == appendOnlyAttributes)

        attributes.isAppendOnly = false

        #expect(!attributes.contains(.linux.isAppendOnly))
        #expect(attributes.isAppendOnly == false)

    }


    @Test
    func `isReadOnly accessor returns nil and ignores mutations on Linux`() {

        var attributes: PlatformFileAttributes = [.linux.noDump]
        let original = attributes

        #expect(attributes.isReadOnly == nil)

        attributes.isReadOnly = true
        #expect(attributes == original)

        attributes.isReadOnly = false
        #expect(attributes == original)

        attributes.isReadOnly = nil
        #expect(attributes == original)

    }


    @Test
    func `isCompressed and isEncrypted accessors reflect Linux flags`() {

        var attributes: PlatformFileAttributes = []

        #expect(attributes.isCompressed == false)
        #expect(attributes.isEncrypted == false)

        attributes.insert(.linux.isCompressed)
        attributes.insert(.linux.isEncrypted)

        #expect(attributes.isCompressed == true)
        #expect(attributes.isEncrypted == true)

    }

}

#endif
