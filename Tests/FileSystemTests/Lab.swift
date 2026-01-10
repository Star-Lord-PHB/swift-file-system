import Testing
import SystemPackage
import Foundation
@testable import FileSystem



extension FileSystemTest {

    /// A collection of tests that are not actually testable. Mainly aimed at manual execution and verification.
    /// But of course, the tests can at least ensure that they run without crashing.
    final class Lab: FileSystemTest {}

}



extension FileSystemTest.Lab {

    #if canImport(WinSDK)
    @Test("Setting and Getting Windows Security Info")
    func settingAndGettingWindowsSecurityInfo() async throws {
        
        let filePath = try makeFile(at: "file")

        print(try FileSystem().getSecurityInfo(forItemAt: filePath).fullyParsedDescriptor().dacl!)

        let newSecurity = WindowsRawAcl(entries: [
            .init(permission: [.genericRead, .genericWrite, .genericExecute, .delete], trustee: .administrators),
            .init(permission: .genericRead, trustee: .authenticatedUsers)
        ])

        try FileSystem().setSecurityInfo(
            forItemAt: filePath,
            dacl: .replace(newSecurity)
        )

        print(try FileSystem().getSecurityInfo(forItemAt: filePath).fullyParsedDescriptor().dacl!)

    }
    #endif


    @Test("Current Identity & Account Name")
    func currentIdentityAndAccountName() async throws {
        
        let platformAPI = PlatformAPI()
        let currentIdentity = try platformAPI.currentIdentity()
        let currentAccountName = try platformAPI.accountName(for: currentIdentity)
        
        print("Current Identity: \(currentIdentity)")
        print("Current Account Name: \(currentAccountName ?? "nil")")

    }


    @Test("Account Name -> Identity")
    func accountNameToIdentity() async throws {
        
        let platformAPI = PlatformAPI()

        #if canImport(WinSDK)

        let everyoneName = "Everyone"
        let systemName = "SYSTEM"
        let administratorsName = "Administrators"
        let administratorName = "Administrator"
        let authenticatedUsersName = "Authenticated Users"
        let guestName = "Guest"
        let guestsName = "Guests"
        let wdagUtilityAccountName = "WDAGUtilityAccount"

        let everyoneIdentity = try platformAPI.identity(forAccountName: everyoneName)
        let systemIdentity = try platformAPI.identity(forAccountName: systemName)
        let administratorsIdentity = try platformAPI.identity(forAccountName: administratorsName)
        let administratorIdentity = try platformAPI.identity(forAccountName: administratorName)
        let authenticatedUsersIdentity = try platformAPI.identity(forAccountName: authenticatedUsersName)
        let guestIdentity = try platformAPI.identity(forAccountName: guestName)
        let guestsIdentity = try platformAPI.identity(forAccountName: guestsName)
        let wdagUtilityAccountIdentity = try platformAPI.identity(forAccountName: wdagUtilityAccountName)

        print("Everyone Identity: \(everyoneIdentity?.description ?? "nil")")
        print("System Identity: \(systemIdentity?.description ?? "nil")")
        print("Administrators Identity: \(administratorsIdentity?.description ?? "nil")")
        print("Administrator Identity: \(administratorIdentity?.description ?? "nil")")
        print("Authenticated Users Identity: \(authenticatedUsersIdentity?.description ?? "nil")")
        print("Guest Identity: \(guestIdentity?.description ?? "nil")")
        print("Guests Identity: \(guestsIdentity?.description ?? "nil")")
        print("WDAGUtilityAccount Identity: \(wdagUtilityAccountIdentity?.description ?? "nil")")

        #else 

        let rootName = "root"
        let nobodyName = "nobody"
        let nobodyGroupName1 = "nobody"
        let nobodyGroupName2 = "nogroup"
        let wheelName = "wheel"
        let staffName = "staff"
        let everyoneName = "everyone"
        let daemonName = "daemon"
        let binName = "bin"
        let systemName = "sys"
        let usersName = "users"
        let windowServerName = "_windowserver"
        let mdnsresponderName = "_mdnsresponder"

        let rootIdentity = try platformAPI.identity(forAccountName: rootName, kind: .user)
        let nobodyIdentity = try platformAPI.identity(forAccountName: nobodyName, kind: .user)
        let nobodyGroupIdentity1 = try platformAPI.identity(forAccountName: nobodyGroupName1, kind: .group)
        let nobodyGroupIdentity2 = try platformAPI.identity(forAccountName: nobodyGroupName2, kind: .group)
        let wheelIdentity = try platformAPI.identity(forAccountName: wheelName, kind: .group)
        let staffIdentity = try platformAPI.identity(forAccountName: staffName, kind: .group)
        let everyoneIdentity = try platformAPI.identity(forAccountName: everyoneName, kind: .group)
        let daemonIdentity = try platformAPI.identity(forAccountName: daemonName, kind: .user)
        let binIdentity = try platformAPI.identity(forAccountName: binName, kind: .user)
        let systemIdentity = try platformAPI.identity(forAccountName: systemName, kind: .user)
        let usersIdentity = try platformAPI.identity(forAccountName: usersName, kind: .group)
        let windowServerIdentity = try platformAPI.identity(forAccountName: windowServerName, kind: .user)
        let mdnsresponderIdentity = try platformAPI.identity(forAccountName: mdnsresponderName, kind: .user)

        print("Root Identity: \(rootIdentity?.description ?? "nil")")
        print("Nobody Identity: \(nobodyIdentity?.description ?? "nil")")
        print("Nobody Group Identity 1: \(nobodyGroupIdentity1?.description ?? "nil")")
        print("Nobody Group Identity 2: \(nobodyGroupIdentity2?.description ?? "nil")")
        print("Wheel Identity: \(wheelIdentity?.description ?? "nil")")
        print("Staff Identity: \(staffIdentity?.description ?? "nil")")
        print("Everyone Identity: \(everyoneIdentity?.description ?? "nil")")
        print("Daemon Identity: \(daemonIdentity?.description ?? "nil")")
        print("Bin Identity: \(binIdentity?.description ?? "nil")")
        print("System Identity: \(systemIdentity?.description ?? "nil")")
        print("Users Identity: \(usersIdentity?.description ?? "nil")")
        print("WindowServer Identity: \(windowServerIdentity?.description ?? "nil")")
        print("mdnsresponder Identity: \(mdnsresponderIdentity?.description ?? "nil")")

        #endif 

    }

}