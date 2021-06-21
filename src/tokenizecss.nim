# Css Tokenizer following W3C Syntax Module Level 3 spec which is "Candidate Recommendation"
# defined at "https://www.w3.org/TR/css-syntax-3".
# MIT License - Look at license.txt for details.
## This module works almost OK, but may have few bugs, and needs more tests.
## PRs are wellcome!
import lexbase, streams
from strutils import parseInt, parseFloat, toLowerAscii, fromHex


const
  letters    = {'a'..'z', 'A'..'Z', '_'}
  digits     = {'0'..'9'}
  hexdigits  = {'A'..'F', 'a'..'f'} + digits
  nonAscii   = {'\x80'..'\xFF'}
  newline    = lexbase.NewLines + {'\f'}
  whitespace = {' ', '\t'} + newline
  
  maxAllowedCode = 0x10ffff'u32
  replaceChar    = "\xef\xbf\xbd"


type
  CssTokenKind* = enum
    ## Tokens defined at "https://www.w3.org/TR/css-syntax-3/#tokenization"
    cssIdent,
    cssFunction,
    cssAtKeyword,
    cssString,
    cssUrl,
    cssHash,
    cssBadString,
    cssBadUrl,
    cssDelim,
    cssNumber,
    cssPercentage,
    cssDimension
    cssWhitespace,
    cssCDO,
    cssCDC,
    cssColon,
    cssSemicolon,
    cssComma,
    cssSquareOp,
    cssSquareCl,
    cssParenOp,
    cssParenCl,
    cssCurlyOp,
    cssCurlyCl,
    ## Not defined by the spec.
    cssComment,
    cssEOF

  CssTypeFlag* {.pure.} = enum
    none, id, unrestricted, integer, number

  CssTokenizer* = object of BaseLexer
    kind*: CssTokenKind
    flag*: CssTypeFlag
    strVal*: string
    intVal*: int
    fltVal*: float
    chrVal*: char
    temp*  : string
    readComment*: bool
    filename*: string




using my: var CssTokenizer




proc open*(my; input: Stream, filename: string, readComment: bool = false) =
  ## Finish all preparation to start lex.
  ## Working with lexbase from standard library.
  lexbase.open(my, input)
  my.readComment = readComment
  my.filename = filename
  my.flag = CssTypeFlag.none
  my.strVal = ""
  my.temp = ""

proc open*(my; filename: string, readComment: bool = false) =
  ## Init and open target css file.
  ## Opening the file as fileStream.
  let s = newFileStream(filename, fmRead)
  open(my, s, filename, readComment)

proc close*(my: var CssTokenizer) {.inline.} =
  lexbase.close(my)




# helpers
template areValidEscape(a,b: char): bool =
  (a == '\\') and not (b in newline)

template isName(a): bool =
  (
    a in letters or
    a == '-' or
    a in digits or
    a in nonAscii
  )

proc wouldStartIdent(a,b,c: char): bool {.inline.} =
  result = (
    (a == '-') and ((b in letters or b == '-' or b in nonAscii) or
                    areValidEscape(b, c) )
  ) or (
    (a in letters) or (a in nonAscii)
  ) or (
    (a == '\\') and areValidEscape(a, b)
  )

proc wouldStartNumber(a,b,c: char): bool {.inline.} =
  result = (
    (a == '+' or a == '-') and ( b in digits or
                                (b == '.' and c in digits))   
  ) or (
    (a == '.') and (b in digits)
  ) or (
    (a in digits)
  )




## token-consuming facilities
template consumeAsMuchWhitespaceAsCan(my) =
  while my.buf[my.bufpos] in whitespace: 
    if my.buf[my.bufpos] == '\c':
      my.bufpos = my.handleCR(my.bufpos)
    elif my.buf[my.bufpos] == '\L':
      my.bufpos = my.handleLF(my.bufpos)
    else:
      my.bufpos.inc()

template consumeNewLine(my) =
  if my.buf[my.bufpos] == '\c':
    my.bufpos = my.handleCR(my.bufpos)
  
  elif my.buf[my.bufpos] == '\L':
    my.bufpos = my.handleLF(my.bufpos)
  
  else:
    my.bufpos.inc()

proc consumeEscaped(my) =
  my.bufpos.inc()
  var res = ""
  if my.buf[my.bufpos] in hexdigits:
    var count = 1
    res.add(my.buf[my.bufpos])
    my.bufpos.inc()
    while my.buf[my.bufpos] in digits and count < 6:
      res.add(my.buf[my.bufpos])
      my.bufpos.inc()
      count.inc()
    if res.len > 0 and
      fromHex[uint32](("0x" & res)) > maxAllowedCode:
      res.setLen(0)
      res.add(replaceChar)
    my.strVal.add res
  elif my.buf[my.bufpos] == EndOfFile:
    my.strVal.add(replaceChar)
  else:
    my.strVal.add(my.buf[my.bufpos])
    my.bufpos.inc()

