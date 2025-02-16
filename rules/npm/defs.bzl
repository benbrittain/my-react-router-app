load("@prelude//:paths.bzl", "paths")

PnpmInfo = provider(
    fields = {},
)

def _pnpm_impl(ctx: AnalysisContext) -> list[Provider]:
    out_dir = ctx.actions.declare_output("node_modules")
    workdir = ctx.actions.symlinked_dir("__workspace", {
        "package.json": ctx.attrs.package,
        "lockfile": ctx.attrs.lockfile,
    })
    ctx.actions.run(
        cmd_args([
            "pnpm",
            "install",
            "-C",
            workdir,
            "--modules-dir",
            cmd_args(out_dir.as_output()).relative_to(workdir),
        ], hidden = [ctx.attrs.package, ctx.attrs.lockfile]),
        category = "pnpm",
    )

    return [
        PnpmInfo(),
        DefaultInfo(default_outputs = [out_dir]),
    ]

pnpm = rule(
    impl = _pnpm_impl,
    attrs = {
        "package": attrs.source(),
        "lockfile": attrs.source(),
    },
)
