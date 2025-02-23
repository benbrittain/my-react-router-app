A demo of setting up a multi-language rust + javascript buck2 project. Very rudimentary and a work in progress.

## Example
```
buckle run //backend
```

(Example uses [buckle](https://github.com/benbrittain/buckle))

## Rules

### Rust
Rust uses the Meta provided buck2 prelude rules with the exception of a buildscript patch that in conjunction with rust nightly allows passing env variables through build scripts. This allows avoiding a tedious reindeer fixup. 

### Javascript
Uses the [Yarn PnP spec](https://yarnpkg.com/advanced/pnp-spec) to inform the build system of how to resolve javascript dependencies. Rules either incorporate (or plan on) `esbuild`, `tsc`, and `node` to create a holistic js ruleset.

## Third Party (//third-party)

### Rust
Rust uses `reindeer` to convert cargo.toml to `BUCK`. Use `third-party/rust/update.sh`

### Javascript
Js/Yarn uses `//build/utils/pnp-buck` to generate a BUCK file off the yarn.lock. Use `third-party/js/update.sh`.
