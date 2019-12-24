#
#
#           The Nim Compiler
#        (c) Copyright 2015 Andreas Rumpf
#
#    See the file "copying.txt", included in this
#    distribution, for details about the copyright.
#

## This module implements lifting for type-bound operations
## (``=sink``, ``=``, ``=destroy``, ``=deepCopy``).

# Todo:
# - use openArray instead of array to avoid over-specializations

import modulegraphs, lineinfos, idents, ast, renderer, semdata,
  sighashes, lowerings, options, types, msgs, magicsys, tables

type
  TLiftCtx = object
    g: ModuleGraph
    info: TLineInfo # for construction
    kind: TTypeAttachedOp
    fn: PSym
    asgnForType: PType
    recurse: bool
    c: PContext # c can be nil, then we are called from lambdalifting!

proc fillBody(c: var TLiftCtx; t: PType; body, x, y: PNode)
proc produceSym(g: ModuleGraph; c: PContext; typ: PType; kind: TTypeAttachedOp;
              info: TLineInfo): PSym

proc createTypeBoundOps*(g: ModuleGraph; c: PContext; orig: PType; info: TLineInfo)

proc at(a, i: PNode, elemType: PType): PNode =
  result = newNodeI(nkBracketExpr, a.info, 2)
  result[0] = a
  result[1] = i
  result.typ = elemType

proc fillBodyTup(c: var TLiftCtx; t: PType; body, x, y: PNode) =
  for i in 0..<t.len:
    let lit = lowerings.newIntLit(c.g, x.info, i)
    let b = if c.kind == attachedTrace: y else: y.at(lit, t[i])
    fillBody(c, t[i], body, x.at(lit, t[i]), b)

proc dotField(x: PNode, f: PSym): PNode =
  result = newNodeI(nkDotExpr, x.info, 2)
  if x.typ.skipTypes(abstractInst).kind == tyVar:
    result[0] = x.newDeref
  else:
    result[0] = x
  result[1] = newSymNode(f, x.info)
  result.typ = f.typ

proc newAsgnStmt(le, ri: PNode): PNode =
  result = newNodeI(nkAsgn, le.info, 2)
  result[0] = le
  result[1] = ri

proc defaultOp(c: var TLiftCtx; t: PType; body, x, y: PNode) =
  if c.kind in {attachedAsgn, attachedDeepCopy, attachedSink}:
    body.add newAsgnStmt(x, y)

proc fillBodyObj(c: var TLiftCtx; n, body, x, y: PNode) =
  case n.kind
  of nkSym:
    let f = n.sym
    let b = if c.kind == attachedTrace: y else: y.dotField(f)
    if sfCursor in f.flags and f.typ.skipTypes(abstractInst).kind in {tyRef, tyProc} and
        c.g.config.selectedGC in {gcArc, gcOrc, gcHooks}:
      defaultOp(c, f.typ, body, x.dotField(f), b)
    else:
      fillBody(c, f.typ, body, x.dotField(f), b)
  of nkNilLit: discard
  of nkRecCase:
    if c.kind in {attachedSink, attachedAsgn, attachedDeepCopy}:
      ## the value needs to be destroyed before we assign the selector
      ## or the value is lost
      let prevKind = c.kind
      c.kind = attachedDestructor
      fillBodyObj(c, n, body, x, y)
      c.kind = prevKind

    # copy the selector:
    fillBodyObj(c, n[0], body, x, y)
    # we need to generate a case statement:
    var caseStmt = newNodeI(nkCaseStmt, c.info)
    # XXX generate 'if' that checks same branches
    # generate selector:
    var access = dotField(x, n[0].sym)
    caseStmt.add(access)
    var emptyBranches = 0
    # copy the branches over, but replace the fields with the for loop body:
    for i in 1..<n.len:
      var branch = copyTree(n[i])
      branch[^1] = newNodeI(nkStmtList, c.info)

      fillBodyObj(c, n[i].lastSon, branch[^1], x, y)
      if branch[^1].len == 0: inc emptyBranches
      caseStmt.add(branch)
    if emptyBranches != n.len-1:
      body.add(caseStmt)
  of nkRecList:
    for t in items(n): fillBodyObj(c, t, body, x, y)
  else:
    illFormedAstLocal(n, c.g.config)

proc fillBodyObjT(c: var TLiftCtx; t: PType, body, x, y: PNode) =
  if t.len > 0 and t[0] != nil:
    fillBodyObjT(c, skipTypes(t[0], abstractPtrs), body, x, y)
  fillBodyObj(c, t.n, body, x, y)

