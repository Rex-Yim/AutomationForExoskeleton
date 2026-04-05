# Final Report (LaTeX) — MAEG4999 replica

This folder builds a **PDF report** aligned to the **current MATLAB codebase**: per-dataset **USC-HAD** and protocol-aware **HuGaDB** binary SVM comparisons (30-D features), dataset ablation metrics, optional **multiclass ECOC** figures, optional **binary and multiclass LSTM** holdout metrics, Kalman fusion, and FSM.

## Files

| File | Role |
|------|------|
| `main.tex` | Title page, Ch.1--2 inputs, Ch.3--5 chapter headings + chapter bodies |
| `../final_report.pdf` | **Built report** at `docs/final_report.pdf` (see `compile.sh` below) |
| `poster.tex` / `../poster.pdf` | Poster source; built PDF copied to **`docs/poster.pdf`** via `compile_poster.sh` |
| `chapters/abstract_merged.tex` | Abstract: interim PDF + repository corrections/updates |
| `chapters/methods_merged.tex` | Ch.3: planned (PDF) vs implemented methods |
| `chapters/results_merged.tex` | Ch.4: interim narrative + updated metrics/figures |
| `chapters/conclusions_merged.tex` | Ch.5: roadmap, timeline, risks, repository status |
| `chapters/literature_review.tex` | Chapter 2 (literature + summary table) |
| `references.bib` | BibTeX database (all cited works) |
| `IEEEtran.bst` | IEEE bibliography style (bundled for BasicTeX / CI; same as CTAN) |
| `chapters/references.tex` | Invokes `\bibliographystyle{IEEEtran}` + `\bibliography{references}` |
| `generated_metrics.tex` | **Auto-generated** SVM/LSTM accuracies for tables/abstract (`scripts/ExportMetricsForReport.m`) |

## References (IEEE style)

Citations use numeric brackets (e.g.\ [1]) with the **`cite`** package, and the list is formatted by **`IEEEtran.bst`**, consistent with the IEEE Reference Style described in IEEE’s *Information for Authors* (numbered references, order of first citation). Edit `references.bib` and re-run the build (which runs **BibTeX**).

The reference list appears **once at the end** of the report (standard for thesis-style documents). `chapters/references.tex` sets `\bibname` to **References** so you do not get a duplicate **Bibliography** heading from the default `report` class.

Each entry in `references.bib` includes **`url={https://doi.org/...}`** (derived from the DOI) so the PDF lists a resolvable link, similar to pasting `https://doi.org/...` under each reference in Word. Pagination and DOIs follow Crossref/IEEE metadata where they differ from an older manuscript (for example, Lazzaroni et al.\ vs.\ Poliero et al.\ are distinct RA-L papers with different DOIs and page ranges).

## Figures (required before compile)

From the **project root**, run MATLAB so these exist (commit figures if you ship a PDF):

- `results/figures/binary/svm_confusion_matrix_hugadb_streaming.png` — HuGaDB binary SVM under the streaming policy
- `results/figures/multiclass/multiclass_confusion_matrix_usc_had.png` / `multiclass_confusion_matrix_hugadb_streaming.png` — from `EvaluateMulticlassConfusion` per dataset
- `results/figures/pipeline/pipeline_binary_svm_output.png` — from `RunExoskeletonPipeline`

**Optional** (for Chapter 4 LSTM subsection): `RunLstmDatasetAblation` → `results/figures/binary/lstm_confusion_matrix_usc_had.png` / `results/figures/binary/lstm_confusion_matrix_hugadb_streaming.png`. `RunTrainEvalLstmMulticlass` writes `results/figures/multiclass/lstm_multiclass_confusion_matrix_usc_had.png` / `results/figures/multiclass/lstm_multiclass_confusion_matrix_hugadb_streaming.png`.

**Before committing a “final” PDF:** run `ExportMetricsForReport` in MATLAB so `generated_metrics.tex` matches the current `results/metrics/*/*_evaluation_metrics_*.mat` files for SVM and LSTM.

## Install LaTeX on macOS

**BasicTeX** (smaller download) requires **admin password** once:

```bash
brew install --cask basictex
```

When the installer finishes, restart the terminal or run:

```bash
eval "$(/usr/libexec/path_helper)"
```

Install extra packages on first setup:

```bash
sudo tlmgr update --self
sudo tlmgr install collection-latexextra
```

*(If `brew install` failed in a non-interactive environment, run the same command in your own Terminal so you can enter your password.)*

## Compile PDF

From `docs/latex/`:

```bash
./compile.sh
```

Or manually: compile here, then **`cp main.pdf ../final_report.pdf`**.

```bash
cd /path/to/AutomationForExoskeleton/docs/latex
pdflatex -interaction=nonstopmode main.tex
bibtex main
pdflatex -interaction=nonstopmode main.tex
pdflatex -interaction=nonstopmode main.tex
cp -f main.pdf ../final_report.pdf
```

**Poster:** `./compile_poster.sh` or `pdflatex poster.tex` then **`cp poster.pdf ../poster.pdf`**.

Alternative (Homebrew `tectonic`): compile in this folder, then copy outputs to `../final_report.pdf` / `../poster.pdf` as above.

Optional:

```bash
latexmk -pdf -interaction=nonstopmode main.tex && cp -f main.pdf ../final_report.pdf
```

## Note on `WHL3.`

The original PDF shows `WHL3.` on the title page; it is preserved here—confirm with your supervisor whether it should stay or be removed.
