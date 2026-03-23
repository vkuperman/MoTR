## Fill missing interest-area metadata (word, line_number, position_in_line)
##
## This script is intended to be run **after** collecting data from the Provo
## experiment. It reads:
##   1. The exported `interest_area_report.csv`
##   2. One or more Provo items TSV files (e.g., `provo_items_*.tsv`)
## and joins them by `ItemId` and `word_index` to fill in missing values for:
##   - `word`
##   - `line_number`
##   - `position_in_line`
##
## The output is a new CSV (by default, `interest_area_report_filled.csv`)
## with the filled-in metadata.

## ------------------------- User configuration ------------------------- ##

# Where your exported results live.
results_dir <- "Results"

# Path to the interest-area CSV exported by the browser (fallback if no ZIPs are present).
interest_area_csv <- file.path(results_dir, "interest_area_report.csv")

# If TRUE, combine all participant IA reports first, then fill metadata on that combined table.
combine_all_participants <- TRUE

# When ZIPs are present in `results_dir`, the script will extract `interest_area_report.csv` from them.
zip_pattern <- "motr_results_.*\\.zip$"

# Fallback: where to search for participant IA CSV files when combine_all_participants = TRUE and no ZIPs exist.
participant_reports_pattern <- "interest_area_report\\.csv$"
combined_output_csv <- file.path(results_dir, "interest_area_report_all_participants.csv")

# Directory containing the Provo items TSV files.
items_dir <- "provo/trials"

# Pattern matching the items TSV files.
items_pattern <- "^provo_items_.*\\.tsv$"

# Output CSV path.
output_csv <- file.path(results_dir, "interest_area_report_filled.csv")

## --------------------------------------------------------------------- ##

suppressWarnings({
  if (!requireNamespace("dplyr", quietly = TRUE)) install.packages("dplyr")
  if (!requireNamespace("readr", quietly = TRUE)) install.packages("readr")
  if (!requireNamespace("stringr", quietly = TRUE)) install.packages("stringr")
})

library(dplyr)
library(readr)
library(stringr)

get_interest_area_csv_entries_from_results <- function(results_dir, zip_pattern, participant_reports_pattern) {
  zip_files <- list.files(results_dir, pattern = zip_pattern, full.names = TRUE)

  if (length(zip_files) > 0) {
    message("Found ZIP result file(s) in ", results_dir, "; extracting interest_area_report.csv from them...")
    tmp_base <- tempfile("motr_ia_unzip_")
    dir.create(tmp_base, showWarnings = FALSE, recursive = TRUE)

    paths <- character()
    sources <- character()

    for (z in zip_files) {
      z_base <- basename(z)
      unzip_dir <- file.path(tmp_base, tools::file_path_sans_ext(z_base))
      dir.create(unzip_dir, showWarnings = FALSE, recursive = TRUE)
      utils::unzip(z, exdir = unzip_dir)

      ia_paths <- list.files(unzip_dir, pattern = "^interest_area_report\\.csv$", full.names = TRUE, recursive = TRUE)
      if (length(ia_paths) == 0) {
        stop("No interest_area_report.csv found inside ZIP: ", z)
      }
      # If more than one exists, keep them all.
      paths <- c(paths, ia_paths)
      sources <- c(sources, rep(z_base, length(ia_paths)))
    }
    return(list(paths = paths, sources = sources))
  }

  message("No ZIPs found; using existing CSV files in ", results_dir)
  files <- list.files(results_dir, pattern = participant_reports_pattern, full.names = TRUE, recursive = TRUE)
  files <- files[!grepl("filled\\.csv$", files, ignore.case = TRUE)]
  files <- files[!grepl("all_participants\\.csv$", files, ignore.case = TRUE)]
  if (length(files) == 0) {
    stop("No participant IA CSV files found in ", results_dir, " matching pattern ", participant_reports_pattern)
  }
  list(paths = files, sources = basename(files))
}

combine_interest_area_reports <- function(ia_paths, sources, output_path) {
  message("Combining ", length(ia_paths), " interest-area CSV file(s)...")
  frames <- lapply(seq_along(ia_paths), function(i) {
    f <- ia_paths[[i]]
    # Read all columns as character to avoid type collisions across participant files
    # (e.g., SONAId inferred as numeric in one file and character in another).
    d <- readr::read_csv(f, col_types = readr::cols(.default = readr::col_character()), show_col_types = FALSE)
    d$source_file <- sources[[i]]
    d
  })
  combined <- dplyr::bind_rows(frames)
  readr::write_csv(combined, output_path, na = "")
  message("Wrote combined IA report to: ", output_path)
  combined
}

