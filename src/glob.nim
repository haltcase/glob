##[
``glob`` is a cross-platform, pure Nim module for matching files against Unix
style patterns. It supports creating patterns, testing file paths, and walking
through directories to find matching files or directories. For example, the
pattern ``src/**/*.nim`` will be *expanded* to return all files with a ``.nim``
extension in the ``src`` directory and any of its subdirectories.

It's similar to Python's `glob <https://docs.python.org/2/library/glob.html>`_
module but supports extended glob syntax like ``{}`` groups.

Note that while ``glob`` works on all platforms, the patterns it generates can
be platform specific due to differing path separator characters.

Syntax
******

=======  ===============  =============
 token    example          description
=======  ===============  =============
``?``    ``?.nim``        acts as a wildcard, matching any single character
``*``    ``*.nim``        matches any string of any length until a path separator is found
``**``   ``**/license``   same as ``*`` but crosses path boundaries to any depth
``[]``   ``[ch]``         character class, matches any of the characters or ranges inside
``{}``   ``{nim,js}``     string class (group), matches any of the strings inside
``/``    ``foo/*.js``     literal path separator (even on Windows)
``\``    ``foo\*.js``     escape character (not path separator, even on Windows)
=======  ===============  =============

Any other characters are matched literally. Make special note of the difference
between ``/`` and ``\``. Even when on Windows platforms you should **not** use
``\`` as a path separator, since it is actually the escape character in glob
syntax. Instead, always use ``/`` as the path separator. This module will then
use the correct separator when the glob is created.

Character classes
#################

Matching special characters
---------------------------

If you need to match some special characters like ``]`` or ``-`` inside a
bracket expression, you'll need to use them in specific ways to match them
literally.

===========  =========  =========  =======================================================
 character    special    literal    description
===========  =========  =========  =======================================================
``]``        ``[)}]]``  ``[]_.]``  must come first or is treated as closing bracket
``-``        ``[_-=]``  ``[-_]``   must come first or last or is treated as a range
``!``        ``[!<>]``  ``[<!>]``  must not come first or is treated as negation character
===========  =========  =========  =======================================================

POSIX classes
-------------

Within bracket expressions (``[]``) you can use POSIX character classes,
which are basically named groups of characters. These are the available
classes and their roughly equivalent regex values:

==================   ==========================================   ======================================================================
 POSIX class	        similar to                                   meaning
==================   ==========================================   ======================================================================
``[:upper:]``	       ``[A-Z]``	                                  uppercase letters
``[:lower:]``	       ``[a-z]``	                                  lowercase letters
``[:alpha:]``	       ``[A-Za-z]``                                 upper- and lowercase letters
``[:digit:]``	       ``[0-9]``	                                  digits
``[:xdigit:]``	     ``[0-9A-Fa-f]``	                            hexadecimal digits
``[:alnum:]``	       ``[A-Za-z0-9]``                              digits, upper- and lowercase letters
``[:word:]``         ``[A-Za-z0-9_]``                             alphanumeric and underscore
``[:blank:]``	       ``[ \t]``	                                  space and TAB characters only
``[:space:]``	       ``[ \t\n\r\f\v]``	                          blank (whitespace) characters
``[:cntrl:]``        ``[\x00-\x1F\x7F]``                          control characters
``[:ascii:]``        ``[\x00-\x7F]``                              ASCII characters
``[:graph:]``	       ``[^ [:cntrl:]]``	                          graphic characters (all characters which have graphic representation)
``[:punct:]``	       ``[!"\#$%&'()*+,-./:;<=>?@\[\]^_`{|}~]``     punctuation (all graphic characters except letters and digits)
``[:print:]``	       ``[[:graph] ]``	                            graphic characters and space
==================   ==========================================   ======================================================================

Extended pattern matching
#########################

``glob`` supports most of the extended pattern matching syntax found under
bash's ``extglob`` flag:

===================  =======================================================
``?(...patterns)``   match zero or one occurrences of the given patterns
``*(...patterns)``   match zero or more occurrences of the given patterns
``+(...patterns)``   match one or more occurrences of the given patterns
``@(...patterns)``   match one of the given patterns
===================  =======================================================

Note that the ``!(...patterns)`` form that allows for matching anything *except*
the given patterns is not currently supported. This is a limitation in the regex
backend.

Examples
********

For these examples let's imagine we have this file structure:

.. code-block::
  ├─ assets/
  │  └─ img/
  │     ├─ favicon.ico
  │     └─ logo.svg
  ├─ src/
  │  ├─ glob/
  │  │  ├─ other.nim
  │  │  ├─ regexer.nim
  │  │  └─ private/
  │  │     └─ util.nim
  │  └─ glob.nim
  └─ glob.nimble

======================  ====================================================
 glob pattern            files returned
======================  ====================================================
``*``                   ``@["glob.nimble"]``
``src/*.nim``           ``@["src/glob.nim"]``
``src/**/*.nim``        ``@["src/glob.nim", "src/glob/other.nim",``
                        ``"src/glob/regexer.nim", "src/glob/private/util.nim"]``
