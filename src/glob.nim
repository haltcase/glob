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

=======  ===============  =================================================================
 token    example          description
=======  ===============  =================================================================
``?``    ``?.nim``        acts as a wildcard, matching any single character
``*``    ``*.nim``        matches any string of any length until a path separator is found
``**``   ``**/license``   same as ``*`` but crosses path boundaries to any depth
``[]``   ``[ch]``         character class, matches any of the characters or ranges inside
``{}``   ``{nim,js}``     string class (group), matches any of the strings inside
``/``    ``foo/*.js``     literal path separator (even on Windows)
``\``    ``foo\*.js``     escape character (not path separator, even on Windows)
=======  ===============  =================================================================

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

==============  =========================================  ======================================================================
 POSIX class     similar to                                  meaning
==============  =========================================  ======================================================================
``[:upper:]``   ``[A-Z]``                                  uppercase letters
``[:lower:]``   ``[a-z]``                                  lowercase letters
``[:alpha:]``   ``[A-Za-z]``                               upper- and lowercase letters
``[:digit:]``   ``[0-9]``                                  digits
``[:xdigit:]``  ``[0-9A-Fa-f]``                            hexadecimal digits
``[:alnum:]``   ``[A-Za-z0-9]``                            digits, upper- and lowercase letters
``[:word:]``    ``[A-Za-z0-9_]``                           alphanumeric and underscore
``[:blank:]``   ``[ \t]``                                  space and TAB characters only
``[:space:]``   ``[ \t\n\r\f\v]``                          blank (whitespace) characters
``[:cntrl:]``   ``[\x00-\x1F\x7F]``                        control characters
``[:ascii:]``   ``[\x00-\x7F]``                            ASCII characters
``[:graph:]``   ``[^ [:cntrl:]]``                          graphic characters (all characters which have graphic representation)
``[:punct:]``   ``[!"\#$%&'()*+,-./:;<=>?@\[\]^_`{|}~]``   punctuation (all graphic characters except letters and digits)
``[:print:]``   ``[[:graph] ]``                            graphic characters and space
==============  =========================================  ======================================================================

Extended pattern matching
#########################

``glob`` supports most of the extended pattern matching syntax found under
bash's ``extglob`` flag:

===================  =====================================================
``?(...patterns)``   match zero or one occurrences of the given patterns
``*(...patterns)``   match zero or more occurrences of the given patterns
``+(...patterns)``   match one or more occurrences of the given patterns
``@(...patterns)``   match one of the given patterns
``!(...patterns)``   match anything *except* the given patterns
===================  =====================================================

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

===================  ==========================================================================
 glob pattern         files returned
===================  ==========================================================================
``*``                ``@["glob.nimble"]``
``src/*.nim``        ``@["src/glob.nim"]``
``src/**/*.nim``     ``@["src/glob.nim", "src/glob/other.nim",``
                     ``"src/glob/regexer.nim", "src/glob/private/util.nim"]``
``**/*.{ico,svg}``   ``@["assets/img/favicon.ico", "assets/img/logo.svg"]``
``**/????.???``      ``@["src/glob.nim", "src/glob/private/util.nim", "assets/img/logo.svg"]``
===================  ==========================================================================

For more info on glob syntax see `this link <https://mywiki.wooledge.org/glob>`_
for a good reference, although it references a few more extended features which
aren't yet supported. As a cheatsheet, `this wiki <http://wiki.bash-hackers.org/syntax/pattern>`_
might also be useful.

Roadmap
*******

There may be some features and other capabilities which aren't supported yet but
will potentially be added in the future, for example:

- unicode character support
- multiple patterns (something like ``glob(["*.nim", "!foo.nim"])``)

]##

import os, strutils
from sequtils import toSeq
from sugar import `=>`, `->`

import regex

import glob/regexer

const
  # used for determing path separators, not for filesystem case sensitivity
  isDosDefault = defined windows

