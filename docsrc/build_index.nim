import algorithm, pegs, os, sequtils, strformat, strutils

if paramCount() < 1:
  echo "build_index.nim should be passed the repo path"
  quit 1

let tmpl = readFile paramStr(1) / "docsrc" / "index.html"
let versionPattern = peg"'v' \d+ '.' \d+ '.' \d+ ('-' \w+)?"

let releaseList = toSeq(walkDirs "*")
  .filterIt(it.match(versionPattern))
  .reversed()
  .map(proc (name: string): string =
    result = fmt"""
            <tr>
              <th>{name}</th>
              <td><a href="{name}/glob.html">documentation</a></td>
              <td><a href="https://github.com/haltcase/glob/releases/tag/{name}">release notes</a></td>
            </tr>
    """
  )
  .join("\n")

let indexFileContent = tmpl % ["releaseList", releaseList]
writeFile("index.html", indexFileContent)