proc genAddr(g: ModuleGraph; x: PNode): PNode =
  if x.kind == nkHiddenDeref:
    checkSonsLen(x, 1, g.config)
    result = x[0]
  else:
    result = newNodeIT(nkHiddenAddr, x.info, makeVarType(x.typ.owner, x.typ))
    result.add x

proc newHookCall(g: ModuleGraph; op: PSym; x, y: PNode): PNode =
  #if sfError in op.flags:
  #  localError(c.config, x.info, "usage of '$1' is a user-defined error" % op.name.s)
  result = newNodeI(nkCall, x.info)
  result.add newSymNode(op)
  if op.typ.sons[1].kind == tyVar:
    result.add genAddr(g, x)
  else:
    result.add x
  if y != nil:
    result.add y

proc newOpCall(op: PSym; x: PNode): PNode =
  result = newNodeIT(nkCall, x.info, op.typ[0])
  result.add(newSymNode(op))
  result.add x

proc destructorCall(g: ModuleGraph; op: PSym; x: PNode): PNode =
  result = newNodeIT(nkCall, x.info, op.typ[0])
  result.add(newSymNode(op))
  result.add genAddr(g, x)

proc newDeepCopyCall(op: PSym; x, y: PNode): PNode =
  result = newAsgnStmt(x, newOpCall(op, y))

proc useNoGc(c: TLiftCtx; t: PType): bool {.inline.} =
  result = optSeqDestructors in c.g.config.globalOptions and
    ({tfHasGCedMem, tfHasOwned} * t.flags != {} or t.isGCedMem)

proc requiresDestructor(c: TLiftCtx; t: PType): bool {.inline.} =
  result = optSeqDestructors in c.g.config.globalOptions and
    containsGarbageCollectedRef(t)

proc instantiateGeneric(c: var TLiftCtx; op: PSym; t, typeInst: PType): PSym =
  if c.c != nil and typeInst != nil:
    result = c.c.instTypeBoundOp(c.c, op, typeInst, c.info, attachedAsgn, 1)
  else:
    localError(c.g.config, c.info,
      "cannot generate destructor for generic type: " & typeToString(t))
    result = nil

proc considerAsgnOrSink(c: var TLiftCtx; t: PType; body, x, y: PNode;
                        field: var PSym): bool =
  if optSeqDestructors in c.g.config.globalOptions:
    let op = field
    if field != nil and sfOverriden in field.flags:
      if sfError in op.flags:
        incl c.fn.flags, sfError
      #else:
      #  markUsed(c.g.config, c.info, op, c.g.usageSym)
      onUse(c.info, op)
      body.add newHookCall(c.g, op, x, y)
      result = true
  elif tfHasAsgn in t.flags:
    var op: PSym
    if sameType(t, c.asgnForType):
      # generate recursive call:
      if c.recurse:
        op = c.fn
      else:
        c.recurse = true
        return false
    else:
      op = field
      if op == nil:
        op = produceSym(c.g, c.c, t, c.kind, c.info)
    if sfError in op.flags:
      incl c.fn.flags, sfError
    #else:
    #  markUsed(c.g.config, c.info, op, c.g.usageSym)
    onUse(c.info, op)
    # We also now do generic instantiations in the destructor lifting pass:
    if op.ast[genericParamsPos].kind != nkEmpty:
      op = instantiateGeneric(c, op, t, t.typeInst)
      field = op
      #echo "trying to use ", op.ast
      #echo "for ", op.name.s, " "
      #debug(t)
      #return false
    assert op.ast[genericParamsPos].kind == nkEmpty
    body.add newHookCall(c.g, op, x, y)
    result = true

proc addDestructorCall(c: var TLiftCtx; orig: PType; body, x: PNode) =
  let t = orig.skipTypes(abstractInst)
  var op = t.destructor

  if op != nil and sfOverriden in op.flags:
    if op.ast[genericParamsPos].kind != nkEmpty:
      # patch generic destructor:
      op = instantiateGeneric(c, op, t, t.typeInst)
      t.attachedOps[attachedDestructor] = op

  if op == nil and (useNoGc(c, t) or requiresDestructor(c, t)):
    op = produceSym(c.g, c.c, t, attachedDestructor, c.info)
    doAssert op != nil
    doAssert op == t.destructor

  if op != nil:
    #markUsed(c.g.config, c.info, op, c.g.usageSym)
    onUse(c.info, op)
    body.add destructorCall(c.g, op, x)
  elif useNoGc(c, t):
    internalError(c.g.config, c.info,
      "type-bound operator could not be resolved")

