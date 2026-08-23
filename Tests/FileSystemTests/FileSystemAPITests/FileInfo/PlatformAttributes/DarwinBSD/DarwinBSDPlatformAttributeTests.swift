#if canImport(Darwin) || os(FreeBSD) || os(OpenBSD)

import PlatformCLib
import Testing
import SwiftFileSystem



extension FileInfoAPITests.PlatformFileAttributeTests {

    @Suite("Darwin and BSD")
    struct DarwinBSDTests {}

}



extension FileInfoAPITests.PlatformFileAttributeTests.DarwinBSDTests {

    @Test(
        arguments: [
            (.bsd.noDump, .init(UF_NODUMP)),
            (.bsd.isUserImmutable, .init(UF_IMMUTABLE)),
            (.bsd.isUserAppendOnly, .init(UF_APPEND)),
            (.bsd.isArchived, .init(SF_ARCHIVED)),
            (.bsd.isSystemImmutable, .init(SF_IMMUTABLE)),
            (.bsd.isSystemAppendOnly, .init(SF_APPEND))
        ] as [(PlatformFileAttributes, PlatformInteropTypes.FileAttribute)]
    )
    func `BSD attributes map to native flags`(
        _ attribute: PlatformFileAttributes,
        _ rawValue: PlatformInteropTypes.FileAttribute
    ) {

        #expect(attribute.rawValue == rawValue)

    }


    @Test
    func `Current platform namespace matches the native namespace`() {

        #if canImport(Darwin)
        #expect(PlatformFileAttributes.currentPlatform.noDump == .darwin.noDump)
        #elseif os(FreeBSD)
        #expect(PlatformFileAttributes.currentPlatform.noDump == .freebsd.noDump)
        #elseif os(OpenBSD)
        #expect(PlatformFileAttributes.currentPlatform.noDump == .openbsd.noDump)
        #endif

    }


    @Test
    func `All contains every native attribute`() {

        #if canImport(Darwin)
        let expected: PlatformFileAttributes = [
            .darwin.noDump, .darwin.isUserImmutable, .darwin.isUserAppendOnly,
            .darwin.isArchived, .darwin.isSystemImmutable, .darwin.isSystemAppendOnly,
            .darwin.isHidden, .darwin.isOpaque, .darwin.systemNoUnlink,
            .darwin.isCompressed, .darwin.isTracked, .darwin.isDataVault,
            .darwin.isRestricted, .darwin.isFirmLink, .darwin.isDataLess
        ]
        #elseif os(FreeBSD)
        let expected: PlatformFileAttributes = [
            .freebsd.noDump, .freebsd.isUserImmutable, .freebsd.isUserAppendOnly,
            .freebsd.isArchived, .freebsd.isSystemImmutable, .freebsd.isSystemAppendOnly,
            .freebsd.isHidden, .freebsd.isOpaque, .freebsd.systemNoUnlink,
            .freebsd.userNoUnlink, .freebsd.isOffline, .freebsd.isReadOnly,
            .freebsd.isReparse, .freebsd.isSparse, .freebsd.isSystem,
            .freebsd.isSnapshot
        ]
        #elseif os(OpenBSD)
        let expected: PlatformFileAttributes = [
            .openbsd.noDump, .openbsd.isUserImmutable, .openbsd.isUserAppendOnly,
            .openbsd.isArchived, .openbsd.isSystemImmutable, .openbsd.isSystemAppendOnly
        ]
        #endif

        #expect(PlatformFileAttributes.all == expected)

    }


    @Test
    func `isImmutable accessor handles BSD user and system flags`() {

        var attributes: PlatformFileAttributes = []

        #expect(attributes.isImmutable == false)

        attributes.isImmutable = true

        #expect(attributes.contains(.bsd.isUserImmutable))
        #expect(!attributes.contains(.bsd.isSystemImmutable))
        #expect(attributes.isImmutable == true)

        let userImmutableAttributes = attributes
        attributes.isImmutable = nil

        #expect(attributes == userImmutableAttributes)

        attributes.remove(.bsd.isUserImmutable)
        attributes.insert(.bsd.isSystemImmutable)

        #expect(attributes.isImmutable == true)

        attributes.isImmutable = false

        #expect(!attributes.contains(.bsd.isUserImmutable))
        #expect(!attributes.contains(.bsd.isSystemImmutable))
        #expect(attributes.isImmutable == false)

    }


    @Test
    func `isAppendOnly accessor handles BSD user and system flags`() {

        var attributes: PlatformFileAttributes = []

        #expect(attributes.isAppendOnly == false)

        attributes.isAppendOnly = true

        #expect(attributes.contains(.bsd.isUserAppendOnly))
        #expect(!attributes.contains(.bsd.isSystemAppendOnly))
        #expect(attributes.isAppendOnly == true)

        let userAppendOnlyAttributes = attributes
        attributes.isAppendOnly = nil

        #expect(attributes == userAppendOnlyAttributes)

        attributes.remove(.bsd.isUserAppendOnly)
        attributes.insert(.bsd.isSystemAppendOnly)

        #expect(attributes.isAppendOnly == true)

        attributes.isAppendOnly = false

        #expect(!attributes.contains(.bsd.isUserAppendOnly))
        #expect(!attributes.contains(.bsd.isSystemAppendOnly))
        #expect(attributes.isAppendOnly == false)

    }


    #if canImport(Darwin)

