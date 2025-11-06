import SystemPackage


public enum FileOperationOptions {

    public enum CreateFile {
        case never
        case createIfMissing(permissions: FilePermissions? = nil)
        case assertMissing(permissions: FilePermissions? = nil)

        var unsafeSystemCreationOptions: UnsafeSystemHandle.OpenOptions.CreationOptions {
            switch self {
                case .never:            .never
                case .createIfMissing:  .createIfMissing
                case .assertMissing:    .assertMissing
            }
        }

        var creationPermissions: FilePermissions? {
            switch self {
                case .never:                            nil
                #if !canImport(WinSDK)
                // On Posix, when creating file is requested but no creation permissions are specified, 
                // use default permissions 0o644 (rw-r--r--).
                // On Windows, permissions will be inherited from parent directory, so no need to provide default permissions.
                case .createIfMissing(.none):           [.ownerReadWrite, .groupRead, .otherRead]
                case .assertMissing(.none):             [.ownerReadWrite, .groupRead, .otherRead]
                #endif
                case .createIfMissing(let permissions): permissions
                case .assertMissing(let permissions):   permissions
            }
        }
    }


    public struct OpenForReading {

        public var noFollow: Bool
        public var closeOnExec: Bool


        public init(noFollow: Bool = false, closeOnExec: Bool = true) {
            self.noFollow = noFollow
            self.closeOnExec = closeOnExec
        }


        func unsafeSystemFileOpenOptions(
            platformAdditionalRawFlags: UnsafeSystemHandle.OpenOptions.FlagType = 0
        ) -> UnsafeSystemHandle.OpenOptions {
            .init(
                access: .readOnly(), 
                noFollow: noFollow, 
                closeOnExec: closeOnExec, 
                platformAdditionalRawFlags: platformAdditionalRawFlags
            )
        }

    }


    public struct OpenForDirectory {

        public var noFollow: Bool
        public var closeOnExec: Bool


        public init(noFollow: Bool = false, closeOnExec: Bool = true) {
            self.noFollow = noFollow
            self.closeOnExec = closeOnExec
        }


        func unsafeSystemFileOpenOptions(
            platformAdditionalFlags: UnsafeSystemHandle.OpenOptions.FlagType = 0
        ) -> UnsafeSystemHandle.OpenOptions {
            .init(
                access: .readOnly(), 
                noFollow: noFollow, 
                closeOnExec: closeOnExec, 
                platformSpecificOptions: [.posix.directoryOnly, .windows.backupSemantics],
                platformAdditionalRawFlags: platformAdditionalFlags
            )
        }

    }


    public struct OpenForWriting {

        public var createFile: CreateFile
        public var truncate: Bool 
        public var append: Bool
        public var noFollow: Bool
        public var closeOnExec: Bool

        public var creationPermissions: FilePermissions? {
            createFile.creationPermissions
        }


        public init(
            createFile: CreateFile = .never, 
            truncate: Bool = false, 
            append: Bool = false, 
            noFollow: Bool = false, 
            closeOnExec: Bool = true
        ) {
            self.createFile = createFile
            self.truncate = truncate
            self.append = append
            self.noFollow = noFollow
            self.closeOnExec = closeOnExec
        }


        func unsafeSystemFileOpenOptions(
            platformAdditionalFlags: UnsafeSystemHandle.OpenOptions.FlagType = 0
        ) -> UnsafeSystemHandle.OpenOptions {
            .init(
                access: .writeOnly, 
                creation: createFile.unsafeSystemCreationOptions, 
                truncate: truncate, 
                append: append, 
                noFollow: noFollow, 
                closeOnExec: closeOnExec, 
                platformAdditionalRawFlags: platformAdditionalFlags
            )
        }


        public static func newFile(
            replaceExisting: Bool = true, 
            append: Bool = false, 
            noFollow: Bool = false, 
            closeOnExec: Bool = true,
            creationPermissions: FilePermissions? = nil
        ) -> OpenForWriting {
            if replaceExisting {
                .init(createFile: .createIfMissing(permissions: creationPermissions), truncate: true, append: append, noFollow: noFollow, closeOnExec: closeOnExec)
            } else {
                .init(createFile: .assertMissing(permissions: creationPermissions), truncate: false, append: append, noFollow: noFollow, closeOnExec: closeOnExec)
            }
        }


        public static func editFile(
            createIfMissing: Bool = true, 
            truncate: Bool = false, 
            append: Bool = false, 
            noFollow: Bool = false, 
            closeOnExec: Bool = true,
            creationPermissions: FilePermissions? = nil
        ) -> OpenForWriting {
            .init(
                createFile: createIfMissing ? .createIfMissing(permissions: creationPermissions) : .never, 
                truncate: truncate, 
                append: append, 
                noFollow: noFollow, 
                closeOnExec: closeOnExec
            )
        }

    }

}