proc considerUserDefinedOp(c: var TLiftCtx; t: PType; body, x, y: PNode): bool =
  case c.kind
  of attachedDestructor:
    var op = t.destructor
    if op != nil and sfOverriden in op.flags:

      if op.ast[genericParamsPos].kind != nkEmpty:
        # patch generic destructor:
        op = instantiateGeneric(c, op, t, t.typeInst)
        t.attachedOps[attachedDestructor] = op

      #markUsed(c.g.config, c.info, op, c.g.usageSym)
      onUse(c.info, op)
      body.add destructorCall(c.g, op, x)
      result = true
    #result = addDestructorCall(c, t, body, x)
  of attachedAsgn, attachedSink, attachedTrace:
    result = considerAsgnOrSink(c, t, body, x, y, t.attachedOps[c.kind])
  of attachedDispose:
    result = considerAsgnOrSink(c, t, body, x, nil, t.attachedOps[c.kind])
  of attachedDeepCopy:
    let op = t.attachedOps[attachedDeepCopy]
    if op != nil:
      #markUsed(c.g.config, c.info, op, c.g.usageSym)
      onUse(c.info, op)
      body.add newDeepCopyCall(op, x, y)
      result = true

proc addVar(father, v, value: PNode) =
  var vpart = newNodeI(nkIdentDefs, v.info, 3)
  vpart[0] = v
  vpart[1] = newNodeI(nkEmpty, v.info)
  vpart[2] = value
  father.add vpart

proc declareCounter(c: var TLiftCtx; body: PNode; first: BiggestInt): PNode =
  var temp = newSym(skTemp, getIdent(c.g.cache, lowerings.genPrefix), c.fn, c.info)
  temp.typ = getSysType(c.g, body.info, tyInt)
  incl(temp.flags, sfFromGeneric)

  var v = newNodeI(nkVarSection, c.info)
  result = newSymNode(temp)
  v.addVar(result, lowerings.newIntLit(c.g, body.info, first))
  body.add v

proc genBuiltin(g: ModuleGraph; magic: TMagic; name: string; i: PNode): PNode =
  result = newNodeI(nkCall, i.info)
  result.add createMagic(g, name, magic).newSymNode
  result.add i

proc genWhileLoop(c: var TLiftCtx; i, dest: PNode): PNode =
  result = newNodeI(nkWhileStmt, c.info, 2)
  let cmp = genBuiltin(c.g, mLtI, "<", i)
  cmp.add genLen(c.g, dest)
  cmp.typ = getSysType(c.g, c.info, tyBool)
  result[0] = cmp
  result[1] = newNodeI(nkStmtList, c.info)

proc genIf(c: var TLiftCtx; cond, action: PNode): PNode =
  result = newTree(nkIfStmt, newTree(nkElifBranch, cond, action))

proc addIncStmt(c: var TLiftCtx; body, i: PNode) =
  let incCall = genBuiltin(c.g, mInc, "inc", i)
  incCall.add lowerings.newIntLit(c.g, c.info, 1)
  body.add incCall

proc newSeqCall(g: ModuleGraph; x, y: PNode): PNode =
  # don't call genAddr(c, x) here:
  result = genBuiltin(g, mNewSeq, "newSeq", x)
  let lenCall = genBuiltin(g, mLengthSeq, "len", y)
  lenCall.typ = getSysType(g, x.info, tyInt)
  result.add lenCall

proc setLenStrCall(g: ModuleGraph; x, y: PNode): PNode =
  let lenCall = genBuiltin(g, mLengthStr, "len", y)
  lenCall.typ = getSysType(g, x.info, tyInt)
  result = genBuiltin(g, mSetLengthStr, "setLen", x) # genAddr(g, x))
  result.add lenCall

proc setLenSeqCall(c: var TLiftCtx; t: PType; x, y: PNode): PNode =
  let lenCall = genBuiltin(c.g, mLengthSeq, "len", y)
  lenCall.typ = getSysType(c.g, x.info, tyInt)
  var op = getSysMagic(c.g, x.info, "setLen", mSetLengthSeq)
  op = instantiateGeneric(c, op, t, t)
  result = newTree(nkCall, newSymNode(op, x.info), x, lenCall)

proc forallElements(c: var TLiftCtx; t: PType; body, x, y: PNode) =
  let i = declareCounter(c, body, toInt64(firstOrd(c.g.config, t)))
  let whileLoop = genWhileLoop(c, i, x)
  let elemType = t.lastSon
  let b = if c.kind == attachedTrace: y else: y.at(i, elemType)
  fillBody(c, elemType, whileLoop[1], x.at(i, elemType), b)
  addIncStmt(c, whileLoop[1], i)
  body.add whileLoop

