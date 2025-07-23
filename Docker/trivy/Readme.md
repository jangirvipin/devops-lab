# Docker Image Scan and Multi-Architecture Build Workflow

This repository contains a GitHub Actions workflow designed to automate the security scanning of your Docker image using Trivy, and then, if the scan is successful, build and push a multi-architecture Docker image to Docker Hub.

## Workflow File Location

The workflow is defined in `.github/workflows/image-scan-and-build.yml` (assuming you name your file this).

## Workflow Overview

This workflow consists of two main jobs that run sequentially:

1.  **`scan` Job**: Builds the Docker image locally and performs a vulnerability scan using Trivy. If critical or high-severity vulnerabilities are found, this job will fail.
2.  **`build` Job**: If the `scan` job passes successfully, this job proceeds to set up Docker Buildx, log in to Docker Hub, and then build and push a multi-architecture version of your Docker image.

This setup ensures that only Docker images that have passed a security scan are pushed to your container registry.

## Workflow Triggers

The workflow is configured to run automatically on the following events:

* **`push` to `main` branch**: Whenever changes are pushed to the `main` branch.
* **`pull_request` to `main` branch**: When a pull request is opened, synchronized, or reopened targeting the `main` branch.

```yaml
on:
  push:
    branches:
      - main
  pull_request:
    branches:
      - main
```

## Jobs Breakdown

### 1. `scan` Job: Local Image Build and Trivy Scan

This job is responsible for the initial security validation of your Docker image.

* **`runs-on: ubuntu-latest`**: Specifies that this job will run on the latest Ubuntu environment provided by GitHub Actions.
* **`steps`**:

    * **`Checkout code`**:
        ```yaml
        - name: Checkout code
          uses: actions/checkout@v2
        ```
      This step uses the `actions/checkout` action to pull your repository's code onto the runner, making it available for subsequent steps.

    * **`Build Docker image`**:
        ```yaml
        - name: Build Docker image
          run: docker build -t my-image .
        ```
      This command builds your Docker image from the `Dockerfile` in the current directory (`.`) and tags it as `my-image`. This image is built *locally* on the GitHub Actions runner and is not pushed to any registry at this stage.

    * **`Run Trivy vulnerability scan on local image`**:
        ```yaml
        - name: Run Trivy vulnerability scan on local image
          uses: aquasecurity/trivy-action@master
          with:
            image-ref: my-image
            format: 'sarif'
            output: 'trivy-scan-results.sarif'
            exit-code: '1'
            ignore-unfixed: true
            severity: 'CRITICAL,HIGH,MEDIUM'
        ```
      This crucial step uses the `aquasecurity/trivy-action` to scan the `my-image` that was just built locally.
        * `image-ref: my-image`: Tells Trivy to scan the local image tagged `my-image`.
        * `format: 'sarif'` and `output: 'trivy-scan-results.sarif'`: Configures Trivy to generate its report in SARIF format and save it to a file. SARIF is essential for integrating with GitHub's native security features.
        * `exit-code: '1'`: **Important for security gating.** If Trivy finds any vulnerabilities with `CRITICAL`, `HIGH`, or `MEDIUM` severity, this step will fail, causing the entire `scan` job (and thus the workflow) to fail.
        * `ignore-unfixed: true`: Only reports vulnerabilities for which a fix is available.
        * `severity: 'CRITICAL,HIGH,MEDIUM'`: Filters the reported vulnerabilities to only include these severity levels.

    * **`Upload Trivy scan results`**:
        ```yaml
        - name: Upload Trivy scan results
          uses: github/codeql-action/upload-sarif@v3
          with:
            sarif_file: trivy-scan-results.sarif
            category: 'security'
          if: always()
        ```
      This step takes the `trivy-scan-results.sarif` file and uploads it to your repository's **GitHub Security tab** (under "Code scanning alerts").
        * `if: always()`: This ensures that the SARIF report is uploaded *even if the Trivy scan step fails*. This is a best practice, as you want to see the security findings regardless of whether they broke the build.

### 2. `build` Job: Multi-Architecture Image Build and Push

