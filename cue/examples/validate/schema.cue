package validate

import "strings"

// #Service is one deployable unit. Data files supply a map of these
// under `services`, keyed by name.
#Service: {
	name!:    string & =~"^[a-z][a-z0-9-]*$"
	image!:   string
	replicas: *1 | int & >=1 & <=10
	port?:    int & >0 & <65536
	tier!:    "web" | "worker"
	env: [string]:          string
	labels: [string]~(K,_): strings.MaxRunes(63)

	// Workers do not listen.
	matchIf({tier: "worker"}, {port?: _|_}, _)
}

services: [string]~(N,_): #Service & {name: N}
