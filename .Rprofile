options(pkgdown.internet = FALSE)

# Use PNG device with optional Cairo backend so knitr figure output works headless.
if (requireNamespace("knitr", quietly = TRUE)) {
  knitr::opts_chunk$set(
    dev = "png",
    dev.args = if (capabilities("cairo")) list(type = "cairo") else NULL
  )
}

# When building the pkgdown site, downlit calls tools::CRAN_package_db() via
# its internal CRAN_urls() to resolve hyperlinks for packages not installed
# locally.  In a firewalled / offline environment this times out.
# Patch the inner function of the memoised CRAN_urls to return an empty
# data frame immediately, so downlit skips the CRAN lookup entirely.
if (requireNamespace("downlit", quietly = TRUE)) {
  local({
    f_memo <- utils::getFromNamespace("CRAN_urls", "downlit")
    env    <- environment(f_memo)
    # Replace the memoised inner function with a no-op that returns an empty
    # data frame matching the structure CRAN_package_db() would return.
    env[["_f"]] <- function() data.frame(Package = character(0), URL = character(0),
                                          stringsAsFactors = FALSE)
    # Also clear the memo cache so any prior result is discarded.
    tryCatch(env[["_cache"]]$reset(), error = function(e) NULL)
  })
}
