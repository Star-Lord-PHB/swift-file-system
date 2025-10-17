#if canImport(WinSDK)

import Foundation
import WinSDK
import CFileSystem


@usableFromInline
func errorCodeDescription(for error: DWORD) -> String? {

    var buffer = nil as LPWSTR?
    
    let size = withUnsafeMutablePointer(to: &buffer) { ptrToBuffer in
        ptrToBuffer.withMemoryRebound(to: LPWSTR.Pointee.self, capacity: 1) { wrappedPtrToBuffer in
            FormatMessageW(
                DWORD(FORMAT_MESSAGE_ALLOCATE_BUFFER | FORMAT_MESSAGE_FROM_SYSTEM | FORMAT_MESSAGE_IGNORE_INSERTS), 
                nil, 
                error, 
                makeLanguageIdentifier(USHORT(LANG_NEUTRAL), USHORT(SUBLANG_DEFAULT)),
                wrappedPtrToBuffer, 
                0, 
                nil
            )
        }
    }

    guard size > 0, let buffer else { return nil }

    let message = String(decodingCString: buffer, as: UTF16.self)

    LocalFree(buffer)

    return message

}

#endif