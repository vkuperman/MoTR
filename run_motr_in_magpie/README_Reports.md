## MoTR Click Reports

This document describes the variables exported in the two main CSV reports:

- `fixation_report.csv`
- `interest_area_report.csv`

Both files are generated and zipped at the end of each session and uploaded according to the `resultsUploadUrl` in `magpie.config.js`.

---

## Where to place zipped result files

For post-processing with `analysis/fill_interest_area_metadata.R`, place participant ZIP files in:

- `run_motr_in_magpie/Results/`

Expected ZIP naming pattern (default script setting):

- `motr_results_*.zip`

The script automatically:

1. Finds ZIPs in `run_motr_in_magpie/Results/`
2. Extracts each `interest_area_report.csv`
3. Combines them into `interest_area_report_all_participants.csv`
4. Fills metadata (`word`, `line_number`, `position_in_line`)
5. Writes `interest_area_report_filled.csv`

Run from `run_motr_in_magpie`:

```r
# Set this to your own local folder that contains `analysis/` and `Results/`
setwd("C:/path/to/your/MoTR_Click/run_motr_in_magpie")
source("analysis/fill_interest_area_metadata.R")
```

---

## Fixation report (`fixation_report.csv`)

Each row corresponds to **one mouse click (fixation)** on a word.

- **participant_id**: Anonymous participant code for this session. Taken from `ParticipantId` in the experiment data if available; otherwise an 8‑character random alphanumeric ID is generated.
- **SONAId**: Participant’s SONA ID (string), taken from `SONAId` / `SubjectId` / `SubjectID` / `SonaId` fields at the experiment or trial level.
- **Condition**: Experimental condition label for the item. In the current Provo setup, `1` = practice text and `2` = experimental text.
- **ItemId**: Identifier of the text / trial item (e.g., a sentence or passage) being read on that screen.
- **text_presentation_order**: Order in which this text item was presented within the session (1 = first text shown).
- **WordIndex**: Position of the clicked word within the text item (1-based index; same logical position used in the interest-area report).
- **Word**: The actual word string that was clicked, as rendered to the participant.
- **responseTime**: Absolute timestamp of the click in milliseconds since experiment start (used to order clicks within a session and within an item).
- **mousePositionX**: X coordinate of the click on the screen, in pixels.
- **mousePositionY**: Y coordinate of the click on the screen, in pixels.
- **Regression**: Within-item leftward regression flag for this fixation:  
  - `"1"` = this click’s X position is **left of** the previous click on the same item.  
  - `"0"` = not a leftward regression (first click on the item or moved rightward / stayed in place).
- **clickDurationMs**: Duration (in milliseconds) that the mouse button was held down for this click.
- **relativeXInWord**: Horizontal position of the click **within the word’s interest area** as a proportion from 0 to 1 (0 = left edge, 1 = right edge), when available.
- **relativeYInWord**: Vertical position of the click within the word’s interest area as a proportion from 0 to 1 (0 = top, 1 = bottom), when available.
- **wordPositionTop**: Top Y coordinate of the word’s interest area, in pixels.
- **wordPositionLeft**: Left X coordinate of the word’s interest area, in pixels.
- **wordPositionBottom**: Bottom Y coordinate of the word’s interest area, in pixels.
- **wordPositionRight**: Right X coordinate of the word’s interest area, in pixels.
- **line_number**: Line number in the rendered text where the clicked word appears (1 = top line).
- **position_in_line**: Position of the word within its line (1 = leftmost word on that line).
- **response**: Participant’s comprehension response for this **item** (e.g., answer to the post-text question). The same value is repeated for all fixations belonging to the same item.
- **position_in_text**: Same logical position as `WordIndex` (1-based index of the word within the text item).
- **text_total_viewing_time_ms**: Total viewing time of the **page** (text item) in milliseconds: time from the first fixation to the last fixation on that item (same value for all fixations belonging to the same item).
- **saccade_start_x**, **saccade_start_y**, **saccade_start_time**: For the saccade **from this fixation to the next** (within the same item): start position and timestamp. Same as this row’s `mousePositionX`, `mousePositionY`, `responseTime`.
- **saccade_end_x**, **saccade_end_y**, **saccade_end_time**: End position and timestamp of the saccade (next fixation’s coordinates and time). Empty on the last fixation of an item.
- **saccade_length_px**: Length of the saccade in pixels (Euclidean distance from start to end). Empty on the last fixation of an item.
- **device**: Device type reported in the session (e.g., `"mouse"`, `"trackpad"` or similar).
- **hand**: Reported hand used for the mouse (e.g., `"left"`, `"right"`), if provided.
- **experiment_start_time**: ISO 8601 start time of the experiment / session. Taken from experiment data if present; otherwise approximated from the first recorded response time.
- **experiment_end_time**: ISO 8601 end time of the experiment / session (time at which the reports are exported).
- **experiment_duration**: Total duration of the session in milliseconds (`experiment_end_time - experiment_start_time`).
- **experiment**: Name or label of the experiment (e.g., `"MoTR_Click_Provo"`). This is filled from experiment-level data if present and otherwise from the configured experiment name in `magpie.config.js`.

---

## Interest-area report (`interest_area_report.csv`)

Each row corresponds to **one word position** in a text item (whether that word was clicked or skipped). The data are aggregated across all fixations on that word within the item.

