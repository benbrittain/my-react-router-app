load("@prelude//:paths.bzl", "paths")

YarnInfo = provider(
    fields = {},
)

def _yarn_impl(ctx: AnalysisContext) -> list[Provider]:
    workspace = ctx.actions.declare_output("__workspace")
    cache_folder = ctx.actions.declare_output("cache_folder")
    pnp_data = ctx.actions.declare_output(".pnp.data.json")
    pnp_loader = ctx.actions.declare_output(".pnp.cjs")

    # out_dir = ctx.actions.declare_output("node_modules")
    # workdir = ctx.actions.symlinked_dir("__workspace", {
    #     "package.json": ctx.attrs.package,
    #     "lockfile": ctx.attrs.lockfile,
    # })
    ctx.actions.run(
        cmd_args([
            "yarn",
            "install",
            ])
    #         "-C",
    #         workdir,
    #         "--modules-dir",
    #         cmd_args(out_dir.as_output()).relative_to(workdir),
    #     ], hidden = [ctx.attrs.package, ctx.attrs.lockfile]),
        category = "yarn",
    )

    return [
        YarnInfo(),
        DefaultInfo(default_outputs = [out_dir]),
    ]

yarn = rule(
    impl = _yarn_impl,
    attrs = {
        "package": attrs.source(),
        "lockfile": attrs.source(),
    },
)
