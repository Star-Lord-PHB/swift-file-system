import SystemPackage
import FileSystemCore



extension FileSystem {

    public func removeItem(at path: FilePath) throws(PlatformError) {

        do {
            try InternalFS.remove(itemAt: path)
            return 
        } catch let error where error.kind != .notEmptyDirectory {
            throw PlatformError(lowLevelError: error, operation: .remove(path))
        } catch {
            // do nothing
        }

        try _removeDirectoryRecursive(at: path)

    }


    fileprivate func _removeDirectoryRecursive(at path: FilePath) throws(PlatformError) {

        var enumerator = DirectoryEntryRecursiveEnumerator(path: path, doStat: false)

        while true {

            // Currently the deletion is best-effort, meaning that any errors when traversing or deleting 
            // individual items will be ignored and will not currently be reported back to the caller.
            // MARK: TODO: add a callback for reporting errors? 

            let enumerationElement = try catchLowLevelError(operation: .remove(path)) { () throws(LowLevelError) in
                try enumerator.next()
            }
            guard let enumerationElement = enumerationElement else { break }

            try catchLowLevelError(operation: .remove(enumerationElement.path)) { () throws(LowLevelError) in

                switch enumerationElement {
                    case .entry(let entry) where entry.type != .directory && entry.path.lastComponent?.kind == .regular:
                        #if canImport(WinSDK)
                        try? InternalFS.remove(itemAt: path.appending(entry.path.components))
                        #else 
                        try? InternalFS.unlink(fileAt: path.appending(entry.path.components))
                        #endif 
                    case .leavingDir(let dirPath, .none): 
                        try InternalFS.rmdir(at: path.appending(dirPath.components))
                    default:
                        // All the other cases are error cases, currently the strategy is to skip those
                        // items and continue deleting other items.
                        break
                }

            }

        }

        try catchLowLevelError(operation: .remove(path)) { () throws(LowLevelError) in
            try InternalFS.rmdir(at: path)
        }

    }

}