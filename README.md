# cue skill

An agent skill for [CUE](https://github.com/cue-lang/cue) v0.18.0, focused on data validation and templating.

```
cue/
  SKILL.md                    entry point: workflow + v0.18 rules
  references/validation.md    schemas, validators, cue vet, JSON Schema
  references/templating.md    comprehensions, tags, output formats, cue cmd
  references/migration.md     moving pre-0.18 CUE to v0.18
  examples/validate/          schema + good/bad YAML
  examples/template/          apps -> Kubernetes manifests, cue cmd gen
tests/run.sh                  checks the examples against the installed cue
```

## Install

Copy or symlink `cue/` into a skills directory, for example:

```sh
ln -s "$PWD/cue" ~/.claude/skills/cue
```

## Test

```sh
mise install        # cue 0.18.0, pinned in mise.toml
tests/run.sh
```

Re-run `tests/run.sh` when moving to a new cue release. Every snippet in `references/` was checked against v0.18.0 by hand, and the examples are checked by the script.
