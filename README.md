# SSD Scanner CLI

A comprehensive security scanning CLI tool that integrates multiple security scanners to analyze source code, container images, and artifacts for vulnerabilities, secrets, licenses, and security best practices.

## Table of Contents

- [What is SSD Scanner CLI?](#what-is-ssd-scanner-cli)
- [Installation](#installation)
  - [Binary Installation](#binary-installation)
  - [Docker Installation](#docker-installation)
- [Quick Start](#quick-start)
- [Use Cases & Examples](#use-cases--examples)
  - [1. Source Code Scanning](#1-source-code-scanning)
  - [2. Container Image & Artifact Scanning](#2-container-image--artifact-scanning)
  - [3. Helm Chart Scanning](#3-helm-chart-scanning)
  - [4. SBOM Generation](#4-sbom-generation)
  - [5. Differential Scanning (PR/CI Use Case)](#5-differential-scanning-prci-use-case)
- [Scanner-Specific Options](#scanner-specific-options)
- [Authentication Options](#authentication-options)
  - [Git Repository Authentication](#git-repository-authentication)
  - [Container Registry Authentication](#container-registry-authentication)
- [Advanced Configuration](#advanced-configuration)
- [Common Scanner Combinations](#common-scanner-combinations)
- [CI/CD Integration Examples](#cicd-integration-examples)
- [Troubleshooting](#troubleshooting)
- [Dependencies Installation](#dependencies-installation)

## What is SSD Scanner CLI?

SSD Scanner CLI is a unified security scanning platform that combines the power of industry-leading security tools:

- **Vulnerability Scanning** - Trivy, Grype, Snyk
- **SAST (Static Analysis)** - Semgrep, Opengrep, Codacy  
- **Security Scorecards** - OpenSSF Scorecard
- **SBOM Generation** - Syft, Trivy, Grype
- **Kubernetes Security** - Kubescape, Trivy
- **Secret Detection** - Trivy, Semgrep
- **License Compliance** - Trivy


## Installation

### Binary Installation

Download the latest release for your architecture:

<details>
<summary><strong>Linux AMD64</strong></summary>

```bash
curl -L -o ssd-scanner-cli https://github.com/OpsMx/ssd-scanner-cli-public/releases/download/v2025.07.12/ssd-scanner-cli-amd64
chmod +x ssd-scanner-cli
sudo mv ssd-scanner-cli /usr/local/bin/
```

</details>

<details>
<summary><strong>Linux ARM64</strong></summary>

```bash
curl -L -o ssd-scanner-cli https://github.com/OpsMx/ssd-scanner-cli-public/releases/download/v2025.07.12/ssd-scanner-cli-arm64
chmod +x ssd-scanner-cli
sudo mv ssd-scanner-cli /usr/local/bin/
```

</details>

### Docker Installation

<details>
<summary><strong>Pull Docker Image</strong></summary>

```bash
# Pull the latest image
docker pull opsmx11/ssd-scanner-cli:v2025.07.12
```

</details>

## Quick Start

<details>
<summary><strong>Scan Local Source Code (Offline)</strong></summary>

```bash
ssd-scanner-cli \
  --scanners=trivy,semgrep \
  --source-code-path=./my-project \
  --repository-url=https://github.com/user/my-app \
  --branch=main \
  --build-id=local-scan \
  --trivy-scanners=codelicensescan,codesecretscan \
  --offline-mode
```

</details>

<details>
<summary><strong>Scan Container Image</strong></summary>

```bash
ssd-scanner-cli \
  --scanners=trivy,grype \
  --artifact-type=image \
  --artifact-name=nginx \
  --artifact-tag=latest \
  --trivy-scanners=imagelicensescan,imagesecretscan,sbom \
  --grype-scanners=sbom \
  --offline-mode
```

</details>

<details>
<summary><strong>Docker Scan with Mounted Source Code</strong></summary>

```bash
docker run -v $(pwd):/home/scanner/source opsmx11/ssd-scanner-cli:v2025.07.12 \
  --scanners=semgrep,trivy \
  --source-code-path=/home/scanner/source \
  --repository-url=https://github.com/user/my-app \
  --branch=main \
  --build-id=docker-scan \
  --trivy-scanners=codelicensescan,codesecretscan \
  --offline-mode
```

</details>

## Use Cases & Examples

### 1. Source Code Scanning

Analyze your source code for security vulnerabilities, secrets, license compliance, and code quality issues using static analysis tools.

#### Local Source Code Scanning

<details>
<summary><strong>Binary Command</strong></summary>

```bash
ssd-scanner-cli \
  --scanners=semgrep,trivy,openssf \
  --source-code-path=./my-application \
  --repository-url=https://github.com/user/my-app \
  --branch=main \
  --build-id=local-123 \
  --trivy-scanners=codelicensescan,codesecretscan \
  --offline-mode
```

</details>

<details>
<summary><strong>Docker Command</strong></summary>

```bash
docker run -v $(pwd):/home/scanner/source opsmx11/ssd-scanner-cli:v2025.07.12 \
  --scanners=semgrep,trivy,openssf \
  --source-code-path=/home/scanner/source \
  --repository-url=https://github.com/user/my-app \
  --branch=main \
  --build-id=docker-123 \
  --trivy-scanners=codelicensescan,codesecretscan \
  --offline-mode
```

</details>

#### Remote Git Repository Scanning

Clone and scan remote repositories without having the code locally. Perfect for CI/CD pipelines.

<details>
<summary><strong>With Token Authentication</strong></summary>

```bash
ssd-scanner-cli \
  --scanners=semgrep,codacy,snyk \
  --repository-url=https://github.com/user/private-repo \
  --branch=develop \
  --build-id=remote-456 \
  --git-auth-type=token \
  --git-auth-key=ghp_your_token_here \
  --codacy-api-token=your_codacy_token \
  --snyk-api-token=your_snyk_token \
  --upload-url=https://your-ssd-instance.com \
  --ssd-token=your_ssd_token
```

</details>

<details>
<summary><strong>With Username/Password</strong></summary>

```bash
ssd-scanner-cli \
  --scanners=semgrep,opengrep \
  --repository-url=https://github.com/user/private-repo \
  --branch=main \
  --build-id=auth-789 \
  --git-auth-type=password \
  --git-username=your_username \
  --git-password=your_password \
  --offline-mode
```

</details>

### 2. Container Image & Artifact Scanning

Scan container images and local artifacts for vulnerabilities, malware, and security issues. Use `--artifact-type=image` for container images from registries, or `--artifact-type=file` for local files and artifacts.

#### Local Container Image Scanning

Scan container images that are available locally or in accessible registries.

<details>
<summary><strong>Binary Command</strong></summary>

```bash
ssd-scanner-cli \
  --scanners=trivy,grype,syft \
  --artifact-type=image \
  --artifact-name=python \
  --artifact-tag=3.9-slim \
  --trivy-scanners=imagelicensescan,imagesecretscan,sbom \
  --grype-scanners=sbom \
  --syft-scanners=sbom \
  --offline-mode
```

</details>

<details>
<summary><strong>Docker Command</strong></summary>

```bash
docker run -v /var/run/docker.sock:/var/run/docker.sock opsmx11/ssd-scanner-cli:v2025.07.12 \
  --scanners=trivy,grype \
  --artifact-type=image \
  --artifact-name=nginx \
  --artifact-tag=latest \
  --trivy-scanners=sbom,imagelicensescan \
  --grype-scanners=sbom \
  --offline-mode
```

</details>

#### Remote Registry Image Scanning

Pull and scan images from remote container registries with authentication.

<details>
<summary><strong>With Registry Authentication</strong></summary>

```bash
ssd-scanner-cli \
  --scanners=trivy,syft \
  --artifact-type=image \
  --artifact-name=my-app \
  --artifact-tag=v1.2.3 \
  --image-registry=registry.hub.docker.com \
  --registry-username=user \
  --registry-password=pass \
  --trivy-scanners=sbom,imagelicensescan \
  --syft-scanners=sbom \
  --upload-url=https://your-ssd-instance.com \
  --ssd-token=your_ssd_token
```

</details>

#### Local File/Artifact Scanning

Scan local files, binaries, archives, or any artifacts stored on the filesystem.

<details>
<summary><strong>Binary Command</strong></summary>

```bash
ssd-scanner-cli \
  --scanners=trivy,syft \
  --artifact-type=file \
  --artifact-name=my-binary \
  --artifact-tag=v1.0.0 \
  --artifact-path=./dist/my-binary.tar.gz \
  --trivy-scanners=sbom \
  --syft-scanners=sbom \
  --offline-mode
```

</details>

<details>
<summary><strong>Docker Command (with file mount)</strong></summary>

```bash
docker run -v $(pwd):/home/scanner/source opsmx11/ssd-scanner-cli:v2025.07.12 \
  --scanners=semgrep,openssf,trivy,syft \
  --artifact-type=file \
  --artifact-name=supply-chain \
  --artifact-tag=v2 \
  --artifact-path=/home/scanner/source \
  --syft-scanners=sourcecodesbom \
  --trivy-scanners=codelicensescan \
  --source-code-path=/home/scanner/source \
  --repository-url=https://github.com/OpsMx/supplychain-api \
  --branch=main \
  --build-id=test-131 \
  --offline-mode
```

</details>

### 3. Helm Chart Scanning

Analyze Helm charts for security misconfigurations, vulnerabilities, and compliance issues using Kubernetes security scanners.

#### Local Helm Template Scanning

<details>
<summary><strong>Command Example</strong></summary>

```bash
ssd-scanner-cli \
  --scanners=trivy,kubescape \
  --helm-template-path=./helm-charts/my-app \
  --helm-release-name=my-app \
  --helm-release-version=1.0.0 \
  --trivy-scanners=helmscan \
  --offline-mode
```

</details>

#### Packaged Helm Chart Scanning

<details>
<summary><strong>Command Example</strong></summary>

```bash
ssd-scanner-cli \
  --scanners=kubescape \
  --helm-package-path=./my-app-1.0.0.tgz \
  --helm-release-name=my-app \
  --helm-release-version=1.0.0 \
  --offline-mode
```

</details>

### 4. SBOM Generation

Generate Software Bill of Materials (SBOM) for container images and source code to track dependencies and supply chain security.

#### Generate SBOM for Container Image

<details>
<summary><strong>Command Example</strong></summary>

```bash
ssd-scanner-cli \
  --scanners=syft,grype,trivy \
  --artifact-type=image \
  --artifact-name=alpine \
  --artifact-tag=latest \
  --syft-scanners=sbom \
  --grype-scanners=sbom \
  --trivy-scanners=sbom \
  --offline-mode
```

</details>

#### Generate SBOM for Source Code

<details>
<summary><strong>Command Example</strong></summary>

```bash
ssd-scanner-cli \
  --scanners=syft,trivy \
  --source-code-path=./my-project \
  --artifact-type=file \
  --artifact-name=my-project \
  --artifact-tag=main \
  --artifact-path=./my-project \
  --syft-scanners=sourcecodesbom \
  --trivy-scanners=sourcecodesbom \
  --repository-url=https://github.com/user/my-project \
  --branch=main \
  --build-id=sbom-gen \
  --offline-mode
```

</details>

### 5. Differential Scanning (PR/CI Use Case)

Compare security findings between branches to identify new issues introduced in pull requests. This helps maintain security standards by catching issues before they reach production.

#### Basic Differential Scan

<details>
<summary><strong>Command Example</strong></summary>

```bash
ssd-scanner-cli \
  --scanners=semgrep,trivy \
  --source-code-path=./my-project \
  --repository-url=https://github.com/user/my-project \
  --branch=feature-branch \
  --build-id=pr-123 \
  --diff-scan=true \
  --base-branch=main \
  --base-commit=abc123def \
  --head-commit=xyz789uvw \
  --interrupt-condition=critical,high \
  --trivy-scanners=codelicensescan,codesecretscan \
  --upload-url=https://your-ssd-instance.com \
  --ssd-token=your_ssd_token
```

</details>

#### Advanced Differential Scan with Interruption

<details>
<summary><strong>Command Example</strong></summary>

```bash
ssd-scanner-cli \
  --scanners=semgrep,trivy,snyk \
  --repository-url=https://github.com/user/my-project \
  --branch=feature-branch \
  --build-id=pr-456 \
  --diff-scan=true \
  --base-branch=main \
  --base-commit=abc123def \
  --head-commit=xyz789uvw \
  --interrupt-condition=all \
  --interrupt-for-old-issues=true \
  --git-auth-type=token \
  --git-auth-key=your_token \
  --snyk-api-token=your_snyk_token \
  --trivy-scanners=codelicensescan,codesecretscan \
  --upload-url=https://your-ssd-instance.com \
  --ssd-token=your_ssd_token
```

</details>

## Scanner-Specific Options

### Available Scanners

| Scanner | Purpose | Special Flags |
|---------|---------|---------------|
| `trivy` | Vulnerability, License, Secret scanning | `--trivy-scanners` |
| `semgrep` | Static Analysis Security Testing (SAST) | - |
| `opengrep` | Open-source SAST | - |
| `grype` | Vulnerability scanning | `--grype-scanners` |
| `syft` | SBOM generation | `--syft-scanners` |
| `snyk` | Vulnerability and license scanning | `--snyk-api-token` |
| `codacy` | Code quality and security | `--codacy-api-token` |
| `openssf` | Security scorecards | - |
| `kubescape` | Kubernetes security | - |

### Trivy Scanner Options

<details>
<summary><strong>Available Modes</strong></summary>

```bash
--trivy-scanners=codelicensescan,codesecretscan,imagelicensescan,imagesecretscan,sbom,sourcecodesbom,helmscan
```

**Available modes:**
- `codelicensescan` - License scanning for source code
- `codesecretscan` - Secret detection in source code  
- `imagelicensescan` - License scanning for container images
- `imagesecretscan` - Secret detection in container images
- `sbom` - Generate SBOM for images
- `sourcecodesbom` - Generate SBOM for source code
- `helmscan` - Security scanning for Helm charts

</details>

### Grype Scanner Options

<details>
<summary><strong>Available Modes</strong></summary>

```bash
--grype-scanners=sbom,sourcecodesbom
```

</details>

### Syft Scanner Options

<details>
<summary><strong>Available Modes</strong></summary>

```bash
--syft-scanners=sbom,sourcecodesbom
```

</details>

## Authentication Options

### Git Repository Authentication

#### Token-based Authentication (Recommended)

<details>
<summary><strong>Command Example</strong></summary>

```bash
--git-auth-type=token \
--git-auth-key=ghp_your_github_token
```

</details>

#### Username/Password Authentication

<details>
<summary><strong>Command Example</strong></summary>

```bash
--git-auth-type=password \
--git-username=your_username \
--git-password=your_password
```

</details>

### Container Registry Authentication

#### Token-based Registry Authentication

<details>
<summary><strong>Command Example</strong></summary>

```bash
--image-registry=registry.hub.docker.com \
--registry-token=your_registry_token
```

</details>

#### Username/Password Registry Authentication

<details>
<summary><strong>Command Example</strong></summary>

```bash
--image-registry=registry.hub.docker.com \
--registry-username=your_username \
--registry-password=your_password
```

</details>

**Supported Registries:**
- Docker Hub

*More registry support coming soon*

## Advanced Configuration

### Artifact Types

**`--artifact-type=image`**: For container images stored in registries (Docker Hub, etc.). No `--artifact-path` required.

**`--artifact-type=file`**: For local files, binaries, archives, or any filesystem artifacts. **Requires `--artifact-path`** to specify the local file location.

### Offline Mode

<details>
<summary><strong>Usage</strong></summary>

Run scans without uploading results:

```bash
--offline-mode=true
```

</details>

### Debug Mode

<details>
<summary><strong>Usage</strong></summary>

Enable detailed logging:

```bash
--debug=true
```

</details>

### Custom Scanner Binary Path

<details>
<summary><strong>Usage</strong></summary>

```bash
--scanners-path=/custom/path/to/scanners
```

</details>

### Keep Results Locally

<details>
<summary><strong>Usage</strong></summary>

```bash
--keep-results=true
```

</details>

## Common Scanner Combinations

### Comprehensive Security Scan

<details>
<summary><strong>Command Example</strong></summary>

```bash
--scanners=semgrep,trivy,openssf,snyk \
--trivy-scanners=codelicensescan,codesecretscan
```

</details>

### SBOM + Vulnerability Analysis

<details>
<summary><strong>Command Example</strong></summary>

```bash
--scanners=syft,grype,trivy \
--syft-scanners=sbom \
--grype-scanners=sbom \
--trivy-scanners=sbom
```

</details>

### Code Quality + Security

<details>
<summary><strong>Command Example</strong></summary>

```bash
--scanners=semgrep,codacy,opengrep
```

</details>

### Container Security Focus

<details>
<summary><strong>Command Example</strong></summary>

```bash
--scanners=trivy,grype \
--trivy-scanners=imagelicensescan,imagesecretscan,sbom \
--grype-scanners=sbom
```

</details>

## CI/CD Integration Examples

### GitHub Actions

<details>
<summary><strong>Complete Workflow Example</strong></summary>

Create `.github/workflows/security-scan.yml`:

```yaml
name: Security Scan

on:
  pull_request:
    branches: [ main, develop ]
  push:
    branches: [ main ]

jobs:
  security-scan:
    runs-on: ubuntu-latest
    
    steps:
    - name: Checkout code
      uses: actions/checkout@v3
      with:
        fetch-depth: 0  # Needed for diff scanning
    
    - name: Run SSD Scanner CLI
      run: |
        curl -L -o ssd-scanner-cli https://github.com/OpsMx/ssd-scanner-cli-public/releases/download/v2025.07.12/ssd-scanner-cli-amd64
        chmod +x ssd-scanner-cli
        
        ./ssd-scanner-cli \
          --scanners=semgrep,trivy,openssf \
          --source-code-path=. \
          --repository-url=${{ github.server_url }}/${{ github.repository }} \
          --branch=${{ github.ref_name }} \
          --build-id=${{ github.run_number }} \
          --trivy-scanners=codelicensescan,codesecretscan \
          --upload-url=${{ secrets.SSD_UPLOAD_URL }} \
          --ssd-token=${{ secrets.SSD_TOKEN }}

  differential-scan:
    runs-on: ubuntu-latest
    if: github.event_name == 'pull_request'
    
    steps:
    - name: Checkout code
      uses: actions/checkout@v3
      with:
        fetch-depth: 0
    
    - name: Run Differential Scan
      run: |
        curl -L -o ssd-scanner-cli https://github.com/OpsMx/ssd-scanner-cli-public/releases/download/v2025.07.12/ssd-scanner-cli-amd64
        chmod +x ssd-scanner-cli
        
        ./ssd-scanner-cli \
          --scanners=semgrep,trivy \
          --source-code-path=. \
          --repository-url=${{ github.server_url }}/${{ github.repository }} \
          --branch=${{ github.head_ref }} \
          --build-id=pr-${{ github.event.number }} \
          --diff-scan=true \
          --base-branch=${{ github.base_ref }} \
          --base-commit=${{ github.event.pull_request.base.sha }} \
          --head-commit=${{ github.event.pull_request.head.sha }} \
          --interrupt-condition=critical,high \
          --git-auth-type=token \
          --git-auth-key=${{ secrets.GITHUB_TOKEN }} \
          --trivy-scanners=codelicensescan,codesecretscan \
          --upload-url=${{ secrets.SSD_UPLOAD_URL }} \
          --ssd-token=${{ secrets.SSD_TOKEN }}

  container-scan:
    runs-on: ubuntu-latest
    
    steps:
    - name: Build Docker image
      run: |
        docker build -t my-app:${{ github.sha }} .
    
    - name: Scan Container Image
      run: |
        docker run -v /var/run/docker.sock:/var/run/docker.sock \
          opsmx11/ssd-scanner-cli:v2025.07.12 \
          --scanners=trivy,grype \
          --artifact-type=image \
          --artifact-name=my-app \
          --artifact-tag=${{ github.sha }} \
          --trivy-scanners=imagelicensescan,imagesecretscan,sbom \
          --grype-scanners=sbom \
          --upload-url=${{ secrets.SSD_UPLOAD_URL }} \
          --ssd-token=${{ secrets.SSD_TOKEN }}
```

</details>

## Troubleshooting

### Common Issues

<details>
<summary><strong>Permission denied when running binary</strong></summary>

```bash
chmod +x ssd-scanner-cli
```

</details>

<details>
<summary><strong>Docker socket permission issues</strong></summary>

```bash
# Add your user to docker group
sudo usermod -aG docker $USER
# Or run with sudo
sudo docker run...
```

</details>

<details>
<summary><strong>Git authentication failures</strong></summary>

- Ensure your token has appropriate repository permissions
- For private repositories, use a token with `repo` scope
- Check that the repository URL is correct

</details>

<details>
<summary><strong>Scanner-specific failures</strong></summary>

- Ensure API tokens are valid for Snyk and Codacy
- Check that the source code path exists and is readable
- Verify artifact paths and names are correct

</details>

<details>
<summary><strong>Memory issues with large repositories</strong></summary>

- Use `--sub-directory` to scan specific parts
- Consider running scanners individually rather than all at once

</details>

### Getting Help

- Check scanner logs with `--debug=true`
- Verify all required flags are provided
- Ensure you have sufficient disk space for scan results
- For upload issues, verify your SSD instance URL and token

## Dependencies Installation

<details>
<summary><strong>Install Scanner Dependencies</strong></summary>

```bash
ssd-scanner-cli install-deps --scanners=trivy,semgrep,opengrep,kubescape
```

</details>

---

**Version**: v2025.07.12  
**Support**: For issues and questions, please create an issue in the GitHub repository.
