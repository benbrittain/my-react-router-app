load("@prelude//:paths.bzl", "paths")

TypescriptToolchainInfo = provider(
    fields = {
        "compiler": str,
    },
)

def _typescript_toolchain_impl(ctx: AnalysisContext) -> list[Provider]:
    return [DefaultInfo(), TypescriptToolchainInfo(
        compiler = "tsc",
    )]

typescript_toolchain = rule(
    impl = _typescript_toolchain_impl,
    attrs = {
    },
    is_toolchain_rule = True,
)

TypescriptInfo = provider(
    fields = {},
)

def relativize_to_tsconfig(artifact: Artifact, tsconfig_artifact: Artifact) -> cmd_args:
    return cmd_args(
        artifact,
        format = "{}",
        delimiter = "",
    ).relative_to(tsconfig_artifact, parent = 1)

def _typescript_impl(ctx: AnalysisContext) -> list[Provider]:
    out_dir = ctx.actions.declare_output("__output")
    tsconfig_artifact = ctx.actions.declare_output("tsconfig.json")

    src_dir = {}
    for src in ctx.attrs.srcs:
        src_dir[src.short_path] = src
    for gen_ty in ctx.attrs.generated_types:
        src_dir["types"] = gen_ty

    src_dir = ctx.actions.copied_dir("__srcs", src_dir)

    inputs = []
    for src in ctx.attrs.srcs:
        inputs.append(
            relativize_to_tsconfig(src_dir.project(src.short_path), tsconfig_artifact),
        )
    ty_dir = relativize_to_tsconfig(src_dir.project("types"), tsconfig_artifact)
    inputs.append(ty_dir)

    tsconfig = ctx.actions.write_json(
        tsconfig_artifact,
        {
            # Specifies an array of filenames or patterns to include in the program. These filenames are resolved relative to the directory containing the tsconfig.json file.
            "include": inputs,
            "compilerOptions": {
                # https://www.typescriptlang.org/docs/handbook/project-references.html
                "composite": True,
                # "incremental": True,
                "lib": ["DOM", "DOM.Iterable", "ES2022"],
                "types": ["node"],
                "target": "ES2022",
                "module": "ES2022",
                "moduleResolution": "bundler",
                "jsx": "react-jsx",
                "rootDirs": [
                    relativize_to_tsconfig(src_dir, tsconfig_artifact),
                    ty_dir,
                ],
                "paths": {
                    "~/*": ["./app/*"],
                },
                "esModuleInterop": True,
                "verbatimModuleSyntax": True,
                "resolveJsonModule": True,
                "skipLibCheck": True,
                "strict": True,
                "noEmit": True,
                "outDir": relativize_to_tsconfig(out_dir, tsconfig_artifact),
            },
        },
        pretty = True,
    )

    ctx.actions.run(
        cmd_args([
            ctx.attrs._toolchain[TypescriptToolchainInfo].compiler,
            "-p",
            tsconfig,
        ], hidden = [inputs, ctx.attrs.generated_types, out_dir.as_output()]),
        category = "typescript",
    )

    sub_targets = {
        "tsconfig": [DefaultInfo(default_output = tsconfig_artifact)],  #[tsconfig])],
    }

    return [
        TypescriptInfo(),
        DefaultInfo(default_outputs = [out_dir], sub_targets = sub_targets),
    ]

typescript = rule(
    impl = _typescript_impl,
    attrs = {
        "srcs": attrs.list(attrs.source(), default = []),
        "generated_types": attrs.list(attrs.source(), default = []),
        "_toolchain": attrs.toolchain_dep(default = "toolchains//:typescript", providers = [TypescriptToolchainInfo]),
    },
)
