<a name="v0.11.0"></a>
### [`v0.11.0`](https://github.com/citycide/glob/compare/v0.9.1...v0.11.0) (2021-01-16)


###### BREAKING CHANGES

* Nim v1.x is now required.

###### FEATURES

* enable negative match patterns ([`83bdafc`](https://github.com/citycide/glob/commit/83bdafc85ffdcc64004788ded4b94fe8ba06fb7c))

###### BUG FIXES

* make `GlobSyntaxError` derive from `CatchableError` ([`09e50e1`](https://github.com/citycide/glob/commit/09e50e1b89efa886a4a1ec17ac8cc0f8c55006f2))
* change`toPattern` to `re` to avoid deprecation warnings ([`cb7cdd9`](https://github.com/citycide/glob/commit/cb7cdd9a2ef7e878bdd56941cb4a41da8b9fd9d0))

---

<a name="v0.10.0"></a>
### [`v0.10.0`](https://github.com/citycide/glob/compare/v0.9.1...v0.10.0) (2020-11-09)


###### BREAKING CHANGES

* Nim v1.x is now required.

###### BUG FIXES

* make `GlobSyntaxError` derive from `CatchableError` ([`09e50e1`](https://github.com/citycide/glob/commit/09e50e1b89efa886a4a1ec17ac8cc0f8c55006f2))
* change`toPattern` to `re` to avoid deprecation warnings ([`cb7cdd9`](https://github.com/citycide/glob/commit/cb7cdd9a2ef7e878bdd56941cb4a41da8b9fd9d0))

---

<a name="v0.9.1"></a>
### [`v0.9.1`](https://github.com/citycide/glob/compare/v0.9.0...v0.9.1) (2020-11-07)


###### BUG FIXES

* require regex < 0.17 ([#50](https://github.com/citycide/glob/pull/50))) ([`4258cb5`](https://github.com/citycide/glob/commit/4258cb5799792a51e19f56bb8fe8473adc687f82))
* handle symlinks correctly, closes #36 ([#38](https://github.com/citycide/glob/pull/38))) ([`068369b`](https://github.com/citycide/glob/commit/068369b2a9f4e9a47286855c06ca61f3a0b4c2da))
* normalize input paths on posix; simplify code a bit ([#45](https://github.com/citycide/glob/pull/45))) ([`28e5f93`](https://github.com/citycide/glob/commit/28e5f939abae8f60e90bd38773ebea29b09735a6)), closes [#35](https://github.com/citycide/glob/issues/35), [#35](https://github.com/citycide/glob/issues/35)
* normalize input paths ([#37](https://github.com/citycide/glob/pull/37))) ([`4171cfa`](https://github.com/citycide/glob/commit/4171cfa2560ac0436a9f0be5e2f7e6fb384c76a9))


###### CONTRIBUTORS

This release was made possible by:

* [@timotheecour](https://github.com/timotheecour)
* [@xzfc](https://github.com/xzfc)

Thanks!

---

<a name="v0.9.0"></a>
### [`v0.9.0`](https://github.com/citycide/glob/compare/v0.8.1...v0.9.0) (2018-10-02)


###### BREAKING CHANGES

* **walk:** absolute patterns now result in absolute paths if no root is provided (even if
`Absolute notin options`)

###### FEATURES

* **walk:** make `Absolute` option handling smarter (#27) ([`589671a`](https://github.com/citycide/glob/commit/589671a897c12398113605193130d1c60ffab282)), closes [#23](https://github.com/citycide/glob/issues/23)

###### BUG FIXES

* **walk:** ensure hidden directories are not entered on non-Windows systems ([`1ea34f9`](https://github.com/citycide/glob/commit/1ea34f92126eae586528c0552641b9b3bcb1c1b2))
* **walk:** match filesystem casing for entries on macOS (#33) ([`d9d1175`](https://github.com/citycide/glob/commit/d9d1175ef04603d91f7d6bc615a3e799f2111932))
* **compat:** support future module relocation in nim devel (#31) ([`ffd65d3`](https://github.com/citycide/glob/commit/ffd65d3b94109bddb8cb0df0af351aa4f2ef41a6))
* **walk:** handle leading shallow magic correctly (#30) ([`1fa54df`](https://github.com/citycide/glob/commit/1fa54df5fa57e38adc43de2cb050c7748c305047)), closes [#29](https://github.com/citycide/glob/issues/29)
* **walk:** handle leading magic correctly pt. 2 ([`633a87d`](https://github.com/citycide/glob/commit/633a87d18cab63cef8bee2b6674a2c6a768236ca)), closes [#29](https://github.com/citycide/glob/issues/29)
* **windows:** improve case insensitive path handling ([`4a0d545`](https://github.com/citycide/glob/commit/4a0d545e682f3f7792159f31119c34bdf2aaf4e3))

###### CONTRIBUTORS

This release was made possible by:

* [@skellock](https://github.com/skellock)

Thanks!

---

<a name="v0.8.1"></a>
### [`v0.8.1`](https://github.com/citycide/glob/compare/v0.8.0...v0.8.1) (2018-07-21)


###### BUG FIXES

* change `expandGlob` back to `proc` ([`98a5c79`](https://github.com/citycide/glob/commit/98a5c791ed1b024473c345b52b7e7810b8013017)), closes [#21](https://github.com/citycide/glob/issues/21)

---

<a name="v0.8.0"></a>
### [`v0.8.0`](https://github.com/citycide/glob/compare/v0.7.0...v0.8.0) (2018-07-21)


###### BREAKING CHANGES

* `listGlob` has been removed to encourage the use of iterators. `sequtils.toSeq`
from Nim's stdlib can be used to convert the iterators to seqs
* The walk iterators now take an options set rather than multiple boolean parameters
* `GlobResult` has been renamed `GlobEntry`

###### FEATURES

* support case insensitive matching ([`fe17bdd`](https://github.com/citycide/glob/commit/fe17bddcd45f86771ba248a6756143dcd7a5a82d))
* **windows:** match casing of expanded directories to filesystem ([`76e1582`](https://github.com/citycide/glob/commit/76e1582f4f1e36109147aa8882ccc97034f71e6e))
* rename `GlobResult` to `GlobEntry` ([`34fa6f3`](https://github.com/citycide/glob/commit/34fa6f338ae1d41f55aa8a358bb4055cbbdcddd8))
* forward `os.PathComponent` for ease of use ([`de74aff`](https://github.com/citycide/glob/commit/de74affcda0fcebc81da9db80363dacd2005477b))

###### BUG FIXES

* **walk:** expand magic if given a glob ([`8ef605b`](https://github.com/citycide/glob/commit/8ef605b0adac77440e3d8653e0543b489a9bfd00))
* handle empty base paths when joining ([`0cdb00f`](https://github.com/citycide/glob/commit/0cdb00f268fc45df4c9ba73269a5cf54f4a250ee))
* don't recurse into hidden directories when `includeHidden == false` (#14) ([`b6de2fd`](https://github.com/citycide/glob/commit/b6de2fd1a9eff022bc0006e565840f431cb99015))

###### PERFORMANCE

* **walk:** move some processing inside proceed check ([`cfabbea`](https://github.com/citycide/glob/commit/cfabbeaa9496d8e9a96f143f052377ea293f982a))

---

<a name="v0.7.0"></a>
### [`v0.7.0`](https://github.com/citycide/glob/compare/v0.6.0...v0.7.0) (2018-07-04)


###### FEATURES

* normalize returned paths to current os style ([`966e8cf`](https://github.com/citycide/glob/commit/966e8cfdf1bc0f98640dad9b7c8b0615eb2d009d))
* remove `$` to improve inspection & debugging ([`c897d6b`](https://github.com/citycide/glob/commit/c897d6b8d9c2de818ac0cf7567b33e437b5f5ac2))

###### BUG FIXES

* handle absolute paths correctly ([`1753cb8`](https://github.com/citycide/glob/commit/1753cb81f6f184ab40ba11dd2e75024d2617c900))

---

<a name="v0.6.0"></a>
### [`v0.6.0`](https://github.com/citycide/glob/compare/v0.5.0...v0.6.0) (2018-06-06)

This release has the potential to _greatly_ improve performance. `glob` will no
longer traverse into directories or over files that have no hope of matching the
given pattern. A simple example is that a shallow pattern like `*.nim` can only
match files with a `.nim` extension in the current directory &mdash; so `glob`
should never enter a subdirectory or consider files with any other extension.
This is now the case!

TL;DR when using shallow patterns in roots of huge directory structures, users
should see huge performance gains.

###### PERFORMANCE

* optimize walk iterator ([`1a57121`](https://github.com/citycide/glob/commit/1a57121e3810d78c913c9d3a37f36a7ed03cace0))

---

<a name="v0.5.0"></a>
### [`v0.5.0`](https://github.com/citycide/glob/compare/v0.4.0...v0.5.0) (2018-05-30)

This release brings a number of API improvements, the most significant of which
is that procs/iterators like `listGlob` that previously only accepted string
patterns now also accept pre-constructed `Glob` objects:

```nim
import glob
const matcher = glob("src/**/*.nim")

# the following are now equivalent:
listGlob(matcher)
listGlob("src/**/*.nim")
```

This makes globs more reusable and can reduce the number of created objects.

An internal proc named `splitPattern` is now exposed publicly:

```nim
import glob

echo splitPattern("src/dir/**/*.{png,svg}")
# -> (base: "src/dir", magic: "**/*.{png.svg}")
```

The full feature update list is below, and all of these have been documented on
the [full docs site](https://citycide.github.io/glob/).

###### FEATURES

* `walkGlobKinds`, `walkGlob`, & `listGlob` now also accept
a preconstructed `Glob` object instead of a string
* the internal `splitPattern` proc is now publicly exported,
which allows users to split string glob patterns into their
"magic" & "non-magic" (base) parts
* `Glob` objects now contain their `base` & `magic` path segments
* `hasMagic` now checks for extended glob features like pattern
matches

---

<a name="v0.4.0"></a>
### [`v0.4.0`](https://github.com/citycide/glob/compare/v0.3.1...v0.4.0) (2018-05-23)

While it's a fairly small release, almost the entire glob parser was actually rewritten for this
release to make supporting [extended pattern matches](https://citycide.github.io/glob/#syntax-extended-pattern-matching)
easier and to generally make it simpler. :tada:

###### FEATURES

* add extended pattern matching ([`a7cf070`](https://github.com/citycide/glob/commit/a7cf0708335459c2acf969182f2a1cdf6bb37d7f))

---

<a name="v0.3.1"></a>
### [`v0.3.1`](https://github.com/citycide/glob/compare/v0.3.0...v0.3.1) (2018-05-22)


###### BUG FIXES

* correctly handle patterns in cwd ([`ee12839`](https://github.com/citycide/glob/commit/ee12839bc3e13b886f0df9bc75da52e1993437c5))

---

<a name="v0.3.0"></a>
### [`v0.3.0`](https://github.com/citycide/glob/compare/v0.2.0...v0.3.0) (2018-05-22)

###### FEATURES

* allow matching `]` in character class ([`991553b`](https://github.com/citycide/glob/commit/991553b8de6dc32015e7976348eb0660a255d93d))

###### BUG FIXES

* error correctly on invalid character escapes ([`2ae42eb`](https://github.com/citycide/glob/commit/2ae42eb9b357e70a3780b6b8516e9150cfb8c683))

---

<a name="v0.2.0"></a>
### [`v0.2.0`](https://github.com/citycide/glob/compare/v0.1.0...v0.2.0) (2018-05-22)


###### FEATURES

* support posix character classes ([`a8a8fc6`](https://github.com/citycide/glob/commit/a8a8fc623a7d8c353a54c1482a7a1915f1ea53e1))

---

<a name="v0.1.0"></a>
### `v0.1.0` (2018-05-20)

Initial release.
