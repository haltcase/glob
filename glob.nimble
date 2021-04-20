version       = "0.11.1"
author        = "Bo Lingen"
description   = "Pure library for matching file paths against Unix style glob patterns."
license       = "MIT"
srcDir        = "src"
skipDirs      = @["docsrc"]
skipFiles     = @["tests.nim"]

requires "nim >= 1.0.0 & < 2.0.0"
requires "regex >= 0.19.0 & < 0.20.0"

task test, "Run the test suite":
  exec "nimble c -y --hints:off --verbosity:0 -r tests.nim"

task docs, "Generate the documentation":
  rmDir("docs")
  exec "nim doc --project -o:docs src/glob.nim"
  cpFile("docsrc/redirect.html", "docs/index.html")

task prep_release, "Prepare for release":
  if "fugitive".findExe == "":
    echo "Could not locate `fugitive` for updating the changelog."
    echo "Please run `nimble install fugitive` or ensure it is in your PATH."
  elif "git".findExe == "":
    echo "Could not locate `git`. Please install it or ensure it is in your PATH."
  else:
    exec "fugitive changelog changelog.md -t:v" & version
    exec "git add changelog.md glob.nimble"
    exec "git commit -m 'release: " & version & "'"
    exec "git tag -a v" & version & " -m v" & version
