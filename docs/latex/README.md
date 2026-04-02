# Final Report (LaTeX) — MAEG4999 replica

This folder builds a **PDF report** aligned to the **current MATLAB codebase**: merged **USC-HAD + HuGaDB** binary SVM (30-D features), dataset ablation metrics, optional **multiclass ECOC** figure, Kalman fusion, and FSM.

## Files

| File | Role |
|------|------|
| `main.tex` | Title page, Ch.1--2 inputs, Ch.3--5 chapter headings + merged bodies |
| `main.pdf` | **Built report** (commit after recompiling; see build commands below) |
| `chapters/abstract_merged.tex` | Abstract: interim PDF + repository corrections/updates |
| `chapters/methods_merged.tex` | Ch.3: planned (PDF) vs implemented methods |
| `chapters/results_merged.tex` | Ch.4: interim narrative + updated metrics/figures |
| `chapters/conclusions_merged.tex` | Ch.5: roadmap, timeline, risks, repository status |
| `chapters/literature_review.tex` | Chapter 2 (literature + summary table) |
| `references.bib` | BibTeX database (all cited works) |
| `chapters/references.tex` | Invokes `\bibliographystyle{IEEEtran}` + `\bibliography{references}` |

## References (IEEE style)

Citations use numeric brackets (e.g.\ [1]) with the **`cite`** package, and the list is formatted by **`IEEEtran.bst`**, consistent with the IEEE Reference Style described in IEEE’s *Information for Authors* (numbered references, order of first citation). Edit `references.bib` and re-run the build (which runs **BibTeX**).

The reference list appears **once at the end** of the report (standard for thesis-style documents). `chapters/references.tex` sets `\bibname` to **References** so you do not get a duplicate **Bibliography** heading from the default `report` class.

## Figures (required before compile)

From the **project root**, run MATLAB so these exist (commit them for GitHub Actions):

- `results/svm_confusion_matrix.png` — merged binary (default after `RunSvmDatasetAblation` or copied from merged run)
- `results/multiclass_confusion_matrix.png` — from `EvaluateMulticlassConfusion`
- `results/pipeline_output.png` — from `RunExoskeletonPipeline`

## Install LaTeX on macOS

**BasicTeX** (smaller download) requires **admin password** once:

```bash
brew install --cask basictex
```

When the installer finishes, restart the terminal or run:

```bash
eval "$(/usr/libexec/path_helper)"
```

Install extra packages (first time only):

```bash
sudo tlmgr update --self
sudo tlmgr install collection-latexextra
```

*(If `brew install` failed in a non-interactive environment, run the same command in your own Terminal so you can enter your password.)*

## Compile PDF

```bash
cd /Users/rexyim/Documents/MATLAB/AutomationForExoskeleton/docs/latex
pdflatex -interaction=nonstopmode main.tex
bibtex main
pdflatex -interaction=nonstopmode main.tex
pdflatex -interaction=nonstopmode main.tex
```

Output: **`main.pdf`** in this folder.

Alternative (Homebrew `tectonic`, no full TeX Live install):

```bash
tectonic -X compile main.tex
```

Optional:

```bash
latexmk -pdf -interaction=nonstopmode main.tex
```

## Build PDF on GitHub (no local TeX)

If you **push** this repo to GitHub, the workflow [`.github/workflows/build-latex-pdf.yml`](../../.github/workflows/build-latex-pdf.yml) compiles `main.pdf` on GitHub’s servers.

1. **Commit** `docs/latex/**` and **`results/*.png`** (figures must be in the repo for the build).
2. Push to `main` (or **Actions → Build LaTeX PDF → Run workflow**).
3. Open **Actions** → latest run → **Artifacts** → download **FYP-Final-Report-PDF** (contains `main.pdf`).

## Note on `WHL3.`

The original PDF shows `WHL3.` on the title page; it is preserved here—confirm with your supervisor whether it should stay or be removed.