proc fillSeqOp(c: var TLiftCtx; t: PType; body, x, y: PNode) =
  case c.kind
  of attachedAsgn, attachedDeepCopy:
    # we generate:
    # setLen(dest, y.len)
    # var i = 0
    # while i < y.len: dest[i] = y[i]; inc(i)
    # This is usually more efficient than a destroy/create pair.
    body.add setLenSeqCall(c, t, x, y)
    forallElements(c, t, body, x, y)
  of attachedSink:
    let moveCall = genBuiltin(c.g, mMove, "move", x)
    moveCall.add y
    doAssert t.destructor != nil
    moveCall.add destructorCall(c.g, t.destructor, x)
    body.add moveCall
  of attachedDestructor:
    # destroy all elements:
    forallElements(c, t, body, x, y)
    body.add genBuiltin(c.g, mDestroy, "destroy", x)
  of attachedTrace:
    # follow all elements:
    forallElements(c, t, body, x, y)
  of attachedDispose:
    body.add genBuiltin(c.g, mDestroy, "destroy", x)

proc useSeqOrStrOp(c: var TLiftCtx; t: PType; body, x, y: PNode) =
  createTypeBoundOps(c.g, c.c, t, body.info)
  # recursions are tricky, so we might need to forward the generated
  # operation here:
  var t = t
  if t.assignment == nil or t.destructor == nil:
    let h = sighashes.hashType(t, {CoType, CoConsiderOwned, CoDistinct})
    let canon = c.g.canonTypes.getOrDefault(h)
    if canon != nil: t = canon

  case c.kind
  of attachedAsgn, attachedDeepCopy:
    doAssert t.assignment != nil
    body.add newHookCall(c.g, t.assignment, x, y)
  of attachedSink:
    # we always inline the move for better performance:
    let moveCall = genBuiltin(c.g, mMove, "move", x)
    moveCall.add y
    doAssert t.destructor != nil
    moveCall.add destructorCall(c.g, t.destructor, x)
    body.add moveCall
    # alternatively we could do this:
    when false:
      doAssert t.asink != nil
      body.add newHookCall(c.g, t.asink, x, y)
  of attachedDestructor:
    doAssert t.destructor != nil
    body.add destructorCall(c.g, t.destructor, x)
  of attachedTrace:
    body.add newHookCall(c.g, t.attachedOps[c.kind], x, y)
  of attachedDispose:
    body.add newHookCall(c.g, t.attachedOps[c.kind], x, nil)

proc fillStrOp(c: var TLiftCtx; t: PType; body, x, y: PNode) =
  case c.kind
  of attachedAsgn, attachedDeepCopy:
    body.add callCodegenProc(c.g, "nimAsgnStrV2", c.info, genAddr(c.g, x), y)
  of attachedSink:
    let moveCall = genBuiltin(c.g, mMove, "move", x)
    moveCall.add y
    doAssert t.destructor != nil
    moveCall.add destructorCall(c.g, t.destructor, x)
    body.add moveCall
  of attachedDestructor, attachedDispose:
    body.add genBuiltin(c.g, mDestroy, "destroy", x)
  of attachedTrace:
    discard "strings are atomic and have no inner elements that are to trace"

proc atomicRefOp(c: var TLiftCtx; t: PType; body, x, y: PNode) =
  var actions = newNodeI(nkStmtList, c.info)
  let elemType = t.lastSon

  if isFinal(elemType):
    addDestructorCall(c, elemType, actions, genDeref(x, nkDerefExpr))
    actions.add callCodegenProc(c.g, "nimRawDispose", c.info, x)
  else:
    addDestructorCall(c, elemType, newNodeI(nkStmtList, c.info), genDeref(x, nkDerefExpr))
    actions.add callCodegenProc(c.g, "nimDestroyAndDispose", c.info, x)

  let isCyclic = c.g.config.selectedGC == gcOrc and types.canFormAcycle(t)

  var cond: PNode
  if isCyclic:
    if isFinal(elemType):
      let typInfo = genBuiltin(c.g, mGetTypeInfo, "getTypeInfo", newNodeIT(nkType, x.info, elemType))
      typInfo.typ = getSysType(c.g, c.info, tyPointer)
      cond = callCodegenProc(c.g, "nimDecRefIsLastCyclicStatic", c.info, x, typInfo)
    else:
      cond = callCodegenProc(c.g, "nimDecRefIsLastCyclicDyn", c.info, x)
  else:
    cond = callCodegenProc(c.g, "nimDecRefIsLast", c.info, x)
  cond.typ = getSysType(c.g, x.info, tyBool)

  case c.kind
  of attachedSink:
    body.add genIf(c, cond, actions)
    body.add newAsgnStmt(x, y)
  of attachedAsgn:
    body.add genIf(c, y, callCodegenProc(c.g,
        if isCyclic: "nimIncRefCyclic" else: "nimIncRef", c.info, y))
    body.add genIf(c, cond, actions)
    body.add newAsgnStmt(x, y)
  of attachedDestructor:
    actions.add newAsgnStmt(x, newNodeIT(nkNilLit, body.info, t))
    body.add genIf(c, cond, actions)
  of attachedDeepCopy: assert(false, "cannot happen")
  of attachedTrace:
    if isFinal(elemType):
      let typInfo = genBuiltin(c.g, mGetTypeInfo, "getTypeInfo", newNodeIT(nkType, x.info, elemType))
      typInfo.typ = getSysType(c.g, c.info, tyPointer)
      body.add callCodegenProc(c.g, "nimTraceRef", c.info, x, typInfo, y)
    else:
      # If the ref is polymorphic we have to account for this
      body.add callCodegenProc(c.g, "nimTraceRefDyn", c.info, x, y)
  of attachedDispose:
    # this is crucial! dispose is like =destroy but we don't follow refs
    # as that is dealt within the cycle collector.
    when false:
      let cond = copyTree(x)
      cond.typ = getSysType(c.g, x.info, tyBool)
      actions.add callCodegenProc(c.g, "nimRawDispose", c.info, x)
      body.add genIf(c, cond, actions)

