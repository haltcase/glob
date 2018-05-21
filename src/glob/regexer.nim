##[
This module provides the backend for glob pattern parsing and the compilation
to regular expressions. While it's re-exported from the main module and importing
it separately isn't necessary, it could be imported independently of the main
``glob`` package.
]##

import strformat
from ospaths import DirSep

type GlobSyntaxError* = object of Exception
  ## Raised if the parsing of a glob pattern fails.

const
  EOL = '\0'
  globMetaChars = {'\\', '*', '?', '[', '{'}
  regexMetaChars = {'.', '^', '$', '+', '{', '[', ']', '|', '(', ')'}

when defined windows:
  const isDosDefault = true
else:
  const isDosDefault = false

proc check (glob: string, i: int): char =
  if i < glob.len: glob[i] else: EOL

proc globToRegexString* (pattern: string, isDos = isDosDefault): string {.raises([GlobSyntaxError]).} =
  ## Parses the given ``pattern`` glob string and returns a regex string.
  ## Syntactic errors will cause a ``GlobSyntaxError`` to be raised.
  var
    hasGlobstar = false
    inGroup = false
    rgx = "^"
    i = -1

  proc next (c: var char) =
    inc i
    c = check(pattern, i)

  while i < pattern.len - 1:
    inc i
    var c = pattern[i]

    case c
    of '\\':
      # escape special characters
      if i == pattern.len:
        raise newException(GlobSyntaxError, &"No character to escape ({pattern}, {i})")

      let nextChar = check(pattern, i + 1)
      if nextChar in globMetaChars or nextChar in regexMetaChars:
        rgx &= '\\'

      rgx &= nextChar
      inc i
    of '/':
      if hasGlobstar: continue

      if isDos:
        rgx &= r"\\"
      else:
        rgx &= c
    of '[':
      # don't match name separator in class
      # if isDos:
        # rgx &= r"[[^\\]&&["
      # else:
        # rgx &= "[[^/]&&["

      rgx &= c
      next(c)

      case c
      of '!': rgx &= '^'; next(c)
      of '-': rgx &= '-'; next(c)
      of '^': rgx &= r"\^"; next(c)
      else: discard

      var
        hasRangeStart = false
        last = EOL

      while i < pattern.len:
        if c == ']':
          break

        if c == '/' or (isDos and c == '\\'):
          raise newException(GlobSyntaxError, &"Explicit 'name separator' in class ({pattern}, {i})")

        # TBD: how to specify ']' in a class?
        if c == '\\' or (c == '&' and check(pattern, i + 1) == '&'):
          # escape `\` and `&&` for regex class
          rgx &= '\\'

        rgx &= c

        if c == '-' and check(pattern, i - 1) != '!':
          if not hasRangeStart:
            raise newException(GlobSyntaxError, &"Invalid range ({pattern}, {i})")

          next(c)
          if c == EOL or c == ']':
            break

          if c.int < last.int:
            raise newException(GlobSyntaxError, &"Cannot nest groups ({pattern}, {i - 2})")

          rgx &= c
          hasRangeStart = false
        else:
          hasRangeStart = true
          last = c

        next(c)

      if c != ']':
        raise newException(GlobSyntaxError, &"Missing ']' ({pattern}, {i})")

      # rgx &= "]]"
      rgx &= "]"
    of '{':
      if inGroup:
        raise newException(GlobSyntaxError, &"Cannot nest groups ({pattern}, {i})")

      rgx &= "(?:(?:"
      inGroup = true
    of '}':
      if inGroup:
        rgx &= "))"
        inGroup = false
      else:
        rgx &= '}'
    of ',':
      if inGroup:
        rgx &= ")|(?:"
      else:
        rgx &= ','
    of '*':
      if check(pattern, i + 1) == '*':
        # crosses directory boundaries
        hasGlobstar = true
        if isDos:
          rgx &= r"(?:[^\\]*(?:\\|$))*"
        else:
          rgx &= r"(?:[^\/]*(?:\/|$))*"
        inc i
      else:
        # within directory boundary
        if isDos:
          rgx &= r"[^\\]*"
        else:
          rgx &= "[^/]*"
    of '?':
      if isDos:
        rgx &= r"[^\\]"
      else:
        rgx &= "[^/]"
    else:
      if c in regexMetaChars:
        rgx &= '\\'

      rgx &= c

  if inGroup:
    raise newException(GlobSyntaxError, &"Missing '}}' ({pattern}, {i})")

  result = rgx & '$'
