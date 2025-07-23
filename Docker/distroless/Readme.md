# Scratch vs. Distroless: Understanding Minimal Docker Images

When building Docker images, choosing the right base image is crucial for security, size, and efficiency. This guide explores two ultra-minimal base images: `scratch` and `distroless`, highlighting their differences, use cases, and best practices for implementation.

---

## 1. Introduction to Minimal Base Images

Traditional base images like `ubuntu`, `debian`, or `centos` are complete Linux distributions. While convenient, they often include a vast amount of software (shells, package managers, utilities) that your application doesn't need at runtime. This bloat increases image size and, more critically, expands the **attack surface** by introducing more potential vulnerabilities.

`scratch` and `distroless` images aim to solve this by providing only the bare essentials.

## 2. `scratch`: The Absolute Minimum

* **What it is**: `scratch` is Docker's **empty base image**. It's literally an empty tarball, containing no operating system, no shell, no libraries, and no file system structure beyond what you explicitly add.
* **Content**: Nothing.
* **Use Case**: Primarily for applications that are **statically compiled** and entirely self-contained, with no external runtime dependencies. The most common example is a Go language application that doesn't need system libraries for network operations (like SSL certificates).
* **Pros**:
    * **Smallest Image Size**: Achieves the absolute minimum possible container size.
    * **Minimal Attack Surface**: With no OS components, there are virtually no OS-level CVEs.
* **Cons**:
    * **Extremely Difficult to Debug**: No shell (`sh`, `bash`), no `ls`, `cat`, `ps`, `curl`, or any other diagnostic tools. Debugging relies solely on application logs.
    * **Limited Application Compatibility**: Only suitable for truly static binaries. Most applications (Java, Node.js, Python, dynamically linked C/C++) cannot run on `scratch` as they require shared system libraries.
    * **No HTTPS Support (out-of-the-box)**: Lacks `ca-certificates` for validating SSL/TLS connections.

## 3. `distroless`: Just Enough for Your App

* **What it is**: `distroless` images (coined by Google) contain **only your application and its essential runtime dependencies**. They are "distro-less" because they explicitly *exclude* package managers, shells, and other common OS utilities not required for your application's execution.
* **Content**: Varies by language/runtime. For example:
    * `gcr.io/distroless/java17`: Contains the OpenJDK 17 Java Runtime Environment (JRE).
    * `gcr.io/distroless/nodejs20`: Contains the Node.js 20 runtime.
    * `gcr.io/distroless/static`: Contains minimal system libraries like `glibc` and `ca-certificates`.
* **Use Case**: Ideal for applications written in languages like Java, Node.js, Python, and even Go (if they need minimal system libraries like SSL certificates or user/group definitions).
* **Pros**:
    * **Very Small Image Size**: Significantly smaller than traditional base images (e.g., `alpine`, `ubuntu`), leading to faster deployments and reduced storage.
    * **Greatly Reduced Attack Surface**: Eliminates common attack vectors by removing tools often exploited by attackers (e.g., `curl`, `wget`, `bash`, `apt`). Fewer packages mean fewer CVEs to manage.
    * **Improved Security Posture**: By default, containers are harder to explore and exploit post-compromise.
* **Cons**:
    * **Harder to Debug (than full distros)**: Similar to `scratch`, you cannot easily `exec` into a `distroless` container to run commands. Google provides `-debug` variants for troubleshooting.
    * **Missing Common Tools**: If your application's health checks or internal logic rely on external tools (e.g., `ping`, `curl`), you'll need to re-evaluate or explicitly include them (which slightly increases size/attack surface).

## 4. Why `distroless/static` is Preferred Over `scratch` for Most Go Apps (Especially with HTTPS)

While `scratch` offers the absolute smallest size, it's often too bare for practical production applications, especially those that need to make secure network connections.

* **The HTTPS Requirement**: For an application to make outbound HTTPS calls securely, it needs to validate the SSL/TLS certificates presented by the server. This validation relies on a **trust store** (a collection of trusted root Certificate Authorities).
* **`scratch`'s Deficiency**: `scratch` contains no operating system, no file system structure, and therefore **no `ca-certificates`**. Without these, your application cannot perform proper SSL/TLS certificate validation, leading to connection errors or critical security vulnerabilities if validation is bypassed.
* **`distroless/static`'s Solution**: `gcr.io/distroless/static` (and its Debian-based variants like `gcr.io/distroless/static-debian12`) is designed to address this. It provides the necessary `ca-certificates` and minimal `/etc/passwd` and `/etc/group` files, allowing your statically compiled Go application to:
    * Make secure HTTPS connections.
    * Run as a non-root user (a security best practice).

Therefore, for most real-world Go applications that interact with external services over HTTPS, `distroless/static` is the practical and secure choice, offering nearly the same minimal footprint as `scratch` but with essential runtime capabilities.

