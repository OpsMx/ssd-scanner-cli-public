# CDXGen Slim Image — Customer Guide

---

## 1. What it is, when to use it

The **slim image** is a CDXGen-focused variant of the SSD scanner. It ships only what cdxgen itself needs (Node, Python, sudo, build-base, libstdc++) and **bootstraps language toolchains on demand** (JDK, Gradle, Maven, .NET SDK, CMake, Ruby) into a host-mounted cache directory the first time you scan a project that requires them.

| Use the slim image when… | Use the fat image when… |
|---|---|
| You only need CDXGen SBOM scans | You also run trivy / grype / syft / snyk / semgrep / kubescape / docker-bench / etc. |
| You want a smaller image (~1 GB vs ~5 GB) | Image size is not a concern |
| You can mount a persistent toolchain cache | You need every scanner pre-baked, no first-scan download |

The slim image is **additive**: the fat image (`opsmx11/ssd-scanner-cli:<version>`) continues to exist and is unchanged. There is no deprecation timeline for the fat image.

---

## 2. Image tags

```
opsmx11/ssd-scanner-cli:<version>-slim    e.g. v0.6.0-slim
opsmx11/ssd-scanner-cli:slim              floating pointer to the latest stable -slim
```

`:slim` floats only on real release tags (`vX.Y.Z`). Pre-release / test tags only get the suffixed form.

The fat image keeps its existing tag scheme (`opsmx11/ssd-scanner-cli:<version>` and `opsmx11/ssd-scanner-cli:latest`). Pin to `<version>-slim` in production; use `:slim` only if you've validated rolling forward on minor bumps.

Current stable slim release:

| Tag | Digest / manifest |
|---|---|
| `opsmx11/ssd-scanner-cli:v0.6.0-slim` | amd64 image manifest `sha256:bb5156607cfbfe4b966376a97e1f4865ab85f080fec6ef13fad062b7f5db0cba` |
| `opsmx11/ssd-scanner-cli:slim` | image index `sha256:a6b8693d064e5295578e6f3b38eeeab67fe16390ad9d9a3537cd5fdd9757a72a`; amd64 image manifest `sha256:bb5156607cfbfe4b966376a97e1f4865ab85f080fec6ef13fad062b7f5db0cba` |

The additional `unknown/unknown` manifest in Docker Hub output is the BuildKit attestation manifest for the amd64 image, not a runtime platform.

---

## 3. Quick start

```bash
docker run --rm \
  -v /path/to/your/project:/home/scanner/source:rw \
  -v /var/cache/ssd-scanner/toolchains:/var/cache/ssd-scanner/toolchains:rw \
  opsmx11/ssd-scanner-cli:slim \
    --scanners=cdxgen \
    --cdxgen-scanners=sourcecodesbom \
    --source-code-path=/home/scanner/source \
    --repository-url=https://github.com/your-org/your-repo \
    --branch=main \
    --build-id=run-001 \
    --upload-url=https://your-ssd-tenant.example.com \
    --ssd-token=$SSD_TOKEN
```

For local-only (no upload), add `--offline-mode=true --keep-results=true` and either read the BOM from `/home/scanner/.local/bin/ssd-scan-results/` inside the container, or bind-mount that path to capture results on the host (see §4.3).

---

## 4. Required mounts — read this before your first run

### 4.1 Project / source mount must be **read-write** (`:rw`)

This is the single biggest deployment gotcha. **Do not mount the source as `:ro`.**

| Why? | What happens with `:ro` |
|---|---|
| Gradle writes to `<project>/.gradle/` (per-project file hashes, daemon state) | Gradle exits with `Cannot create directory` and the scan fails |
| Maven writes to `<project>/target/` while resolving | Maven fails before producing a BOM |
| npm/yarn writes to `<project>/node_modules/` and `<project>/.npm/` | cdxgen falls back to manifest-only mode and you lose the transitive graph |
| pip/poetry writes to `<project>/.venv/` or temporary build dirs | Component resolution becomes shallow |

These caches are written *inside* the project directory by the language tools cdxgen invokes — there is no upstream way to redirect them all to a separate volume. The project mount must be writable.

If the original source must be preserved untouched, copy it into a scratch dir and mount that:

