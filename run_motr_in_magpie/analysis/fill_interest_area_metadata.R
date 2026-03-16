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

# Path to the interest-area CSV exported by the browser.
interest_area_csv <- "Results/interest_area_report.csv"

# Directory containing the Provo items TSV files.
items_dir <- "provo/trials"

# Pattern matching the items TSV files.
items_pattern <- "^provo_items_.*\\.tsv$"

# Output CSV path.
output_csv <- "Results/interest_area_report_filled.csv"

## --------------------------------------------------------------------- ##

suppressWarnings({
  if (!requireNamespace("dplyr", quietly = TRUE)) install.packages("dplyr")
  if (!requireNamespace("readr", quietly = TRUE)) install.packages("readr")
  if (!requireNamespace("stringr", quietly = TRUE)) install.packages("stringr")
})

library(dplyr)
library(readr)
library(stringr)

message("Reading interest-area report from: ", interest_area_csv)
ia <- readr::read_csv(interest_area_csv, show_col_types = FALSE)

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

  # Try to standardize column names: ItemId, word_index, word, line_number, position_in_line
  cn <- names(df)
  lower <- tolower(cn)

  # ItemId
  if (!"itemid" %in% lower) {
    stop("Items file ", path, " must contain a column for ItemId (e.g., 'ItemId').")
  }
  itemid_col <- cn[match("itemid", lower)]

  # word_index
  if ("word_index" %in% lower) {
    word_index_col <- cn[match("word_index", lower)]
  } else if ("wordindex" %in% lower) {
    word_index_col <- cn[match("wordindex", lower)]
  } else {
    stop("Items file ", path, " must contain a column for word index (e.g., 'word_index' or 'WordIndex').")
  }

  # word
  if ("word" %in% lower) {
    word_col <- cn[match("word", lower)]
  } else {
    stop("Items file ", path, " must contain a 'word' column.")
  }

  # line_number (optional)
  line_col <- if ("line_number" %in% lower) cn[match("line_number", lower)] else NA_character_

  # position_in_line (optional)
  pil_col <- if ("position_in_line" %in% lower) cn[match("position_in_line", lower)] else NA_character_

  out <- df %>%
    transmute(
      ItemId = .data[[itemid_col]],
      word_index = as.integer(.data[[word_index_col]]),
      word_from_items = .data[[word_col]],
      line_number_from_items = if (!is.na(line_col)) .data[[line_col]] else NA,
      position_in_line_from_items = if (!is.na(pil_col)) .data[[pil_col]] else NA
    )

  out
}

items_list <- lapply(item_files, read_items_file)
items_all <- bind_rows(items_list) %>%
  distinct(ItemId, word_index, .keep_all = TRUE)

message("Joining items metadata onto interest-area report...")

ia_joined <- ia %>%
  mutate(
    word_index = as.integer(word_index),
    ItemId = as.character(ItemId)
  ) %>%
  left_join(items_all, by = c("ItemId", "word_index")) %>%
  mutate(
    word = if_else(is.na(word) | word == "", word_from_items, word),
    line_number = if_else(
      (is.na(line_number) | line_number == "") & !is.na(line_number_from_items),
      line_number_from_items,
      line_number
    ),
    position_in_line = if_else(
      (is.na(position_in_line) | position_in_line == "") & !is.na(position_in_line_from_items),
      position_in_line_from_items,
      position_in_line
    )
  ) %>%
  select(-word_from_items, -line_number_from_items, -position_in_line_from_items)

message("Writing filled interest-area report to: ", output_csv)
readr::write_csv(ia_joined, output_csv)

message("Done. Filled interest-area report saved at: ", output_csv)

