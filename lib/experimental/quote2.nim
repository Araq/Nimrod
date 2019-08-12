import macros
export macros

template expectNimNode(arg: untyped): NimNode = arg
  ## This template is here just to insert the type check. When the
  ## typecheck to ``NimNode`` fails the user will get a nice error
  ## message.

proc newTreeWithLineinfo*(kind: NimNodeKind; lineinfo: LineInfo; children: varargs[NimNode]): NimNode {.compileTime.} =
  ## like ``macros.newTree``, just that the first argument is a node to take lineinfo from.
  # TODO lineinfo cannot be forwarded to new node.  I am forced to drop it here.
  result = newNimNode(kind, nil)
  result.lineinfoObj = lineinfo
  result.add(children)

# TODO restrict unquote to nimnode expressions (error message)

const forwardLineinfo = true

proc containsSymbol(symbolList, name: NimNode): bool =
  for x in symbolList:
    if eqIdent(x, name):
      return true
  return false

proc newTreeExpr(exprNode, symbolTable: NimNode): NimNode {.compileTime.} =
  # stmtList is a buffer to generate statements
  if exprNode.kind in nnkLiterals:
    result = newCall(bindSym"newLit", exprNode)
  elif exprNode.kind == nnkIdent:
    result =
      if containsSymbol(symbolTable, exprNode): newCall(bindSym"expectNimnode", exprNode)
      else: newCall(bindSym"ident", newLit(exprNode.strVal))
  elif exprNode.kind == nnkSym:
    error("for quoting the ast needs to be untyped", exprNode)
  elif exprNode.kind == nnkCommentStmt:
    result = newCall(bindSym"newCommentStmtNode", newLit(exprNode.strVal))
  elif exprNode.kind == nnkEmpty:
    # bug newTree(nnkEmpty) raises exception:
    result = newCall(bindSym"newEmptyNode")
  else:
    if forwardLineInfo:
      result = newCall(bindSym"newTreeWithLineinfo", newLit(exprNode.kind), newLit(exprNode.lineinfoObj))
    else:
      result = newCall(bindSym"newTree", newLit(exprNode.kind))
    for child in exprNode:
      result.add newTreeExpr(child, symbolTable)

macro quoteAst*(args: varargs[untyped]): untyped =
  let symbolList = nnkBracket.newTree()

  let templateSym = genSym(nskTemplate)

  let formalParams = nnkFormalParams.newTree(ident"untyped")
  for i in 0 ..< args.len-1:
    formalParams.add nnkIdentDefs.newTree(
      args[i], ident"untyped", newEmptyNode()
    )

  let templateDef = nnkTemplateDef.newTree(
    templateSym,
    newEmptyNode(),
    newEmptyNode(),
    formalParams,
    nnkPragma.newTree(ident"dirty"),
    newEmptyNode(),
    nnkStmtList.newTree(
      args[^1]
    )
  )

  let templateCall = newCall(templateSym)
  for i in 0 ..< args.len-1:
    templateCall.add newCall(bindSym"expectNimNode", args[i])
  let getAstCall = newCall(bindSym"getAst", templateCall)

  result = newStmtList(templateDef, getAstCall)

  echo result.repr
