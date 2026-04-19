# Workspace layout (R3DTech Configurator & builds)

This file lives in the **RavenOS PI5** image repository. Use it when this repo sits inside a larger folder (for example **R3DTech Configurator**) next to other projects (`client/`, `server/`, etc.).

## CustomPiOS sibling

CustomPiOS expects to live **next to** this repository so the Makefile’s default `CUSTOMPIOS_PATH=../CustomPiOS` resolves:

```text
<parent>/
├── CustomPiOS/          ← git clone https://github.com/guysoft/CustomPiOS.git
└── R3DTOS-PI5/          ← this repo (recommended directory name)
```

If your local checkout still uses the folder name **`KlipperPi`** (legacy), rename it to **`R3DTOS-PI5`** when nothing holds a lock, or use the **junction** below. CustomPiOS names the output **`<parent-of-src>.img`**, so the parent folder name should be **`R3DTOS-PI5`** if you want **`R3DTOS-PI5.img`**.

## Windows: directory junction (optional)

If you cannot rename `KlipperPi` → `R3DTOS-PI5` (file locks), create a **junction** in the parent directory so build paths and output names match CI:

```powershell
# Run from the parent of this repo (e.g. R3DTech Configurator)
New-Item -ItemType Junction -Path "R3DTOS-PI5" -Target "KlipperPi"
```

Then use `cd R3DTOS-PI5/src` for builds; it is the same working tree.

## Where to build

- **Linux:** native, VM, or **WSL2** with Ubuntu — run `make build` or `sudo bash -x ./build_dist` from `src/` (see **README.md**).
- **GitHub Actions:** push to `main` or run workflow **Build RavenOS PI5 Image** manually; artifacts use the **`R3DTOS-PI5-…`** naming from **`.github/workflows/build.yml`**.

## Upstream repository URL

The canonical remote is currently:

`https://github.com/Raven3DTech/R3DTOS-PI5.git`

Clone with an explicit directory name so the image filename matches docs:

```bash
git clone https://github.com/Raven3DTech/R3DTOS-PI5.git R3DTOS-PI5
```

**Existing clones** (remote was `KlipperPi5`): `git remote set-url origin https://github.com/Raven3DTech/R3DTOS-PI5.git`

## GitHub Actions: remove failed runs (keep green)

1. Install [GitHub CLI](https://cli.github.com/) and run **`gh auth login`** as a user with **admin** rights on **`Raven3DTech/R3DTOS-PI5`** (deleting workflow runs returns **403** for non-admins).
2. Preview: **`powershell -File scripts/delete-failed-github-runs.ps1 -WhatIf`**
3. Delete: **`powershell -File scripts/delete-failed-github-runs.ps1`**

Deletes **`failure`**, **`startup_failure`**, and **`timed_out`** runs (override with **`-Repo owner/name`**). Successful runs are untouched.