proc atomicClosureOp(c: var TLiftCtx; t: PType; body, x, y: PNode) =
  ## Closures are really like refs except they always use a virtual destructor
  ## and we need to do the refcounting only on the ref field which we call 'xenv':
  let xenv = genBuiltin(c.g, mAccessEnv, "accessEnv", x)
  xenv.typ = getSysType(c.g, c.info, tyPointer)

  var actions = newNodeI(nkStmtList, c.info)
  actions.add callCodegenProc(c.g, "nimDestroyAndDispose", c.info, xenv)

  let decRefProc =
    if c.g.config.selectedGC == gcOrc: "nimDecRefIsLastCyclicDyn"
    else: "nimDecRefIsLast"
  let cond = callCodegenProc(c.g, decRefProc, c.info, xenv)
  cond.typ = getSysType(c.g, x.info, tyBool)

  case c.kind
  of attachedSink:
    body.add genIf(c, cond, actions)
    body.add newAsgnStmt(x, y)
  of attachedAsgn:
    let yenv = genBuiltin(c.g, mAccessEnv, "accessEnv", y)
    yenv.typ = getSysType(c.g, c.info, tyPointer)
    let incRefProc =
      if c.g.config.selectedGC == gcOrc: "nimIncRefCyclic"
      else: "nimIncRef"
    body.add genIf(c, yenv, callCodegenProc(c.g, incRefProc, c.info, yenv))
    body.add genIf(c, cond, actions)
    body.add newAsgnStmt(x, y)
  of attachedDestructor:
    actions.add newAsgnStmt(xenv, newNodeIT(nkNilLit, body.info, xenv.typ))
    body.add genIf(c, cond, actions)
  of attachedDeepCopy: assert(false, "cannot happen")
  of attachedTrace:
    body.add callCodegenProc(c.g, "nimTraceRefDyn", c.info, xenv, y)
  of attachedDispose:
    # this is crucial! dispose is like =destroy but we don't follow refs
    # as that is dealt within the cycle collector.
    when false:
      let cond = copyTree(xenv)
      cond.typ = getSysType(c.g, xenv.info, tyBool)
      actions.add callCodegenProc(c.g, "nimRawDispose", c.info, xenv)
      body.add genIf(c, cond, actions)

proc weakrefOp(c: var TLiftCtx; t: PType; body, x, y: PNode) =
  case c.kind
  of attachedSink:
    # we 'nil' y out afterwards so we *need* to take over its reference
    # count value:
    body.add genIf(c, x, callCodegenProc(c.g, "nimDecWeakRef", c.info, x))
    body.add newAsgnStmt(x, y)
  of attachedAsgn:
    body.add genIf(c, y, callCodegenProc(c.g, "nimIncRef", c.info, y))
    body.add genIf(c, x, callCodegenProc(c.g, "nimDecWeakRef", c.info, x))
    body.add newAsgnStmt(x, y)
  of attachedDestructor:
    # it's better to prepend the destruction of weak refs in order to
    # prevent wrong "dangling refs exist" problems:
    var actions = newNodeI(nkStmtList, c.info)
    actions.add callCodegenProc(c.g, "nimDecWeakRef", c.info, x)
    actions.add newAsgnStmt(x, newNodeIT(nkNilLit, body.info, t))
    let des = genIf(c, x, actions)
    if body.len == 0:
      body.add des
    else:
      body.sons.insert(des, 0)
  of attachedDeepCopy: assert(false, "cannot happen")
  of attachedTrace, attachedDispose: discard

