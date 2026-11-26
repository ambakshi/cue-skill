# Migrating to v0.18

Read this when a module's `language.version` is below `v0.18.0`, or when CUE copied from older docs, blog posts, or memory fails to parse.

## Mechanical rewrite

```sh
cue mod upgrade v0.18.0     # rewrites every file of the module, then bumps cue.mod/module.cue
```

The upgrade converts `[K=string]` to `[string]~(K,_)` and `x: X={...}` to `x~(X): {...}`. It also rewrites embeddings, wrapping them as `__closeAll({#A..., b: 1})` so they keep their old meaning. A file it cannot convert stops the upgrade before anything is written. `--force` overrides that.

For a standalone file, or one file at a time, run `cue fix --exp=explicitopen,aliasv2 file.cue` while the file is still at its old version, then raise the version. A file at v0.18.0 cannot go back, because `@experiment` can only enable an experiment, never disable one.

After the rewrite, replace each `__closeAll(...)` with what was meant: usually `{#A, b: 1}` if `b` belongs in `#A`, or `{#A..., b: 1}` if the struct is meant to stay open.

To evaluate an old file unchanged, put `@version(v0.17.0)` first in the file. This works only outside a module, because inside one, `module.cue` decides the version. Alternatively, pass `--language-version v0.17.0` to the command.

## Semantic changes the rewrite does not fix

Run `cue vet -c` and `cue export` after upgrading and diff the exports. These changes show up as new errors or different output:

| Symptom after upgrade | Cause | Fix |
|---|---|---|
| `field not allowed` on a field added next to an embedded `#Def` | strict embedding | `#Def...`, or declare the field in `#Def` |
| `field not allowed` on `d.s & {...}` where `d: #D` | closedness now follows references | keep extendable data out of definitions |
| `field not allowed` inside `for v in #Catalog {v & {...}}` | comprehension over a definition yields closed values | move the catalog to `_catalog` or a regular field |
| `mismatched types float and int` on `float & a / b` | exact division: an exact quotient is an `int` | constrain with `number` |
| an `int` field rejects `list.Sum`/`list.Avg`/`math.Abs` results | the functions keep their argument kinds | use `number`, or convert explicitly |
| `pattern constraint cannot be marked optional` | `[string]?:` / `[string]!:` | delete the marker |
| exported floats gain `.0`, and `6.00 / 3` exports `2.00` | decimal places are preserved | update golden files |
| new `!=` / `=~` / validator errors under a `let` or interpolation | these constraints were silently dropped before | the new errors are real, so fix the data |
| `{a: 1.0} == {a: 1}` is now true | numeric comparison everywhere | review equality guards |
| `cue fmt` reformats untouched files | `formatv2` is the default | commit the reformat on its own; `CUE_EXPERIMENT=formatv2=0` restores the old formatter for v0.18 only |

## CLI changes

- `-n/--name` is accepted only by `cue import`, and `-s/--simplify` only by `eval`, `fix`, `fmt`, and `trim`. Remove them from other commands in scripts.
- `cue vet` now reports every failing data file and document, and honours every `-d`. CI output may get longer.
- `cue get go --exclude` is deprecated in favour of `--omit`.
