#if canImport(WinSDK)
import WinSDK

enum WindowsAPI {

    static func pSidToString(sidPtr: PSID) throws(SystemError) -> String {

        var sidStrPtr = nil as LPWSTR?
        try execThrowingCFunction {
            ConvertSidToStringSidW(sidPtr, &sidStrPtr)
        }
        guard let sidStrPtr else {
            try SystemError.assertError()
        }
        defer { LocalFree(sidStrPtr) }

        return String(decodingCString: sidStrPtr, as: UTF16.self)

    }


    static func name(ofSid sidStr: String) throws(SystemError) -> String {

        do {

            var sidPtr = nil as PSID?

            try sidStr.withCString(encodedAs: UTF16.self) { sidStrPtr in 
                try execThrowingCFunction {
                    ConvertStringSidToSidW(sidStrPtr, &sidPtr)
                }
            }

            guard let sidPtr else {
                try SystemError.assertError()
            }
            defer { LocalFree(sidPtr) }

            var nameSize = 0 as DWORD
            var domainSize = 0 as DWORD
            var use = SID_NAME_USE(0)

            LookupAccountSidW(nil, sidPtr, nil, &nameSize, nil, &domainSize, nil)
            guard GetLastError() == ERROR_INSUFFICIENT_BUFFER else {
                try SystemError.assertError()
            }

            let nameBuffer = UnsafeMutablePointer<WCHAR>.allocate(capacity: Int(nameSize))
            let domainBuffer = UnsafeMutablePointer<WCHAR>.allocate(capacity: Int(domainSize))
            defer {
                nameBuffer.deallocate()
                domainBuffer.deallocate()
            }

            try execThrowingCFunction {
                LookupAccountSidW(nil, sidPtr, nameBuffer, &nameSize, domainBuffer, &domainSize, &use)
            }

            return String(decodingCString: nameBuffer, as: UTF16.self)

        } catch let error as SystemError {
            throw error
        } catch {
            fatalError("Expect error of type \(SystemError.self), but got: \(error)")
        }

    }

}

#endif