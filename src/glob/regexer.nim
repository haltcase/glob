##[
This module provides the backend for glob pattern parsing and the compilation
to regular expressions. While it's re-exported from the main module and importing
it separately isn't necessary, it could be imported independently of the main
``glob`` package.
]##

from strutils import spaces

type GlobSyntaxError* = object of CatchableError
  ## Raised if the parsing of a glob pattern fails.

const
  EOL = '\0'
  globMetaChars = {'\\', '*', '?', '[', '{'}
  regexMetaChars = {'.', '^', '$', '+', '{', '[', ']', '|', '(', ')'}
  charClasses = {
    "upper": "A-Z",
    "lower": "a-z",
    "alpha": "a-zA-Z",
    "digit": "0-9",
    "xdigit": "0-9A-Fa-f",
    "alnum": r"a-zA-Z0-9",
    "punct": r"-!""#$%&'()*+,./\\:;<=>?@[\]^_`{|}~",
    "blank": r" \t",
    "space": r"\s",
    "ascii": r"\x00-\x7F",
    "cntrl": r"\x00-\x1F\x7F",
    "graph": r"\x21-\x7E",
    "print": r"\x20-\x7E ",
    "word": r"\w"
  }

const
  isDosDefault = defined windows

proc getClassRegex (name: string): string =
  result = ""
  for item in charClasses:
    if item[0] == name: return item[1]

template fail (message, pattern: string, index: int) =
  let errLines = 2.spaces & pattern & "\p" & (2 + index).spaces & "^" & "\p\p"
  raise newException(GlobSyntaxError, message & "\p\p" & errLines)

proc globToRegexString* (
  pattern: string,
  isDos = isDosDefault,
  ignoreCase = isDosDefault
): string =
  ## Parses the given ``pattern`` glob string and returns a regex string.
  ## Syntactic errors will cause a ``GlobSyntaxError`` to be raised.
  var
    stack: seq[char] = @[]
    hasGlobstar = false
    inRange = false
    inGroup = false
    rgx = "^"
    i = -1

  template peek (i: int): char =
    if i >= 0 and i < pattern.len: pattern[i] else: EOL

  template add (str: string | char) =
    rgx &= str

  template next (c: var char) =
    inc i
    c = peek(i)

  template isNext (cmp: char): bool =
    peek(i + 1) == cmp

  if ignoreCase: add "(?i)"

  while i < pattern.len - 1:
    inc i
    var c = pattern[i]

    case c
    of '\\':
      # escape special characters
      if i + 1 == pattern.len:
        fail("No character to escape", pattern, i)

      let nextChar = peek(i + 1)
      if nextChar in globMetaChars or nextChar in regexMetaChars:
        add('\\')

      add(nextChar)
      inc i
    of '/':
      if hasGlobstar: continue

      if isDos:
        add(r"\\")
      else:
        add(c)
    of '(', '|':
      if stack.len > 0:
        add(c)
      else:
        add('\\' & c)
    of ')':
      if stack.len > 0:
        add(c)
        let kind = stack.pop
        case kind
        of '@': add("{1}")
        of '!':
          if isDos:
            add("[^\\]*")
          else:
            add("[^/]*")
        else: add(kind)
      else:
        add('\\' & c)
    of '+':
      if isNext('('):
        stack.add(c)
      else:
        add('\\' & c)
    of '@':
      if isNext('('):
        stack.add(c)
      else:
        add(c)
    of '!':
      if inRange:
        add('^')
      elif isNext('('):
        stack.add(c)
        add("(?!")
        inc i
      else:
        add('\\' & c)
    of '?':
      if isNext('('):
        stack.add(c)
      elif isDos:
        add(r"[^\\]")
      else:
        add("[^/]")
    of '[':
      let nextChar = peek(i + 1)
      if nextChar in {'!', '-', '^', ']'}:
        add(c)
        case nextChar
        of '!': add('^')
        of '-': add('-')
        of '^': add(r"\^")
        of ']': add(r"\]")
        else: discard

        inc i
        inRange = true
        continue

      # character classes
      if inRange:
        if nextChar != ':':
          fail("Cannot nest groups", pattern, i - 2)

        inc(i, 2)
        c = peek(i)

        var name = ""
        while c notin {':', EOL, ']'}:
          name &= c
          next(c)

        if not isNext(']'):
          fail("Missing ']' after class", pattern, i)

        let classRgx = getClassRegex(name)
        if classRgx == "":
          fail("Unknown class name '{name}'", pattern, i)

        add(classRgx)
        inc i
        continue

      add(c)
      inRange = true
    of ']':
      inRange = false
      add(c)
    of '-':
      add(c)

      if inRange:
        let prevChar = peek(i - 1)
        let nextChar = peek(i + 1)
        if nextChar == '-' or prevChar.int > nextChar.int:
          fail("Invalid range", pattern, i)
    of '{':
      if inGroup:
        fail("Cannot nest groups", pattern, i)

      add("(?:(?:")
      inGroup = true
    of '}':
      if inGroup:
        add("))")
        inGroup = false
      else:
        add('}')
    of ',':
      if inGroup:
        add(")|(?:")
      else:
        add(',')
    of '*':
      if isNext('('):
        stack.add(c)
        continue

      if isNext('*'):
        # crosses directory boundaries
        hasGlobstar = true
        if isDos:
          add(r"(?:[^\\]*(?:\\|$))*")
        else:
          add(r"(?:[^\/]*(?:\/|$))*")
        inc i
      else:
        # within directory boundary
        if isDos:
          add(r"[^\\]*")
        else:
          add("[^/]*")
    else:
      if c in regexMetaChars:
        add('\\')

      add(c)

  if inRange:
    fail("Missing ']'", pattern, i)

  if inGroup:
    fail("Missing '}'", pattern, i)

  result = rgx & '$'
