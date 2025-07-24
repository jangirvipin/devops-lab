#!/bin/bash

# --- Configuration ---
# Replace with your desired image name and tag
IMAGE_NAME="your-docker-username/my-app"
IMAGE_TAG="latest"
FULL_IMAGE_NAME="${IMAGE_NAME}:${IMAGE_TAG}"

# Registry to log into (e.g., "docker.io", "gcr.io", "public.ecr.aws")
REGISTRY="docker.io"

# Set to 'true' if you want to build from a Dockerfile in the current directory,
# or 'false' if you want to pull an existing image from the registry.
BUILD_IMAGE_FROM_DOCKERFILE="false"

# --- Script Start ---
echo "--- Starting Container Signing and SBOM Generation Process ---"

# 1. Docker Login
echo ""
echo "--- Performing Docker Login for Registry: ${REGISTRY} ---"
if docker login "${REGISTRY}"; then
  echo "Docker login successful for ${REGISTRY}."
else
  echo "Error: Docker login failed for ${REGISTRY}. Please check your credentials. Exiting."
  exit 1
fi

# 2. Prepare the Docker Image (Pull or Build & Push)
echo ""
echo "--- Preparing Docker Image: ${FULL_IMAGE_NAME} ---"

# Fix: Corrected conditional syntax. Spaces are crucial around '=' in bash `[ ]`.
if [ "${BUILD_IMAGE_FROM_DOCKERFILE}" = "true" ]; then
  echo "Building image from Dockerfile and pushing to registry..."
  if [ ! -f "Dockerfile" ]; then # Fix: Space after `[`
    echo "Error: Dockerfile not found in the current directory. Cannot build image. Exiting."
    exit 1
  fi
  if docker build -t "${FULL_IMAGE_NAME}" . && docker push "${FULL_IMAGE_NAME}"; then
    echo "Docker image built and pushed successfully: ${FULL_IMAGE_NAME}"
  else
    echo "Error: Failed to build or push the image. Exiting."
    exit 1
  fi
else
  echo "Pulling existing image from registry..."
  if docker pull "${FULL_IMAGE_NAME}" ; then
    echo "Docker image pulled successfully: ${FULL_IMAGE_NAME}"
  else
    echo "Error: Failed to pull the image. Please check the image name/tag and registry access. Exiting."
    exit 1
  fi
fi

# 3. Sign the Docker Image with Cosign (Keyless Signing)
echo ""
echo "--- Signing Docker Image with Cosign (Keyless) ---"
echo "You will be redirected to your browser to authenticate with your OIDC provider (e.g., Google, GitHub)."

if cosign sign --yes "${FULL_IMAGE_NAME}" ; then
  echo "Image signed successfully with Cosign."
else
  echo "Error: Failed to sign the image with Cosign. Exiting."
  exit 1
fi

# 4. Generate SBOM Locally and then Attest it to the Image
echo ""
echo "--- Generating SBOM for Image using 'docker scout' and Attesting it ---"

SBOM_OUTPUT_FILE="${FULL_IMAGE_NAME//[:\/]/_}_sbom.spdx.json"

if docker scout sbom "${FULL_IMAGE_NAME}" --output "${SBOM_OUTPUT_FILE}" ; then
  echo "SBOM generated to local file: ${SBOM_OUTPUT_FILE}"
  echo "You can inspect the SBOM file locally using: cat ${SBOM_OUTPUT_FILE}"

  echo ""
  echo "--- Attesting (Signing and Associating) the SBOM File with the Image ---"
  echo "You will be redirected to your browser to authenticate with your OIDC provider again (for the attestation)."
  if cosign attest --predicate "${SBOM_OUTPUT_FILE}" --yes "${FULL_IMAGE_NAME}" ; then
      echo "SBOM file successfully attested (signed) and associated with image ${FULL_IMAGE_NAME}."
      echo "You can verify this SBOM attestation using: cosign verify-attestation ${FULL_IMAGE_NAME}"
  else
      echo "Warning: Failed to attest (sign) the SBOM file. The SBOM file still exists locally, but it's not signed and associated in the registry."
  fi
else
  echo "Error: Failed to generate SBOM using docker scout. Please check 'docker scout' installation and connectivity. Exiting."
  exit 1
fi


echo ""
echo "--- Process Completed ---"
