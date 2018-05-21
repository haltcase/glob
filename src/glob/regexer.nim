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

  while i < pattern.len - 1:
    inc i
    var c = pattern[i]

    case c
    of '\\':
      # escape special characters
      if i == pattern.len:
        raise newException(GlobSyntaxError, &"No character to escape ({pattern}, {i})")

      let next = pattern[i + 1]
      inc i
      if next in globMetaChars or next in regexMetaChars:
        rgx &= '\\'

      rgx &= next
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

      if check(pattern, i + 1) == '^':
        # escape the regex negation character
        rgx &= r"\^"
        inc i
      else:
        case check(pattern, i + 1)
        of '!': rgx &= '^'; inc(i, 2)
        of '-': rgx &= '-'; inc(i, 2)
        else: discard

      var
        hasRangeStart = false
        last = EOL

      while i < pattern.len:
        c = pattern[i]
        inc i

        if c == ']':
          break

        if c == '/' or (isDos and c == '\\'):
          raise newException(GlobSyntaxError, &"Explicit 'name separator' in class ({pattern}, {i - 1})")

        # TBD: how to specify ']' in a class?
        if c == '\\' or (c == '&' and check(pattern, i) == '&'):
          # escape `\` and `&&` for regex class
          rgx &= '\\'

        rgx &= c

        if c == '-' and check(pattern, i - 2) != '!':
          if not hasRangeStart:
            raise newException(GlobSyntaxError, &"Invalid range ({pattern}, {i - 1})")

          c = check(pattern, i)
          if c == EOL or c == ']':
            break

          if c.int < last.int:
            raise newException(GlobSyntaxError, &"Cannot nest groups ({pattern}, {i - 3})")

          rgx &= c
          hasRangeStart = false
        else:
          hasRangeStart = true
          last = c

      if c != ']':
        raise newException(GlobSyntaxError, &"Missing ']' ({pattern}, {i})")

      dec i
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
