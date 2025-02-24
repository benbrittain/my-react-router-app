load(":types.bzl", "JsModuleInfo", "JsToolchainInfo")

def _yarn_dep_impl(ctx: AnalysisContext) -> list[Provider]:
    return [
        JsModuleInfo(
            pkg_loc = ctx.attrs.pkg_loc,
            deps = ctx.attrs.deps,
            name = ctx.attrs.pkg_name,
            entrypoint = ctx.attrs.entrypoint,
            reference = ctx.attrs.pkg_reference,
        ),
        DefaultInfo(default_outputs = []),
    ]

def yarn_dep(name, pkg_name, pkg_reference, checksum, **kwargs):
    pkg_loc = "{}-resource".format(name)
    if pkg_name.startswith("@types/"):
        pkg_name_part = pkg_name.split("/")[1]
        entrypoint = pkg_name_part
    else:
        pkg_name_part = pkg_name
        entrypoint = "package"

    native.http_archive(
        name = pkg_loc,
        urls = ["https://registry.npmjs.org/" + pkg_name + "/-/" + pkg_name_part + "-" + pkg_reference + ".tgz"],
        sha256 = checksum,
    )

    _yarn_dep(
        name = name,
        pkg_name = pkg_name,
        pkg_reference = pkg_reference,
        checksum = checksum,
        pkg_loc = ":" + pkg_loc,
        entrypoint = entrypoint,
        **kwargs
    )

_yarn_dep = rule(
    impl = _yarn_dep_impl,
    attrs = {
        "pkg_loc": attrs.dep(),
        "pkg_name": attrs.string(),
        "pkg_reference": attrs.string(),
        "checksum": attrs.string(),
        "entrypoint": attrs.string(),
        "deps": attrs.list(attrs.dep(), default = []),
    },
)
