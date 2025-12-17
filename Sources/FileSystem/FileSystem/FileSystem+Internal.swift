import SystemPackage
import PlatformCLib
import CFileSystem



extension FileSystem {

    func _removeDirectoryRecursive(at path: FilePath) throws(SystemError) {

        var enumerator = try DirectoryEntryRecursiveEnumerator(path: path, doStat: false)

        while let enumerationElement = try enumerator.next() {

            switch enumerationElement {
                case .entry(let entry) where entry.type != .directory && entry.path.lastComponent?.kind == .regular:
                    try InternalFS.unlink(fileAt: path.appending(entry.path.components))
                case .leavingDir(let dirPath): 
                    try InternalFS.rmdir(at: path.appending(dirPath.components))
                default:
                    break
            }

        }

        try InternalFS.rmdir(at: path)

    }

}