proc ownedRefOp(c: var TLiftCtx; t: PType; body, x, y: PNode) =
  var actions = newNodeI(nkStmtList, c.info)

  let elemType = t.lastSon
  #fillBody(c, elemType, actions, genDeref(x), genDeref(y))
  #var disposeCall = genBuiltin(c.g, mDispose, "dispose", x)

  if isFinal(elemType):
    addDestructorCall(c, elemType, actions, genDeref(x, nkDerefExpr))
    actions.add callCodegenProc(c.g, "nimRawDispose", c.info, x)
  else:
    addDestructorCall(c, elemType, newNodeI(nkStmtList, c.info), genDeref(x, nkDerefExpr))
    actions.add callCodegenProc(c.g, "nimDestroyAndDispose", c.info, x)

  case c.kind
  of attachedSink, attachedAsgn:
    body.add genIf(c, x, actions)
    body.add newAsgnStmt(x, y)
  of attachedDestructor:
    actions.add newAsgnStmt(x, newNodeIT(nkNilLit, body.info, t))
    body.add genIf(c, x, actions)
  of attachedDeepCopy: assert(false, "cannot happen")
  of attachedTrace, attachedDispose: discard

proc closureOp(c: var TLiftCtx; t: PType; body, x, y: PNode) =
  if c.kind == attachedDeepCopy:
    # a big problem is that we don't know the environment's type here, so we
    # have to go through some indirection; we delegate this to the codegen:
    let call = newNodeI(nkCall, c.info, 2)
    call.typ = t
    call[0] = newSymNode(createMagic(c.g, "deepCopy", mDeepCopy))
    call[1] = y
    body.add newAsgnStmt(x, call)
  elif (optOwnedRefs in c.g.config.globalOptions and
      optRefCheck in c.g.config.options) or c.g.config.selectedGC in {gcArc, gcOrc}:
    let xx = genBuiltin(c.g, mAccessEnv, "accessEnv", x)
    xx.typ = getSysType(c.g, c.info, tyPointer)
    case c.kind
    of attachedSink:
      # we 'nil' y out afterwards so we *need* to take over its reference
      # count value:
      body.add genIf(c, xx, callCodegenProc(c.g, "nimDecWeakRef", c.info, xx))
      body.add newAsgnStmt(x, y)
    of attachedAsgn:
      let yy = genBuiltin(c.g, mAccessEnv, "accessEnv", y)
      yy.typ = getSysType(c.g, c.info, tyPointer)
      body.add genIf(c, yy, callCodegenProc(c.g, "nimIncRef", c.info, yy))
      body.add genIf(c, xx, callCodegenProc(c.g, "nimDecWeakRef", c.info, xx))
      body.add newAsgnStmt(x, y)
    of attachedDestructor:
      var actions = newNodeI(nkStmtList, c.info)
      actions.add callCodegenProc(c.g, "nimDecWeakRef", c.info, xx)
      actions.add newAsgnStmt(xx, newNodeIT(nkNilLit, body.info, xx.typ))
      let des = genIf(c, xx, actions)
      if body.len == 0:
        body.add des
      else:
        body.sons.insert(des, 0)
    of attachedDeepCopy: assert(false, "cannot happen")
    of attachedTrace, attachedDispose: discard

proc ownedClosureOp(c: var TLiftCtx; t: PType; body, x, y: PNode) =
  let xx = genBuiltin(c.g, mAccessEnv, "accessEnv", x)
  xx.typ = getSysType(c.g, c.info, tyPointer)
  var actions = newNodeI(nkStmtList, c.info)
  #discard addDestructorCall(c, elemType, newNodeI(nkStmtList, c.info), genDeref(xx))
  actions.add callCodegenProc(c.g, "nimDestroyAndDispose", c.info, xx)
  case c.kind
  of attachedSink, attachedAsgn:
    body.add genIf(c, xx, actions)
    body.add newAsgnStmt(x, y)
  of attachedDestructor:
    actions.add newAsgnStmt(xx, newNodeIT(nkNilLit, body.info, xx.typ))
    body.add genIf(c, xx, actions)
  of attachedDeepCopy: assert(false, "cannot happen")
  of attachedTrace, attachedDispose: discard

