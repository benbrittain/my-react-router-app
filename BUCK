load("//rules/typescript:defs.bzl", "typescript")

typescript(
    name = "app",
    srcs = glob(["app/**"]),
    generated_types = [":react-router"],
    node_modules = ":node_modules",
)

# TODO It would be nice to replace this with a genrule
# or a dedicated react-router rule to generate the types.
# instead currently run `npx react-router typegen` to refresh.
export_file(
    name = "react-router",
    src = ".react-router/types",
    out = "types",
)

export_file(
    name = "node_modules",
    src = "node_modules",
)
