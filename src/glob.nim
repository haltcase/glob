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

Character Classes
#################

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
aren't yet supported.

Roadmap
*******

There are a few more extended glob features and other capabilities which aren't
supported yet but will potentially be added in the future. This includes:

- multiple patterns (something like ``glob(["*.nim", "!foo.nim"])``)
- ``?(...patterns)``: match zero or one occurrences of the given patterns
- ``*(...patterns)``: match zero or more occurrences of the given patterns
- ``+(...patterns)``: match one or more occurrences of the given patterns
- ``@(...patterns)``: match one of the given patterns
- ``!(...patterns)``: match anything *except* the given patterns

]##

import os
import options
from ospaths import DirSep, isAbsolute, splitPath, `/`
from sequtils import toSeq
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
    ## Represents a compiled glob pattern and its backing regex.

  GlobResult* =
    tuple[path: string, kind: PathComponent]
    ## The type returned by the ``walkGlobKinds`` iterator, containing
    ## the item's ``path`` and its ``kind`` - ie. ``pcFile``, ``pcDir``.

proc `$`* (glob: Glob): string =
  ## Converts a ``Glob`` object to its string representation.
  ## Useful for using ``echo glob`` directly.
  glob.pattern

proc hasMagic* (str: string): bool =
  ## Returns ``true`` if the given pattern contains any of the special glob
  ## characters ``*``, ``?``, ``[``, ``[``.
  str.contains({'*', '?', '[', '{'})

proc globToRegex* (pattern: string, isDos = isDosDefault): Regex =
  ## Converts a string glob pattern to a regex pattern.
  globToRegexString(pattern, isDos).toPattern

proc glob* (pattern: string, isDos = isDosDefault): Glob =
  ## Constructs a new ``Glob`` object from the given ``pattern``.
  let rgx = globToRegexString(pattern, isDos)
  result = Glob(pattern: pattern, regexStr: rgx, regex: rgx.toPattern)

proc matches* (input: string, glob: Glob, isDos = isDosDefault): bool =
  ## Returns ``true`` if ``input`` is a match for the given ``glob`` object.
  input.contains(glob.regex)

proc matches* (input, pattern: string; isDos = isDosDefault): bool =
  ## Constructs a ``Glob`` object from the given ``pattern`` and returns ``true``
  ## if ``input`` is a match.
  input.contains(globToRegex(pattern, isDos))

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

proc splitPattern (pattern: string): tuple[base: string, magic: string] =
  var head = pattern
  var tail: string
  while head.hasMagic:
    (head, tail) = splitPath(head)

  result = (head, pattern[head.len + 1..<pattern.len])

# TODO: accept Glob objects as well as pattern strings
iterator walkGlobKinds* (
  pattern: string,
  root = "",
  relative = true,
  expandDirs = true,
  includeHidden = false,
  includeDirs = false
): GlobResult =
  ## Iterates over all the paths within the scope of the given glob ``pattern``,
  ## yielding all those that match. ``root`` defaults to the current working
  ## directory (by using ``os.getCurrentDir``).
  ##
  ## Returned paths are relative to ``root`` by default but ``relative = false``
  ## will yield absolute paths instead.
  ##
  ## Directories in the glob pattern are expanded by default. For example,
  ## given a ``./src`` directory, ``src`` will be equivalent to ``src/**`` and
  ## thus all elements within the directory will match. Set ``expandDirs = false``
  ## to disable this behavior.
  ##
  ## Hidden files and directories are not yielded by default but can be included
  ## by setting ``includeHidden = true``. The same goes for directories and the
  ## ``includeDirs = true`` parameter.
  var dir =
    if root == "": getCurrentDir()
    else: root

  var matchPattern = pattern

  var proceed = pattern.hasMagic
  if not proceed:
    let kind = pattern.pathType
    if not kind.isNone:
      case kind.get()
      of pcDir, pcLinkToDir:
        if expandDirs:
          proceed = true
          matchPattern &= "/**"
      else:
        yield (
          (if relative: pattern.toRelative(dir) else: pattern),
          kind.get()
        )

  let (base, magic) = matchPattern.splitPattern
  dir = dir / base
  matchPattern = magic

  var yieldFilter = {pcFile}
  if includeDirs: yieldFilter.incl(pcDir)

  if proceed:
    let matcher = matchPattern.glob
    for path in dir.walkDirRec(yieldFilter):
      let info = path.getFileInfo
      let rel = path.toRelative(dir)

      if rel.matches(matcher):
        if path.isHidden and not includeHidden: continue
        yield ((if relative: base / rel else: path), info.kind)

# TODO: accept Glob objects as well as pattern strings
iterator walkGlob* (
  pattern: string,
  root = "",
  relative = true,
  expandDirs = true,
  includeHidden = false,
  includeDirs = false
): string =
  ## Equivalent to ``walkGlobKinds`` but rather than yielding a ``GlobResult`` it
  ## yields only the ``path`` of the item, ignoring its ``kind``.
  for path, _ in walkGlobKinds(pattern, root, relative, expandDirs, includeHidden, includeDirs):
    yield path

# TODO: accept Glob objects as well as pattern strings
proc listGlob* (
  pattern: string,
  root = "",
  relative = true,
  expandDirs = true,
  includeHidden = false,
  includeDirs = false
): seq[string] =
  ## Returns a list of all the files matching ``pattern``.
  accumulateResult(walkGlob(pattern, root, relative, expandDirs, includeHidden, includeDirs))

export regexer
export regex
