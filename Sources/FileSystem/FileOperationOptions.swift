import Foundation

#if canImport(WinSDK)
import WinSDK
#endif


public enum FileOperationOptions {

    public enum CreateFile {
        case never
        case createIfMissing 
        case assertMissing

        var unsafeSystemCreationOptions: UnsafeSystemHandle.OpenOptions.CreationOptions {
            switch self {
                case .never:            .never
                case .createIfMissing:  .createIfMissing
                case .assertMissing:    .assertMissing
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
            noBlocking: Bool = false, 
            platformAdditionalFlags: UnsafeSystemHandle.OpenOptions.FlagType = 0
        ) -> UnsafeSystemHandle.OpenOptions {
            .init(
                access: .readOnly(), 
                noFollow: noFollow, 
                closeOnExec: closeOnExec, 
                noBlocking: noBlocking, 
                platformAdditionalFlags: platformAdditionalFlags
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
                platformAdditionalFlags: platformAdditionalFlags
            )
        }

    }


    public struct OpenForWriting {

        public var createFile: CreateFile
        public var truncate: Bool 
        public var append: Bool
        public var noFollow: Bool
        public var closeOnExec: Bool


        public init(createFile: CreateFile = .never, truncate: Bool = false, append: Bool = false, noFollow: Bool = false, closeOnExec: Bool = true) {
            self.createFile = createFile
            self.truncate = truncate
            self.append = append
            self.noFollow = noFollow
            self.closeOnExec = closeOnExec
        }


        func unsafeSystemFileOpenOptions(
            noBlocking: Bool = false, 
            platformAdditionalFlags: UnsafeSystemHandle.OpenOptions.FlagType = 0
        ) -> UnsafeSystemHandle.OpenOptions {
            .init(
                access: .writeOnly, 
                creation: createFile.unsafeSystemCreationOptions, 
                truncate: truncate, 
                append: append, 
                noFollow: noFollow, 
                closeOnExec: closeOnExec, 
                noBlocking: noBlocking, 
                platformAdditionalFlags: platformAdditionalFlags
            )
        }


        public static func newFile(
            replaceExisting: Bool = true, 
            append: Bool = false, 
            noFollow: Bool = false, 
            closeOnExec: Bool = true
        ) -> OpenForWriting {
            if replaceExisting {
                .init(createFile: .createIfMissing, truncate: true, append: append, noFollow: noFollow, closeOnExec: closeOnExec)
            } else {
                .init(createFile: .assertMissing, truncate: false, append: append, noFollow: noFollow, closeOnExec: closeOnExec)
            }
        }


        public static func editFile(
            createIfMissing: Bool = true, 
            truncate: Bool = false, 
            append: Bool = false, 
            noFollow: Bool = false, 
            closeOnExec: Bool = true
        ) -> OpenForWriting {
            .init(createFile: createIfMissing ? .createIfMissing : .never, truncate: truncate, append: append, noFollow: noFollow, closeOnExec: closeOnExec)
        }

    }

}