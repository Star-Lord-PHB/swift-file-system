import Foundation
import SystemPackage


extension FileInfo {

    public struct User {

        #if os(Windows)
        public let sid: String?
        #else
        public let uid: UInt32
        public let gid: UInt32
        #endif // os(Windows)

    }

}