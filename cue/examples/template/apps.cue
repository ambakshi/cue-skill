package template

// Input: one terse entry per app. The key becomes the app's name.
apps: [string]~(N,_): #App & {name: N}
apps: {
	api: image: "registry.example/api:1.2"
	web: {image: "registry.example/web:3", port: 80, replicas: 4}
}
