import SwiftFileSystem


extension FileOperationOptions.CopyItemOptions {

    /// Options matching the behavior of the legacy `copyItem(at:to:onExistingTarget:symlinkOption:)` API
    /// these tests were written against: it always restored the source access time and always copied the
    /// exact DACL on Windows.
    static func legacy(
        existingTarget: FileOperationOptions.CopyTargetExistOption = .overwrite,
        symlinkOption: FileOperationOptions.CopyItemSymlinkOption = .copyLink
    ) -> Self {
        .init(
            existingTarget: existingTarget,
            symlinkOption: symlinkOption,
            preserveSrcAccessTime: true,
            windowsPreserveExactDacl: true
        )
    }

}
