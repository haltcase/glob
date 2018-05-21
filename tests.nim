import future
import ospaths
from os import createDir, removeDir, getCurrentDir
from sequtils import mapIt
from algorithm import sortedByIt

import unittest

import src/glob

template isEquiv (pattern, expected: string; forDos = false): bool =
  globToRegexString(pattern, forDos) == expected

template isMatchTest (pattern, input: string; forDos = false): bool =
  matches(input, pattern, forDos)

proc touchFile (path: string) =
  let (head, _) = path.splitPath
  head.createDir
  var f = open(path, fmWrite)
  f.write("")
  f.close

proc createStructure (dir: string, files: seq[string]): () -> void =
  dir.removeDir
  dir.createDir
  for file in files:
    touchFile(dir / file)

  result = () => removeDir(dir)

proc seqsEqual (seq1, seq2: seq[string]): bool =
  seq1.sortedByIt(it) == seq2.sortedByIt(it)

suite "globToRegex":
  test "produces equivalent regular expressions":
    check isEquiv("literal", r"^literal$")
    check isEquiv("*", r"^[^/]*$")
    check isEquiv("**", r"^(?:[^\/]*(?:\/|$))*$")
    check isEquiv("src/*.nim", r"^src/[^/]*\.nim$")
    check isEquiv("src/**/*.nim", r"^src/(?:[^\/]*(?:\/|$))*[^/]*\.nim$")

    check isEquiv(r"\{foo*", r"^\{foo[^/]*$")
    check isEquiv(r"*\}.html", r"^[^/]*}\.html$")
    check isEquiv(r"\[foo*", r"^\[foo[^/]*$")
    check isEquiv(r"*\].html", r"^[^/]*\]\.html$")

suite "regex matching":
  test "basic":
    check isMatchTest("literal", "literal")
    check isMatchTest("literal", "lateral").not
    check isMatchTest("foo.nim", "foo.nim")
    check isMatchTest("foo.nim", "bar.nim").not
    check isMatchTest("src/foo.nim", "src/foo.nim")
    check isMatchTest("src/foo.nim", "foo.nim").not

  test "wildcards (single character)":
    check isMatchTest("?oo.html", "foo.html")
    check isMatchTest("??o.html", "foo.html")
    check isMatchTest("???.html", "foo.html")
    check isMatchTest("???.htm?", "foo.html")
    check isMatchTest("foo.???", "foo.html").not

  test "wildcards & globstars":
    check isMatchTest("*", "matches_anything")
    check isMatchTest("*", "matches_anything/but_not_this").not
    check isMatchTest("**", "matches_anything/even_this")

    check isMatchTest("src/*.nim", "src/foo.nim")
    check isMatchTest("src/*.nim", "src/bar.nim")
    check isMatchTest("src/*.nim", "src/foo/deep.nim").not
    check isMatchTest("src/*.nim", "src/foo/deep/deeper/dir/file.nim").not

    check isMatchTest("f*", "foo.html")
    check isMatchTest("*.html", "foo.html")
    check isMatchTest("foo.html*", "foo.html")
    check isMatchTest("*foo.html", "foo.html")
    check isMatchTest("*foo.html*", "foo.html")
    check isMatchTest("*.htm", "foo.html").not
    check isMatchTest("f.*", "foo.html").not

    check isMatchTest("src/**/*.nim", "foo.nim").not
    check isMatchTest("src/**/*.nim", "src/foo.nim")
    check isMatchTest("src/**/*.nim", "src/foo/deep.nim")
    check isMatchTest("src/**/*.nim", "src/foo/deep/deeper/dir/file.nim")

  test "brace expansion":
    check isMatchTest("src/file.{nim,js}", "src/file.nim")
    check isMatchTest("src/file.{nim,js}", "src/file.js")
    check isMatchTest("src/file.{nim,js}", "src/file.java").not
    check isMatchTest("src/file.{nim,js}", "src/file.rs").not

  test "ranges":
    check isMatchTest("[f]oo.html", "foo.html")
    check isMatchTest("[e-g]oo.html", "foo.html")
    check isMatchTest("[abcde-g]oo.html", "foo.html")
    check isMatchTest("[abcdefx-z]oo.html", "foo.html")
    check isMatchTest("[!a]oo.html", "foo.html")
    check isMatchTest("[!a-e]oo.html", "foo.html")
    check isMatchTest("foo[-a-z]bar", "foo-bar")
    check isMatchTest("foo[!-]html", "foo.html")

    check isMatchTest("[f]oo.{[h]tml,class}", "foo.html")
    check isMatchTest("foo.{[a-z]tml,class}", "foo.html")
    check isMatchTest("foo.{[!a-e]tml,.class}", "foo.html")

  test "medium complexity":
    let pattern = "src/**/*.{nim,js}"
    check isMatchTest(pattern, "src/file.nim")
    check isMatchTest(pattern, "src/file.js")
    check isMatchTest(pattern, "src/deep/file.nim")
    check isMatchTest(pattern, "src/deep/deeper/dir/file.nim")
    check isMatchTest(pattern, "src/deep/deeper/dir/file.js")
    check isMatchTest(pattern, "file.java").not
    check isMatchTest(pattern, "file.nim").not
    check isMatchTest(pattern, "file.js").not

  test "high complexity":
    let pattern = "src/**/[A-Z]???[!_].{png,jpg}"
    check isMatchTest(pattern, "src/res/A001a.png")
    check isMatchTest(pattern, "src/res/D403b.jpg")
    check isMatchTest(pattern, "src/res/D403_.jpg").not
    check isMatchTest(pattern, "src/res/a403.jpg").not
    check isMatchTest(pattern, "src/res/A001a.gif").not

  test "special character escapes":
    check isMatchTest("\\{foo*", "{foo}.html")
    check isMatchTest("*\\}.html", "{foo}.html")
    check isMatchTest("\\[foo*", "[foo].html")
    check isMatchTest("*\\].html", "[foo].html")