## 5. How to Create Minimal Images with Multi-Stage Builds

You cannot build your application directly within a `distroless` or `scratch` image because they lack compilers, build tools, and package managers. The solution is **Multi-Stage Builds** in your `Dockerfile`.

This technique uses multiple `FROM` instructions, where each `FROM` begins a new build stage. You perform your build steps in a "builder" stage (using a larger, feature-rich image) and then copy *only* the final compiled artifacts into a "runner" stage (using the minimal `distroless` or `scratch` image).

### General Multi-Stage Build Pattern

```dockerfile
# syntax=docker/dockerfile:1.4

# === BUILDER STAGE ===
FROM <full_featured_base_image> AS builder

# Install build dependencies (if any)
# Copy source code
# Compile/package your application into a deployable artifact

# === RUNNER STAGE ===
FROM <minimal_distroless_or_scratch_image>

# Copy only the compiled application artifact and its runtime dependencies
# from the 'builder' stage
COPY --from=builder /path/to/artifact /path/in/final/image

# Define the command to run your application
ENTRYPOINT ["/path/in/final/image/your-app"]
```

### Example 1: Go Application

Go applications are often statically compiled, making them excellent candidates.

```dockerfile
# syntax=docker/dockerfile:1.4

# === BUILDER STAGE ===
FROM golang:1.22-alpine AS builder

WORKDIR /app

# Copy Go module files and download dependencies
COPY go.mod go.sum ./
RUN go mod download

# Copy the rest of the application source code
COPY . .

# Build the Go application
# CGO_ENABLED=0: Ensures a static binary without external C dependencies.
# -o app: Names the output binary 'app'.
# -ldflags="-s -w": Reduces binary size by stripping debug info and symbol table.
RUN CGO_ENABLED=0 go build -o app -ldflags="-s -w" .

# === RUNNER STAGE ===
# Use distroless/static-debian12 for Go apps needing CA certificates or user/group info.
# For absolute minimal (no CAs), you could use FROM scratch, but it's rarely practical.
FROM gcr.io/distroless/static-debian12

# Copy the compiled binary from the builder stage to the root of the final image.
COPY --from=builder /app/app /app/app

# Define the entrypoint for the application.
ENTRYPOINT ["/app/app"]
```

### Example 2: Node.js Application

Node.js applications require the Node.js runtime.

```dockerfile
# syntax=docker/dockerfile:1.4

# === BUILDER STAGE ===
FROM node:20-alpine AS builder

WORKDIR /app

# Copy package.json and install production dependencies
COPY package.json package-lock.json ./
RUN npm ci --omit=dev --production

# Copy application source code
COPY . .

# === RUNNER STAGE ===
# Use distroless/nodejs for Node.js applications.
FROM gcr.io/distroless/nodejs20-debian12

# Set the working directory in the final image.
WORKDIR /app

# Copy only the production dependencies and application code from the builder stage.
COPY --from=builder /app/node_modules ./node_modules
COPY --from=builder /app ./

# Define the command to run your Node.js application.
CMD ["index.js"] # Or ["node", "index.js"] or "npm", "start" depending on your setup.
```


## 6. Debugging Distroless Images

The lack of a shell and common utilities in `distroless` images makes direct debugging challenging.

**Solution: Use `-debug` variants for troubleshooting.**
Google provides `distroless` images with a `-debug` suffix (e.g., `gcr.io/distroless/static-debian12-debug`, `gcr.io/distroless/java17-debian12-debug`). These debug images include `busybox`, which provides a minimal shell (`sh`) and common Linux utilities (`ls`, `cat`, `ps`, etc.).

**Crucial Warning**: **NEVER deploy `-debug` images to production.** They are larger and reintroduce the very tools you aimed to remove for security. Use them strictly for development and troubleshooting.

You can create a separate `Dockerfile.debug` or use conditional logic in your CI/CD to build a debug variant when needed.

## 7. Limitations and Considerations

* **No Shell Access by Default**: This is a security feature, but it requires a shift in your debugging approach. Rely more on robust application logging and external monitoring.
* **Missing Common Tools**: If your application or its health checks rely on external tools (e.g., `curl`, `ping`), you'll need to re-evaluate or explicitly add them (which slightly increases image size and attack surface).
* **C-Dependencies**: For languages like Python or Node.js, if your dependencies have native C bindings, ensure you're using the correct `distroless` base image that includes the necessary shared libraries.
* **User ID**: `distroless` images often run as a non-root user by default (e.g., UID/GID 65532). Ensure your application has the necessary permissions.
* **`ONBUILD` Instructions**: These are often ignored when using multi-stage builds and copying content directly, as the `ONBUILD` instructions are part of the intermediate builder image, not the final minimal image.

By embracing multi-stage builds and understanding the trade-offs, `distroless` images offer a powerful way to enhance the security and efficiency of your containerized applications.
"""
