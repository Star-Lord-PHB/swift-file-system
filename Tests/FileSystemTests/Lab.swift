import Testing
import SystemPackage
import Foundation
@testable import FileSystem



extension FileSystemTest {

    final class Lab: FileSystemTest {}

}



extension FileSystemTest.Lab {

    @Test("Lab 1")
    func lab1() async throws {
        
        // let filePath = try makeFile(at: "file")

        // print(try FileSystem().getSecurityInfo(forItemAt: filePath).fullyParsedDescriptor().dacl!)

        // let newSecurity = WindowsRawAcl(entries: [
        //     .init(permission: [.genericRead, .genericWrite, .genericExecute, .delete], trustee: .administrators),
        //     .init(permission: .genericRead, trustee: .authenticatedUsers)
        // ])

        // try FileSystem().setSecurityInfo(
        //     forItemAt: filePath,
        //     dacl: .replace(newSecurity)
        // )

        // print(try FileSystem().getSecurityInfo(forItemAt: filePath).fullyParsedDescriptor().dacl!)

    }

}