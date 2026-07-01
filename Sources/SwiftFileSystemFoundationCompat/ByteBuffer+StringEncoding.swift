//
//  ByteBuffer+StringEncoding.swift
//  swift-file-system
//
//  Created by SerikaPHB  on 2026/6/25.
//

import struct SwiftFileSystem.ByteBuffer
import Foundation



extension ByteBuffer.Reader {
    
    @_lifetime(self: copy self)
    @inlinable
    public mutating func readString(upTo byteCount: Int, encoding: String.Encoding) -> String? {
        self.readSpan(upTo: byteCount).withUnsafeBytes { buffer in
            guard buffer.baseAddress != nil else { return nil }
            return String(bytes: buffer, encoding: encoding)
        }
    }
    
}
