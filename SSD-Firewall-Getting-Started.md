# Getting Started with SSD Firewall CLI

A quick guide to evaluating security scan results against OPA policies.

---

## Available Policy Bundles

| Scan Type | Description | Supported Scanners |
|-----------|-------------|-------------------|
| `vulnerability` | Detect CVEs by severity | Trivy, Grype, Syft |
| `secret-scan` | Detect exposed secrets | Trivy |
| `license-scan` | Check software licenses | Trivy, Syft |
| `sast-scan` | Static code analysis | Semgrep, OpenGrep |
| `pod-security` | Kubernetes security checks | Kubescape, kube-bench |
| `artifact-integrity` | Verify artifact signatures |  |
| `security-scorecard` | OpenSSF Scorecard checks | OSSF Scorecard |

---

## Installation

```bash
# Quick install (Linux amd64/arm64)
curl -sSL https://raw.githubusercontent.com/OpsMx/ssd-scanner-cli-public/main/install-firewall.sh | bash

# Verify installation
ssd-firewall-cli version
```

---

## Quick Start: Evaluate a Scan File

```bash
# Evaluate against policies
ssd-firewall-cli evaluate \
  --scan-type vulnerability \
  --scan-file trivy-scan.json
```

> **Note:** The **scanner type is auto-detected** from the scan file format (Trivy, Grype, Semgrep, etc.). You don't need to specify `--scanner` unless auto-detection fails.

Output shows pass/fail for each policy.

---

## Folder Scanning

Evaluate multiple scan files at once:

```bash
# Scan all JSON/YAML files in a folder
ssd-firewall-cli evaluate --scan-folder ./scan-results/

# Filter to specific scan type
ssd-firewall-cli evaluate --scan-folder ./scan-results/ --scan-type vulnerability

# Continue on errors (don't stop if one file fails)
ssd-firewall-cli evaluate --scan-folder ./scan-results/ --continue-on-error
```

> **Note:** In folder mode, both **scanner and scan type are auto-detected** for each file. Use `--scan-type` only if you want to filter and process specific scan types.

---

## Explore Available Policies

List policies in any bundle:

```bash
# List vulnerability policies
ssd-firewall-cli list bundle-policies --scan-type vulnerability

# List secret scan policies
ssd-firewall-cli list bundle-policies --scan-type secret-scan

# JSON output
ssd-firewall-cli list bundle-policies --scan-type secret-scan --format json
```

Example output:
```
=== Policies in secret-scan Bundle ===

ID     Policy Name                                        ScriptID Status
-------------------------------------------------------------------------------------
274    High severity secret detection in code reposi...   274      active
275    Critical severity secret detection in code re...   275      active
276    Medium severity secret detection in code repo...   276      active
...

Total: 8 policies
```

---

## Configure Policy Filters

Control which policies are evaluated using a config file.

### Create `policy-filter.yaml`

**Include mode** - Only run specific policies:
```yaml
version: "1.0"
mode: "include"
filters:
  secret-scan:
    policies:
      - id: 274
      - id: 275
  vulnerability:
    policies:
      - name: "Critical Vulnerability Prevention Policy"
      - name: "High Vulnerability Prevention Policy"
```

**Exclude mode** - Run all except specific policies:
```yaml
version: "1.0"
mode: "exclude"
filters:
  secret-scan:
    policies:
      - id: 277  # Skip low severity
```

### Use the filter

```bash
# Evaluate with filter
ssd-firewall-cli evaluate \
  --scan-type secret-scan \
  --scan-file scan.json \
  --policy-config policy-filter.yaml

# Preview what gets filtered
ssd-firewall-cli list bundle-policies \
  --scan-type secret-scan \
  --policy-config policy-filter.yaml \
  --show-filtered
```

---

## Output Formats

```bash
# Console output (default)
ssd-firewall-cli evaluate --scan-type vulnerability --scan-file scan.json

# JSON output
ssd-firewall-cli evaluate --scan-type vulnerability --scan-file scan.json --output json

# SSD format (for integration)
ssd-firewall-cli evaluate --scan-type vulnerability --scan-file scan.json --output ssd
```

---

## Exit Codes

| Code | Meaning |
|------|---------|
| 0 | All policies passed |
| 1 | One or more policy violations |
| 2 | Processing errors (with `--continue-on-error`) |

---

## Next Steps

- See `ssd-firewall-cli --help` for all commands
- Check `config/policy-filter.example.yaml` for filter config examples
- Use `list bundle-policies` to discover policy IDs for your filters
