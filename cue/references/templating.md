# Templating

Every snippet here was run against cue v0.18.0.

CUE has no template engine in the Jinja sense. A **template** is a definition plus a pattern constraint or comprehension that stamps it onto every instance, and the output is whatever `cue export` emits once everything is concrete. The goal is a compact source, such as one `apps` map, that expands into the verbose target, such as many manifests.

## Shape of a template package

```cue
package deploy

#App: {
	name!:    string
	image!:   string
	port:     *8080 | int
	replicas: *1 | int & >=1
}

// Input: terse, one entry per app. The key becomes the name.
apps: [string]~(N,_): #App & {name: N}
apps: {
	api: image: "api:1.2"
	web: {image: "web:3", replicas: 3, port: 80}
}

// Expansion: comprehensions derive every output object from the input.
k8s: {
	for n, a in apps {
		deployments: (n): {
			apiVersion: "apps/v1"
			kind:       "Deployment"
			metadata: name: n
			spec: replicas: a.replicas
			spec: template: spec: containers: [{name: n, image: a.image, ports: [{containerPort: a.port}]}]
		}
		services: (n): {
			apiVersion: "v1"
			kind:       "Service"
			metadata: name: n
			spec: ports: [{port: a.port}]
		}
	}
}

objects: [for kind in k8s for o in kind {o}]
```

The complete, runnable version is [examples/template/](../examples/template/).

Mechanics:

- `(n): ...` is a dynamic field label. Parentheses make the label an expression.
- `[string]~(N,_)` binds the key so the value can use it. In v0.18 this replaces `[N=string]`.
- `for k, v in x` iterates struct fields in declaration order, and lists by index. Field order in the source no longer affects whether evaluation succeeds.
- Defaults (`*8080 | int`) give the per-instance override point: set the field in the input, or let the default flow through.
- Use `let` for local intermediates, and `_hidden` fields for helpers that must never be exported.
- Iterate data, not definitions. A `for` over a `#Def` yields closed values that reject added fields in v0.18. Keep catalogs you expand from in regular or `_hidden` fields.

## Layering environments

Unification is commutative and cannot override, so layer by *narrowing*, never by redefining:

```cue
env: *"dev" | "staging" | "prod" @tag(env)
replicas: *1 | int @tag(replicas,type=int)

#Sizes: {dev: 1, staging: 2, prod: 3}
apps: [string]: replicas: *#Sizes[env] | int
```

```sh
cue export . -t env=prod -t replicas=3 -e objects --out yaml
```

Setting a concrete value twice with different values is a conflict, not an override. When something needs a different value per environment, make the base a default (`*x | T`) or compute it from a tag. `@tag(name,type=int)` parses the injected string. Without `type=`, a tag is a string. `cue help injection` lists the built-in tags such as `@tag(now,var=now)`.

## Emitting output

| Target | Command |
|---|---|
| one YAML document | `cue export . -e objects[0] --out yaml` |
| YAML list | `cue export . -e objects --out yaml` |
| Kubernetes-style zero-indent lists | `--out yaml+indentSequences=false` |
| multi-document stream (`---`) | `cue export . -e a -e b --out yaml`, or `stream: yaml.MarshalStream(objects)` with `--out text` |
| arbitrary text, such as INI, nginx, or shell | `template.Execute(tmpl, data)` from `text/template`, then `--out text` |
| one-line JSON | `--out json+compact` |
| many files | `cue cmd` with `tool/file`, below |

`--out text` requires the selected value to be a string.

```cue
import "text/template"

nginx: template.Execute("""
	{{range .}}server {{.name}} listen {{.port}};
	{{end}}
	""", [for a in apps {a}])
```

Prefer CUE structure plus `--out yaml|json|toml` over `text/template`. Use templates only for formats CUE cannot encode.

## Writing many files: `cue cmd`

`cue cmd` finds `command:` only in `*_tool.cue` files of the same package. A command defined anywhere else fails with `could not find command`. Keep `tool/*` imports in those files as well, because their tasks run only under `cue cmd`.

```cue
// gen_tool.cue
package deploy

import (
	"encoding/yaml"
	"tool/file"
)

command: gen: {
	mk: file.MkdirAll & {path: "out"}
	for k, kind in k8s for n, o in kind {
		"write-\(k)-\(n)": file.Create & {
			$after:   mk
			filename: "out/\(n)-\(k).yaml"
			contents: yaml.Marshal(o)
		}
	}
}
```

Run it with `cue cmd gen`. Task names must be unique, so build them by interpolation. Tasks run in parallel unless `$after` or a field reference orders them. Other tasks are `tool/exec.Run`, `tool/cli.Print`, and `tool/http.Do`.

## Feeding data files in

- **On the command line:** `cue export . data/*.yaml -l '"svcs"' -l name -e svcs` places each file under `svcs.<name>`, with the same placement rules as `cue vet` (see [validation.md](validation.md)). Running the same `-l` flags through `vet` and `export` validates exactly what you generate.
- **From inside CUE:** use `@embed`, which needs `@extern(embed)` before the package clause:

  ```cue
  @extern(embed)

  package deploy

  raw: _ @embed(glob=data/*.yaml)          // map: filename -> decoded value
  svcs: {for f, v in raw {(v.name): v & #S}}
  ```

  Use `@embed(file=x.json)` for a single file. Embedded paths must be inside the module.

## Checking the output

1. `cue vet -c .` exits 0. Every output field is concrete.
2. `cue export ... > out.yaml`, then read it. Check field names, list layout, and that no `null` or default appears where an input value belongs. Check **types** against the target too: input ints stay ints. Where the target wants strings, such as ConfigMap `data`, env values, or annotations, convert with `"\(x)"` or `strconv.FormatInt(x, 10)`. To make CUE enforce it, constrain the output (`data: [string]: string`).
3. For Kubernetes, validate the export against the real API schema. Import it with `cue get crd` or `cue import jsonschema:`, or pass the YAML to `kubectl apply --dry-run=server`.
