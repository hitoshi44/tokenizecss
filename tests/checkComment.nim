discard """

  action: "run"
  target: "c cpp"

"""
import "../src/tokenizecss", "../src/helper"
import unittest

var tkz: CssTokenizer

# Check all tokens are cssWhitspace.
tkz.open("./styles/comment.css")
tkz.next()
while tkz.kind != cssEOF:
  check tkz.kind == cssWhitespace
  tkz.next()
tkz.close()

# Check all tokenize with readComment=true, thus, result must be
# comment -> whitespace -> comment -> whitespace -> comment.
tkz.open("./styles/comment.css", readComment = true)

tkz.next()
check tkz.kind == cssComment

tkz.next()
check tkz.kind == cssWhitespace

tkz.next()
check tkz.kind == cssComment

tkz.next()
check tkz.kind == cssWhitespace

tkz.next()
check tkz.kind == cssComment

tkz.next()
check tkz.kind == cssEOF