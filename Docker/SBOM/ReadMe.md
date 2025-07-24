# Container Image Security Script: Signing and SBOM Generation

This script automates the process of securing your Docker container images by:

1. Logging into a specified Docker registry.

2. Preparing your Docker image (either by building a new one from a `Dockerfile` or pulling an existing one).

3. Digitally signing the Docker image using **Cosign** (keyless signing).

4. Generating a **Software Bill of Materials (SBOM)** for the image using **Docker Scout** and then attesting (signing and associating) that SBOM with your image in the registry using Cosign.

This helps ensure the authenticity and integrity of your container images and provides transparency into their components.

## Prerequisites

Before running this script, ensure you have the following installed and configured on your system:
    
* **Docker Desktop / Docker Engine:** Make sure Docker is installed and running.

* **`docker buildx`:** This is usually bundled with Docker Desktop. If using Docker Engine, ensure it's installed and a builder instance is set up (e.g., `docker buildx create --use`).

* **`docker scout`:** Install Docker Scout. You can typically enable it in Docker Desktop settings or download the CLI.

* **Cosign:** Install Cosign. Follow the instructions on the Sigstore website: [https://docs.sigstore.dev/cosign/installation/](https://docs.sigstore.dev/cosign/installation/)

* **A Dockerfile (if building):** If you set `BUILD_IMAGE_FROM_DOCKERFILE` to `true`, you'll need a `Dockerfile` in the same directory as the script.

* **Container Registry Account:** You'll need an account and access to a container registry (e.g., Docker Hub, Google Container Registry, AWS ECR, etc.) where you can push/pull images and attestations.

## Configuration

Open the `secure_image.sh` script and modify the following variables in the `--- Configuration ---` section:

* `IMAGE_NAME`: The name of your Docker image (e.g., `my-docker-username/my-app`).

* `IMAGE_TAG`: The tag for your image (e.g., `latest`, `v1.0.0`).

* `REGISTRY`: The domain of your container registry (e.g., `docker.io` for Docker Hub, `gcr.io` for Google Container Registry).

* `BUILD_IMAGE_FROM_DOCKERFILE`: Set to `true` if you want the script to build an image from a `Dockerfile` in the current directory and push it. Set to `false` if you want the script to pull an existing image from the registry.

## Usage

1.  **Save the script:** Save the code above into a file named, for example, `secure_image.sh`.

2.  **Make it executable:**

    ```bash
    chmod +x secure_image.sh

    ```

3.  **Configure the script:** Open `secure_image.sh` in a text editor and update the `IMAGE_NAME`, `IMAGE_TAG`, `REGISTRY`, and `BUILD_IMAGE_FROM_DOCKERFILE` variables as per your requirements.

4.  **Prepare your Dockerfile (if building):** If `BUILD_IMAGE_FROM_DOCKERFILE` is set to `true`, ensure you have a `Dockerfile` in the same directory as the script. A simple example:

    ```dockerfile
    # Dockerfile
    FROM alpine:latest
    CMD ["echo", "Hello from my secure app!"]

    ```

5.  **Run the script:**

    ```bash
    ./secure_image.sh

    ```

## What the Script Does

1.  **Docker Login:** Prompts you to log in to the specified container registry (`docker.io` by default). This is necessary for pulling existing images or pushing new ones and their associated attestations.

2.  **Prepare Docker Image:**

    * If `BUILD_IMAGE_FROM_DOCKERFILE` is `true`, it builds your Docker image from the `Dockerfile` in the current directory and pushes it to your configured registry.

    * If `BUILD_IMAGE_FROM_DOCKERFILE` is `false`, it pulls the specified existing image from the registry.

3.  **Sign Image with Cosign:** It uses `cosign sign --yes` to digitally sign your Docker image. This process uses Sigstore's keyless signing, which will redirect you to your browser for authentication with an OIDC provider (like Google or GitHub). The signature is then stored in the registry and/or a public transparency log.

4.  **Generate and Attest SBOM:**

    * `docker scout sbom` generates the Software Bill of Materials (SBOM) for your image and saves it to a local `.spdx.json` file.

    * `cosign attest --predicate [SBOM_FILE] --yes [IMAGE]` then takes this local SBOM file, signs its content, and associates this signed SBOM as an "attestation" with your image in the container registry. This makes the SBOM discoverable and verifiable alongside your image.
