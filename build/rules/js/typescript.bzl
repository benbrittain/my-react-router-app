load("@prelude//:paths.bzl", "paths")

def create_tsconfig(ctx: AnalysisContext) -> Artifact:
    tsconfig_artifact = ctx.actions.declare_output("tsconfig.json")

    tsconfig = ctx.actions.write_json(
        tsconfig_artifact,
        {
            # TODO should specify these
            #"include": inputs,
            "compilerOptions": {
                # https://www.typescriptlang.org/docs/handbook/project-references.html
                # "composite": True,
                "lib": ["DOM", "DOM.Iterable", "ES2020"],
                "target": "ES2020",
                "module": "ES2020",
                "useDefineForClassFields": True,
                "isolatedModules": True,
                "moduleDetection": "Force",
                "moduleResolution": "bundler",
                "noUnusedLocals": True,
                "noUnusedParameters": True,
                "noFallthroughCasesInSwitch": True,
                "noUncheckedSideEffectImports": True,
                "jsx": "react-jsx",
                "rootDirs": [
                    ".",
                ],
                "esModuleInterop": True,
                "verbatimModuleSyntax": True,
                "resolveJsonModule": True,
                "skipLibCheck": True,
                "strict": True,
                "noEmit": False,
                "pretty": True,
            },
        },
        pretty = True,
    )
    return tsconfig
