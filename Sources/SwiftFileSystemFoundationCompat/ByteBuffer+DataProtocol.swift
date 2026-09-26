//
//  ByteBuffer+DataProtocol.swift
//  swift-file-system
//
//  Created by SerikaPHB  on 2026/6/25.
//

import Foundation
import struct FileSystemCore.ByteBuffer



extension ByteBuffer: ContiguousBytes {}



extension ByteBuffer: DataProtocol {
        
    @inlinable
    public var regions: CollectionOfOne<Self> { .init(self) }
    
    /// Converts the ``ByteBuffer`` into a [`Data`] instance.
    /// 
    /// [`Data`]: https://developer.apple.com/documentation/foundation/data
    @inlinable
    public var data: Data { .init(self) }
    
}