```bash
cp -r /path/to/your/project /tmp/scan-copy
docker run --rm -v /tmp/scan-copy:/home/scanner/source:rw  ...
```

### 4.2 Toolchain cache mount

```
-v /var/cache/ssd-scanner/toolchains:/var/cache/ssd-scanner/toolchains:rw
```

Mount the cache directory directly — not its parent — so the path inside the container matches `SSD_TOOLCHAIN_CACHE` exactly (`/var/cache/ssd-scanner/toolchains`). Persist it between runs: on the first scan that needs Gradle/Maven/.NET/CMake/Node-musl/JDK, the bootstrap downloads them into this cache; subsequent scans reuse them.

### 4.3 Optional: scan-results mount

```
-v /var/log/ssd-scanner:/home/scanner/.local/bin/ssd-scan-results:rw
```

Only needed when running `--offline-mode=true --keep-results=true` to inspect BOMs on the host. The CLI writes results under `/home/scanner/.local/bin/ssd-scan-results/scan-<timestamp>/<scanner>/...` inside the container — the mount above captures that tree on the host at `/var/log/ssd-scanner/`.

---

## 5. Toolchain cache behaviour

The numbers below are **toolchain bootstrap overhead only** — the cost of getting a JDK / Gradle / .NET SDK / etc. onto the scanner host before cdxgen runs. They are **not** total scan time. Total scan time is usually dominated by *dependency resolution* (Gradle pulling JARs from Maven Central, npm walking `node_modules`, dotnet restoring NuGet packages); that cost is the same in every image and is governed by your project size and registry mirror, not by the bootstrap.