type
  Glob* = object
    pattern*: string
    regexStr*: string
    regex*: Regex
    base*: string
    magic*: string
    ## Represents a compiled glob pattern and its backing regex. Also stores
    ## the glob's ``base`` & ``magic`` components as given by the
    ## `splitPattern proc <#splitPattern,string>`_.

  GlobEntry* =
    tuple[path: string, kind: PathComponent]
    ## Represents a filesystem entity matched by a glob pattern, containing the
    ## item's ``path`` and its ``kind`` as an `os.PathComponent <https://nim-lang.org/docs/os.html#PathComponent>`_.

  PatternStems* =
    tuple[base: string, magic: string]
    ## The type returned by `splitPattern <#splitPattern,string>`_ where
    ## ``base`` contains the leading non-magic path components and ``magic``
    ## contains any path segments containing or following special glob
    ## characters.

  GlobOption* {.pure.} = enum
    ## Flags that control the behavior or results of the file system iterators. See
    ## `defaultGlobOptions <#defaultGlobOptions>`_ for some usage & examples.
    ##
    ## ============================  ===========================================================
    ##  flag                          meaning
    ## ============================  ===========================================================
    ## ``GlobOption.Absolute``       yield paths as absolute rather than relative to root
    ## ``GlobOption.IgnoreCase``     matching will ignore case differences
    ## ``GlobOption.NoExpandDirs``   if pattern is a directory don't treat it as ``<dir>/**/*``
    ## ``GlobOption.Hidden``         yield hidden files or directories
    ## ``GlobOption.Directories``    yield directories
    ## ``GlobOption.Files``          yield files
    ## ``GlobOption.DirLinks``       yield links to directories
    ## ``GlobOption.FileLinks``      yield links to files
    ## ``GlobOption.FollowLinks``    recurse into directories through links
    ## ============================  ===========================================================
    Absolute, IgnoreCase, NoExpandDirs, FollowLinks,  ## iterator behavior
    Hidden, Files, Directories, FileLinks, DirLinks   ## to yield or not to yield

  GlobOptions* = set[GlobOption]
    ## The ``set`` type containing flags for controlling glob behavior.
    ##
    ## .. code-block:: nim
    ##    var options: GlobOptions = {}
    ##    if someCondition: options += GlobOption.Absolute

  FilterDescend* = (path: string) -> bool
    ## A predicate controlling whether or not to recurse into a directory when
    ## iterating with a recursive glob pattern. Returning ``true`` will allow
    ## recursion, while returning ``false`` will prevent it.
    ##
    ## ``path`` can either be relative or absolute, which depends on
    ## ``GlobOption.Absolute`` being present in the iterator's options.

  FilterYield* = (path: string, kind: PathComponent) -> bool
    ## A predicate controlling whether or not to yield a filesystem item. Paths
    ## for which this predicate returns ``false`` will not be yielded.
    ##
    ## ``path`` can either be relative or absolute, which depends on
    ## ``GlobOption.Absolute`` being present in the iterator's options.
    ## ``kind`` is an `os.PathComponent <https://nim-lang.org/docs/os.html#PathComponent>`_.

when defined Nimdoc:
  const defaultGlobOptions* = {Files, FileLinks, DirLinks}
    ## The default options used when none are provided. If a new set is
    ## provided it overrides the defaults entirely, so in order to partially
    ## modify the default options you can use Nim's ``set`` union and intersection
    ## operators:
    ##
    ## .. code-block:: nim
    ##    const optsNoFiles = defaultGlobOptions - {Files}
    ##    const optsHiddenNoLinks = defaultGlobOptions + {Hidden} - {FileLinks, DirLinks}
    ##
    ## On case-insensitive filesystems (like Windows), this also includes ``GlobOption.IgnoreCase``.
elif FileSystemCaseSensitive:
  const defaultGlobOptions* = {Files, FileLinks, DirLinks, IgnoreCase}
else:
  const defaultGlobOptions* = {Files, FileLinks, DirLinks}