proc fillBody(c: var TLiftCtx; t: PType; body, x, y: PNode) =
  case t.kind
  of tyNone, tyEmpty, tyVoid: discard
  of tyPointer, tySet, tyBool, tyChar, tyEnum, tyInt..tyUInt64, tyCString,
      tyPtr, tyOpt, tyUncheckedArray, tyVar, tyLent:
    defaultOp(c, t, body, x, y)
  of tyRef:
    if c.g.config.selectedGC in {gcArc, gcOrc}:
      atomicRefOp(c, t, body, x, y)
    elif (optOwnedRefs in c.g.config.globalOptions and
        optRefCheck in c.g.config.options):
      weakrefOp(c, t, body, x, y)
    else:
      defaultOp(c, t, body, x, y)
  of tyProc:
    if t.callConv == ccClosure:
      if c.g.config.selectedGC in {gcArc, gcOrc}:
        atomicClosureOp(c, t, body, x, y)
      else:
        closureOp(c, t, body, x, y)
    else:
      defaultOp(c, t, body, x, y)
  of tyOwned:
    let base = t.skipTypes(abstractInstOwned)
    if optOwnedRefs in c.g.config.globalOptions:
      case base.kind
      of tyRef:
        ownedRefOp(c, base, body, x, y)
        return
      of tyProc:
        if base.callConv == ccClosure:
          ownedClosureOp(c, base, body, x, y)
          return
      else: discard
    defaultOp(c, base, body, x, y)
  of tyArray:
    if tfHasAsgn in t.flags or useNoGc(c, t):
      forallElements(c, t, body, x, y)
    else:
      defaultOp(c, t, body, x, y)
  of tySequence:
    if useNoGc(c, t):
      useSeqOrStrOp(c, t, body, x, y)
    elif optSeqDestructors in c.g.config.globalOptions:
      # note that tfHasAsgn is propagated so we need the check on
      # 'selectedGC' here to determine if we have the new runtime.
      discard considerUserDefinedOp(c, t, body, x, y)
    elif tfHasAsgn in t.flags:
      if c.kind in {attachedAsgn, attachedSink, attachedDeepCopy}:
        body.add newSeqCall(c.g, x, y)
      forallElements(c, t, body, x, y)
    else:
      defaultOp(c, t, body, x, y)
  of tyString:
    if useNoGc(c, t):
      useSeqOrStrOp(c, t, body, x, y)
    elif tfHasAsgn in t.flags:
      discard considerUserDefinedOp(c, t, body, x, y)
    else:
      defaultOp(c, t, body, x, y)
  of tyObject:
    if not considerUserDefinedOp(c, t, body, x, y):
      fillBodyObjT(c, t, body, x, y)
  of tyDistinct:
    if not considerUserDefinedOp(c, t, body, x, y):
      fillBody(c, t[0], body, x, y)
  of tyTuple:
    fillBodyTup(c, t, body, x, y)
  of tyVarargs, tyOpenArray:
    if c.kind == attachedDestructor:
      forallElements(c, t, body, x, y)
    else:
      discard "cannot copy openArray"

  of tyFromExpr, tyProxy, tyBuiltInTypeClass, tyUserTypeClass,
     tyUserTypeClassInst, tyCompositeTypeClass, tyAnd, tyOr, tyNot, tyAnything,
     tyGenericParam, tyGenericBody, tyNil, tyUntyped, tyTyped,
     tyTypeDesc, tyGenericInvocation, tyForward:
    #internalError(c.g.config, c.info, "assignment requested for type: " & typeToString(t))
    discard
  of tyOrdinal, tyRange, tyInferred,
     tyGenericInst, tyStatic, tyAlias, tySink:
    fillBody(c, lastSon(t), body, x, y)

proc produceSymDistinctType(g: ModuleGraph; c: PContext; typ: PType;
                            kind: TTypeAttachedOp; info: TLineInfo): PSym =
  assert typ.kind == tyDistinct
  let baseType = typ[0]
  if baseType.attachedOps[kind] == nil:
    discard produceSym(g, c, baseType, kind, info)
  typ.attachedOps[kind] = baseType.attachedOps[kind]
  result = typ.attachedOps[kind]