template consumeName(my) =
  while true:
    if isName(my.buf[my.bufpos]):
      my.strVal.add(my.buf[my.bufpos])
      my.bufpos.inc()
    elif areValidEscape(my.buf[my.bufpos], my.buf[my.bufpos + 1]):
      my.consumeEscaped()
    else:
      break

proc consumeComment(my) =
  ## Assume buffer pointing '/' and
  ## next buf is '*' confirmed.
  my.bufpos.inc(2)
  if my.readComment:
    my.strVal.setLen(0)
    while true:
      if my.buf[my.bufpos] == '*' and
         my.buf[my.bufpos + 1] == '/':
        my.bufpos.inc(2)
        my.kind = cssComment
        break
      elif my.buf[my.bufpos] == EndOfFile:
        break
      else:
        my.strVal.add my.buf[my.bufpos]
        my.bufpos.inc()
  else:
    while true:
      if my.buf[my.bufpos] == '*' and
         my.buf[my.bufpos + 1] == '/':
        my.bufpos.inc(2)
        my.kind = cssComment
        break
      elif my.buf[my.bufpos] == EndOfFile:
        break
      else:
        my.bufpos.inc()

proc consumeNumber(my) =
  my.flag = CssTypeFlag.integer
  my.temp.setLen(0)

  if my.buf[my.bufpos] == '+' or my.buf[my.bufpos] == '-':
    my.temp.add(my.buf[my.bufpos])
    my.bufpos.inc()
  
  while my.buf[my.bufpos] in digits:
    my.temp.add(my.buf[my.bufpos])
    my.bufpos.inc()
  
  if my.buf[my.bufpos] == '.' and my.buf[my.bufpos + 1] in digits:
    my.temp.add '.'
    my.temp.add(my.buf[my.bufpos + 1])
    my.flag = CssTypeFlag.number
    my.bufpos.inc(2)
    while my.buf[my.bufpos] in digits:
      my.temp.add my.buf[my.bufpos]
      my.bufpos.inc()
  
  if (my.buf[my.bufpos] == 'E' or my.buf[my.bufpos] == 'e') and
     ( (my.buf[my.bufpos+1] in digits) or 
       (my.buf[my.bufpos+1] in {'+', '-'} and my.buf[my.bufpos+2] in digits) ):
    my.temp.add(my.buf[my.bufpos])
    my.bufpos.inc()
    my.flag = CssTypeFlag.number
    while my.buf[my.bufpos] in digits:
      my.temp.add(my.buf[my.bufpos])
      my.bufpos.inc()
  
  if my.flag == CssTypeFlag.number:
    my.fltVal = parseFloat(my.temp)
  else:
    my.intVal = parseInt(my.temp)

proc consumeString(my; ending: static[char]) =
  my.bufpos.inc()
  my.kind = cssString
  while true:
    case my.buf[my.bufpos]
    of ending:
      my.bufpos.inc()
      break
    of EndOfFile:
      break
    of '\c', '\L', '\f':
      my.kind = cssBadString
      break
    of '\\':
      if my.buf[my.bufpos + 1] == EndOfFile:
        my.bufpos.inc()
        break
      elif my.buf[my.bufpos + 1] in newline:
        my.consumeNewLine()
      else:
        my.consumeEscaped()
    else:
      my.strVal.add(my.buf[my.bufpos])
      my.bufpos.inc()

template handleNumberSign(my) =
  my.bufpos.inc()
  if isName(my.buf[my.bufpos]) or
     areValidEscape(my.buf[my.bufpos], my.buf[my.bufpos + 1]):
    my.kind = cssHash
    my.flag = CssTypeFlag.unrestricted
    my.strVal.setLen(0)
    if wouldStartIdent(my.buf[my.bufpos], my.buf[my.bufpos+1], my.buf[my.bufpos+2]):
      my.flag = CssTypeFlag.id
    my.consumeName()
  else:
    my.handleDelimiter('#')

template consumeNumeric(my) =
  my.consumeNumber()
  if wouldStartIdent(my.buf[my.bufpos], my.buf[my.bufpos+1], my.buf[my.bufpos+2]):
    my.kind = cssDimension
    my.strVal.setLen(0)
    my.consumeName()
  elif my.buf[my.bufpos] == '%':
    my.bufpos.inc()
    my.kind = cssPercentage
  else:
    my.kind = cssNumber