if (combine_all_participants) {
  entries <- get_interest_area_csv_entries_from_results(results_dir, zip_pattern, participant_reports_pattern)
  ia <- combine_interest_area_reports(entries$paths, entries$sources, combined_output_csv)
} else {
  message("Reading interest-area report from: ", interest_area_csv)
  ia <- readr::read_csv(
    interest_area_csv,
    col_types = readr::cols(.default = readr::col_character()),
    show_col_types = FALSE
  )
}

message("Searching for items TSV files in: ", items_dir)
item_files <- list.files(items_dir, pattern = items_pattern, full.names = TRUE)

if (length(item_files) == 0) {
  stop("No items TSV files found in ", items_dir, " matching pattern ", items_pattern)
}

message("Found ", length(item_files), " items file(s):")
print(item_files)

read_items_file <- function(path) {
  message("Reading items file: ", path)
  df <- readr::read_tsv(path, show_col_types = FALSE)

  cn <- names(df)
  lower <- tolower(cn)

  # Item identifier: accept item_id (Provo) or ItemId
  if ("item_id" %in% lower) {
    itemid_col <- cn[match("item_id", lower)]
  } else if ("itemid" %in% lower) {
    itemid_col <- cn[match("itemid", lower)]
  } else {
    stop("Items file ", path, " must contain 'item_id' or 'ItemId'.")
  }

  # Word-level TSV (has word_index + word)?
  has_word_level <- ("word" %in% lower) && ("word_index" %in% lower || "wordindex" %in% lower)
  # Item-level TSV (Provo lists) has text column only
  has_text <- "text" %in% lower

  if (has_word_level) {
    word_index_col <- if ("word_index" %in% lower) cn[match("word_index", lower)] else cn[match("wordindex", lower)]
    word_col <- cn[match("word", lower)]
    line_col <- if ("line_number" %in% lower) cn[match("line_number", lower)] else NA_character_
    pil_col <- if ("position_in_line" %in% lower) cn[match("position_in_line", lower)] else NA_character_

    out <- df %>%
      transmute(
        ItemId = as.character(.data[[itemid_col]]),
        word_index = as.integer(.data[[word_index_col]]),
        word_from_items = as.character(.data[[word_col]]),
        line_number_from_items = if (!is.na(line_col)) as.character(.data[[line_col]]) else NA_character_,
        position_in_line_from_items = if (!is.na(pil_col)) as.character(.data[[pil_col]]) else NA_character_
      )
    return(out)
  }

  if (!has_text) {
    stop("Items file ", path, " must contain either word-level columns (word, word_index) or a 'text' column.")
  }

  # Item-level TSV: tokenize text into words, build word_index.
  text_col <- cn[match("text", lower)]
  out_list <- lapply(seq_len(nrow(df)), function(i) {
    txt <- df[[text_col]][i]
    if (is.na(txt) || as.character(txt) == "") return(NULL)
    words <- stringr::str_extract_all(as.character(txt), stringr::boundary("word"))[[1]]
    if (length(words) == 0) return(NULL)
    data.frame(
      ItemId = as.character(df[[itemid_col]][i]),
      word_index = seq_along(words),
      word_from_items = words,
      line_number_from_items = NA_character_,
      position_in_line_from_items = NA_character_,
      stringsAsFactors = FALSE
    )
  })
  dplyr::bind_rows(out_list)
}

items_list <- lapply(item_files, read_items_file)
items_all <- bind_rows(items_list) %>%
  distinct(ItemId, word_index, .keep_all = TRUE)

message("Joining items metadata onto interest-area report...")

# Build fallback lookup for line_number / position_in_line from observed clicks
# in the IA data itself (useful when item TSVs lack these columns).
line_pos_lookup <- ia %>%
  mutate(
    ItemId = as.character(ItemId),
    word_index = as.integer(word_index),
    line_number = as.character(line_number),
    position_in_line = as.character(position_in_line)
  ) %>%
  group_by(ItemId, word_index) %>%
  summarise(
    line_number_obs = {
      vals <- line_number[!is.na(line_number) & line_number != ""]
      if (length(vals) > 0) vals[[1]] else NA_character_
    },
    position_in_line_obs = {
      vals <- position_in_line[!is.na(position_in_line) & position_in_line != ""]
      if (length(vals) > 0) vals[[1]] else NA_character_
    },
    .groups = "drop"
  )

