import Testing
import SystemPackage
import Foundation
@testable import SwiftFileSystem
@testable import FileSystemCore

#if canImport(WinSDK)
import WinSDK
#endif 


// Tests of the FileSystem APIs will include resource handle leakage check, which does not work correctly
// in parallel testing
@Suite(.serialized, .catchTestCancellation)
class FileSystemTest {

}