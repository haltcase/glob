version       = "0.8.0"
author        = "Bo Lingen"
description   = "Pure library for matching file paths against Unix style glob patterns."
license       = "MIT"
srcDir        = "src"
skipFiles     = @["tests.nim"]

requires "nim >= 0.18.1"
requires "regex >= 0.6.3"

task test, "Run the test suite":
  exec "nimble c -y --hints:off --verbosity:0 -r tests.nim"

task docs, "Generate the documentation":
  mkDir("docs/glob")
  exec "nim doc --hints:off --verbosity:0 -o:./docs/index.html src/glob.nim"
  exec "nim doc --hints:off --verbosity:0 -o:./docs/glob/regexer.html src/glob/regexer.nim"
