import PlatformCLib
import SystemPackage
import Testing



extension FileSystemTestSupport {

    /// A name whose platform characters are not valid Unicode: `base` followed by a lone 0xFF byte
    /// on POSIX, or by an unpaired high surrogate on Windows.
    ///
    /// Converting it to `String` repairs that character to U+FFFD, giving
    /// ``nameAfterLossyStringConversion(of:)``. Workspace helpers create items through Foundation,
    /// which takes `String` paths, so a test creates the item under a plain name and gives it this
    /// name with ``Workspace/renameNatively(_:to:sourceLocation:)``.
    static func nonUnicodeName(_ base: String) -> FilePath.Component {
        #if canImport(WinSDK)
        let platformString = Array(base.utf16) + [0xD800, 0] as [CInterop.PlatformChar]
        #else
        let platformString = base.utf8.map { CChar(bitPattern: $0) } + [CChar(bitPattern: 0xFF), 0]
            as [CInterop.PlatformChar]
        #endif
        return FilePath.Component(platformString: platformString)!
    }


    /// The name `name` turns into when converted to `String` and back: every character that is not
    /// valid Unicode becomes U+FFFD. Tests give a sibling this name, so code that opens a path
    /// through such a lossy conversion reaches the sibling instead and is caught.
    static func nameAfterLossyStringConversion(of name: FilePath.Component) -> FilePath.Component {
        FilePath.Component(name.string)!
    }

}



extension FileSystemTestSupport.Workspace {

    /// Renames the item at `itemPath` within its directory with a native call, so `newName` stays
    /// byte-exact, and returns the new absolute path.
    @discardableResult
    func renameNatively(
        _ itemPath: FilePath,
        to newName: FilePath.Component,
        sourceLocation: SourceLocation = #_sourceLocation
    ) throws -> FilePath {
        let source = path(itemPath)
        let destination = source.removingLastComponent().appending(newName)
        #if canImport(WinSDK)
        let renamed = source.withPlatformString { sourcePointer in
            destination.withPlatformString { MoveFileExW(sourcePointer, $0, 0) }
        }
        let error = GetLastError()
        try #require(renamed, "MoveFileExW failed with error \(error)", sourceLocation: sourceLocation)
        #else
        let result = source.withPlatformString { sourcePointer in
            destination.withPlatformString { rename(sourcePointer, $0) }
        }
        try #require(result == 0, "rename failed with errno \(errno)", sourceLocation: sourceLocation)
        #endif
        return destination
    }

}
