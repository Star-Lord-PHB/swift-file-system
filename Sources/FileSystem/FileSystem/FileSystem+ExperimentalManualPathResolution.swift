import SystemPackage
import Foundation


extension FileSystem {

    #if !canImport(WinSDK)

    @inlinable
    func __symlinkDestination(fromDirHandle dirHandle: CInt, component: UnsafeBufferPointer<CChar>, buffer: inout [CChar]) throws(SystemError) -> Int {

        while true {
            let len = buffer.withUnsafeMutableBufferPointer { bufferPtr in 
                readlinkat(dirHandle, component.baseAddress!, bufferPtr.baseAddress!, bufferPtr.count)
            }
            if len < 0 {
                try SystemError.assertError()
            } else if len == buffer.count {
                buffer.append(contentsOf: [CChar](repeating: 0, count: Int(PATH_MAX)))
            } else {
                return len
            }
        }

    }
    #endif


    @usableFromInline
    struct __PathComponentEmitter: ~Copyable {
        @usableFromInline var path: UnsafeMutableBufferPointer<CChar>
        @usableFromInline var startIndex: Int
        @usableFromInline var endIndex: Int
        @usableFromInline var capacity: Int { path.count }
        @inlinable
        init(posixCPath: [CChar], length: Int? = nil) {
            let length = length ?? ((posixCPath.firstIndex(where: { $0 == 0 }) ?? posixCPath.count) + 1)
            self.startIndex = 0
            self.endIndex = 0
            self.path = .init(start: nil, count: 0)
            self.push(components: posixCPath, length: length)
        }
        init() {
            self.init(posixCPath: [])
        }
        @inlinable
        deinit {
            path.deallocate()
        }
        @inlinable
        var isEmpty: Bool { startIndex == endIndex }
        @inlinable
        mutating func next() -> UnsafeBufferPointer<CChar>? {
            guard !isEmpty else { return nil }
            let start = startIndex
            while startIndex < endIndex && path[startIndex] != CChar(ascii: "/") { startIndex += 1 }
            let end = startIndex
            path[startIndex] = 0
            startIndex += 1;
            while startIndex < endIndex && path[startIndex] == CChar(ascii: "/") { startIndex += 1 }
            return UnsafeBufferPointer(rebasing: path[start ... end])   // use closed range to include the null terminator
        }
        // length includes the null terminator
        @inlinable
        mutating func push(components: borrowing [CChar], length: Int) {
            // reserve one more space for an additional '/'
            if startIndex < length + 1 {
                let requiredCapacity = endIndex - startIndex + length + 1
                let distanceToMove = length + 1 - startIndex
                if capacity < requiredCapacity {
                    let newCapacity = max(capacity * 2, requiredCapacity)
                    let newBuffer = UnsafeMutableBufferPointer<CChar>.allocate(capacity: newCapacity)
                    newBuffer[(startIndex + distanceToMove) ..< (endIndex + distanceToMove)] = path[startIndex ..< endIndex]
                    path.deallocate()
                    path = newBuffer
                } else {
                    _ = path[(startIndex + distanceToMove)...].moveInitialize(fromContentsOf: path[startIndex ..< endIndex])
                }
                startIndex += distanceToMove
                endIndex += distanceToMove
            }
            startIndex -= (length + 1)
            components.withUnsafeBufferPointer { buffer in 
                _ = path[startIndex ..< (startIndex + length)].update(fromContentsOf: buffer[0 ..< length])
            }
            path[startIndex + length] = CChar(ascii: "/")
            while startIndex < endIndex && path[startIndex] == CChar(ascii: "/") { startIndex += 1 }
        }
    }


    @usableFromInline
    struct __FdStack: ~Copyable {
        @usableFromInline var buffer: UnsafeMutableBufferPointer<CInt>
        @usableFromInline var stackTop: Int 
        @inlinable var capacity: Int { buffer.count }
        @inlinable var isEmpty: Bool { stackTop == 0 }
        @inlinable var count: Int { stackTop }
        @inlinable var top: CInt? { stackTop == 0 ? nil : buffer[stackTop - 1] }
        @inlinable 
        init(capacity: Int = 32) {
            buffer = .allocate(capacity: capacity)
            stackTop = 0
        }
        @inlinable 
        deinit {
            buffer.deallocate()
        }
        @inlinable 
        mutating func push(_ fd: CInt) {
            if _slowPath(stackTop == buffer.count) {
                let newBuffer = UnsafeMutableBufferPointer<CInt>.allocate(capacity: capacity * 2)
                newBuffer[0 ..< stackTop] = buffer[0 ..< stackTop]
                buffer.deallocate()
                buffer = newBuffer
            }
            buffer[stackTop] = fd 
            stackTop += 1
        }
        @inlinable 
        mutating func pop() -> CInt? {
            guard !isEmpty else { return nil }
            stackTop -= 1
            return buffer[stackTop]
        }
    }