suite "pattern walking / listing":
  test "yields expected files":
    let cleanup = createStructure("temp", @[
      "deep" / "dir" / "file.nim",
      "not_as" / "deep.jpg",
      "not_as" / "deep.nim",
      "shallow.nim"
    ])

    test "basic":
      check seqsEqual(listGlob("temp"), @[
        "temp" / "deep" / "dir" / "file.nim",
        "temp" / "not_as" / "deep.jpg",
        "temp" / "not_as" / "deep.nim",
        "temp" / "shallow.nim"
      ])

      check seqsEqual(listGlob("temp/**/*.{nim,jpg}"), @[
        "temp" / "deep" / "dir" / "file.nim",
        "temp" / "not_as" / "deep.jpg",
        "temp" / "not_as" / "deep.nim",
        "temp" / "shallow.nim"
      ])

      check seqsEqual(listGlob("temp/*.nim"), @[
        "temp" / "shallow.nim"
      ])

      check seqsEqual(listGlob("temp/**/*.nim"), @[
        "temp" / "deep" / "dir" / "file.nim",
        "temp" / "not_as" / "deep.nim",
        "temp" / "shallow.nim"
      ])

    test "`includeDirs` adds matching directories to the results":
      check seqsEqual(listGlob("temp/**", includeDirs = true), @[
        "temp" / "deep",
        "temp" / "deep" / "dir",
        "temp" / "deep" / "dir" / "file.nim",
        "temp" / "not_as",
        "temp" / "not_as" / "deep.jpg",
        "temp" / "not_as" / "deep.nim",
        "temp" / "shallow.nim"
      ])

    test "directories are expanded by default":
      check seqsEqual(listGlob("temp"), @[
        "temp" / "deep" / "dir" / "file.nim",
        "temp" / "not_as" / "deep.jpg",
        "temp" / "not_as" / "deep.nim",
        "temp" / "shallow.nim"
      ])

    test "`relative = false` makes returned paths absolute":
      check seqsEqual(listGlob("temp/*.nim", relative = false), @[
        getCurrentDir() / "temp" / "shallow.nim"
      ])

    cleanup()