func hasMagic* (str: string): bool =
  ## Returns ``true`` if the given string is glob-like, ie. if it contains any
  ## of the special characters ``*``, ``?``, ``[``, ``{`` or an ``extglob``
  ## which is one of the characters ``?``, ``!``, ``@``, ``+``, or ``*``
  ## followed by ``(``.
  runnableExamples:
    doAssert("*.nim".hasMagic)
    doAssert("profile_picture.{png,jpg}".hasMagic)
    doAssert(not "literal_match.html".hasMagic)

  str.contains({'*', '?', '[', '{'}) or str.contains(re"[?!@+]\(")

# use this in the future (when/if merged)
# https://github.com/nim-lang/Nim/pull/8166
func toRelative (path, dir: string): string =
  let (innerPath, innerDir) =
    when defined FileSystemCaseSensitive: (path, dir)
    else: (path.toLowerAscii, dir.toLowerAscii)

  if innerPath == innerDir:
    return "."
  elif innerPath.startsWith(innerDir):
    let start = dir.len + dir.endsWith(DirSep).not.int
    return path[start..<path.len]
  else:
    return path

proc pathType (path: string, kind: var PathComponent): bool =
  try:
    kind = path.getFileInfo.kind
    result = true
  except:
    discard

# we need this wrapper because `isHidden` is currently broken
# on non-Windows systems and doesn't work for directories:
#   https://github.com/nim-lang/Nim/issues/8225
# we can remove this wrapper once the following PR is merged:
#   https://github.com/nim-lang/Nim/pull/8315
proc isHiddenEntry (path: string): bool =
  when defined windows:
    result = path.isHidden
  else:
    # https://github.com/nim-lang/Nim/blob/2b5e80c81f4135ea8daef5a503f368bff2639549/lib/pure/os.nim#L1713-L1714
    let fileName = extractFilename(path)
    result = len(fileName) >= 2 and fileName[0] == '.' and fileName != ".."

func maybeJoin (p1, p2: string): string =
  unixToNativePath(
    if p2 == "": p1
    elif p2.isAbsolute: p2
    else: p1 / p2
  )

when FileSystemCaseSensitive:
  func makeCaseInsensitive (pattern: string): string =
    result = ""
    for c in pattern:
      if c in Letters:
        result.add '['
        result.add c.toLowerAscii
        result.add c.toUpperAscii
        result.add ']'
      else:
        result.add c

# helper to find file system items case insensitively
# on case insensitive systems this is equivalent to an existence check
# any resulting paths are guaranteed to be absolute
iterator initStack (
  path: string,
  kinds = {pcFile, pcLinkToFile, pcDir, pcLinkToDir},
  ignoreCase = false
): GlobEntry =
  template push (path: string) =
    var kind: PathComponent
    if path.pathType(kind) and kind in kinds:
      yield (path.absolutePath, kind)

  let normalized =
    when FileSystemCaseSensitive:
      if ignoreCase: path.makeCaseInsensitive
      else: path
    else:
      path

  # using `walkPattern` even on case insensitive systems (where it can only match
  # one item anyway) gets us a path that matches the casing of the actual filesystem
  for subPath in walkPattern(normalized):
    push subPath

proc expandGlob (pattern, root: string, ignoreCase: bool): string =
  if pattern.hasMagic: return pattern

  for path, _ in initStack(maybeJoin(root, pattern), {pcDir, pcLinkToDir}, ignoreCase):
    # we can't easily check a file's existence case insensitively on case
    # sensitive systems, so (when necessary) walk over a case insensitive
    # version of this pattern until we find a matching directory and
    # break/return immediately when we've found one
    return path.toRelative(root) & "/**"

  return pattern

func globToRegex* (pattern: string, isDos = isDosDefault, ignoreCase = isDosDefault): Regex =
  ## Converts a string glob pattern to a regex pattern.
  globToRegexString(pattern, isDos, ignoreCase).re

