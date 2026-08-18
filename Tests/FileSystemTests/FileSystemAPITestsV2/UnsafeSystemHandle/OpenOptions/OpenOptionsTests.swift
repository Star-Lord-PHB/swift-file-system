import Testing



extension UnsafeSystemHandleAPITests {

    /// Value-level tests for `UnsafeSystemHandle.OpenOptions`: the `NativeFlagDiff` invariants and
    /// the derivation of native platform flags from the semantic properties.
    ///
    /// The semantic properties are the single source of truth and native flags are derived on the
    /// fly, so the derivation is observable through the public `accessModeFlags` / `creationFlags`
    /// / `openFlags` properties without opening any file. Behavioral counterparts that do open
    /// files live in the `Open` and platform suites.
    @Suite("OpenOptions")
    struct OpenOptionsTests {}

}
