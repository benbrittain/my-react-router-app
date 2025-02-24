load("@prelude//:paths.bzl", "paths")
load(":pnp.bzl", "create_pnp_json")
load(":types.bzl", "JsModuleInfo", "JsToolchainInfo")
load(":typescript.bzl", "create_tsconfig")
load(":yarn.bzl", _yarn_dep = "yarn_dep")

# re-export
yarn_dep = _yarn_dep

def _js_module_impl(ctx: AnalysisContext) -> list[Provider]:
    """
    The .pnp.data.json file is part of the yarn pnp specification
    We use that spec to interop with the js ecosystem.
    """

    workspace = ctx.actions.declare_output("__workspace", dir = True)
    (js_deps, pnp_json) = create_pnp_json(ctx, workspace)

    bundle = ctx.actions.declare_output("{}-bundle.js".format(ctx.label.name))

    srcs = {}
    for x in ctx.attrs.srcs:
        srcs[ctx.label.package + "/" + x.short_path] = x
    workspace = ctx.actions.copied_dir(workspace, {
        ".pnp.data.json": pnp_json,
    } | srcs)

    esbuild_script, _ = ctx.actions.write(
        "bundle.sh",
        [
            cmd_args([
                "set -e",
                cmd_args(workspace, format = "cd {}"),
                cmd_args(
                    [
                        ctx.attrs._toolchain[JsToolchainInfo].esbuild,
                        "--bundle",
                        "--sourcemap=external",
                        "--loader:.js=jsx",
                        "--format=cjs",
                        # "--log-level=verbose",
                        ctx.attrs.entry,
                        cmd_args(bundle, format = "--outfile={}").relative_to(workspace),
                    ],
                    delimiter = " ",
                ),
            ]),
        ],
        is_executable = True,
        allow_args = True,
    )

    # Tell custom pnp node loader where to load the pnp json from
    node_env_file = ctx.actions.write(
        ".env",
        cmd_args([
            cmd_args(
                pnp_json,
                format = "PNP_BUCK_JSON={}",
            ).relative_to(workspace),
            "PNP_DEBUG_LEVEL=0",
        ], delimiter = "\n"),
    )

    # Typescript
    tsconfig = create_tsconfig(ctx)
    tsc_output = ctx.actions.declare_output("{}-stdout".format(ctx.label.name))

    loader = ctx.attrs._loader[DefaultInfo].default_outputs[0]
    tsc_script, _ = ctx.actions.write(
        "typecheck.sh",
        [
            cmd_args([
                "set -e",
                cmd_args(workspace, format = "cd {}"),
                cmd_args(
                    [
                        # node --require <pnploader.js> tsc -p tsconfig.toml
                        ctx.attrs._toolchain[JsToolchainInfo].node,
                        "--env-file",
                        cmd_args(node_env_file.as_output()).relative_to(workspace),
                        "--require",
                        cmd_args(loader).relative_to(workspace),
                        ctx.attrs._toolchain[JsToolchainInfo].typescript_compiler,
                        "-p",
                        cmd_args(tsconfig).relative_to(workspace),
                    ],
                    delimiter = " ",
                ),
                cmd_args(tsc_output, format = "$? || touch {}").relative_to(workspace),
            ]),
        ],
        is_executable = True,
        allow_args = True,
    )

    ctx.actions.run(
        cmd_args(["/bin/sh", esbuild_script], hidden = [bundle.as_output(), workspace] + js_deps),
        category = "bundle_js",
    )

    ctx.actions.run(
        cmd_args(["/bin/sh", tsc_script], hidden = [
            tsc_output.as_output(),
            node_env_file,
            workspace,
            tsconfig,
            loader,
        ] + js_deps),
        category = "typecheck_js",
    )

    return [
        DefaultInfo(default_outputs = [tsc_output], sub_targets = {
            "tsconfig": [DefaultInfo(default_output = tsconfig)],
            "bundle": [DefaultInfo(default_output = bundle)],
            "pnp": [DefaultInfo(default_output = pnp_json)],
        }),
    ]

js_module = rule(
    impl = _js_module_impl,
    attrs = {
        "deps": attrs.list(attrs.dep(providers = [JsModuleInfo])),
        "srcs": attrs.list(attrs.source()),
        "entry": attrs.source(),
        "_loader": attrs.default_only(attrs.dep(default = "//build/rules/js:loader")),
        "_toolchain": attrs.toolchain_dep(default = "toolchains//:js", providers = [JsToolchainInfo]),
    },
)

def _js_toolchain_impl(ctx: AnalysisContext) -> list[Provider]:
    return [DefaultInfo(), JsToolchainInfo(
        esbuild = ctx.attrs.esbuild,
        typescript_compiler = ctx.attrs.tsc,
        node = ctx.attrs.node,
    )]

js_toolchain = rule(
    impl = _js_toolchain_impl,
    attrs = {
        "esbuild": attrs.string(),
        "tsc": attrs.string(),
        "node": attrs.string(),
    },
    is_toolchain_rule = True,
)
