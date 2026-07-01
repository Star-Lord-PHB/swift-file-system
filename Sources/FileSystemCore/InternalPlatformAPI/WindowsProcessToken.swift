#if canImport(WinSDK)
import WinSDK
import SystemPackage
import CFileSystem


package struct WindowsProcessToken: ~Copyable {

    package let handle: UnsafeOwnedAutoResource

    package init(handle: consuming UnsafeOwnedAutoResource) {
        self.handle = handle
    }


    package func getTokenInformation<T>(
        of tokenInfoClass: TOKEN_INFORMATION_CLASS, 
        as type: T.Type = T.self
    ) throws(SystemError) -> UnsafeOwnedAutoPointer<T> {
        var size = 0 as DWORD
        guard 
            GetTokenInformation(handle.unsafeResourcePtr, tokenInfoClass, nil, 0, &size) == false, 
            GetLastError() == ERROR_INSUFFICIENT_BUFFER 
        else {
            try SystemError.assertError()
        }
        let infoPtr = UnsafeOwnedRawAutoPointer
            .swiftAllocate(byteCount: Int(size), alignment: MemoryLayout<T>.alignment)
            .assumingMemoryBound(to: T.self)
        try execThrowingCFunction {
            GetTokenInformation(handle.unsafeResourcePtr, tokenInfoClass, infoPtr.unsafelyCastedMutableRawPtr, size, &size)
        }
        return infoPtr
    }

}



extension WindowsProcessToken {

    package func getUser() throws(SystemError) -> UnsafeOwnedAutoPointer<TOKEN_USER> {
        return try getTokenInformation(of: TokenUser)
    }

    package func getPrimaryGroups() throws(SystemError) -> UnsafeOwnedAutoPointer<TOKEN_PRIMARY_GROUP> {
        return try getTokenInformation(of: TokenPrimaryGroup)
    }

    

}



extension WindowsProcessToken {

    package static func current() throws(SystemError) -> Self {
        var processToken = nil as HANDLE?
        try execThrowingCFunction {
            OpenProcessToken(GetCurrentProcess(), DWORD(TOKEN_QUERY), &processToken)
        }
        guard let processToken else {
            try SystemError.assertError()
        }
        return .init(handle: .init(owningResource: processToken, freeingFunc: { CloseHandle($0) }))
    }

}

#endif