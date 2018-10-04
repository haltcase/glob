import algorithm, os, sequtils, strformat, strutils

if paramCount() < 1:
  echo "build_index.nim should be passed the repo path"
  quit 1

let tmpl = readFile paramStr(1) / "docsrc" / "index.html"

let releaseList = toSeq(walkDirs "*")
  .filterIt(it != "latest")
  .reversed()
  .map(proc (name: string): string =
    result = fmt"""
            <tr>
              <th>{name}</th>
              <td><a href="{name}/glob.html">documentation</a></td>
              <td><a href="https://github.com/citycide/glob/releases/tag/{name}">release notes</a></td>
            </tr>
    """
  )
  .join("\n")

let indexFileContent = tmpl % ["releaseList", releaseList]
writeFile("index.html", indexFileContent)
