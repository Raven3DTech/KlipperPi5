# Workspace layout (R3DTech Configurator & builds)

This file lives in the **RatOS PI5** image repository. Use it when this repo sits inside a larger folder (for example **R3DTech Configurator**) next to other projects (`client/`, `server/`, etc.).

## CustomPiOS sibling

CustomPiOS expects to live **next to** this repository so the Makefileâ€™s default `CUSTOMPIOS_PATH=../CustomPiOS` resolves:

```text
<parent>/
â”œâ”€â”€ CustomPiOS/          â† git clone https://github.com/guysoft/CustomPiOS.git
â””â”€â”€ RAVENOS-PI5/          â† this repo (recommended directory name)
```

If your local checkout still uses the folder name **`KlipperPi`** (legacy), rename it to **`RAVENOS-PI5`** when nothing holds a lock, or use the **junction** below. CustomPiOS names the output **`<parent-of-src>.img`**, so the parent folder name should be **`RAVENOS-PI5`** if you want **`RAVENOS-PI5.img`**.

## Windows: directory junction (optional)

If you cannot rename `KlipperPi` â†’ `RAVENOS-PI5` (file locks), create a **junction** in the parent directory so build paths and output names match CI:

```powershell
# Run from the parent of this repo (e.g. R3DTech Configurator)
New-Item -ItemType Junction -Path "RAVENOS-PI5" -Target "KlipperPi"
```

Then use `cd RAVENOS-PI5/src` for builds; it is the same working tree.

## Where to build

- **Linux:** native, VM, or **WSL2** with Ubuntu â€” run `make build` or `sudo bash -x ./build_dist` from `src/` (see **README.md**).
- **GitHub Actions:** push to `main` or run workflow **Build RatOS PI5 Image** manually; artifacts use **`RatOS-PI5-<version>-arm64`** (see **`.github/workflows/build.yml`**).

## Upstream repository URL

The canonical remote is currently:

`https://github.com/Raven3DTech/RAVENOS-PI5.git`

Clone with an explicit directory name so the image filename matches docs:

```bash
git clone https://github.com/Raven3DTech/RAVENOS-PI5.git RAVENOS-PI5
```

**Existing clones** (remote was `KlipperPi5`): `git remote set-url origin https://github.com/Raven3DTech/RAVENOS-PI5.git`

## GitHub Actions: remove failed runs (keep green)

1. Install [GitHub CLI](https://cli.github.com/) and run **`gh auth login`** as a user with **admin** rights on **`Raven3DTech/RAVENOS-PI5`** (deleting workflow runs returns **403** for non-admins).
2. Preview: **`powershell -File scripts/delete-failed-github-runs.ps1 -WhatIf`**
3. Delete: **`powershell -File scripts/delete-failed-github-runs.ps1`**

Deletes **`failure`**, **`startup_failure`**, and **`timed_out`** runs (override with **`-Repo owner/name`**). Successful runs are untouched.