proc produceSym(g: ModuleGraph; c: PContext; typ: PType; kind: TTypeAttachedOp;
              info: TLineInfo): PSym =
  if typ.kind == tyDistinct:
    return produceSymDistinctType(g, c, typ, kind, info)

  var a: TLiftCtx
  a.info = info
  a.g = g
  a.kind = kind
  a.c = c
  let body = newNodeI(nkStmtList, info)
  let procname = getIdent(g.cache, AttachedOpToStr[kind])

  result = newSym(skProc, procname, typ.owner, info)
  a.fn = result
  a.asgnForType = typ

  let dest = newSym(skParam, getIdent(g.cache, "dest"), result, info)
  let src = newSym(skParam, getIdent(g.cache, if kind == attachedTrace: "env" else: "src"), result, info)
  var d: PNode
  #if kind notin {attachedTrace, attachedDispose}:
  dest.typ = makeVarType(typ.owner, typ)
  d = newDeref(newSymNode(dest))
  #else:
  #  dest.typ = typ
  #  d = newSymNode(dest)

  if kind == attachedTrace:
    src.typ = getSysType(g, info, tyPointer)
  else:
    src.typ = typ

  result.typ = newProcType(info, typ.owner)
  result.typ.addParam dest
  if kind notin {attachedDestructor, attachedDispose}:
    result.typ.addParam src

  # register this operation already:
  typ.attachedOps[kind] = result

  var tk: TTypeKind
  if g.config.selectedGC in {gcArc, gcOrc, gcHooks}:
    tk = skipTypes(typ, {tyOrdinal, tyRange, tyInferred, tyGenericInst, tyStatic, tyAlias, tySink}).kind
  else:
    tk = tyNone # no special casing for strings and seqs
  case tk
  of tySequence:
    fillSeqOp(a, typ, body, d, newSymNode(src))
  of tyString:
    fillStrOp(a, typ, body, d, newSymNode(src))
  else:
    fillBody(a, typ, body, d, newSymNode(src))

  var n = newNodeI(nkProcDef, info, bodyPos+1)
  for i in 0..<n.len: n[i] = newNodeI(nkEmpty, info)
  n[namePos] = newSymNode(result)
  n[paramsPos] = result.typ.n
  n[bodyPos] = body
  result.ast = n
  incl result.flags, sfFromGeneric
  incl result.flags, sfGeneratedOp

template liftTypeBoundOps*(c: PContext; typ: PType; info: TLineInfo) =
  discard "now a nop"

proc patchBody(g: ModuleGraph; c: PContext; n: PNode; info: TLineInfo) =
  if n.kind in nkCallKinds:
    if n[0].kind == nkSym and n[0].sym.magic == mDestroy:
      let t = n[1].typ.skipTypes(abstractVar)
      if t.destructor == nil:
        discard produceSym(g, c, t, attachedDestructor, info)

      if t.destructor != nil:
        if t.destructor.ast[genericParamsPos].kind != nkEmpty:
          internalError(g.config, info, "resolved destructor is generic")
        if t.destructor.magic == mDestroy:
          internalError(g.config, info, "patching mDestroy with mDestroy?")
        n[0] = newSymNode(t.destructor)
  for x in n: patchBody(g, c, x, info)

template inst(field, t) =
  if field.ast != nil and field.ast[genericParamsPos].kind != nkEmpty:
    if t.typeInst != nil:
      var a: TLiftCtx
      a.info = info
      a.g = g
      a.kind = k
      a.c = c

      field = instantiateGeneric(a, field, t, t.typeInst)
      if field.ast != nil:
        patchBody(g, c, field.ast, info)
    else:
      localError(g.config, info, "unresolved generic parameter")

proc isTrival(s: PSym): bool {.inline.} =
  s == nil or (s.ast != nil and s.ast[bodyPos].len == 0)


proc isEmptyContainer(g: ModuleGraph, t: PType): bool =
  (t.kind == tyArray and lengthOrd(g.config, t[0]) == 0) or
    (t.kind == tySequence and t[0].kind == tyError)


proc createTypeBoundOps(g: ModuleGraph; c: PContext; orig: PType; info: TLineInfo) =
  ## In the semantic pass this is called in strategic places
  ## to ensure we lift assignment, destructors and moves properly.
  ## The later 'injectdestructors' pass depends on it.
  if orig == nil or {tfCheckedForDestructor, tfHasMeta} * orig.flags != {}: return
  incl orig.flags, tfCheckedForDestructor

  let skipped = orig.skipTypes({tyGenericInst, tyAlias, tySink})
  if isEmptyContainer(skipped): return

  let h = sighashes.hashType(skipped, {CoType, CoConsiderOwned, CoDistinct})
  var canon = g.canonTypes.getOrDefault(h)
  if canon == nil:
    g.canonTypes[h] = skipped
    canon = skipped

  # multiple cases are to distinguish here:
  # 1. we don't know yet if 'typ' has a nontrival destructor.
  # 2. we have a nop destructor. --> mDestroy
  # 3. we have a lifted destructor.
  # 4. We have a custom destructor.
  # 5. We have a (custom) generic destructor.

  # we do not generate '=trace' nor '=dispose' procs if we
  # have the cycle detection disabled, saves code size.
  let lastAttached = if g.config.selectedGC == gcOrc: attachedDispose
                     else: attachedSink

  # we generate the destructor first so that other operators can depend on it:
  for k in attachedDestructor..lastAttached:
    if canon.attachedOps[k] == nil:
      discard produceSym(g, c, canon, k, info)
    else:
      inst(canon.attachedOps[k], canon)
    if canon != orig:
      orig.attachedOps[k] = canon.attachedOps[k]

  if not isTrival(orig.destructor):
    #or not isTrival(orig.assignment) or
    # not isTrival(orig.sink):
    orig.flags.incl tfHasAsgn
