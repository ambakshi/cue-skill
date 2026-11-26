# Validation

Every snippet here was run against cue v0.18.0.

## Schema building blocks

| Need | CUE |
|---|---|
| type | `string`, `int`, `float`, `number`, `bool`, `bytes`, `null`, `_` (any) |
| range | `int & >=1 & <=10` |
| regex | `string & =~"^[a-z][a-z0-9-]*$"`, negated `!~` |
| enum | `"web" \| "worker"` |
| default | `*1 \| int` (the default applies only when nothing else is given) |
| required | `name!: string`: data must supply it |
| optional | `port?: int`: may be absent, constrained if present |
| regular | `tier: string`: must end concrete under `-c`, and a schema may fill it |
| closed struct | any `#Definition`, or `close({...})` |
| open struct | `{..., known: int}` |
| map | `env: [string]: string` |
| keyed map | `ann: {[=~"^x-"]: string, [!~"^x-"]: int}` |
| key bound into value | `services: [string]~(N,_): #Service & {name: N}` |
| list | `[...int]`, `[string, ...int]` |
| cross-field | `max!: int & >=min` (a reference to a sibling) |
| allowed values depend on another field | `#Versions: {postgres: "16" \| "17", mysql: "8.0" \| "8.4"}` then `version!: #Versions[engine]` |

Reach for indexing (the last row) before `matchIf` or `if`. It is shorter, and its errors name the values that are actually allowed.

Prefer `name!:` over `name:` for fields the data must supply. A required field reports `field is required but not present` at the data's position, while a plain `name: string` the data omits reports `incomplete value`.

## Standard library validators

Import the package, then use the call as a constraint:

```cue
import ("list", "net", "strings", "struct", "time")

hosts:   [...net.IPv4] & list.UniqueItems() & list.MinItems(1)
host:    net.FQDN
started: time.Time                   // RFC 3339
day:     time.Format("2006-01-02")
tags:    struct.MinFields(1) & {[string]: string}
owner:   strings.HasSuffix("@corp.example")
label:   strings.MaxRunes(63)
```

Full list: https://pkg.go.dev/cuelang.org/go/pkg (`strings`, `list`, `struct`, `net`, `time`, `math`, `regexp`, `uuid`, `encoding/json`, `encoding/yaml`, and others).

## Conditional and combinational rules

```cue
#T: {
	mode?:      "single" | "ha"
	replicas?:  int
	tls?:       {cert!: string}
	plaintext?: bool

	matchN(1, [{tls!: _}, {plaintext!: _}])       // exactly one of tls / plaintext
	matchIf({mode: "ha"}, {replicas: >=3}, _)     // if / then / else

	if replicas != _|_ if mode != _|_ if replicas > 5 && mode == "single" {
		_bad: error("single mode supports at most 5 replicas")  // custom message
	}
}
```

- `matchN(n, [...])` also takes bounds: `matchN(>=1, ...)` is anyOf, and `matchN(0, [X])` is not.
- `error("msg")` is the way to give a user-facing message. Put it in a hidden field so it never exports.
- `if` guards on optional fields need the field to exist. Chain an existence check for each one (`if x != _|_ if y != _|_ if ...`), or make the field regular with a default.
- With several `matchN` calls in one struct, v0.18.0 can attribute a failure to the wrong call (`0 matched, expected 0`). If the message contradicts itself, test each `matchN` alone.

## Running `cue vet`

- **Placement.** Data files unify at the package root by default. `-d '#Def'` checks *each* data file, and each document of a YAML stream, against `#Def` instead. Its error paths start at the field (`nodes: ...`), so only the position lines tell you which file failed. `-l` places a file under a path built from labels or from its own fields: `-l '"services"' -l name` puts `{name: api, ...}` at `services.api`, and errors then read `services.api.nodes`. Prefer `-l` for one-object-per-file directories, and when the same data also feeds a template. `--with-context` exposes `filename`, `index`, and `data` to `-l` expressions, so `-l data.name` is the same as `-l name`. You need it only for `filename` or `index`.
- **Duplicates unify silently.** Two files that place at the same `-l` path merge. Identical copies pass, and differing ones fail as `conflicting values`, not as "duplicate".
- **Mixing.** Packages, CUE files, and data files combine in one call: `cue vet -c ./schemapkg extra.cue data.yaml`.
- **Qualifiers stick.** `jsonschema: s.json d.yaml` reads *both* files as JSON Schema and then complains `data files specified without a schema`. Requalify: `cue vet -c jsonschema: s.json yaml: d.yaml`.
- **Always pass `-c`.** Without it, a package that still has non-concrete fields fails with `some instances are incomplete`, and no field-level errors are shown.
- vet reports every failing file and document, not just the first.

## Reading errors

```
services.Bad_Name.replicas: invalid value 20 (out of bound <=10):
    ./schema.cue:8:30
    ./data.yaml:8:15
```

The path comes first, then each position that contributed a conjunct, both schema and data. `N errors in empty disjunction` means no branch of `a | b | c` matched, and each branch's conflict follows it.

`mismatched types float and string` (or `int and string`) on a value that looks right usually means a YAML scalar was read as a number. Examples are `version: 8.0`, `version: 16`, and `zip: 01234`. The data needs quotes (`"8.0"`). Widening the schema would hide the problem.

**Errors mask each other.** A field whose constraint depends on another field (`#Versions[engine]`, an `if` guard, `matchIf`) goes unchecked while that other field is in error. A failing validator in a struct can also hide a `matchN`/`matchIf` in the same struct, and `field not allowed` can stay silent while sibling fields conflict. Fix what is reported and re-run until vet is clean. One run is not proof that nothing else is wrong.

To see what a value actually is, run `cue eval . -e path`, which shows the partially evaluated value including unresolved constraints.

## JSON Schema and OpenAPI

```sh
cue vet -c jsonschema: schema.json yaml: data.yaml        # validate directly, no CUE written
cue import -p people -l '#Person:' jsonschema: s.json     # writes s.cue with #Person
cue def ./pkg -e '#Person' --out jsonschema               # CUE -> JSON Schema 2020-12
```

Imported schemas use `close({...})`, `name!:` for `required`, and `strings.MinRunes` for `minLength`. Add `+strict` (`jsonschema+strict:`) to fail on keywords that CUE cannot map. The JSON Schema encoder is experimental, so diff its output when upgrading cue. CRDs import with `cue get crd`, Go types with `cue get go`.
