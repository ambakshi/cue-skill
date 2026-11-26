package template

#App: {
	name!:    string
	image!:   string
	port:     *8080 | int & >0 & <65536
	replicas: *#Sizes[env] | int & >=1
}

env: *"dev" | "staging" | "prod" @tag(env)

#Sizes: {dev: 1, staging: 2, prod: 3}