func splitPattern* (pattern: string): PatternStems =
  ## Splits the given pattern into two parts: the ``base`` which is the part
  ## containing no special glob characters and the ``magic`` which includes
  ## any path segments containing or following special glob characters.
  ##
  ## When ``pattern`` is not glob-like, ie. ``pattern.hasMagic == false``,
  ## it will be considered a literal matcher and the entire pattern will
  ## be returned as ``magic``, while ``base`` will be the empty string ``""``.
  runnableExamples:
    doAssert "root_dir/inner/**/*.{jpg,gif}".splitPattern == ("root_dir/inner", "**/*.{jpg,gif}")
    doAssert "this/is-a/literal-match.txt".splitPattern == ("", "this/is-a/literal-match.txt")

  if not pattern.hasMagic or not pattern.contains(re"[^\\]\/"):
    return ("", pattern)

  var head = pattern
  var tail: string
  while head.hasMagic:
    (head, tail) = splitPath(head)

  let start = if head.len == 0: head.len else: head.len + 1
  result = (head, pattern[start..<pattern.len])

func glob* (pattern: string, isDos = isDosDefault, ignoreCase = isDosDefault): Glob =
  ## Constructs a new `Glob <#Glob>`_ object from the given ``pattern``.
  when defined(posix):
    # causes complications on windows since that would change / to \
    let pattern = pattern.normalizedPath
  let rgx = globToRegexString(pattern, isDos, ignoreCase)
  let (base, magic) = pattern.splitPattern
  result = Glob(
    pattern: pattern,
    regexStr: rgx,
    regex: rgx.re,
    base: base,
    magic: magic
  )

func matches* (input: string, glob: Glob): bool =
  ## Returns ``true`` if ``input`` is a match for the given ``glob`` object.
  runnableExamples:
    const matcher = glob("src/**/*.nim")
    const matcher2 = glob("bar//src//**/*.nim")
    when defined posix:
      doAssert("src/dir/foo.nim".matches(matcher))
      doAssert(not r"src\dir\foo.nim".matches(matcher))
      doAssert("bar/src/dir/foo.nim".matches(matcher2))
      doAssert("./bar//src/baz.nim".matches(matcher2))
    elif defined windows:
      doAssert(r"src\dir\foo.nim".matches(matcher))
      doAssert(not "src/dir/foo.nim".matches(matcher))
  when defined(posix):
    # see note in `glob`
    let input = input.normalizedPath
  input.contains(glob.regex)

func matches* (input, pattern: string; isDos = isDosDefault, ignoreCase = isDosDefault): bool =
  ## Check that ``input`` matches the given ``pattern`` and return ``true`` if it does.
  ## Shortcut for ``matches(input, glob(pattern, isDos, ignoreCase))``.
  runnableExamples:
    when defined posix:
      doAssert "src/dir/foo.nim".matches("src/**/*.nim")
    elif defined windows:
      doAssert r"src\dir\foo.nim".matches("src/**/*.nim")

  input.contains(globToRegex(pattern, isDos, ignoreCase))

proc shouldDescend (
  subdir, resultPath, matchPattern: string;
  isRec, ignoreCase: bool,
  depth: int,
  entry: GlobEntry,
  filter: FilterDescend
): bool =
  if isRec or (not filter.isNil and filter(resultPath)):
    return true

  let tail = entry.path.toRelative(subdir)
  let patternComponents = matchPattern.split('/', depth + 1)
  if depth > patternComponents.len - 1: return false

  let head = patternComponents[depth]
  if head == tail: return true

  let subPattern = head.globToRegex(ignoreCase = ignoreCase)
  if subPattern in tail: return true

func toOutputPath (
  path, root, internalRoot: string;
  pattern: string | Glob,
  options: GlobOptions
): string =
  if Absolute in options or internalRoot == "":
    return maybeJoin(internalRoot, path)

  if root != "":
    return path.toRelative(internalRoot)

  let patternStr = when pattern is Glob: pattern.pattern else: pattern
  if patternStr.isAbsolute:
    return maybeJoin(internalRoot, path)

  return path.toRelative(internalRoot)

func getPathDepth (parent, child: string): int =
  var rel = child.toRelative(parent)
  if rel != ".": rel &= DirSep
  result = rel.count(DirSep)

