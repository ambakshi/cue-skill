---
name: cue
description: CUE (cue-lang) v0.18 for validating JSON/YAML/TOML data against schemas and generating config from templates. Use when writing or debugging .cue files, running cue vet/export/cmd, converting JSON Schema or OpenAPI to or from CUE, or migrating CUE written for an older version.
---

# CUE v0.18

CUE unifies values: a schema, a constraint, and data are all values, and `&` combines them. Validation is unification that must not produce bottom (`_|_`); templating is unification that must end **concrete** (every field a single, exportable value).

v0.18.0 is a long-term support release that changed syntax and semantics. Much CUE in the wild, and in your priors, is pre-0.18. Write to the rules below, not from memory.

## Steps

1. **Pin the toolchain.** Run `cue version`; it must report `v0.18.x`. In a module, `cue.mod/module.cue` holds `language: version:`, which decides how its files parse. A standalone file can declare `@version(v0.18.0)` as its first line. Done when you know the language version every file will be evaluated at. If it is below v0.18.0, read [references/migration.md](references/migration.md) before editing anything.
2. **Pick the branch** and read its reference:
   - Checking data against a schema, writing constraints, reading `cue vet` errors, JSON Schema / OpenAPI interop: [references/validation.md](references/validation.md).
   - Generating YAML/JSON/text, Kubernetes-style manifests, per-environment config, writing multiple output files: [references/templating.md](references/templating.md).
   - Both, which is common: define the shape once as `#Thing`. Place the data files into a keyed map with `-l` (`things: [string]~(N,_): #Thing & {name: N}`). Validate that map, and generate from the same map. Read both references.
   - Working patterns live in [examples/](examples/) (`validate/`, `template/`).
3. **Write CUE** to the v0.18 rules below. Give every file in a package the same `package` clause, because files without one do not share scope, so a `#Def` in one is "not found" in another.
4. **Prove it.** Run `cue fmt ./...` and then the branch's check. Validation is done when `cue vet -c` exits 0 on the good input *and* goes **red** on a deliberately bad input with the error you expected. A schema that has never gone red has never been tested. Templating is done when `cue export` (or `cue cmd`) exits 0 and you have read the actual output against the target format, field by field.

## v0.18 rules

These are the rules older CUE gets wrong. They apply on every branch.

| Write (v0.18) | Not (pre-0.18, now a parse error or different meaning) |
|---|---|
| `[string]~(K,_): {name: K}` | `[K=string]: {name: K}` |
| `x~(X): {a: 1, b: X.a}` | `x: X={a: 1, b: X.a}` |
| `y: {let Y = self, c: 2, d: Y.c}` | `y: Y={c: 2, d: Y.c}` |
| `self["a-b"]` to reference a non-identifier sibling | quoting tricks |
| `[string]: int` | `[string]?: int` (pattern markers are now rejected) |
| `#A...` to embed `#A` and stay open | `{#A, extra: 1}` and expecting `extra` to be allowed |

- **Strict embedding.** Embedding a definition closes the enclosing struct to that definition's fields. `{#Base, extra: 1}` fails with `field not allowed`. Write `{#Base..., extra: 1}`, or put `extra` in `#Base`.
- **Closedness follows references.** `d: #D` then `d.s & {extra: 1}` is an error, and so is iterating a definition in a `for` and adding fields to what it yields. Data you mean to extend belongs in a regular or hidden (`_name`) field, not a `#definition`.
- **Exact arithmetic.** `10 / 5` is the int `2` and `10 / 4` is the float `2.5`, so `float & 10 / 5` conflicts. `list.Sum([1.5, 2.5])` is the float `4.0`, so an `int` field rejects it. Constrain arithmetic results with `number` when either kind is acceptable.
- **`==`/`!=` compare numerically** across int and float, including inside structs and lists.
- **`cue fmt` uses the new formatter.** Expect alignment changes on existing files, and commit them separately from semantic edits.
- **Experiments** (`functions`, `openlists`, `try`, `shortcircuit`) need `@experiment(name)` and are unstable. Use them only when the user asks.

## Commands

`cue help <cmd>` is authoritative. These are the invocations both branches use:

```sh
cue vet -c ./schema data.yaml            # data unified at the package root
cue vet -c . data/*.yaml -d '#Service'   # each data file checked against one definition
cue export . -e path.to.value --out yaml # emit one value
cue eval . -e expr                       # inspect a partially evaluated value while debugging
cue def . -e '#Def' --out jsonschema     # schema out
cue import -p pkg -l '#Def:' jsonschema: schema.json -o -   # schema in
cue mod init example.com/name            # new module, language.version = v0.18.0
cue mod upgrade v0.18.0                  # migrate a module and rewrite its files
```
