import "./tokenizecss"

proc str*(z: CssTokenizer): string {.inline.} =
  case z.kind:

    of cssWhitespace:
      return " "

    of cssCDO:
      return "<!--"

    of cssCDC:
      return "-->"

    of cssColon:
      return ":"

    of cssSemicolon:
      return ";"

    of cssComma:
      return ","

    of cssSquareOp:
      return "["

    of cssSquareCl:
      return "]"

    of cssParenOp:
      return "("

    of cssParenCl:
      return ")"

    of cssCurlyOp:
      return "{"

    of cssCurlyCl:
      return "}"

    of cssDelim:
      return $z.chrVal

    of cssIdent, cssFunction, cssUrl, cssString:
      return z.strVal

    of cssAtKeyword:
      return ('@' & z.strVal)

    of cssHash:
      return ('#' & z.strVal)

    of cssNumber:
      return z.temp

    of cssPercentage:
      return (z.temp & '%')

    of cssDimension:
      return (z.temp & z.strVal)

    of cssComment:
      if z.readComment: return ("/*" & z.strVal & "*/")
      else: return ""

    else:
      return ""