import SystemPackage
import FileSystemCore



extension FileSystem {

    func _removeDirectoryRecursive(at path: FilePath) throws(PlatformError) {

        var enumerator = try catchSystemError(operation: .remove(path)) { () throws(SystemError) in
            try DirectoryEntryRecursiveEnumerator(path: path, doStat: false)
        }

        while true {

            let enumerationElement = try catchSystemError(operation: .remove(path)) { () throws(SystemError) in
                try enumerator.next()
            }
            guard let enumerationElement = enumerationElement else { break }

            try catchSystemError(operation: .remove(enumerationElement.path)) { () throws(SystemError) in

                switch enumerationElement {
                    case .entry(let entry) where entry.type != .directory && entry.path.lastComponent?.kind == .regular:
                        #if canImport(WinSDK)
                        try InternalFS.remove(itemAt: path.appending(entry.path.components))
                        #else 
                        try InternalFS.unlink(fileAt: path.appending(entry.path.components))
                        #endif 
                    case .leavingDir(let dirPath): 
                        try InternalFS.rmdir(at: path.appending(dirPath.components))
                    default:
                        break
                }

            }

        }

        try catchSystemError(operation: .remove(path)) { () throws(SystemError) in
            try InternalFS.rmdir(at: path)
        }

    }

}