- **participant_id**: Same as in the fixation report; participant code for this session.
- **SONAId**: Same SONA ID field as in the fixation report.
- **Condition**: Experimental condition label for the item. In the current Provo setup, `1` = practice text and `2` = experimental text.
- **ItemId**: Identifier of the text / trial item.
- **text_presentation_order**: Order in which the text item appeared in the session (same value for all rows belonging to a given item).

- **word_index**: Position of this word within the text item (1-based). Every possible word index for the item gets a row, even if the word was never clicked.
- **word**: The word string **only if it was clicked at least once**. This field is left blank for words that were skipped (no clicks). To populate these blanks for skipped words, use the companion R script described below to join in information from the Provo items TSV files.
- **response**: Participant’s comprehension response for this item (same as `response` in the fixation report; identical for all word positions within the same item).
- **line_number**: Line number in the rendered text where this word is located (taken from the first click on this word; blank if the word was never clicked, and can be filled for skipped words via the R script).
- **position_in_line**: Position of the word within its line (taken from the first click on this word; blank if never clicked, and can be filled for skipped words via the R script).

- **click_count**: Number of clicks recorded on this word (0 for skipped words, 1 or more for visited words).
- **skipped**: Whether the word was skipped:  
  - `"1"` = no clicks on this word (`click_count = 0`).  
  - `"0"` = at least one click on this word (`click_count > 0`).

- **IA_FIRST_RUN_DWELL_TIME** (gaze duration): Sum of the duration of all fixations on this interest area **before it is exited** (to the left or to the right). That is, the duration of the first run of consecutive fixations on this word, in milliseconds.
- **IA_DWELL_TIME** (total fixation duration): Sum of **all** fixations on this interest area, including gaze duration and all regressions, in milliseconds (same as `total_duration_ms`).
- **IA_FIRST_FIXATION_DURATION**: Duration (in milliseconds) of the **first fixation/click** on this interest area.
- **go_past_time_ms**: Sum of all fixations made on this word from first entry **up to the point when the eyes go past it** (i.e., first time the reader moves to a later word). Excludes time spent on this word after regressing back into it.
- **IA_REGRESSION_IN**: Whether a regression was made **from another interest area into** the current interest area.  
  - `"1"` = at least one entry into this word was from a later word (regression-in).  
  - `"0"` = no regression-in.
- **IA_REGRESSION_OUT**: Whether regression(s) were made **from the current interest area to earlier interest areas** (e.g., previous parts of the sentence) **before leaving that interest area in a forward direction**.  
  - `"1"` = at least one saccade from this word went to an earlier word.  
  - `"0"` = no regression-out.
- **text_total_viewing_time_ms**: Total viewing time of the **page** (text item) in milliseconds: from first fixation to last fixation on that item. Same value for all rows belonging to the same item.

- **first_click_x**: Screen X coordinate (in pixels) of the **first click** on this word.
- **first_click_y**: Screen Y coordinate (in pixels) of the **first click** on this word.
- **next_click_regression**: Whether the **next click after this word’s last click** was a regression in word order:  
  - `"1"` = the next click was on an **earlier** word (lower `word_index`, indicating a regression).  
  - `"0"` = the next click was on the same or a later word (no regression).  
  - `""` (empty) = there was no later click in this item.

- **x_distance_from_previous_click_px**: Horizontal distance in pixels from the **previous click on a different word** (within the same item) to the first click on this word. Computed as current `first_click_x` minus the previous click’s X coordinate (positive = moved right; negative = moved left).
- **x_distance_from_previous_click_chars**: Same distance as above, but expressed in estimated **character-width units** (dividing the pixel distance by the estimated character width of the clicked word).

- **first_click_x_from_word_left_chars**: Horizontal position of the first click relative to the word’s **left edge**, in character-width units (0 ≈ left edge, 1 ≈ one character to the right, etc.).
- **first_click_x_from_word_center_chars**: Horizontal position of the first click relative to the word’s **center**, in character-width units (0 ≈ center; negative values = left of center; positive values = right of center).
- **first_click_x_from_line_start_px**: Horizontal distance in pixels from the **start of the line** to the first click on this word.
- **first_click_x_from_line_start_chars**: Same as above, but in character-width units.

- **device**: Device type for the session (same interpretation as in the fixation report).
- **hand**: Preferred hand used for the mouse (same interpretation as in the fixation report).
- **experiment_start_time**: Session start time in ISO 8601 format.
- **experiment_end_time**: Session end time in ISO 8601 format.
- **experiment_duration**: Session duration in milliseconds.
- **experiment**: Name or label of the experiment (same logic as in the fixation report).

---

### Filling in skipped-word metadata (R script)

For interest-area rows where the word was **not clicked** (`skipped = "1"`), the `word`, `line_number`, and `position_in_line` columns are left blank by the JavaScript export. To fill these values, you can run the accompanying R script (for example, saved as `analysis/fill_interest_area_metadata.R`):

1. Put participant ZIP result files in `run_motr_in_magpie/Results/`.
2. The script extracts `interest_area_report.csv` from each ZIP and combines them into `interest_area_report_all_participants.csv`.
3. It reads Provo items TSV files (`provo/trials/provo_items_*.tsv`) to fill lexical metadata.
4. It fills `word`, `line_number`, and `position_in_line` using TSV data plus observed/inferred line-position anchors.
5. It writes `interest_area_report_filled.csv` with blanks instead of `NA`.

See the comments at the top of the R script file for configuration details (paths, file patterns, and column names). This offline step ensures that skipped words have complete lexical and positional information for downstream analysis.

