version       = "0.9.1"
author        = "Bo Lingen"
description   = "Pure library for matching file paths against Unix style glob patterns."
license       = "MIT"
srcDir        = "src"
skipDirs      = @["docsrc"]
skipFiles     = @["tests.nim"]

requires "nim >= 1.0.0 & < 2.0.0"
requires "regex >= 0.17.1 & < 0.18.0"

task test, "Run the test suite":
  exec "nimble c -y --hints:off --verbosity:0 -r tests.nim"

task docs, "Generate the documentation":
  rmDir("docs")
  exec "nim doc --project -o:docs src/glob.nim"
  cpFile("docsrc/redirect.html", "docs/index.html")