template consumeIdentLike(my) =
  my.strVal.setLen(0)
  my.consumeName()
  if my.strVal.toLowerAscii() == "url" and my.buf[my.bufpos] == '(':
    my.bufpos.inc()
    while my.buf[my.bufpos] == ' ' and my.buf[my.bufpos + 1] == ' ':
      my.bufpos.inc()
    if my.buf[my.bufpos] in {'"', '\''} or (
                      my.buf[my.bufpos] == ' ' and
                      my.buf[my.bufpos + 1] in {'"', '\''}
                    ):
      my.kind = cssFunction
    else:
      my.kind = cssUrl
  elif my.buf[my.bufpos] == '(':
    my.kind = cssFunction
  else:
    my.kind = cssIdent

template handleDelimiter(my; c: static[char]) =
  my.chrVal = c
  my.kind = cssDelim
  my.bufpos.inc()




# main procedure.
proc next*(my) =
  ## Consume and read a token pointed by the current buffer
  ## into CssTokenizer object.
  ## After EOF has been catched, this proc does nothing.
  case my.buf[my.bufpos]
  of '/':
    if my.buf[my.bufpos + 1] == '*':
      my.consumeComment()
      if not my.readComment:
        # If readComment is false, skip comment. 
        my.next()
    else:
      my.handleDelimiter('/')

  of ' ', '\t', '\c', '\L', '\f':
    # Whitespace
    my.consumeAsMuchWhitespaceAsCan()
    my.kind = cssWhitespace
  
  of '"':
    my.strVal.setLen(0)
    my.consumeString('"')

  of '\'':
    my.strVal.setLen(0)
    my.consumeString('\'')

  of '#':
    my.handleNumberSign()

  of '(':
    my.bufpos.inc()
    my.kind = cssParenOp

  of ')':
    my.bufpos.inc()
    my.kind = cssParenCl

  of '+':
    if wouldStartNumber('+', my.buf[my.bufpos+1], my.buf[my.bufpos+2]):
      my.consumeNumeric()
    else:
      my.handleDelimiter('+')

  of ',':
    my.bufpos.inc()
    my.kind = cssComma

  of '-':
    if wouldStartNumber('-', my.buf[my.bufpos+1], my.buf[my.bufpos+2]):
      my.consumeNumeric()
    elif my.buf[my.bufpos+1] == '-' and my.buf[my.bufpos+2] == '>':
      my.bufpos.inc(2)
      my.kind = cssCDC
    elif wouldStartIdent('-', my.buf[my.bufpos+1], my.buf[my.bufpos+2]):
      my.consumeIdentLike()
    else:
      my.handleDelimiter('-')

  of '.':
    if wouldStartNumber('.',my.buf[my.bufpos+1],my.buf[my.bufpos+2]):
      my.consumeNumeric()
    else:
      my.handleDelimiter('.')

  of ':':
    my.bufpos.inc()
    my.kind = cssColon

  of ';':
    my.bufpos.inc()
    my.kind = cssSemicolon

  of '<':
    if my.buf[my.bufpos + 1] == '!' and
       my.buf[my.bufpos + 2] == '-' and
       my.buf[my.bufpos + 3] == '-':
      my.bufpos.inc(4)
      my.kind = cssCDO
    else:
      my.handleDelimiter('<')

  of '@':
    if wouldStartIdent(my.buf[my.bufpos + 1],
                       my.buf[my.bufpos + 2],
                       my.buf[my.bufpos + 3]):
      my.bufpos.inc()
      my.strVal.setLen(0)
      my.consumeName()
      my.kind = cssAtKeyword
    else:
      my.handleDelimiter('@')

  of '[':
    my.bufpos.inc()
    my.kind = cssSquareOp

  of '\\':
    if areValidEscape(my.buf[my.bufpos], my.buf[my.bufpos + 1]):
      my.consumeIdentLike()
    else:
      my.handleDelimiter('\\')

  of ']':
    my.bufpos.inc()
    my.kind = cssSquareCl

  of '{':
    my.bufpos.inc()
    my.kind = cssCurlyOp

  of '}':
    my.bufpos.inc()
    my.kind = cssCurlyCl

  of '0'..'9':
    my.consumeNumeric()

  of 'A'..'Z', 'a'..'z', '_', '\x80'..'\xff':
    # Name Start Code Point
    my.consumeIdentLike()

  of EndOfFile:
    my.kind = cssEOF

  else:
    my.chrVal = my.buf[my.bufpos]
    my.kind = cssDelim
    my.bufpos.inc()
