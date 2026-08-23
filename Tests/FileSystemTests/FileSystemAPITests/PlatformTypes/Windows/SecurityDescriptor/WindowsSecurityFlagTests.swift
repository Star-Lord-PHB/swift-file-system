#if canImport(WinSDK)

import PlatformCLib
import Testing
import SwiftFileSystem



extension PlatformTypesAPITests.WindowsSecurityTests {

    @Suite("Security flags")
    struct WindowsSecurityFlagTests {}

}



extension PlatformTypesAPITests.WindowsSecurityTests.WindowsSecurityFlagTests {

    // NOTE: Windows gives several access bits two names, one for files and one for
    // directories, so the pairs below deliberately share a raw value.
    @Test(
        arguments: [
            (.readData, ACCESS_MASK(FILE_READ_DATA)),
            (.listDirectory, ACCESS_MASK(FILE_LIST_DIRECTORY)),
            (.writeData, ACCESS_MASK(FILE_WRITE_DATA)),
            (.addFile, ACCESS_MASK(FILE_ADD_FILE)),
            (.appendData, ACCESS_MASK(FILE_APPEND_DATA)),
            (.addSubdirectory, ACCESS_MASK(FILE_ADD_SUBDIRECTORY)),
            (.readExtentedAttrs, ACCESS_MASK(FILE_READ_EA)),
            (.writeExtendedAttrs, ACCESS_MASK(FILE_WRITE_EA)),
            (.execute, ACCESS_MASK(FILE_EXECUTE)),
            (.traverse, ACCESS_MASK(FILE_TRAVERSE)),
            (.deleteChild, ACCESS_MASK(FILE_DELETE_CHILD)),
            (.readAttributes, ACCESS_MASK(FILE_READ_ATTRIBUTES)),
            (.writeAttributes, ACCESS_MASK(FILE_WRITE_ATTRIBUTES)),
            (.delete, ACCESS_MASK(DELETE)),
            (.readControl, ACCESS_MASK(READ_CONTROL)),
            (.writeDAC, ACCESS_MASK(WRITE_DAC)),
            (.writeOwner, ACCESS_MASK(WRITE_OWNER)),
            (.synchronize, ACCESS_MASK(SYNCHRONIZE)),
            (.genericRead, ACCESS_MASK(GENERIC_READ)),
            (.genericWrite, ACCESS_MASK(GENERIC_WRITE)),
            (.genericExecute, ACCESS_MASK(GENERIC_EXECUTE)),
            (.genericAll, ACCESS_MASK(GENERIC_ALL))
        ] as [(WindowsAccessMask, ACCESS_MASK)]
    )
    func `Access mask flags map to native flags`(_ mask: WindowsAccessMask, _ rawValue: ACCESS_MASK) {

        #expect(mask.rawValue == rawValue)

    }


    @Test(
        arguments: [
            (.objectInherit, BYTE(OBJECT_INHERIT_ACE)),
            (.containerInherit, BYTE(CONTAINER_INHERIT_ACE)),
            (.noPropagateInherit, BYTE(NO_PROPAGATE_INHERIT_ACE)),
            (.inheritOnly, BYTE(INHERIT_ONLY_ACE)),
            (.inherited, BYTE(INHERITED_ACE)),
            (.successfulAccess, BYTE(SUCCESSFUL_ACCESS_ACE_FLAG)),
            (.failedAccess, BYTE(FAILED_ACCESS_ACE_FLAG))
        ] as [(WindowsACEFlags, BYTE)]
    )
    func `ACE flags map to native flags`(_ flags: WindowsACEFlags, _ rawValue: BYTE) {

        #expect(flags.rawValue == rawValue)

    }


    @Test(
        arguments: [
            (.allow, BYTE(ACCESS_ALLOWED_ACE_TYPE)),
            (.deny, BYTE(ACCESS_DENIED_ACE_TYPE)),
            (.audit, BYTE(SYSTEM_AUDIT_ACE_TYPE)),
            (.alarm, BYTE(SYSTEM_ALARM_ACE_TYPE))
        ] as [(WindowsACEType, BYTE)]
    )
    func `ACE types round trip through the native type`(_ type: WindowsACEType, _ rawValue: BYTE) {

        #expect(type.rawValue == rawValue)
        #expect(WindowsACEType(rawValue: rawValue) == type)

    }

}

#endif