| | Cold (first scan) | Warm (subsequent) |
|---|---|---|
| Bootstrap behaviour | Fetches JDK, Gradle/Maven, .NET SDK, Node, glibc CMake (or `apk add` for Ruby/Alpine CMake) | Cache hit, skips download |
| Typical bootstrap overhead | 30 s – 2 min, depending on languages detected | < 1 s for tarball toolchains; ~5–10 s when `apk add` re-runs in a fresh container (Ruby every time, CMake on Alpine every time — apk-installed binaries live in `/usr/bin/`, which is part of the container's ephemeral layer, not the mounted cache volume) |
| Network required by bootstrap | Yes — see [firewall allowlist](cdxgen-firewall-allowlist.md) Category A | No |
| Network required by cdxgen + language tools | Yes (Category B — every scan) | Yes (Category B — every scan) |

### Cache ownership

The slim image runs as **UID 1000** (`scanner` user). The mounted cache directory must be writable by that UID:

```bash
sudo mkdir -p /var/cache/ssd-scanner/toolchains
sudo chown -R 1000:1000 /var/cache/ssd-scanner/toolchains
sudo chmod 0755 /var/cache/ssd-scanner/toolchains
```

If cache mount fails the writability probe, the bootstrap exits early with a clear error. Common cause: SELinux on RHEL-family hosts. Add `:Z` to the mount (`-v /var/cache/ssd-scanner/toolchains:/var/cache/ssd-scanner/toolchains:rw,Z`) to relabel.

### Choosing the cache path

The default is `/var/cache/ssd-scanner/toolchains`. To override, set `SSD_TOOLCHAIN_CACHE` or pass `--toolchain-cache-dir=...`. Precedence: flag → config file → env var → default.

### Cache is target-platform-specific

A cache populated by an Ubuntu host is **not** interchangeable with one populated on Alpine — see §6.4 for the bundle constraint.

---

## 6. `prepare-toolchains` — pre-staging the cache

Use this when the scanner host cannot reach toolchain download domains directly (air-gapped CI, locked-down runners) but has another connected host that can.

### 6.1 Warm a cache on the same host

```bash
docker run --rm \
  -v /var/cache/ssd-scanner/toolchains:/var/cache/ssd-scanner/toolchains:rw \
  opsmx11/ssd-scanner-cli:slim \
    prepare-toolchains \
    --languages=kotlin,java,nodejs,dotnet,cpp \
    --toolchain-cache-dir=/var/cache/ssd-scanner/toolchains
```

### 6.2 Build a portable bundle and ship it air-gapped

**On a connected host that matches your scanner target's OS family:**

```bash
docker run --rm \
  -v $PWD:/out:rw \
  -v /var/cache/ssd-scanner/toolchains:/var/cache/ssd-scanner/toolchains:rw \
  opsmx11/ssd-scanner-cli:slim \
    prepare-toolchains \
    --languages=kotlin,java,nodejs,dotnet \
    --toolchain-cache-dir=/var/cache/ssd-scanner/toolchains \
    --output-tar=/out/ssd-toolchains.tgz
```

**On the air-gapped scanner host, extract before scanning:**

```bash
sudo mkdir -p /var/cache/ssd-scanner/toolchains
sudo tar -xzf ssd-toolchains.tgz -C /var/cache/ssd-scanner/toolchains
sudo chown -R 1000:1000 /var/cache/ssd-scanner/toolchains
```

### 6.3 Languages **not** bundleable via `--output-tar`

| Language | Status | Why |
|---|---|---|
| `python` | Not a target | The slim image's system `python3` + `pip` already cover Python cdxgen support; nothing to cache |
| `ruby` | Rejected on every host | Ruby has no upstream redistributable Linux binary; the bootstrap always uses `apk add ruby ruby-bundler`. The cache only holds an `apk-installed` marker |
| `cpp` on Alpine | Rejected on Alpine | CMake on Alpine uses `apk add cmake` (Kitware ships no musl-linked binary). Same marker-only situation as Ruby |
| `cpp` on glibc Linux | **Allowed** | The Kitware tarball IS unpacked into the cache and IS bundleable. The resulting bundle works only on glibc Linux targets, not Alpine |

For the rejected combinations, ship a target-side workaround instead of a bundle:

- **Ruby:** allow `dl-cdn.alpinelinux.org` (or your internal Alpine mirror) on the scanner host so `apk add ruby ruby-bundler` runs locally.
- **Cpp on Alpine:** same — allow Alpine's apk mirror so `apk add cmake` runs locally.

Running `prepare-toolchains --output-tar` with a rejected combination exits non-zero with an actionable error — there is no silent failure.

### 6.4 Bundles are target-platform-specific

The cache encodes the platform discriminator in directory names:

```
Ubuntu (glibc, x64):
  temurin-jdk/jdk-21.0.5+11-linux-x64/
  nodejs/22.11.0-linux-x64/
  dotnet-sdk/8.0.404-linux-x64/

Alpine (musl, x64):
  temurin-jdk/jdk-21.0.5+11-alpine-linux-x64/
  nodejs/22.11.0-linux-x64-musl/
  dotnet-sdk/8.0.404-linux-musl-x64/
```

A bundle produced on Ubuntu **will not be recognised** on an Alpine target, and vice versa. Run `prepare-toolchains` on the same OS family as the scanner deployment target — or, recommended, run it inside the slim image itself so platform always matches.

---

## 7. Firewall allowlist

The full reference (with per-customer templates and verification probes) is in [`cdxgen-firewall-allowlist.md`](cdxgen-firewall-allowlist.md). Quick orientation:

### Two categories of outbound HTTPS

| Category | Domains | Frequency | If blocked |
|---|---|---|---|
| **A. Toolchain bootstrap** | `api.adoptium.net`, `services.gradle.org`, `archive.apache.org`, `builds.dotnet.microsoft.com`, `nodejs.org`, `unofficial-builds.nodejs.org`, `github.com` (Kitware/CMake), `dl-cdn.alpinelinux.org` | Once per host, per toolchain version | Use `prepare-toolchains --output-tar` to pre-stage **tarball-backed** toolchains (JDK, Gradle, Maven, .NET, Node, glibc CMake). Ruby and CMake on Alpine cannot be bundled — they need apk on the scanner host (direct, or via your internal Alpine mirror). See §6.3 for the full list. |
| **B. Dependency registries** | Maven Central, npm, PyPI, RubyGems, NuGet — whatever your project's package manager pulls from | Every scan | Configure your project's existing internal mirror (Artifactory/Nexus); the scanner uses whatever your `settings.xml` / `.npmrc` / `pip.conf` already point at |

### Domains to flag explicitly

- **`unofficial-builds.nodejs.org`** — required if the scanner runs on Alpine (i.e. the slim image). Node's official archive (`nodejs.org/dist`) does not publish musl binaries; the Node project's musl builds live at this separate domain.
- **`dl-cdn.alpinelinux.org`** — required when running the slim image for **every Ruby scan** (Ruby is always installed via `apk add ruby ruby-bundler`) and for **CMake on Alpine** (the slim image's CMake path uses `apk add cmake`). Either allow direct, or point the host at your internal Alpine mirror.

All traffic is HTTPS / TCP 443 / outbound only. No inbound, no UDP, no plain HTTP.

---

## 8. Language support matrix

Reference projects are publicly cloneable, production-grade repos. Component / dependency-edge / max-graph-depth counts are approximate but representative — your project will differ by manifest density.

| Language | Status | Reference project | Components / Edges / Depth | Notes |
|---|---|---|---|---|
| Kotlin (Gradle) | ✅ Full | JetBrains/Exposed | 132 / 146 / 16 | Bootstrap installs JDK 21 + Gradle |
| Java (Maven) | ✅ Full | apache/commons-lang | 33 / 24 / 4 | Bootstrap installs JDK 21 + Maven |
| Python | ✅ Full | pallets/flask | 91 / 83 / 7 | Uses slim image's system `python3` + `pip` (no bootstrap needed) |
| Node.js | ✅ Full | expressjs/express | 375 / 367 / 14 | Bootstrap installs Node (musl variant on Alpine) |
| .NET | ✅ Full | serilog/serilog | 18 / 7 / 1 | cdxgen parses `.csproj` statically; bootstrap installs .NET SDK for projects that need it |
| Ruby | ✅ Full | sinatra/sinatra | 8 / 1 / 0 | Bootstrap uses `apk add ruby ruby-bundler` (Alpine only). Shallow graph reflects Bundler's typical resolution behaviour, not a scanner limitation |
| C++ (CMake) | ⚠ Limited | jbeder/yaml-cpp | 14 / 0 / 0 | See caveat below |

### C++ caveat

cdxgen's C/C++ support is best-effort. For CMake projects **without** a `conan.lock` or `vcpkg.json`, cdxgen reads `CMakeLists.txt` statically and produces a flat list of references found in `find_package` / `target_link_libraries` calls — typical output is 10–30 components, **0 dependency edges**.

This is an upstream cdxgen limitation, not a scanner integration issue. To get a richer transitive graph for C++:

- Add a `conan.lock` (Conan-managed projects), or
- Add a `vcpkg.json` / `vcpkg-configuration.json` (vcpkg-managed projects).

The scanner ensures CMake is available on the scanner host (Kitware tarball on glibc Linux, `apk add cmake` on Alpine). The **depth** of the resulting C++ BOM, however, is governed by what cdxgen can extract from your project metadata — adding `conan.lock` or `vcpkg.json` is the actionable next step if you need transitive resolution. Without one, expect a flat manifest-style listing regardless of how completely your project builds locally.

---

## 9. Troubleshooting

### "Cache is not writable"
Cache mount must be owned by UID 1000 and writable. See §5.

### "java: not found" or "gradle: command not found" mid-scan
The bootstrap detected the project but downloaded a glibc JDK on an Alpine host (or vice versa). Confirm you're on the slim image (`opsmx11/ssd-scanner-cli:*-slim`) and not a custom image; the slim image autodetects libc.

### Scan succeeds but BOM is sparse for a non-C++ project
Most likely the project mount is read-only — language tools fall back to manifest-only mode. Re-run with `:rw`.

### `prepare-toolchains` exits with "incompatible flag combination"
You hit one of the §6.3 not-bundleable cases. Read the error message — it tells you which subset of `--languages` triggered the rejection and the workarounds.

### Cache populated but bootstrap re-downloads on a different host
Bundles are platform-specific (§6.4). Re-run `prepare-toolchains` on the matching OS family, or inside the slim image.

---

## 10. Reference

- [`cdxgen-firewall-allowlist.md`](cdxgen-firewall-allowlist.md) — exact domains and per-customer templates
- `Dockerfile.slim` (repo root) — image build reference
- `prepare-toolchains --help` — current flag list and accepted languages
- ADR `0001-cdxgen-toolchain-distribution.md` — design rationale
