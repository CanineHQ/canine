# Rover Sidecar

`rover` is Canine's managed coding-agent sidecar image.

It is designed to:

- mount the same writable workspace volume as the user's development container
- stay alive and ready for Canine to exec coding-agent commands into it
- include a broad set of common developer tools without coupling the sidecar to a specific app stack

Key defaults:

- workspace: `/workspace`
- entrypoint: `rover-entrypoint`
- default command: `sleep infinity`

Build example:

```bash
docker build -f resources/sidecars/rover/Dockerfile.sidecar -t canine/rover-sidecar:dev resources/sidecars/rover
```
