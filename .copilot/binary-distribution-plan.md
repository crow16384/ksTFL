# Plan: Distribute ksTFL Binaries via Public GitHub Repo

Build Windows + Linux binaries in the private repo's GitHub Actions on tag push, deploy compiled binaries to a public repo as a CRAN-like repository on GitHub Pages. **~80 billed minutes per release** — very comfortable on the free tier (~25 releases/month).

```
Private repo (ksTFL)                     Public repo (ksTFL-release)
┌─────────────────────┐                  ┌──────────────────────────┐
│ Source code (C++/R) │                  │ bin/windows/contrib/4.x/ │
│ .github/workflows/  │  GH Actions      │ releases/ (Linux .tar.gz)│
│   release.yml       │ ─── build ───>   │ PACKAGES index files     │
│                     │   & deploy       │ README.md                │
└─────────────────────┘                  │ GitHub Pages ✓           │
                                         └──────────────────────────┘
```

---

## Phase 1: You — Create public repo & deploy key

### Step 1.1 — Create public repo

- Go to github.com → New repository
- Name: `ksTFL-release` (or your preferred name)
- Visibility: **Public**
- Do NOT initialize with README (we'll push initial content)

### Step 1.2 — Generate SSH deploy key

Run locally:

```bash
ssh-keygen -t ed25519 -C "ksTFL-deploy" -f ksTFL-deploy-key -N ""
```

This creates two files: `ksTFL-deploy-key` (private) and `ksTFL-deploy-key.pub` (public).

### Step 1.3 — Add public key to the public repo

- `ksTFL-release` → Settings → Deploy keys → Add deploy key
- Title: `Private repo deploy`
- Key: paste contents of `ksTFL-deploy-key.pub`
- Check **"Allow write access"**
- Click Add key

### Step 1.4 — Add private key as secret in the private repo

- Private `ksTFL` → Settings → Secrets and variables → Actions → New repository secret
- Name: `DEPLOY_KEY`
- Value: paste full contents of `ksTFL-deploy-key` (private key file)

### Step 1.5 — Add public repo name as a variable

- Private `ksTFL` → Settings → Secrets and variables → Actions → Variables tab → New repository variable
- Name: `PUBLIC_REPO`
- Value: `<your-github-username>/ksTFL-release`

### Step 1.6 — Delete local key files

Remove `ksTFL-deploy-key` and `ksTFL-deploy-key.pub` — they are now stored in GitHub.

---

## Phase 2: Copilot — Create workflow + public repo bootstrap

### Step 2.1 — Create `.github/workflows/release.yml`

The workflow has 3 jobs:

#### Job 1: `build` (matrix strategy)

| Runner | R versions |
|---|---|
| `ubuntu-latest` | 4.4, 4.5 |
| `windows-latest` | 4.4, 4.5 |

Per job:

1. Checkout code
2. Setup R via `r-lib/actions/setup-r@v2`
3. Install system deps
   - Linux: `sudo apt-get install -y libharfbuzz-dev libfreetype-dev libminizip-dev pkg-config`
   - Windows: handled by Rtools automatically
4. Install R dependencies via `r-lib/actions/setup-r-dependencies@v2`
5. `R CMD build .` → builds vignettes, produces `ksTFL_<version>.tar.gz` source tarball
6. `R CMD INSTALL --build ksTFL_<version>.tar.gz` → produces `.zip` (Windows) or `ksTFL_<version>_R_<arch>.tar.gz` (Linux binary)
7. Upload artifact via `actions/upload-artifact@v4`

#### Job 2: `deploy` (after all builds)

1. Download all artifacts
2. Setup SSH with deploy key (`webfactory/ssh-agent@v0.9.0`)
3. Clone the public repo via SSH
4. Organize Windows binaries into CRAN-like structure:
   - `bin/windows/contrib/4.4/ksTFL_<version>.zip`
   - `bin/windows/contrib/4.5/ksTFL_<version>.zip`
5. Generate `PACKAGES` / `PACKAGES.gz` / `PACKAGES.rds` indexes via `tools::write_PACKAGES()`
6. Place Linux binaries in `releases/` directory
7. Prune old versions (keep last 2)
8. Ensure `.nojekyll` exists
9. Commit and push to public repo

#### Job 3: `release`

- Create GitHub Release on the private repo with all binaries attached using `softprops/action-gh-release@v2`

### Step 2.2 — Bootstrap public repo

Push initial structure to the public repo: `.nojekyll`, `README.md`.

---

## Phase 3: You — Enable GitHub Pages

After the first deployment pushes content:

- `ksTFL-release` → Settings → Pages
- Source: **Deploy from branch**
- Branch: `main`, folder: `/ (root)`
- Save

---

## Phase 4: Test

### Step 4.1 — Tag and push

```bash
git tag v0.7.6
git push origin v0.7.6
```

### Step 4.2 — Monitor

Watch the Actions tab in the private repo — all 3 jobs should pass.

### Step 4.3 — Verify public repo

- `bin/windows/contrib/4.4/` and `bin/windows/contrib/4.5/` directories exist with `.zip` files
- `PACKAGES` index files exist in each directory
- `releases/` directory has Linux `.tar.gz` files
- `https://<user>.github.io/ksTFL-release/` renders the README

### Step 4.4 — Test install

```r
# Windows — seamless via CRAN-like repo:
install.packages("ksTFL", repos = "https://<user>.github.io/ksTFL-release")
library(ksTFL)

# Linux — download from releases page, then:
install.packages("ksTFL_0.7.6_R_x86_64-pc-linux-gnu.tar.gz", repos = NULL)
library(ksTFL)
```

---

## Billed minutes estimate

| Runner | Multiplier | ~Build time | × 2 R versions | Billed |
|---|---|---|---|---|
| Linux | 1× | ~10 min | 20 min | 20 |
| Windows | 2× | ~15 min | 30 min | 60 |
| **Total** | | | | **~80** |

~25 releases/month on the free 2,000 minute tier.

---

## Decisions

- **Platforms**: Windows + Linux only (macOS can be added later at 10× minute cost)
- **R versions**: 4.4 and 4.5
- **Retention**: Last 2 versions per R version per platform
- **No source code** in public repo
- **Deploy key** for authentication (least privilege)
- **Windows** via CRAN-like repo (seamless `install.packages()`); **Linux** via GitHub Releases (manual download)

---

## Future enhancements (out of scope)

- Add macOS arm64 builds when needed
- Add source tarball to CRAN-like repo (if source sharing becomes acceptable)
- Set up r-universe.dev as alternative distribution channel
- Add R-CMD-check workflow alongside binary builds
