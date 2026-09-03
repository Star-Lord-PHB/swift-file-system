//
//  SendableBox.swift
//  swift-file-system
//
//  Created by SerikaPHB  on 2026/9/2.
//

package struct SendableBox<T: ~Copyable>: ~Copyable, @unchecked Sendable {

    let value: T

    package init(_ value: consuming sending T) {
        self.value = value
    }

    package consuming func take() -> sending T {
        return value
    }

}
