//! https://yarnpkg.com/advanced/pnpapi
//! https://yarnpkg.com/advanced/pnp-spec

use std::{
    ascii::AsciiExt,
    collections::HashMap,
    fs::File,
    io::{BufRead, BufReader, BufWriter, Read, Write},
    path::{Path, PathBuf},
};

use anyhow::Error;
use clap::{Parser as ClapParser, Subcommand};
use nom::{
    branch::alt,
    bytes::complete::{escaped, tag, take_while},
    character::complete::{
        alphanumeric0, alphanumeric1 as alphanumeric, char, multispace0, multispace1, newline,
        one_of,
    },
    combinator::{cut, map, opt, value},
    error::{context, ContextError, ErrorKind, ParseError},
    multi::{separated_list0, separated_list1},
    number::complete::double,
    sequence::{delimited, preceded, separated_pair, terminated},
    AsChar, Err, IResult, Parser,
};
use nom_language::error::{convert_error, VerboseError};
use regex::Regex;
use serde::Deserialize;
use serde_json::Value;

#[derive(ClapParser)]
struct Args {
    /// yarn lock
    yarnlock: PathBuf,
    /// generated buck2 file
    output: PathBuf,
}

#[derive(Debug, Default, Clone, PartialEq, Eq)]
struct Dep {
    name: String,
    version: String,
}

fn sp<'a, E: ParseError<&'a str>>(i: &'a str) -> IResult<&'a str, &'a str, E> {
    let chars = " \t\r\n";

    // nom combinators like `take_while` return a function. That function is the
    // parser,to which we can pass the input
    take_while(move |c| chars.contains(c))(i)
}

fn ident<'a, E: ParseError<&'a str>>(i: &'a str) -> IResult<&'a str, &'a str, E> {
    let chars = "<>%^#!=&:^./-@";
    take_while(move |c: char| chars.contains(c) | c.is_alphanum())(i)
}

fn bare_ident<'a, E: ParseError<&'a str>>(i: &'a str) -> IResult<&'a str, &'a str, E> {
    let chars = "^-./";
    take_while(move |c: char| chars.contains(c) | c.is_alphanum())(i)
}

fn version<'a, E: ParseError<&'a str>>(i: &'a str) -> IResult<&'a str, &'a str, E> {
    let chars = "-.";
    take_while(move |c: char| chars.contains(c) | c.is_alphanum())(i)
}

fn checksum<'a, E: ParseError<&'a str>>(i: &'a str) -> IResult<&'a str, &'a str, E> {
    let chars = "/";
    take_while(move |c: char| chars.contains(c) | c.is_alphanum())(i)
}

#[derive(Debug, PartialEq)]
struct YarnDep<'a> {
    name: &'a str,
    version: &'a str,
}

#[derive(Debug, PartialEq)]
struct YarnTarget<'a> {
    name: &'a str,
    version: &'a str,
    resolution: &'a str,
    bins: Vec<(&'a str, &'a str)>,
    dependencies: Vec<YarnDep<'a>>,
    checksum: Option<&'a str>,
    lang_name: &'a str,
    link_type: &'a str,
}

fn parse_str<'a, E: ParseError<&'a str>>(i: &'a str) -> IResult<&'a str, &'a str, E> {
    escaped(alphanumeric, '\\', one_of("\"n\\"))(i)
}

fn string<'a, E: ParseError<&'a str> + ContextError<&'a str>>(
    i: &'a str,
) -> IResult<&'a str, &'a str, E> {
    context(
        "string",
        preceded(char('\"'), cut(terminated(ident, char('\"')))),
    )
    .parse(i)
}

fn dependency<'a, E: ParseError<&'a str> + ContextError<&'a str>>(
    i: &'a str,
) -> IResult<&'a str, YarnDep<'_>, E> {
    map(
        separated_pair(
            alt((string, bare_ident)),
            tag(": "),
            alt((string, bare_ident)),
        ),
        |(name, version)| YarnDep { name, version },
    )
    .parse(i)
}

fn pdmeta<'a, E: ParseError<&'a str> + ContextError<&'a str>>(
    i: &'a str,
) -> IResult<&'a str, (), E> {
    map(
        (
            tag("    "),
            bare_ident,
            tag(":\n      optional: "),
            bare_ident,
        ),
        |_| (),
    )
    .parse(i)
}

fn yarn_bin<'a, E: ParseError<&'a str> + ContextError<&'a str>>(
    i: &'a str,
) -> IResult<&'a str, Vec<(&str, &str)>, E> {
    (preceded(
        tag("  bin:\n"),
        separated_list0(
            tag("\n"),
            preceded(
                tag("    "),
                separated_pair(
                    alt((string, bare_ident)),
                    tag(": "),
                    alt((string, bare_ident)),
                ),
            ),
        ),
    ))
    .parse(i)
}

