# GitHub Workflows

This directory contains the CI/CD workflows for jupyter-quant-kubernetes.

## Workflows Overview

| Workflow | Trigger | Action |
|----------|---------|--------|
| `docker-build-n-test.yml` | Push to `master`/`dev` | Build & test CPU Docker image + PyPI package |
| `docker-build-gpu.yml` | Push to `master`/`dev` (GPU files) | Build & test NVIDIA + AMD GPU images |
| `docker-publish.yml` | Tag push (e.g., `v1.0.0`) | Publish all images to Docker Hub + GHCR + PyPI |
| `docker-base-image.yml` | Daily 04:20 + manual | Check for base image updates, create issue |
| `security-scan.yml` | Every PR | OSV-Scanner vulnerability check |

## What Happens When You Push

### Push to `master` or `dev` Branch

```
✅ Python package build (3.11, 3.12, 3.13)
✅ Docker CPU image build (linux/amd64)
✅ Docker GPU images build (if Dockerfile.nvidia/amd changed)
❌ No publishing (images not pushed to registry)
```

### Push a Tag (e.g., `v1.0.0`)

```
✅ Build & publish CPU image → Docker Hub + GHCR
✅ Build & publish NVIDIA image → Docker Hub + GHCR  
✅ Build & publish AMD image → Docker Hub + GHCR
✅ Build PyPI package (.tar.gz + .whl)
✅ Publish to PyPI
✅ Sign with Sigstore
✅ Create GitHub Release with artifacts
```

**Result:**
- `Aidas-dev/jupyter-quant-kubernetes:<version>` (CPU)
- `Aidas-dev/jupyter-quant-kubernetes:<version>-nvidia` (GPU)
- `Aidas-dev/jupyter-quant-kubernetes:<version>-amd` (GPU)
- `jupyter-quant` package on PyPI

### Create a Pull Request

```
✅ Python package build test
✅ Docker CPU image build test
✅ Security scan (OSV-Scanner)
❌ No publishing
```

## Automated Dependency Updates (Dependabot)

| Ecosystem | Schedule | Configuration |
|-----------|----------|---------------|
| Docker | Daily 04:00 | Ignores major versions |
| GitHub Actions | Daily 04:10 | Grouped by type |
| Python/pip | Daily 04:20 | Minor/patch grouped together |

Dependabot creates PRs automatically. Review and merge to apply updates.

## Base Image Update Check

The `docker-base-image.yml` workflow:
- Runs daily at 04:20
- Checks if `python:*-slim` base image has updates
- Builds image to verify compatibility
- **Creates a GitHub issue** if update is available (doesn't auto-publish)

## Manual Triggers

All workflows support `workflow_dispatch`, meaning you can manually trigger them from the GitHub Actions tab:

1. Go to **Actions** tab
2. Select the workflow
3. Click **Run workflow**
4. Choose branch/tag
5. Click **Run workflow**

## Required Secrets

For publishing to work, configure these repository secrets:

| Secret | Purpose |
|--------|---------|
| `DOCKERHUB_USERNAME` | Docker Hub username |
| `DOCKERHUB_TOKEN` | Docker Hub access token |
| `GITHUB_TOKEN` | Auto-created by GitHub (for GHCR) |

## Publishing a New Version

```bash
# 1. Update version in .env-dist
IMAGE_VERSION=2512.3

# 2. Commit and push
git add .env-dist
git commit -m "Bump version to 2512.3"
git push

# 3. Create and push tag
git tag v2512.3
git push origin v2512.3

# 4. Watch the workflow run
# Go to: https://github.com/Aidas-dev/jupyter-quant-kubernetes/actions
```

## Image Tags After Publish

| Tag | Description |
|-----|-------------|
| `:latest` | Latest CPU build |
| `:<version>` | Specific version CPU (e.g., `:2512.3`) |
| `:<version>-nvidia` | NVIDIA GPU variant |
| `:<version>-amd` | AMD GPU variant |

## Troubleshooting

### Build Fails

1. Check **Actions** tab for detailed logs
2. Look for dependency resolution errors
3. Verify `.env-dist` has correct values

### Publish Fails

1. Verify secrets are configured
2. Check if tag follows `v*` pattern (e.g., `v1.0.0`)
3. Ensure CPU build succeeds first (GPU depends on it)

### GPU Images Not Building

1. Verify `Dockerfile.nvidia` and `Dockerfile.amd` exist
2. Check if push touched GPU-related files
3. Manually trigger `docker-build-gpu.yml` workflow

## Credits

Original workflow design from [jupyter-quant](https://github.com/quantbelt/jupyter-quant) by [@gnzsnz](https://github.com/gnzsnz).
