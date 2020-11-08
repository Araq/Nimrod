#
#
#           The Nim Compiler
#        (c) Copyright 2020 Andreas Rumpf
#
#    See the file "copying.txt", included in this
#    distribution, for details about the copyright.
#

import std / [hashes, tables]
import bitabs, packed_ast
import ".." / [ast, lineinfos, options, pathutils, ropes, msgs, idents,
  modulegraphs]

type
  Context = object
    thisModule: int32
    lastFile: FileIndex # remember the last lookup entry.
    lastLit: LitId
    filenames: Table[LitId, FileIndex]
    pendingTypes: seq[ItemId]
    pendingSyms: seq[ItemId]
    typeMap: Table[ItemId, PType]  # ItemId.item -> PType
    symMap: Table[ItemId, PSym]    # ItemId.item -> PSym
    graph: ModuleGraph

proc fromTree(ir: PackedTree; c: var Context; index = 0): PNode
proc fromSym(s: PackedSym; id: ItemId; ir: PackedTree; c: var Context): PSym
proc fromType(t: PackedType; ir: PackedTree; c: var Context): PType

proc fromSym(s: SymId or int32; id: ItemId; ir: PackedTree;
             c: var Context): PSym =
  if s.int >= 0:
    result = fromSym(ir.sh.syms[int s], id, ir, c)

proc fromType(t: TypeId or int32; ir: PackedTree; c: var Context): PType =
  if t.int >= 0:
    result = fromType(ir.sh.types[int t], ir, c)

proc fromIdent(l: LitId; ir: PackedTree; c: var Context): PIdent =
  result = getIdent(c.graph.cache, ir.sh.strings[l])

proc fromLineInfo(p: PackedLineInfo; ir: PackedTree; c: var Context): TLineInfo =
  if p.file notin c.filenames:
    `[]=` c.filenames, p.file:  # too bad add() was deprecated, huh?
      var itIsKnown: bool
      fileInfoIdx(ir.sh.config, AbsoluteFile ir.sh.strings[p.file], itIsKnown)
  TLineInfo(line: p.line, col: p.col, fileIndex: c.filenames[p.file])

proc fromLib(l: PackedLib; ir: PackedTree; c: var Context): PLib =
  result = PLib(generated: l.generated, isOverriden: l.isOverriden,
                kind: l.kind, name: rope ir.sh.strings[l.name],
                path: fromTree(l.path, c))

proc loadSymbol(id: ItemId; c: var Context; ir: PackedTree): PSym =
  # short-circuit if we already have the PSym
  result = getOrDefault(c.symMap, id, nil)
  if result != nil: return
  # if it's our module, then the .item will be a SymId;
  if id.module == c.thisModule:
    result = fromSym(id.item, id, ir, c)
  # else, it's a PIdent identity; an index into the symbol table
  else:
    # XXX: temporary hack
    result = c.graph.modules[int id.module].tab.data[int id.item]
  # cache the result
  c.symMap[id] = result

proc fromSym(s: PackedSym; id: ItemId; ir: PackedTree; c: var Context): PSym =
  result = getOrDefault(c.symMap, id, nil)
  if result != nil: return

  # XXX: move some decodes out of here for recursion reasons...
  result = PSym(itemId: id, kind: s.kind, magic: s.magic, flags: s.flags,
                info: fromLineInfo(s.info, ir, c), options: s.options,
                position: s.position, annex: fromLib(s.annex, ir, c),
                typ: fromType(s.typeId, ir, c),
                ast: fromTree(s.ast, c), name: fromIdent(s.name, ir, c),
                constraint: fromTree(s.constraint, c))
  c.symMap[id] = result

  when hasFFI:
    result.cname = ir.sh.strings[int s.cname]

  case s.kind
  of skModule, skPackage:
    # setup tab?
    discard
  of skLet, skVar, skField, skForVar:
    result.guard = fromSym(ir.sh.syms[int s.guard.item], s.guard, ir, c)
    result.bitsize = s.bitsize
    result.alignment = s.alignment
  else:
    discard
  result.owner = fromSym(ir.sh.syms[int s.owner.item], s.owner, ir, c)
  let externalName = ir.sh.strings[s.externalName]
  if externalName != "":
    result.loc.r = rope externalName

proc asItemId(ir: PackedTree; index = 0): ItemId =
  ## read an itemId from the tree
  assert ir.nodes[index].kind == nkModuleRef
  result.module = ir.nodes[index + 1].operand
  result.item = ir.nodes[index + 2].operand

proc fromSymNode(ir: PackedTree; c: var Context; index = 0.NodePos): PSym =
  template n: Node = ir.nodes[int index]
  let id = case n.kind
  of nkModuleRef:
    asItemId(ir, int index)
  else:
    ItemId(module: c.thisModule, item: n.operand)
  result = loadSymbol(id, c, ir)

proc fromType(t: PackedType; ir: PackedTree; c: var Context): PType =
  # short-circuit if we already have the PType
  result = getOrDefault(c.typeMap, t.nonUniqueId, nil)
  if result != nil: return

  result = PType(kind: t.kind, flags: t.flags, size: t.size, align: t.align,
                 paddingAtEnd: t.paddingAtEnd, lockLevel: t.lockLevel,
                 uniqueId: t.nonUniqueId)

  result.sym = loadSymbol(t.sym, c, ir)
  result.owner = loadSymbol(t.owner, c, ir)
  for op, item in pairs t.attachedOps:
    result.attachedOps[op] = loadSymbol(item, c, ir)
  result.typeInst = fromType(t.typeInst, ir, c)
  for son in items t.types:
    result.sons.add fromType(son, ir, c)
  result.n = fromTree(t.node, c)
  for generic, id in items t.methods:
    result.methods.add (generic, loadSymbol(id, c, ir))

proc fromTree(ir: PackedTree; c: var Context; index = 0): PNode =
  template n: Node = ir.nodes[int index]
  result = PNode(typ: fromType(n.typeId, ir, c), flags: n.flags,
                 kind: n.kind, info: fromLineInfo(n.info, ir, c))

  case n.kind
  of nkNone, nkEmpty, nkNilLit:
    discard
  of nkIdent:
    result.ident = getIdent(c.graph.cache, ir.sh.strings[LitId n.operand])
  of nkSym:
    result.sym = fromSymNode(ir, c, index = index.NodePos)
  of directIntLit:
    result.intVal = n.operand
  of externIntLit:
    result.intVal = ir.sh.integers[LitId n.operand]
  of nkStrLit..nkTripleStrLit:
    result.strVal = ir.sh.strings[LitId n.operand]
  of nkFloatLit..nkFloat128Lit:
    result.floatVal = ir.sh.floats[LitId n.operand]
  else:
    for i in index ..< index + n.operand:
      result.sons.add fromTree(ir, c, i)