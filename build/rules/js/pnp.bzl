load(":types.bzl", "JsModuleInfo")

def add_dep(reg_data, mod: JsModuleInfo, js_deps, workspace):
    if mod.name not in reg_data:
        reg_data[mod.name] = {}
    reg_data[mod.name][mod.reference] = {}

    direct_deps = []
    direct_deps.append([mod.name, mod.reference])
    for dep in mod.deps:
        dep = dep[JsModuleInfo]
        pkg_ref = dep.reference

        direct_deps.append([dep.name, pkg_ref])

    pkg_loc_artifact = mod.pkg_loc[DefaultInfo].default_outputs[0]

    js_deps.append(pkg_loc_artifact)

    pkg_ref = mod.reference
    reg_data[mod.name][pkg_ref] = {
        "packageLocation": cmd_args(
            pkg_loc_artifact,
            mod.entrypoint,
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
        "fallbackPool": [],
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