``**/*.{ico,svg}``      ``@["assets/img/favicon.ico", "assets/img/logo.svg"]``
``**/????.???``         ``@["src/glob.nim", "src/glob/private/util.nim", "assets/img/logo.svg"]``
======================  ====================================================

For more info on glob syntax see `this link <https://mywiki.wooledge.org/glob>`_
for a good reference, although it references a few more extended features which
aren't yet supported. As a cheatsheet, `this wiki <http://wiki.bash-hackers.org/syntax/pattern>`_
might also be useful.

Roadmap
*******

There are a few more extended glob features and other capabilities which aren't
supported yet but will potentially be added in the future. This includes:

- multiple patterns (something like ``glob(["*.nim", "!foo.nim"])``)

]##

import future
import os
import options
from strutils import contains, endsWith, startsWith

import regex

import glob/regexer

when defined windows:
  const isDosDefault = true
else:
  const isDosDefault = false

type
  Glob* = object
    pattern*: string
    regexStr*: string
    regex*: Regex
    base*: string
    magic*: string
    ## Represents a compiled glob pattern and its backing regex. Also stores
    ## the glob's ``base`` & ``magic`` components as per the
    ## `splitPattern proc <#splitPattern,string>`_.

  GlobResult* =
    tuple[path: string, kind: PathComponent]
    ## The type yielded by the `walkGlobKinds iterator <#walkGlobKinds.i,string,string>`_,
    ## containing the item's ``path`` and its ``kind`` - ie. ``pcFile``, ``pcDir``.

  PatternStems* =
    tuple[base: string, magic: string]
    ## The type returned by `splitPattern <#splitPattern,string>`_ where
    ## ``base`` contains the leading non-magic path components and ``magic``
    ## contains any path segments containing or following special glob
    ## characters.

  GlobOptions* {.pure.} = enum
    ## Flags that control the behavior or results of the file system iterators. See
    ## `defaultGlobOptions <#defaultGlobOptions>`_ for some usage & examples.
    ##
    ## ============================  ======================================================
    ##  flag                          meaning
    ## ============================  ======================================================
    ## ``GlobOptions.Absolute``      yield paths as absolute rather than relative to root
    ## ``GlobOptions.ExpandDirs``    if pattern is a directory, treat it as ``<dir>/**/*``
    ## ``GlobOptions.Hidden``        yield hidden files or directories
    ## ``GlobOptions.Directories``   yield directories
    ## ``GlobOptions.Files``         yield files
    ## ``GlobOptions.DirLinks``      yield links to directories
    ## ``GlobOptions.FileLinks``     yield links to files
    ## ``GlobOptions.FollowLinks``   recurse into directories through links
    ## ============================  ======================================================
    Absolute, ExpandDirs, FollowLinks,               ## iterator behavior
    Hidden, Files, Directories, FileLinks, DirLinks  ## to yield or not to yield

  FilterDescend* = (path: string) -> bool
    ## A predicate controlling whether or not to recurse into a directory when
    ## iterating with a recursive glob pattern. Returning ``true`` will allow
    ## recursion, while returning ``false`` will prevent it.
    ##
    ## ``path`` can either be relative or absolute, which depends on
    ## ``GlobOptions.Absolute`` being present in the iterator's options.
  FilterYield* = (path: string, kind: PathComponent) -> bool
    ## A predicate controlling whether or not to yield a filesystem item. Paths
    ## for which this predicate returns ``false`` will not be yielded.
    ##
    ## ``path`` can either be relative or absolute, which depends on
    ## ``GlobOptions.Absolute`` being present in the iterator's options.
    ## ``kind`` is one of ``pcDir``, ``pcFile``, ``pcLinkToDir``, ``pcLinkToFile``.

