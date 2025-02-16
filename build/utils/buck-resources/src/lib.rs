use std::{
    collections::HashMap,
    ffi::{OsStr, OsString},
    path::PathBuf,
};

use thiserror::Error;

#[derive(Debug, Error)]
pub enum BuckResourcesError {
    #[error("Failed to look up our own executable path")]
    NoCurrentExe { source: std::io::Error },
    #[error("Failed to find parent directory of executable: `{executable_path}`")]
    NoParentDir { executable_path: PathBuf },
    #[error("Executable doesn't have a filename: `{executable_path}`")]
    NoFileName { executable_path: PathBuf },
    #[error(
        "Failed to read manifest file: `{manifest_path}`. \
        Are you maybe running `buck1`? `rust_binary` only supports `resources` under `buck2`!"
    )]
    ReadFailed {
        manifest_path: PathBuf,
        source: std::io::Error,
    },
    #[error("Failed to parse manifest file: `{manifest_path}`")]
    ParsingFailed {
        manifest_path: PathBuf,
        source: serde_json::Error,
    },
    #[error("No resource named `{name}` found in manifest file: `{manifest_path}`")]
    NoSuchResource {
        name: String,
        manifest_path: PathBuf,
    },
    #[error(
        "Resource `{name}` points to invalid path `{resource_path}` in manifest `{manifest_path}`"
    )]
    BadResourcePath {
        name: String,
        resource_path: PathBuf,
        manifest_path: PathBuf,
        source: std::io::Error,
    },
}

/// As seen on https://internals.rust-lang.org/t/pathbuf-has-set-extension-but-no-add-extension-cannot-cleanly-turn-tar-to-tar-gz/14187/10
/// Returns a path with a new dotted extension component appended to the end.
/// Note: does not check if the path is a file or directory; you should do that.
fn append_ext(ext: impl AsRef<OsStr>, path: PathBuf) -> PathBuf {
    let mut os_string: OsString = path.into();
    os_string.push(".");
    os_string.push(ext.as_ref());
    os_string.into()
}

#[test]
fn test_append_ext() {
    let path = PathBuf::from("foo/bar/baz.txt");
    assert_eq!(
        append_ext("app", path),
        PathBuf::from("foo/bar/baz.txt.app"),
    );
}

// N.B.: I spent about an hour trying to make this as lazy as possible. Turns out the potential error we're
// storing in a lazy static would be *borrowed* when resolving it, and most of the wrapped errors
// don't implement `clone`, which is maybe because of backtraces? Consider this for a moment before
// you embark on making this lazy. It *may* be worth it, depending on how exactly this library
// ends up being used. -abesto
/// Look up a resource based on a manifest file. Built to work seamlessly with `resources` defined
/// in a `rust_binary` target, but in principle it would work with any correct manifest file.
///
/// * Manifest location: `$CUR_EXE.resources.json`, where `$CUR_EXE` is the absolute path of the
///   currently executing binary.
/// * Relative paths in the manifest are resolved relative to the location of the currently
///   executing binary.
pub fn get_resource<S>(name: S) -> Result<PathBuf, BuckResourcesError>
where
    S: AsRef<str>,
{
    // This is horrible and I wish there was a better way of doing it
    let executable_path =
        std::env::current_exe().map_err(|source| BuckResourcesError::NoCurrentExe { source })?;

    let dir = match executable_path.parent() {
        Some(x) => x,
        None => return Err(BuckResourcesError::NoParentDir { executable_path }),
    };

    let file_name = match executable_path.file_name() {
        Some(x) => x,
        None => return Err(BuckResourcesError::NoFileName { executable_path }),
    };

    let manifest_path = append_ext("resources.json", dir.join(file_name));
    let manifest_str = match std::fs::read_to_string(&manifest_path) {
        Ok(s) => s,
        Err(source) => {
            return Err(BuckResourcesError::ReadFailed {
                manifest_path,
                source,
            });
        }
    };

    let manifest: HashMap<String, PathBuf> = match serde_json::from_str(&manifest_str) {
        Ok(x) => x,
        Err(source) => {
            return Err(BuckResourcesError::ParsingFailed {
                source,
                manifest_path,
            });
        }
    };

    if let Some(resource_path) = manifest.get(name.as_ref()) {
        if resource_path.is_relative() {
            let p = dir.join(resource_path);
            dunce::canonicalize(&p).map_err(|err| (p, err))
        } else {
            dunce::canonicalize(resource_path).map_err(|err| (resource_path.clone(), err))
        }
        .map_err(
            |(resource_path, source)| BuckResourcesError::BadResourcePath {
                name: name.as_ref().to_string(),
                resource_path,
                manifest_path,
                source,
            },
        )
    } else {
        Err(BuckResourcesError::NoSuchResource {
            name: name.as_ref().to_string(),
            manifest_path,
        })
    }
}