iterator walkGlobKinds* (
  pattern: string | Glob,
  root = "",
  options = defaultGlobOptions,
  filterDescend: FilterDescend = nil,
  filterYield: FilterYield = nil
): GlobEntry =
  ## Equivalent to `walkGlob <#walkGlob.i,,string,FilterDescend,FilterYield>`_ but
  ## yields a `GlobEntry <#GlobEntry>`_ which contains the ``path`` as well as
  ## the ``kind`` of the item.
  runnableExamples:
    for path, kind in walkGlobKinds("src/*.nim"):
      doAssert(path is string and kind is PathComponent)

    ## include hidden items, exclude links
    const optsHiddenNoLinks = defaultGlobOptions + {Hidden} - {FileLinks, DirLinks}
    for path, kind in walkGlobKinds("src/**/*", options = optsHiddenNoLinks):
      doAssert(kind notin {pcLinkToFile, pcLinkToDir})

  when pattern is string:
    let pattern = pattern.glob

  let internalRoot =
    if root == "": getCurrentDir()
    elif root.isAbsolute: root
    else: getCurrentDir() / root
  var matchPattern = pattern.pattern
  var proceed = matchPattern.hasMagic

  template push (path: string, kind: PathComponent, dir = "") =
    if filterYield.isNil or filterYield(path, kind):
      yield (
        path.toOutputPath(root, dir, pattern, options).unixToNativePath,
        kind
      )

  if not proceed:
    for path, kind in initStack(
      maybeJoin(internalRoot, matchPattern),
      ignoreCase = IgnoreCase in options
    ):
      if Hidden notin options and path.isHiddenEntry: continue

      case kind
      of pcDir, pcLinkToDir:
        if Directories in options and (kind == pcDir or DirLinks in options):
          push(path, kind, internalRoot)
        if NoExpandDirs notin options:
          proceed = true
          matchPattern &= "/**"
      of pcFile:
        if Files in options: push(path, kind, internalRoot)
      of pcLinkToFile:
        if FileLinks in options: push(path, kind, internalRoot)

  if proceed:
    let dir = maybeJoin(internalRoot, pattern.base)
    matchPattern = pattern.magic.expandGlob(dir, IgnoreCase in options)

    let matcher = matchPattern.globToRegex(ignoreCase = IgnoreCase in options)
    let isRec = "**" in matchPattern

    var stack = toSeq(initStack(dir, {pcDir, pcLinkToDir}, IgnoreCase in options))
    var last = dir
    while stack.len > 0:
      let (subdir, _) = stack.pop
      let depth = getPathDepth(internalRoot, subdir)

      for kind, path in walkDir(subdir):
        if Hidden notin options and path.isHiddenEntry: continue

        let resultPath = unixToNativePath(
          path.toOutputPath(root, internalRoot, pattern, options)
        )
        let isMatch = matcher in path.toRelative(dir)

        case kind
        of pcLinkToDir:
          if DirLinks in options and isMatch:
            push(resultPath, kind)

          if FollowLinks in options:
            if subdir.startsWith(last & DirSep):
              # recursive symbolic link; following would result in an infinite loop
              continue

            last = subdir
            if shouldDescend(
              subdir, resultPath, matchPattern,
              isRec, IgnoreCase in options,
              depth,
              (path, kind),
              filterDescend
            ):
              stack.add((path, kind))
        of pcDir:
          if Directories in options and isMatch:
            push(resultPath, kind)

          if shouldDescend(
            subdir, resultPath, matchPattern,
            isRec, IgnoreCase in options,
            depth,
            (path, kind),
            filterDescend
          ):
            stack.add((path, kind))
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
  ## directory (by using `os.getCurrentDir <https://nim-lang.org/docs/os.html#getCurrentDir,>`_).
  ##
  ## See `GlobOption <#GlobOption>`_ for the flags available to alter
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

  when pattern is string:
    let pattern = pattern.glob

  for path, _ in walkGlobKinds(pattern, root, options, filterDescend, filterYield):
    yield path

export PathComponent
export regexer
export regex
