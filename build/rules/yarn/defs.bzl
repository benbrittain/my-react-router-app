load("@prelude//:paths.bzl", "paths")

JsToolchainInfo = provider(
    fields = {
        "esbuild": str,
        "node": str,
        "typescript_compiler": str,
    },
)

JsModuleInfo = provider(
    fields = {
        "pkg_loc": Dependency,
        # "entry": str,
        "name": str,
        "reference": str,
        "deps": list[Dependency],
    },
)

def _yarn_dep_impl(ctx: AnalysisContext) -> list[Provider]:
    return [
        JsModuleInfo(
            pkg_loc = ctx.attrs.pkg_loc,
            # entry = ctx.attrs.entry,
            deps = ctx.attrs.deps,
            name = ctx.attrs.pkg_name,
            reference = ctx.attrs.pkg_reference,
        ),
        DefaultInfo(default_outputs = []),
    ]

def yarn_dep(name, pkg_name, pkg_reference, checksum, **kwargs):
    pkg_loc = "{}-resource".format(name)
    native.http_archive(
        name = pkg_loc,
        urls = ["https://registry.npmjs.org/" + pkg_name + "/-/" + pkg_name + "-" + pkg_reference + ".tgz"],
        sha256 = checksum,
    )

    _yarn_dep(
        name = name,
        pkg_name = pkg_name,
        pkg_reference = pkg_reference,
        checksum = checksum,
        pkg_loc = ":" + pkg_loc,
        **kwargs
    )

_yarn_dep = rule(
    impl = _yarn_dep_impl,
    attrs = {
        "pkg_loc": attrs.dep(),
        "pkg_name": attrs.string(),
        "pkg_reference": attrs.string(),
        "checksum": attrs.string(),
        # "entry": attrs.string(),
        "deps": attrs.list(attrs.dep(), default = []),
    },
)

def add_dep(reg_data, mod: JsModuleInfo, js_deps, workspace):
    if mod.name not in reg_data:
        reg_data[mod.name] = {}
    reg_data[mod.name][mod.reference] = {}

    direct_deps = []
    direct_deps.append([mod.name, mod.reference])
    for dep in mod.deps:
        dep = dep[JsModuleInfo]
        pkg_ref = dep.reference

        # pkg_ref = "npm:" + dep.reference
        direct_deps.append([dep.name, pkg_ref])

    pkg_loc_artifact = mod.pkg_loc[DefaultInfo].default_outputs[0]

    js_deps.append(pkg_loc_artifact)

    # pkg_ref = "npm:" + mod.reference
    pkg_ref = mod.reference
    reg_data[mod.name][pkg_ref] = {
        "packageLocation": cmd_args(
            pkg_loc_artifact,
            "package",
            "",
            delimiter = "/",
        ).relative_to(workspace),
        "packageDependencies": direct_deps,
        "linkType": "HARD",
    }

    for dep in mod.deps:
        add_dep(reg_data, dep[JsModuleInfo], js_deps, workspace)

def _generate_reg_data(ctx: AnalysisContext, js_deps, workspace):
    reg_data = {}

    for dep in ctx.attrs.deps:
        add_dep(reg_data, dep[JsModuleInfo], js_deps, workspace)
    return reg_data

def create_pnp_json(ctx: AnalysisContext, workspace) -> (list[Artifact], Artifact):
    reg_data = []
    root_deps = []
    js_deps = []
    for dep in ctx.attrs.deps:
        info = dep[JsModuleInfo]
        pkg_name = info.name

        # pkg_ref = "npm:" + info.reference
        pkg_ref = info.reference
        root_deps.append([pkg_name, pkg_ref])

    reg_data.append(
        [
            None,
            [[
                None,
                {
                    "packageLocation": "./",
                    "packageDependencies": root_deps,
                },
            ]],
        ],
    )

    for (pkg_name, versions) in _generate_reg_data(ctx, js_deps, workspace).items():
        pkg_versions = []
        for (pkg_version, data) in versions.items():
            # pkg_version = "npm:" + pkg_version
            pkg_versions.append(
                [
                    pkg_version,
                    data,
                ],
            )
        reg_data.append([
            pkg_name,
            pkg_versions,
        ])

    pnp_json = ctx.actions.write_json(".pnp.data.json", {
        "__info": [],
        "enableTopLevelFallback": True,
        "dependencyTreeRoots": [
            {
                "name": "monorepo",
                "reference": "workspace:.",
            },
        ],
        # "ignorePatternData": "",
        # "ignorePatternData": "(^(?:\\.yarn\\/sdks(?:\\/(?!\\.{1,2}(?:\\/|$))(?:(?:(?!(?:^|\\/)\\.{1,2}(?:\\/|$)).)*?)|$))$)",
        "fallbackPool": [],
        #     "monorepo",
        #     "workspace:.",
        # ]],
        "fallbackExclusionList": [
            [
                "monorepo",
                [
                    "workspace:.",
                ],
            ],
        ],
        "packageRegistryData": reg_data,
    }, pretty = True)

    return (js_deps, pnp_json)

    # node_env_file = ctx.actions.write(
    #     ".env",
    #     cmd_args([
    #         cmd_args(pnp_json, format = "PNP_BUCK_JSON={}"),
    #         "PNP_DEBUG_LEVEL=0",
    #     ], delimiter = "\n"),
    # )
    # node_loader_cmd = cmd_args([
    #     "node",
    #     "--env-file",
    #     node_env_file.as_output(),
    #     "--require",
    #     ctx.attrs._loader[DefaultInfo].default_outputs[0],
    #     ctx.attrs.entry,
    # ], hidden = [node_env_file, pnp_json])

def _js_module_impl(ctx: AnalysisContext) -> list[Provider]:
    """
    The .pnp.data.json file is part of the yarn pnp specification
    We use that spec to interop with the js ecosystem.
    """

    workspace = ctx.actions.declare_output("__runspace", dir = True)
    (js_deps, pnp_json) = create_pnp_json(ctx, workspace)

    bundle = ctx.actions.declare_output("{}-bundle.js".format(ctx.label.name))

    srcs = {}
    for x in ctx.attrs.srcs:
        srcs[ctx.label.package + "/" + x.short_path] = x
    workspace = ctx.actions.copied_dir(workspace, {
        ".pnp.data.json": pnp_json,
    } | srcs)

    script, _ = ctx.actions.write(
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
                        "--log-level=verbose",
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

    ctx.actions.run(
        cmd_args(["/bin/sh", script], hidden = [bundle.as_output(), workspace] + js_deps),
        category = "bundle",
    )

    return [
        DefaultInfo(default_outputs = [bundle], sub_targets = {
            "pnp": [DefaultInfo(default_output = pnp_json)],
        }),
        # RunInfo(args = node_loader_cmd),
    ]

js_module = rule(
    impl = _js_module_impl,
    attrs = {
        "deps": attrs.list(attrs.dep(providers = [JsModuleInfo])),
        "srcs": attrs.list(attrs.source()),
        "entry": attrs.source(),
        "_loader": attrs.default_only(attrs.dep(default = "//build/rules/yarn:loader")),
        "_toolchain": attrs.toolchain_dep(default = "toolchains//:js", providers = [JsToolchainInfo]),
    },
)

def _js_toolchain_impl(ctx: AnalysisContext) -> list[Provider]:
    return [DefaultInfo(), JsToolchainInfo(
        esbuild = "esbuild",
        typescript_compiler = "tsc",
        node = "node",
    )]

js_toolchain = rule(
    impl = _js_toolchain_impl,
    attrs = {
    },
    is_toolchain_rule = True,
)
