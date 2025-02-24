JsModuleInfo = provider(
    fields = {
        "pkg_loc": Dependency,
        "name": str,
        "reference": str,
        "entrypoint": str,
        "deps": list[Dependency],
    },
)

JsToolchainInfo = provider(
    fields = {
        "esbuild": str,
        "node": str,
        "typescript_compiler": str,
    },
)
