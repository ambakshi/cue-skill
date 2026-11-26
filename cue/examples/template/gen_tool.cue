package template

import (
	"encoding/yaml"
	"tool/file"
)

// cue cmd gen  (writes out/<name>-<kind>.yaml)
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