infer_line_pos_lookup <- function(ia_df, anchor_lookup) {
  items <- unique(as.character(ia_df$ItemId))
  out <- list()
  for (item in items) {
    idxs <- sort(unique(as.integer(ia_df$word_index[as.character(ia_df$ItemId) == item])))
    idxs <- idxs[!is.na(idxs)]
    if (length(idxs) == 0) next

    n <- max(idxs)
    ln <- rep(NA_integer_, n)
    pos <- rep(NA_integer_, n)

    anchors <- anchor_lookup %>%
      filter(ItemId == item) %>%
      mutate(
        word_index = as.integer(word_index),
        line_number_obs = suppressWarnings(as.integer(line_number_obs)),
        position_in_line_obs = suppressWarnings(as.integer(position_in_line_obs))
      ) %>%
      arrange(word_index)

    if (nrow(anchors) > 0) {
      for (k in seq_len(nrow(anchors))) {
        wi <- anchors$word_index[k]
        if (!is.na(wi) && wi >= 1 && wi <= n) {
          ln[wi] <- anchors$line_number_obs[k]
          pos[wi] <- anchors$position_in_line_obs[k]
        }
      }
    }

    # Forward pass: continue same line and increment position when missing.
    for (i in 2:n) {
      if (is.na(ln[i]) && !is.na(ln[i - 1])) ln[i] <- ln[i - 1]
      if (is.na(pos[i]) && !is.na(pos[i - 1])) pos[i] <- pos[i - 1] + 1L
    }
    # Backward pass: infer from next known token.
    if (n >= 2) {
      for (i in (n - 1):1) {
        if (is.na(ln[i]) && !is.na(ln[i + 1])) ln[i] <- ln[i + 1]
        if (is.na(pos[i]) && !is.na(pos[i + 1])) pos[i] <- pos[i + 1] - 1L
      }
    }
    # Clamp impossible positions.
    pos[pos < 1] <- 1L

    out[[length(out) + 1]] <- data.frame(
      ItemId = item,
      word_index = seq_len(n),
      line_number_infer = as.character(ln),
      position_in_line_infer = as.character(pos),
      stringsAsFactors = FALSE
    )
  }
  dplyr::bind_rows(out)
}

line_pos_infer <- infer_line_pos_lookup(ia, line_pos_lookup)

ia_joined <- ia %>%
  mutate(
    word_index = as.integer(word_index),
    ItemId = as.character(ItemId),
    line_number = as.character(line_number),
    position_in_line = as.character(position_in_line)
  ) %>%
  left_join(items_all, by = c("ItemId", "word_index")) %>%
  left_join(line_pos_lookup, by = c("ItemId", "word_index")) %>%
  left_join(line_pos_infer, by = c("ItemId", "word_index")) %>%
  mutate(
    word = if_else(is.na(word) | word == "", word_from_items, word),
    line_number = if_else(
      (is.na(line_number) | line_number == "") & !is.na(line_number_from_items),
      as.character(line_number_from_items),
      as.character(line_number)
    ),
    line_number = if_else(
      (is.na(line_number) | line_number == "") & !is.na(line_number_obs),
      as.character(line_number_obs),
      as.character(line_number)
    ),
    position_in_line = if_else(
      (is.na(position_in_line) | position_in_line == "") & !is.na(position_in_line_from_items),
      as.character(position_in_line_from_items),
      as.character(position_in_line)
    ),
    position_in_line = if_else(
      (is.na(position_in_line) | position_in_line == "") & !is.na(position_in_line_obs),
      as.character(position_in_line_obs),
      as.character(position_in_line)
    ),
    line_number = if_else(
      (is.na(line_number) | line_number == "") & !is.na(line_number_infer),
      as.character(line_number_infer),
      as.character(line_number)
    ),
    position_in_line = if_else(
      (is.na(position_in_line) | position_in_line == "") & !is.na(position_in_line_infer),
      as.character(position_in_line_infer),
      as.character(position_in_line)
    )
  ) %>%
  select(
    -word_from_items,
    -line_number_from_items,
    -position_in_line_from_items,
    -line_number_obs,
    -position_in_line_obs,
    -line_number_infer,
    -position_in_line_infer
  )

message("Writing filled interest-area report to: ", output_csv)
readr::write_csv(ia_joined, output_csv, na = "")

message("Done. Filled interest-area report saved at: ", output_csv)

