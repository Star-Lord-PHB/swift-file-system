//
//  ByteBuffer+DataProtocol.swift
//  swift-file-system
//
//  Created by SerikaPHB  on 2026/6/25.
//

import Foundation
import struct SwiftFileSystem.ByteBuffer



extension ByteBuffer: ContiguousBytes {}



extension ByteBuffer: DataProtocol {
        
    @inlinable
    public var regions: CollectionOfOne<Self> { .init(self) }
    
    @inlinable
    public var data: Data { .init(self) }
    
}