fn yarn_target<'a, E: ParseError<&'a str> + ContextError<&'a str>>(
    i: &'a str,
) -> IResult<&'a str, YarnTarget<'_>, E> {
    map(
        (
            terminated(string, tag(":\n")),
            terminated(preceded(tag("  version: "), version), newline),
            terminated(preceded(tag("  resolution: "), string), newline),
            opt(terminated(yarn_bin, newline)),
            opt(terminated(
                (preceded(
                    tag("  dependencies:\n"),
                    separated_list0(tag("\n"), preceded(tag("    "), dependency)),
                )),
                newline,
            )),
            opt(terminated(
                (preceded(
                    tag("  peerDependencies:\n"),
                    separated_list0(tag("\n"), preceded(tag("    "), dependency)),
                )),
                newline,
            )),
            opt(terminated(
                (preceded(
                    tag("  peerDependenciesMeta:\n"),
                    separated_list0(tag("\n"), pdmeta),
                )),
                newline,
            )),
            opt(terminated(preceded(tag("  checksum: "), checksum), newline)),
            terminated(preceded(tag("  languageName: "), alphanumeric), newline),
            terminated(preceded(tag("  linkType: "), alphanumeric), newline),
        ),
        |(
            name,
            version,
            resolution,
            bins,
            dependencies,
            _peer_deps,
            _peer_deps_meta,
            checksum,
            lang_name,
            link_type,
        )| {
            let dependencies = dependencies.unwrap_or_else(|| vec![]);
            let bins = bins.unwrap_or_else(|| vec![]);
            YarnTarget {
                name,
                version,
                resolution,
                bins,
                dependencies,
                checksum,
                lang_name,
                link_type,
            }
        },
    )
    .parse(i)
}

/// the root element of a JSON parser is either an object or an array
fn root<'a, E: ParseError<&'a str> + ContextError<&'a str>>(
    i: &'a str,
) -> IResult<&'a str, Vec<YarnTarget>, E> {
    separated_list1(sp, yarn_target).parse(i)
}

fn main() -> Result<(), Error> {
    let args = Args::parse();
    let f = File::create(args.output)?;
    let mut f = BufWriter::new(f);
    let mut buf = String::new();

    let mut file = File::open(args.yarnlock)?;
    let mut reader = BufReader::new(file);
    for _ in 0..7 {
        // ugly hack to not parse the first few lines of a yarn.lock
        let buf = &mut Default::default();
        reader.read_line(buf);
    }
    reader.read_to_string(&mut buf);
    writeln!(f, r#"load("//build/rules/js/defs.bzl", "yarn_dep")"#);
    match root::<(&str, ErrorKind)>(&buf) {
        Err(e) => {
            panic!("error: {e}");
        }
        Ok((r, packages)) => {
            assert_eq!(r, "", "yarn.lock was not fully parsed.");
            let mut lookup: HashMap<(String, String), String> = HashMap::new();
            // lookup table
            for package in &packages {
                let name_components: Vec<&str> = package.name.split("@npm:").collect();
                if name_components.len() <= 1 {
                    // top level target
                    continue;
                }
                // dbg!(&name_components);
                let pkg_name = name_components[0];
                let unresolved_version = name_components[1];

                let pkg_reference = package.version;
                lookup.insert(
                    (pkg_name.to_string(), format!("npm:{unresolved_version}")),
                    format!("{pkg_name}-{pkg_reference}"),
                );
            }
            // dbg!(&lookup);

            for package in &packages {
                if package.name.contains("monorepo-yarn") {
                    // skip the top-level root target
                    continue;
                }
                if package.name.contains("@patch") {
                    // skip the patch targets for now
                    continue;
                }
                // if package.name.contains("@types") {
                // skip the type targets for now
                // continue;
                // }
                let pkg_name = package.name.split("@npm:").next().unwrap();
                let pkg_reference = package.version;
                let pkg_chksum = package.checksum.unwrap();
                let pkg_name_part = pkg_name.to_string();
                let pkg_name_part = pkg_name_part.trim_start_matches("@types/").to_string();
                let url = format!(
                    "https://registry.npmjs.org/{pkg_name}/-/{pkg_name_part}-{pkg_reference}.tgz"
                );
                let body = reqwest::blocking::get(&url)?.bytes()?;
                let sha = sha256::digest_bytes(&body);
                write!(
                    f,
                    r#"yarn_dep(
    name = "{pkg_name}-{pkg_reference}",
    pkg_name = "{pkg_name}",
    pkg_reference = "{pkg_reference}",
    checksum = "{sha}",
    deps = ["#
                );
                for dep in &package.dependencies {
                    write!(
                        f,
                        r#"
        ":{}","#,
                        lookup
                            .get(&(dep.name.to_string(), dep.version.to_string()))
                            .expect("must have key")
                    );
                }
                writeln!(
                    f,
                    r#"
    ],
    visibility = ["PUBLIC"],
)
            "#
                );
            }
        }
    }
    Ok(())
}