    @usableFromInline
    struct __FinalPath: ~Copyable {

        @usableFromInline var buffer: UnsafeMutableBufferPointer<CChar>
        @usableFromInline var endIndex: Int     // always points to the null terminator at the end
        @inlinable var baseAddress: UnsafeMutablePointer<CChar> { buffer.baseAddress! }

        @inlinable var startIndex: Int { 1 }
        @inlinable var isEmpty: Bool { endIndex == startIndex + 1 }
        @inlinable var root: CChar {
            get { buffer[0] }
            set { buffer[0] = newValue }
        }

        @inlinable 
        init(root: CChar, capacity: Int = 32) {
            buffer = .allocate(capacity: max(capacity, 32))
            endIndex = 1
            self.root = root
            buffer[endIndex] = 0
        }

        @inlinable 
        deinit {
            buffer.deallocate()
        }

        @inlinable 
        mutating func append(_ content: UnsafeBufferPointer<CChar>, withTrailingSlash: Bool = true) {
            self.append(content[0 ..< content.count], withTrailingSlash: withTrailingSlash)
        }

        // requirement: `element` MUST be a null-terminate string 
        @inlinable 
        mutating func append(_ element: Slice<UnsafeBufferPointer<CChar>>, withTrailingSlash: Bool = true) {
            let additionalSpaceRequired = element.count + (withTrailingSlash ? 1 : 0)
            if buffer.count > endIndex + additionalSpaceRequired {
                let newBuffer = UnsafeMutableBufferPointer<CChar>.allocate(capacity: max(buffer.count * 2, endIndex + additionalSpaceRequired))
                newBuffer[0 ..< endIndex] = buffer[0 ..< endIndex]
                buffer.deallocate()
                buffer = newBuffer
            }
            // copy the `element`, including the null terminator
            buffer[endIndex ..< endIndex + element.count] = UnsafeMutableBufferPointer(mutating: .init(rebasing: element))[0 ..< element.count]
            endIndex += (element.count - 1)     // the last char in the `element` is the null terminator, which is not included by the `endIndex`
            if withTrailingSlash {
                buffer[endIndex] = CChar(ascii: "/")
                endIndex += 1
                buffer[endIndex] = 0            // when additional slash is added, manually add an null terminator
            }
        }

        @inlinable 
        mutating func removeLastComponent() {
            guard !isEmpty else { return }
            while endIndex > startIndex, buffer[endIndex - 1] == CChar(ascii: "/") { endIndex -= 1 }
            while endIndex > startIndex, buffer[endIndex - 1] != CChar(ascii: "/") { endIndex -= 1 }
        }

        @inlinable
        mutating func removeAllComponents() {
            endIndex = startIndex
            buffer[endIndex] = 0
        }

        @inlinable
        consuming func toFilePath() -> FilePath {
            .init(platformString: baseAddress)
        }

    }