This job only runs if the `scan` job completes successfully, ensuring that only secure images are pushed.

* **`runs-on: ubuntu-latest`**: Specifies the runner environment.
* **`needs: scan`**: This declares a dependency on the `scan` job. The `build` job will only start after the `scan` job has finished.
* **`if: success()`**: This condition explicitly states that the `build` job will only execute if the `scan` job completed successfully (i.e., no critical/high/medium vulnerabilities were found).
* **`steps`**:

    * **`Checkout code`**:
        ```yaml
        - name: Checkout code
          uses: actions/checkout@v2
        ```
      Checks out the repository code again for this job.

    * **`Set up Docker Buildx`**:
        ```yaml
        - name: Set up Docker Buildx
          uses: docker/setup-buildx-action@v3
        ```
      Sets up Docker Buildx, which is necessary for building multi-architecture images. Ensure you have a Buildx builder configured (as discussed in previous interactions, usually via `docker buildx create --name mybuilder --driver docker-container --use`).

    * **`Login to Docker Hub`**:
        ```yaml
        - name: Login to Docker Hub
          uses: docker/login-action@v3
          with:
            username: ${{ secrets.DOCKER_USERNAME }}
            password: ${{ secrets.DOCKER_PASSWORD }}
        ```
      Logs into your Docker Hub account using [GitHub Secrets](https://docs.github.com/en/actions/security-guides/encrypted-secrets).
        * **Action Required**: You must configure `DOCKER_USERNAME` and `DOCKER_PASSWORD` as repository secrets in your GitHub repository settings.

    * **`Build and push Docker image`**:
        ```yaml
        - name: Build and push Docker image
          id: docker_build
          uses: docker/build-push-action@v5
          with:
            context: .
            push: true
            tags: ${{ secrets.DOCKER_USERNAME }}/my-image:latest # Replace with your image name
            platforms: linux/amd64,linux/arm64
            cache-from: type=gha,scope=build-and-scan
            cache-to: type=gha,mode=max,scope=build-and-scan
        ```
      This step builds the Docker image for multiple platforms (`linux/amd64` and `linux/arm64`) and pushes it to your Docker Hub repository.
        * `push: true`: Confirms the image will be pushed.
        * `tags`: The final image tag in your Docker Hub. **Remember to replace `my-image:latest` with your actual image name!**
        * `platforms: linux/amd64,linux/arm64`: Specifies the target architectures for the build.
        * `cache-from` and `cache-to`: Utilizes GitHub Actions caching to speed up subsequent builds by reusing layers.

## Prerequisites for Running This Workflow

1.  **Dockerfile**: Ensure you have a `Dockerfile` in the root of your repository.
2.  **GitHub Secrets**:
    * `DOCKER_USERNAME`: Your Docker Hub username.
    * `DOCKER_PASSWORD`: Your Docker Hub password or a personal access token.
    * Configure these in your GitHub repository: `Settings` -> `Secrets and variables` -> `Actions` -> `New repository secret`.
3.  **Docker Buildx Setup (Manual)**: While the workflow sets up `docker/setup-buildx-action`, for multi-architecture builds to work correctly, you generally need a Buildx builder instance that supports the `docker-container` driver. You might need to run this command once on a machine with Docker installed (e.g., your local machine or a dedicated build server, if not relying purely on GitHub-hosted runners' default setup):
    ```bash
    docker buildx create --name mybuilder --driver docker-container --use
    ```
    This ensures that the Buildx environment on the GitHub runner can perform cross-architecture builds.

## How to Use

1.  Save the provided YAML content as `.github/workflows/image-scan-and-build.yml` in your GitHub repository.
2.  Replace `your_dockerhub_username` and `my-image` placeholders with your actual Docker Hub username and desired image name.
3.  Configure your `DOCKER_USERNAME` and `DOCKER_PASSWORD` GitHub Secrets.
4.  Push the changes to your `main` branch or open a pull request.

The workflow will automatically trigger, scan your image for vulnerabilities, and if clean, build and push the multi-architecture image.
