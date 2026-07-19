import PlatformCLib
import Testing
import SwiftFileSystem


extension FileInfoAPITests {

    @Suite("File identifier")
    struct FileIdentifierTests {}

}



extension FileInfoAPITests.FileIdentifierTests {

    #if canImport(WinSDK)
    @Test
    func `FILE_ID_128 conversion preserves all bits`() {

        var nativeId = FILE_ID_128()
        withUnsafeMutableBytes(of: &nativeId.Identifier) { bytes in
            for index in bytes.indices {
                bytes[index] = UInt8(index)
            }
        }
        let expected: UInt128 = 0x0F0E_0D0C_0B0A_0908_0706_0504_0302_0100

        let identifier = FileIdentifier(
            fileId: nativeId,
            deviceId: 0xFEDC_BA98_7654_3210
        )

        #expect(nativeId.uint128 == expected)
        #expect(identifier.fileId == expected)
        #expect(identifier.deviceId == 0xFEDC_BA98_7654_3210)

    }
    #endif

}
