# tokenizecss
Css tokenizer following W3C Syntax Module Level 3.
This module works almost OK, but may have some bugs, and needs more tests. PRs are wellcome!

# Usage

Open css file with TokenizerObject
```nim
var tkz: CssTokenizer
tkz.open("./a.css")
```

To write out token data as a string, you can use "str" proc defined in "src/hepler".
```nim
import tokenizecss/helper

while tkz.kind != cssEOF:
  someTargetObject.add ( tkz.str )
  tkz.next()
```

If you want catch and tokenize comment, CssTokenizer.open with readComment option = true.
```nim
import tokenizecss

var tokenizer: CssTokenizer
tokenizer.open("./target.css", readComment = true)

import tokenizecss/helper
while tokenizer.kind != cssEOF:
  if tokenizer.kind == cssComment:
    echo tokenizer.str

# Tokenizer Object

```nim
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
```