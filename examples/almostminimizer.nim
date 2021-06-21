## Example to almost minimize css file.
## This proc don't take care around space stuff.
## (such as, just a space or a delimiter)
import "../src/tokenizecss"
import "../src/helper"

proc minimize*(destname, srcname: string) =
  var z: CssTokenizer
  z.open(srcname, readComment = true)

  let f = open(destname, fmWrite)

  while z.kind != cssEOF:
    z.next()
    f.write( z.str )

  z.close()
  f.flushFile()
  f.close()

when isMainModule:
  import os
  if paramCount() == 0:
    echo "Specify the destination and source file name:"
    echo "<program.exe> <destfile> <sourcefile>"
  else:
    let dest = commandLineParams()[0].changeFileExt("css")
    let src  = commandLineParams()[1].changeFileExt("css")
    minimize(dest, src)  