const defaultGlobOptions* = {ExpandDirs, Files, FileLinks, DirLinks}
  ## The default options used when none are provided. If a new set is
  ## provided, it overrides the defaults entirely, so in order to partially
  ## modify the default options you can use Nim's ``set`` union and intersection
  ## operators:
  ##
  ## .. code-block:: Nim
  ##     const optsNoFiles = defaultGlobOptions - {Files}
  ##     const optsHiddenNoLinks = defaultGlobOptions + {Hidden} - {FileLinks, DirLinks}

proc hasMagic* (str: string): bool =
  ## Returns ``true`` if the given string is glob-like, ie. if it contains any
  ## of the special characters ``*``, ``?``, ``[``, ``{`` or an ``extglob``
  ## which is one of the characters ``?``, ``!``, ``@``, ``+``, or ``*``
  ## followed by ``(``.
  runnableExamples:
    doAssert("*.nim".hasMagic)
    doAssert("profile_picture.{png,jpg}".hasMagic)
    doAssert(not "literal_match.html".hasMagic)

  str.contains({'*', '?', '[', '{'}) or str.contains(re"[?!@+]\(")

proc toRelative (path, dir: string): string =
  if path.startsWith(dir):
    let start = if dir.endsWith(DirSep): dir.len else: dir.len + 1
    path[start..<path.len]
  else:
    path

proc pathType (path: string): Option[PathComponent] =
  try:
    result = some(path.getFileInfo.kind)
  except:
    discard

proc maybeJoin (p1, p2: string): string =
  if p2.isAbsolute: p2 else: p1 / p2

proc globToRegex* (pattern: string, isDos = isDosDefault): Regex =
  ## Converts a string glob pattern to a regex pattern.
  globToRegexString(pattern, isDos).toPattern

proc splitPattern* (pattern: string): PatternStems =
  ## Splits the given pattern into two parts: the ``base`` which is the part
  ## containing no special glob characters and the ``magic`` which includes
  ## any path segments containing or following special glob characters.
  ##
  ## When ``pattern`` is not glob-like, ie. ``pattern.hasMagic == false``,
  ## it will be considered a literal matcher and the entire pattern will
  ## be returned as ``magic``, while ``base`` will be the empty string ``""``.
  runnableExamples:
    doAssert "root_dir/inner/**/*.{jpg,gif}".splitPattern == ("root_dir/inner", "**/*.{jpg,gif}")

  if not pattern.hasMagic or not pattern.contains(re"[^\\]\/"):
    return ("", pattern)

  var head = pattern
  var tail: string
  while head.hasMagic:
    (head, tail) = splitPath(head)

  let start = if head.len == 0: head.len else: head.len + 1
  result = (head, pattern[start..<pattern.len])

proc glob* (pattern: string, isDos = isDosDefault): Glob =
  ## Constructs a new `Glob <#Glob>`_ object from the given ``pattern``.
  let rgx = globToRegexString(pattern, isDos)
  let (base, magic) = pattern.splitPattern
  result = Glob(
    pattern: pattern,
    regexStr: rgx,
    regex: rgx.toPattern,
    base: base,
    magic: magic
  )

proc matches* (input: string, glob: Glob): bool =
  ## Returns ``true`` if ``input`` is a match for the given ``glob`` object.
  runnableExamples:
    const matcher = glob("src/**/*.nim")
    doAssert "src/dir/foo.nim".matches(matcher)

  input.contains(glob.regex)

proc matches* (input, pattern: string; isDos = isDosDefault): bool =
  ## Constructs a `Glob <#Glob>`_ object from the given ``pattern`` and returns
  ## ``true`` if ``input`` is a match. Shortcut for ``matches(input, glob(pattern, isDos))``.
  runnableExamples:
    doAssert "src/dir/foo.nim".matches("src/**/*.nim")

  input.contains(globToRegex(pattern, isDos))

