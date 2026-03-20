# Mouse Tracking for Reading (MoTR) – Modified Demo

**Live demo:** https://vkuperman.github.io/MoTR_Click/  
If you see 404, see [PAGES_SETUP.md](PAGES_SETUP.md).

This is a modified version of [MoTR](https://github.com/wilcoxeg/MoTR) with **click-to-reveal** and character-based unblur:

- **Reveal on click only:** Text unblurs only while the mouse button is held; release hides it.
- **Reveal window:** 4 characters to the left and 14 characters to the right of the click position.
- **Recording:** One log row per click with position, duration, and position relative to word boundaries. Mouse movement during a click is ignored; the reveal stays fixed at click-start.

## Run the demo locally

1. **Install Node.js** (v16.x recommended): https://nodejs.org/

2. **Go to the demo folder:**
   ```bash
   cd run_motr_in_magpie/demo
   ```

3. **Install dependencies and run:**
   ```bash
   npm install
   npm run serve
   ```

4. Open the URL shown in the terminal (e.g. `http://localhost:8080/`) in your browser.

## Put this repo on your GitHub

You need **Git** installed: https://git-scm.com/download/win

1. **Create a new repository** on GitHub (e.g. `MoTR` or `MouseTracking-MoTR`). Do **not** add a README or .gitignore there.

2. **Initialize git and push** from this folder (the one that contains `run_motr_in_magpie` and this README):

   ```bash
   cd C:\path\to\your\MoTR_Click
   git init
   git add .
   git commit -m "MoTR demo with click-to-reveal and 4/14 character unblur"
   git branch -M main
   git remote add origin https://github.com/YOUR_USERNAME/YOUR_REPO_NAME.git
   git push -u origin main
   ```

   Replace `YOUR_USERNAME` and `YOUR_REPO_NAME` with your GitHub username and repo name.

3. To **run the demo from your GitHub repo** later: clone your repo, then `cd run_motr_in_magpie/demo`, run `npm install` and `npm run serve`.

## Structure

- `run_motr_in_magpie/demo/` – Runnable demo (Vue + Magpie) with the modified behaviour.
- `run_motr_in_magpie/provo/` – Provo experiment `App.vue` (same logic; needs full Magpie setup to run).
- `run_motr_in_magpie/attachment/` – Attachment experiment `App.vue` (same logic; needs full Magpie setup to run).
- `api/` – Upload-results serverless API (email + optional GitHub storage). See [api/README.md](api/README.md) for env vars and saving reports to GitHub.

Only the **demo** folder is set up to run with `npm install` and `npm run serve` from this repo.

## Exported results and new columns

When you complete a Provo session, the app creates a ZIP archive containing:

- `fixation_report.csv` – one row per click/fixation.
- `interest_area_report.csv` – one row per word, with aggregated click information.

For each row, the following participant-level fields are included:

- `SubjectId` – participant identifier used within the experiment.
- `SonaId` – the 5-digit SONA ID entered on the Welcome screen.
- `device` – reported input device (mouse/trackpad/other).
- `hand` – reported hand used during the experiment.

For each text item, the participant’s answer to the comprehension question is stored in the `response` column in both CSV files. The same `SonaId` value is repeated on every row for that participant, which makes it easier to merge these files with other datasets keyed by SONA ID.

## Post-processing IA reports from ZIP files

To combine participant results and fill missing interest-area metadata:

1. Put participant ZIP result files in:
   - `run_motr_in_magpie/Results/`
2. Open R/RStudio and run:
   ```r
   # Set this to your own local folder that contains `analysis/` and `Results/`
   setwd("C:/path/to/your/MoTR_Click/run_motr_in_magpie")
   source("analysis/fill_interest_area_metadata.R")
   ```
3. Outputs:
   - `run_motr_in_magpie/Results/interest_area_report_all_participants.csv`
   - `run_motr_in_magpie/Results/interest_area_report_filled.csv`

See `run_motr_in_magpie/README_Reports.md` for variable definitions and detailed report notes.
