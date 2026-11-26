package template

import "encoding/yaml"

// Expansion: every manifest is derived from `apps`.
k8s: {
	for n, a in apps {
		deployments: (n): {
			apiVersion: "apps/v1"
			kind:       "Deployment"
			metadata:   {name: n, labels: app: n}
			spec: {
				replicas: a.replicas
				selector: matchLabels: app: n
				template: {
					metadata: labels: app: n
					spec: containers: [{
						name:  n
						image: a.image
						ports: [{containerPort: a.port}]
					}]
				}
			}
		}
		services: (n): {
			apiVersion: "v1"
			kind:       "Service"
			metadata: name: n
			spec: {
				selector: app: n
				ports: [{port: a.port}]
			}
		}
	}
}

objects: [for kind in k8s for o in kind {o}]

// cue export . -e stream --out text
stream: yaml.MarshalStream(objects)
