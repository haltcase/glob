version       = "0.9.0"
author        = "Bo Lingen"
description   = "Pure library for matching file paths against Unix style glob patterns."
license       = "MIT"
srcDir        = "src"
skipDirs      = @["docsrc"]
skipFiles     = @["tests.nim"]

requires "nim >= 0.18.0"
requires "regex >= 0.16.0 & < 0.17.0"

task test, "Run the test suite":
  exec "nimble c -y --hints:off --verbosity:0 -r tests.nim"

task docs, "Generate the documentation":
  rmDir("docs")
  if (NimMajor, NimMinor, NimPatch) >= (0, 19, 0):
    echo "Docs generation is broken in Nim v0.19.0"
    echo "If this fails, please use a more recent devel version or < 0.19.0"
    exec "nim doc --project -o:docs src/glob.nim"
  else:
    mkDir("docs/glob")
    exec "nim doc -o:docs/index.html src/glob.nim"
    exec "nim doc -o:docs/glob/regexer.html src/glob/regexer.nim"

  cpFile("docsrc/redirect.html", "docs/index.html")
