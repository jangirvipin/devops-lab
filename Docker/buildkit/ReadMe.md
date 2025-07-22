# Secure, Concurrent, and Efficient Go Application Build with BuildKit

This project demonstrates building a Go application using a multi-stage Dockerfile, leveraging **BuildKit** for a secure, concurrent, and efficient build process. It incorporates best practices like Go module caching and secret management.

---

## Key Features

* **Multi-Stage Build:** Separates build environment from the runtime environment for smaller, more secure final images.
* **BuildKit Integration:** Utilizes advanced BuildKit features for optimized builds.
* **Go Module Caching:** Caches Go modules to significantly speed up build times and reduce network traffic during subsequent builds.
* **Secret Management:** Securely passes environment variables during the build process using BuildKit's secret mounting.

---

## BuildKit Setup

BuildKit is a modern build subsystem for Docker that enables advanced features like caching, parallel builds, and secrets management.

### Enabling BuildKit for a Single Build

You can enable BuildKit for a specific `docker build` command by setting the `DOCKER_BUILDKIT` environment variable:

```bash
DOCKER_BUILDKIT=1 docker build -t my-app .
```

Alternatively, you can use `docker buildx build`, which uses BuildKit by default:

```bash
docker buildx build -t my-app .
```

### Configuring Docker to Use BuildKit by Default

To avoid setting the environment variable every time, you can configure your Docker daemon to use BuildKit by default. Add the following to your `/etc/docker/daemon.json` file:

```json
{
  "features": {
    "buildkit": true
  }
}
```

After modifying the `daemon.json` file, remember to restart your Docker daemon for the changes to take effect.

---

## Dockerfile Overview

This Dockerfile employs a multi-stage build strategy:

1.  **Builder Stage:** Uses a `golang` base image to compile your Go application.
    * It mounts Go modules using `--mount=type=cache,source=/go/pkg/mod,target=/go/pkg/mod` to cache dependencies, speeding up subsequent builds.
    * It also uses a secret, `--secret id=secret,src=.env.build`, to securely pass build-time environment variables.

2.  **Runner Stage:** Copies the compiled Go binary from the builder stage into a minimal `alpine` image. This results in a significantly smaller and more secure final image for running your application.

---

##  Usage

### Build the Docker Image

To build the Docker image, ensure you have a `.env.build` file in the same directory as your Dockerfile. This file should contain any environment variables needed during the build process.

```bash
# Example .env.build file:
# BUILD_VERSION=1.0.0
# SOME_BUILD_FLAG=true
```

Then, use the `docker buildx build` command, specifying the secret:

```bash
docker buildx build \
  --secret id=secret,src=.env.build \
  -t my-app \
  --progress=plain \
  .
```

* `--secret id=secret,src=.env.build`: Mounts your `.env.build` file as a secret named `secret`, making its contents available during the build.
* `-t my-app`: Tags the resulting image as `my-app`.
* `--progress=plain`: Shows a detailed, plain-text progress output of the build.
* `.`: Specifies the build context (the current directory).

### Run the Docker Image

Once the image is built, you can run your application, passing any necessary runtime environment variables:

```bash
docker run \
  -e API_URL=http://localhost:8000 \
  -e API_KEY=1234567890abcdef \
  my-app
```

* `-e API_URL=http://localhost:8000`: Sets the `API_URL` environment variable inside the container.
* `-e API_KEY=1234567890abcdef`: Sets the `API_KEY` environment variable inside the container.
* `my-app`: The name of the Docker image to run.

---