    @inlinable
    public func __symlinkRecursiveDestination(of path: FilePath) throws(SystemError) -> FilePath {

        #if canImport(WinSDK)
        #warning("Not implemented")
        fatalError("Not implemented")
        #else

        let openDirComponentOption = UnsafeSystemHandle.OpenOptions(
            access: .readOnly(metadataOnly: true), 
            noFollow: true, 
            platformSpecificOptions: .posix.directoryOnly
        )

        var dirFdStack = __FdStack(capacity: max(path.components.count, 32))
        var finalPath = __FinalPath(root: path.isAbsolute ? CChar(ascii: "/") : CChar(ascii: "."))
        var remainingSymlinkAllowed = 32        // TODO: use platform defined value 

        defer {
            while let fd = dirFdStack.pop() {
                close(fd)
            }
        }

        do {
            let fd = open(
                finalPath.baseAddress, 
                openDirComponentOption.accessModeFlags | openDirComponentOption.openFlags | openDirComponentOption.platformAdditionalRawFlags
            )
            guard fd >= 0 else { try SystemError.assertError() }
            dirFdStack.push(fd)
        }

        var pendingComponents = __PathComponentEmitter(posixCPath: path.string.cString(using: .utf8)!)

        var buffer = [CChar](repeating: 0, count: Int(PATH_MAX))

        while let component = pendingComponents.next() {

            // print(component.withMemoryRebound(to: UInt8.self) { String(bytes: $0, encoding: .utf8)! })
            // print(String(cString: finalPath.baseAddress, encoding: .utf8)!)

            if component.count == 2 && component[0] == CChar(ascii: ".") { continue }
            if component.count == 3 && component[0] == CChar(ascii: ".") && component[1] == CChar(ascii: ".") {
                if dirFdStack.count > 1 {
                    try execThrowingCFunction { close(dirFdStack.pop()!) }
                    finalPath.removeLastComponent()
                }
                continue
            }

            do {
                let newDirFd = openat(
                    dirFdStack.top!, 
                    component.baseAddress!,
                    openDirComponentOption.accessModeFlags | openDirComponentOption.openFlags | openDirComponentOption.platformAdditionalRawFlags
                )
                if newDirFd >= 0 {
                    finalPath.append(component)
                    dirFdStack.push(newDirFd)
                    continue   
                } else if errno != ENOTDIR {
                    try SystemError.assertError()
                }
            }

            do {
                let len: Int
                do {
                    len = try __symlinkDestination(fromDirHandle: dirFdStack.top!, component: component, buffer: &buffer)
                } catch let error where error.code == EINVAL {
                    if pendingComponents.isEmpty {
                        finalPath.append(component)
                        break
                    } else {
                        throw SystemError(code: ENOTDIR)
                    }
                }

                if remainingSymlinkAllowed == 0 {
                    throw SystemError(code: ELOOP)
                }
                remainingSymlinkAllowed -= 1

                if buffer[0] == CChar(ascii: "/") {
                    finalPath.removeAllComponents()
                    finalPath.root = CChar(ascii: "/")
                    while let fd = dirFdStack.pop() {
                        try execThrowingCFunction { close(fd) }
                    }
                    let fd = open(
                        finalPath.baseAddress, 
                        openDirComponentOption.accessModeFlags | openDirComponentOption.openFlags | openDirComponentOption.platformAdditionalRawFlags
                    )
                    guard fd >= 0 else { try SystemError.assertError() }
                    dirFdStack.push(fd)
                }

                pendingComponents.push(components: buffer, length: len)
            }
            
            // var st = stat()
            // try execThrowingCFunction {
            //     fstatat(dirFdStack.top!, component.baseAddress, &st, AT_SYMLINK_NOFOLLOW)
            // }

            // switch FileInfo.FileType(mode: st.st_mode) {
            //     case .symlink: do {

            //         remainingSymlinkAllowed -= 1
            //         guard remainingSymlinkAllowed >= 0 else {
            //             throw SystemError(code: ELOOP)
            //         }

            //         let len = try _symlinkDestination(fromDirHandle: dirFdStack.top!, component: component, buffer: &buffer)

            //         if buffer[0] == CChar(ascii: "/") {
            //             finalPath.removeAll(keepingCapacity: true)
            //             finalPath.root = "/"
            //             while let fd = dirFdStack.pop() {
            //                 try execThrowingCFunction { close(fd) }
            //             }
            //             let fd = open(
            //                 finalPath.string, 
            //                 openDirComponentOption.accessModeFlags | openDirComponentOption.openFlags | openDirComponentOption.platformAdditionalRawFlags
            //             )
            //             guard fd >= 0 else { try SystemError.assertError() }
            //             dirFdStack.push(fd)
            //         }

            //         pendingComponents.push(components: buffer, length: len)

            //     }
            //     case .directory: do {

            //         let newDirFd = openat(
            //             dirFdStack.top!, 
            //             component.baseAddress!,
            //             openDirComponentOption.accessModeFlags | openDirComponentOption.openFlags | openDirComponentOption.platformAdditionalRawFlags
            //         )
            //         guard newDirFd >= 0 else {
            //             try SystemError.assertError()
            //         }

            //         finalPath.append(
            //             component.withMemoryRebound(to: UInt8.self) { String(bytes: $0, encoding: .utf8)! }
            //         )
            //         dirFdStack.push(newDirFd)

            //     }
            //     case _ where pendingComponents.isEmpty: do {
            //         finalPath.append(
            //             component.withMemoryRebound(to: UInt8.self) { String(bytes: $0, encoding: .utf8)! }
            //         )
            //     }
            //     default: throw SystemError(code: ENOTDIR)
            // }
            
        }

        while let fd = dirFdStack.pop() {
            try execThrowingCFunction { close(fd) }
        }

        return finalPath.toFilePath()

        #endif 

    }

}


extension CChar {

    @inlinable
    init(ascii: Unicode.Scalar) {
        self = CChar(bitPattern: UInt8(ascii: ascii))
    }

}