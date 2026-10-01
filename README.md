# Swift FileSystem

[![](https://img.shields.io/endpoint?url=https%3A%2F%2Fswiftpackageindex.com%2Fapi%2Fpackages%2FStar-Lord-PHB%2Fswift-file-system%2Fbadge%3Ftype%3Dswift-versions)](https://swiftpackageindex.com/Star-Lord-PHB/swift-file-system) [![](https://img.shields.io/endpoint?url=https%3A%2F%2Fswiftpackageindex.com%2Fapi%2Fpackages%2FStar-Lord-PHB%2Fswift-file-system%2Fbadge%3Ftype%3Dplatforms)](https://swiftpackageindex.com/Star-Lord-PHB/swift-file-system)

A cross-platform Swift package that provides both synchronous and asynchronous APIs for filesystem operations.


## Introduction

Swift FileSystem is a cross-platform library for working with files, directories and their metadata in Swift. It covers path-based operations, file handles, recursive traversal, copy and removal, with all of them offered in both a synchronous and an asynchronous flavor, and is available on Darwin, Linux and Windows.

Rather than building on Foundation or NIO, the library talks to each platform's native system calls directly and exposes them through modern Swift features: typed throws, non-copyable resource management, span-based I/O and Swift concurrency. Even so, the APIs are still kept simple. If you have used Foundation's `FileManager` or swift-nio's `NIOFileSystem`, the API will feel familiar.

Where behavior can be made consistent across platforms, it is, but where it cannot (or should not), the differences are surfaced instead of hidden. Platform-specific APIs such as POSIX permissions, Linux inode flags and Windows security descriptors are also available when you need them.

**Attention:** The project has not reached 1.0 yet, so its APIs may still change in source-breaking ways between minor versions. Consider depending on it with `.upToNextMinor(from:)` and reviewing the changes when upgrading.


## Key Features

- Separated modules for synchronous and asynchronous APIs, so if you don't need async APIs for some reason, you can include only the synchronous module (may also be useful for platforms where creating threads for the async executor is not possible)
- Cross-platform support for Darwin, Linux and Windows, with a "mostly" unified set of APIs. Some platform-specific APIs that are not possible to be unified (e.g.: Windows Security Descriptors, Windows SID) are also provided for advanced usages.
- Resource management with Swift's `~Copyable` and lifetime dependency.
- Typed throws with a unified `PlatformError` error type that includes the semantic kind and operation context of the error.
- Modern Swift concurrency support with elastic thread pool executor and cancellation for long-running operations (e.g.: recursive directory copy, recursive directory removal)
- Built directly on native system calls without depending on Foundation. When you do need to work with Foundation, the `SwiftFileSystemFoundationCompat` module provides some bridges for common Foundation types.
- File handles are split by capability, with handles for positional I/O, streaming I/O, appending and directories. Positional handles can also derive sequential views with independent cursors.
- Extensibility through a low-level wrapper over the native file handle (`UnsafeSystemHandle`), on which the high-level APIs are built. You can use it to reach platform features the high-level APIs don't cover.
- Span-based APIs that read into and writes from caller-owned memory.
- Recursive directory traversal with skip controls, recursive copy with configurable error strategies and platform-aware metadata preservation, and recursive removal.
- Additional APIs for account lookup and Windows effective access evaluation.


## Modules

| Module | Description |
| --- | --- |
| `SwiftAsyncFileSystem` | The recommended module to use. Asynchronous APIs for path-based operations, file / directory handles and recursive directory operations, running on an elastic thread pool executor with support for task cancellation. |
| `SwiftFileSystem` | Synchronous APIs for path-based operations, file / directory handles and recursive directory operations. Use it when you explicitly need synchronous calls (e.g.: on platforms where the async executor cannot create threads). |
| `FileSystemCore` | Core types and underlying infrastructure shared by both modules above, which is re-exported by both of them. |
| `SwiftFileSystemFoundationCompat` | Foundation bridging for common types and protocols such as `DataProtocol`, `ContiguousBytes`, `Date` and string encoding. |


## Installation

**Requirements:**
- Swift 6.2+
- macOS 10.15+, iOS 13+, tvOS 13+, watchOS 6+
- Supported Non-Apple platforms: Linux, Windows and Android

Add this package to the dependencies of your SPM project:

```swift
.package(url: "https://github.com/Star-Lord-PHB/swift-file-system", from: "0.1.0")
```

Add the module you need to your target's dependencies:

```swift
.target(
    name: "MyTarget",
    dependencies: [
        .product(name: "SwiftAsyncFileSystem", package: "swift-file-system"),
    ]
)
```

In your source file, import the module:

```swift
import SwiftAsyncFileSystem
```


## Some Examples

**Get metadata of a file:**

```swift
let fs = AsyncFileSystem()
let info = try await fs.info(ofItemAt: "file.txt")

print(
    """
    size: \(info.size)
    type: \(info.type)
    last access time: \(info.times.lastAccess)
    last modification time: \(info.times.lastModification)
    last status change time: \(info.times.lastChange)
    creation time: \(info.times.creation, default: "Not available on current platform")
    file identifier: \(info.fileIdentifier)
    file attributes: \(info.attributes)
    """
)
```

**Create a file with data:**

```swift
// with path based API
let fs = AsyncFileSystem()
let data = ByteBuffer("Hello Swift FileSystem!".utf8)
try await fs.createFile(at: "file.txt", contents: data)
```

**Updating a file with handle:**

```swift
let handle = try await AsyncReadWriteFileHandle(
    forFileAt: "file.txt",
    options: .editFile(createIfMissing: false)
)

try await handle.write(.init("Hello Swift FileSystem!".utf8), toOffset: 0)

let data = Data("AsyncFileSystem!".utf8)
try await handle.write(data.bytes, toOffset: 12)

let readData = try await handle.read(fromOffset: 0, length: 30)
print(String(decoding: readData, as: UTF8.self))    // Hello Swift AsyncFileSystem!
```

**Traversing a directory recursively:**

```swift
var dirIterator = AsyncDirectoryEntryRecursiveSequence(dirAt: "dir").makeAsyncIterator()

while let element = try await dirIterator.next() {

    switch element {
        case .entry(let entry):
            print("entry: \(entry.path), type: \(entry.type)")
        case .leavingDir(let path, nil):
            print("leaving dir: \(path)")
        case .leavingDir(let path, .some(let error)):
            print("leaving dir \(path) with error: \(error)")
        case .subTreeError(let path, let error):
            print("fail to enter a directory at \(path) with error: \(error)")
        case .entryError(let path, let error):
            print("fail to read an entry at \(path) with error: \(error)")
    }

    if element.path == "dir/subdir" {
        // Will not enter "dir/subdir" and skip all its descendants
        dirIterator.skipDescendants()
    }

}
```

**Copying a directory recursively:**

```swift
let fs = AsyncFileSystem()

let copyResult = await fs.copyItem(
    at: "dir",
    to: "dir_copy",
    options: .init(existingTarget: .error),
    errorStrategy: .collectAndReturn
)

if copyResult.operationCancelled {
    print("Copy operation was cancelled")
}
if let errors = copyResult.itemErrors {
    print("Copy finished with errors:")
    for error in errors {
        print("  - \(error.itemRelativePath): \(error.kind) when doing \(error.operation)")
    }
}
```

**Error Handling**

```swift
let fs = AsyncFileSystem()
do {
    try await fs.createFile(at: "dir/subdir", replaceExisting: false)
} catch let error where error.kind == .alreadyExists {
    print("File already exists")
} catch let error where error.kind == .permissionDenied {
    print("No permission to create file")
} catch {
    print("Other error case: \(error)")
}
```
