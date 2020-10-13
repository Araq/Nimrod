import std/os

type
  PathEntry* = object
    kind*: PathComponent
    path*: string

iterator glob*(dir: string, follow: proc(entry: PathEntry): bool = nil,
    relative = false, checkDir = true): PathEntry {.tags: [ReadDirEffect].} =
  ## Improved `os.walkDirRec`.
  #[
  note: a yieldFilter isn't needed because caller can filter at call site, without
  loss of generality, unlike `follow`.

  Future work:
  * need to document
  * add a `sort` option, which can be implemented efficiently only here, not at call site.
  * provide a way to do error reporting, which is tricky because iteration cannot be resumed
  * `walkDirRec` can be implemented in terms of this to avoid duplication,
  modulo some refactoring.
  ]#
  var stack = @["."]
  var checkDir = checkDir
  var entry: PathEntry
  while stack.len > 0:
    let d = stack.pop()
    for k, p in walkDir(dir / d, relative = true, checkDir = checkDir):
      let rel = d / p
      entry.kind = k
      if relative: entry.path = rel
      else: entry.path = dir / rel
      if k in {pcDir, pcLinkToDir}:
        if follow == nil or follow(entry): stack.add rel
      yield entry
    checkDir = false
      # We only check top-level dir, otherwise if a subdir is invalid (eg. wrong
      # permissions), it'll abort iteration and there would be no way to
      # continue iteration.
