# glob &middot; [![nimble](https://img.shields.io/badge/available%20on-nimble-yellow.svg?style=flat-square)](https://nimble.directory/pkg/glob) ![license](https://img.shields.io/github/license/citycide/glob.svg?style=flat-square) [![Travis branch](https://img.shields.io/travis/citycide/glob/master.svg?style=flat-square)](https://travis-ci.com/citycide/glob) [![AppVeyor](https://img.shields.io/appveyor/ci/citycide/glob.svg?style=flat-square)](https://ci.appveyor.com/project/citycide/glob)

> Match file paths against Unix style patterns called _globs_.

_glob_ is a cross-platform, pure Nim implementation of [globs][wiki] that supports
creating patterns, testing file paths, and walking through directories to find
matching files or directories.

If you're unfamiliar with globs, they essentially let you use a simple language
to describe what filenames you're looking for with wildcards, placeholders, and
other pretty intuitive features.

You can find the full [documentation here](https://citycide.github.io/glob).

## features

* full glob support across platforms
* all glob syntax: `*` and `?` wildcards plus ranges, groups, & pattern matching
* efficient file system walking without unnecessary traversals
* configurable iteration behavior with sane defaults
* user defined filters for matching and directory traversal

## installation & usage

Install using [Nimble][nimble]:

```shell
nimble install glob
```

Then `import` and use:

```nim
import glob

const pattern = glob("src/**/*.nim")
assert "src/foo.nim".matches(pattern)
assert "src/lib.rs".matches(pattern).not

# directories are expanded by default
# so `src` and `src/**` are equivalent
for path in walkGlob("src"):
  # every file in `src` or its subdirectories, lazily
  echo path

# need the list now (eagerly)?
from sequtils import toSeq
echo toSeq(walkGlob("src/*.nim"))
```

## development

To build `glob` from source you'll need to install [Nim][nim] and its package
manager [Nimble][nimble].

1. Clone the repo: `git clone https://github.com/citycide/glob.git`
2. Move into the newly cloned directory: `cd glob`
3. Make your changes: `src`, `tests.nim`
4. Run tests: `nimble test`

## contributing

This project is open to contributions of all kinds! Please check and search
the [issues](https://github.com/citycide/glob/issues) if you encounter a
problem before opening a new one. Pull requests for improvements are also
welcome &mdash; see the steps above for [development](#development).

## license

MIT © [Bo Lingen / citycide](https://github.com/citycide)

[wiki]: https://en.wikipedia.org/wiki/Glob_(programming)
[nim]: https://github.com/nim-lang/nim
[nimble]: https://github.com/nim-lang/nimble
