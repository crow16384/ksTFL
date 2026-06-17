args <- commandArgs(trailingOnly = FALSE)
file_arg <- args[grepl("^--file=", args)]
if (length(file_arg) != 1L) {
  stop("Unable to determine script path")
}

script_path <- normalizePath(sub("^--file=", "", file_arg), mustWork = TRUE)
repo_dir <- normalizePath(file.path(dirname(script_path), ".."), mustWork = TRUE)
source_dir <- file.path(repo_dir, "vignettes")
doc_dir <- file.path(repo_dir, "doc")

unlink(doc_dir, recursive = TRUE, force = TRUE)
dir.create(doc_dir, recursive = TRUE, showWarnings = FALSE)

copy_recursive <- function(from, to) {
  dir.create(dirname(to), recursive = TRUE, showWarnings = FALSE)
  ok <- file.copy(from, to, recursive = TRUE, copy.date = TRUE)
  if (!all(ok)) {
    stop("Failed to copy ", from, " to ", to)
  }
}

keep_ext <- c(".html", ".Rmd", ".css", ".pdf", ".R")
source_files <- list.files(source_dir, full.names = TRUE, no.. = TRUE)

for (path in source_files) {
  name <- basename(path)
  dest <- file.path(doc_dir, name)
  if (dir.exists(path) && name %in% c("images", "figures")) {
    copy_recursive(path, dest)
  } else if (file.exists(path) && tolower(tools::file_ext(path)) %in% sub("^\\.", "", keep_ext)) {
    copy_recursive(path, dest)
  }
}

cat("Local vignette help synced to", doc_dir, "\n")
