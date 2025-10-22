
public enum FileOperationOptions {

    public enum OpenFile {
        case direct
        case truncate
    }


    public enum CreateFile {
        case createIfMissing 
        case assertMissing
    }


    public struct Write {

        public let openFile: OpenFile
        public let createFile: CreateFile?


        public init(openFile: OpenFile = .direct, createFile: CreateFile? = nil) {
            self.openFile = openFile
            self.createFile = createFile
        }


        public static func newFile(replaceExisting: Bool = true) -> Write {
            if replaceExisting {
                .init(openFile: .truncate, createFile: .createIfMissing)
            } else {
                .init(openFile: .direct, createFile: .assertMissing)
            }
        }


        public static func editFile(createIfMissing: Bool = true, truncate: Bool = false) -> Write {
            .init(openFile: truncate ? .truncate : .direct, createFile: createIfMissing ? .createIfMissing : nil)
        }

    }

}