    @Test(
        arguments: [
            (.darwin.noDump, .init(UF_NODUMP)),
            (.darwin.isUserImmutable, .init(UF_IMMUTABLE)),
            (.darwin.isUserAppendOnly, .init(UF_APPEND)),
            (.darwin.isArchived, .init(SF_ARCHIVED)),
            (.darwin.isSystemImmutable, .init(SF_IMMUTABLE)),
            (.darwin.isSystemAppendOnly, .init(SF_APPEND)),
            (.darwin.isHidden, .init(UF_HIDDEN)),
            (.darwin.isOpaque, .init(UF_OPAQUE)),
            (.darwin.systemNoUnlink, .init(SF_NOUNLINK)),
            (.darwin.isCompressed, .init(UF_COMPRESSED)),
            (.darwin.isTracked, .init(UF_TRACKED)),
            (.darwin.isDataVault, .init(UF_DATAVAULT)),
            (.darwin.isRestricted, .init(SF_RESTRICTED)),
            (.darwin.isFirmLink, .init(SF_FIRMLINK)),
            (.darwin.isDataLess, .init(SF_DATALESS))
        ] as [(PlatformFileAttributes, PlatformInteropTypes.FileAttribute)]
    )
    func `Darwin attributes map to native flags`(
        _ attribute: PlatformFileAttributes,
        _ rawValue: PlatformInteropTypes.FileAttribute
    ) {

        #expect(attribute.rawValue == rawValue)

    }


    @Test
    func `isReadOnly accessor returns nil and ignores mutations on Darwin`() {

        var attributes: PlatformFileAttributes = [.darwin.noDump]
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
    func `isCompressed accessor reflects Darwin flag`() {

        var attributes: PlatformFileAttributes = []

        #expect(attributes.isCompressed == false)

        attributes.insert(.darwin.isCompressed)

        #expect(attributes.isCompressed == true)

    }


    @Test
    func `isEncrypted accessor returns nil on Darwin`() {

        let attributes: PlatformFileAttributes = []

        #expect(attributes.isEncrypted == nil)

    }

    #elseif os(FreeBSD)

    @Test(
        arguments: [
            (.freebsd.noDump, .init(UF_NODUMP)),
            (.freebsd.isUserImmutable, .init(UF_IMMUTABLE)),
            (.freebsd.isUserAppendOnly, .init(UF_APPEND)),
            (.freebsd.isArchived, .init(SF_ARCHIVED)),
            (.freebsd.isSystemImmutable, .init(SF_IMMUTABLE)),
            (.freebsd.isSystemAppendOnly, .init(SF_APPEND)),
            (.freebsd.isHidden, .init(UF_HIDDEN)),
            (.freebsd.isOpaque, .init(UF_OPAQUE)),
            (.freebsd.systemNoUnlink, .init(SF_NOUNLINK)),
            (.freebsd.userNoUnlink, .init(UF_NOUNLINK)),
            (.freebsd.isOffline, .init(UF_OFFLINE)),
            (.freebsd.isReadOnly, .init(UF_READONLY)),
            (.freebsd.isReparse, .init(UF_REPARSE)),
            (.freebsd.isSparse, .init(UF_SPARSE)),
            (.freebsd.isSystem, .init(UF_SYSTEM)),
            (.freebsd.isSnapshot, .init(SF_SNAPSHOT))
        ] as [(PlatformFileAttributes, PlatformInteropTypes.FileAttribute)]
    )
    func `FreeBSD attributes map to native flags`(
        _ attribute: PlatformFileAttributes,
        _ rawValue: PlatformInteropTypes.FileAttribute
    ) {

        #expect(attribute.rawValue == rawValue)

    }


    @Test
    func `isReadOnly accessor updates FreeBSD flag`() {

        var attributes: PlatformFileAttributes = []

        #expect(attributes.isReadOnly == false)

        attributes.isReadOnly = true

        #expect(attributes.contains(.freebsd.isReadOnly))
        #expect(attributes.isReadOnly == true)

        let readOnlyAttributes = attributes
        attributes.isReadOnly = nil
        #expect(attributes == readOnlyAttributes)

        attributes.isReadOnly = false

        #expect(!attributes.contains(.freebsd.isReadOnly))
        #expect(attributes.isReadOnly == false)

    }


    @Test
    func `isCompressed and isEncrypted accessors return nil on FreeBSD`() {

        let attributes: PlatformFileAttributes = []

        #expect(attributes.isCompressed == nil)
        #expect(attributes.isEncrypted == nil)

    }

    #elseif os(OpenBSD)

    @Test(
        arguments: [
            (.openbsd.noDump, .init(UF_NODUMP)),
            (.openbsd.isUserImmutable, .init(UF_IMMUTABLE)),
            (.openbsd.isUserAppendOnly, .init(UF_APPEND)),
            (.openbsd.isArchived, .init(SF_ARCHIVED)),
            (.openbsd.isSystemImmutable, .init(SF_IMMUTABLE)),
            (.openbsd.isSystemAppendOnly, .init(SF_APPEND))
        ] as [(PlatformFileAttributes, PlatformInteropTypes.FileAttribute)]
    )
    func `OpenBSD attributes map to native flags`(
        _ attribute: PlatformFileAttributes,
        _ rawValue: PlatformInteropTypes.FileAttribute
    ) {

        #expect(attribute.rawValue == rawValue)

    }


    @Test
    func `isReadOnly accessor returns nil and ignores mutations on OpenBSD`() {

        var attributes: PlatformFileAttributes = [.openbsd.noDump]
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
    func `isCompressed and isEncrypted accessors return nil on OpenBSD`() {

        let attributes: PlatformFileAttributes = []

        #expect(attributes.isCompressed == nil)
        #expect(attributes.isEncrypted == nil)

    }

    #endif

}

#endif
