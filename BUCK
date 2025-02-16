# A list of available rules and their signatures can be found here: https://buck2.build/docs/api/rules/

load("//rules/typescript:defs.bzl", "typescript")

typescript(
    name = "ts",
    srcs = glob(["app/**"]),
    generated_types = [":react-router"],
)

export_file(
    name = "react-router",
    src = ".react-router/types",
    out = "types",
)