iterator walkGlobKinds* (
  pattern: string | Glob,
  root = "",
  options = defaultGlobOptions,
  filterDescend: FilterDescend = nil,
  filterYield: FilterYield = nil
): GlobResult =
  ## Equivalent to `walkGlob <#walkGlob.i,,string,FilterDescend,FilterYield>`_ but
  ## yields a `GlobResult <#GlobResult>`_ which contains the ``path`` as well as
  ## the ``kind`` of the item.
  runnableExamples:
    for path, kind in walkGlobKinds("src/*.nim"):
      doAssert path is string and kind is PathComponent

    ## include hidden items, exclude links
    const optsHiddenNoLinks = defaultGlobOptions + {Hidden} - {FileLinks, DirLinks}
    for path, kind in walkGlobKinds("src/**/*", options = options):
      doAssert kind isnot pcFile

  var
    dir = if root == "": getCurrentDir() else: root
    matchPattern = when pattern is Glob: pattern.pattern else: pattern
    proceed = matchPattern.hasMagic

  template push (path: string, kind: PathComponent, dir = "") =
    if filterYield.isNil or filterYield(path, kind):
      yield (
        unixToNativePath(
          if Absolute in options or dir == "": path
          else: path.toRelative(dir)
        ),
        kind
      )

  if not proceed:
    let kind = matchPattern.pathType
    if not kind.isNone:
      let k = kind.get()
      if Hidden in options or not matchPattern.isHidden:
        case k
        of pcDir, pcLinkToDir:
          if Directories in options and (k == pcDir or DirLinks in options):
            push(matchPattern, k, dir)
          if ExpandDirs in options:
            proceed = true
            matchPattern &= "/**"
        of pcFile:
          push(matchPattern, k, dir)
        of pcLinkToFile:
          if FileLinks in options: push(matchPattern, k, dir)

  var base: string
  when pattern is Glob:
    dir = maybeJoin(dir, pattern.base)
    base = pattern.base
    matchPattern = pattern.magic
  else:
    (base, matchPattern) = splitPattern(matchPattern)
    dir = maybeJoin(dir, base)

  if proceed:
    let matcher = matchPattern.glob
    let isRec = matchPattern.contains("**")

    var stack = @[dir]
    var last = dir
    while stack.len > 0:
      let subdir = stack.pop
      for kind, path in walkDir(subdir):
        if Hidden notin options and path.isHidden: continue

        let
          rel = path.toRelative(dir)
          isMatch = rel.matches(matcher)
          resultPath = unixToNativePath(
            if Absolute notin options: base / rel else: path
          )

        case kind
        of pcLinkToDir:
          if DirLinks in options and isMatch:
            push(resultPath, kind)

          if FollowLinks in options:
            if subdir.startsWith(last & DirSep):
              # recursive symbolic link; following would result in an infinite loop
              continue

            last = subdir

            if isRec and (filterDescend.isNil or filterDescend(resultPath)):
              stack.add(path)
        of pcDir:
          if Directories in options and isMatch:
            push(resultPath, kind)

          if isRec and (filterDescend.isNil or filterDescend(resultPath)):
            stack.add(path)
        of pcLinkToFile:
          if FileLinks in options and isMatch:
            push(resultPath, kind)
        of pcFile:
          if Files in options and isMatch:
            push(resultPath, kind)

iterator walkGlob* (
  pattern: string | Glob,
  root = "",
  options = defaultGlobOptions,
  filterDescend: FilterDescend = nil,
  filterYield: FilterYield = nil
): string =
  ## Iterates over all the paths within the scope of the given glob ``pattern``,
  ## yielding all those that match. ``root`` defaults to the current working
  ## directory (by using ``os.getCurrentDir``).
  ##
  ## See `GlobOptions <#GlobOptions>`_ for the flags available to alter
  ## iteration behavior and output.
  runnableExamples:
    for path in walkGlob("src/*.nim"):
      ## `path` is a file only in the `src` directory (not any of its
      ## subdirectories) with the `.nim` file extension
      discard

    for path in walkGlob("docs/**/*.{png, svg}"):
      ## `path` is a file in the `docs` directory or any of its
      ## subdirectories with either a `png` or `svg` file extension
      discard
  for path, _ in walkGlobKinds(pattern, root, options, filterDescend, filterYield):
    yield path

export PathComponent
export regexer
export regex
