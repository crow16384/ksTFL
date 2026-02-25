FROM rocker/verse:latest

# Install C++ renderer system dependencies
RUN apt-get update && apt-get install -y --no-install-recommends \
    libharfbuzz-dev \
    libfreetype-dev \
    libminizip-dev \
    pkg-config \
    && rm -rf /var/lib/apt/lists/*

# Set Russian CRAN mirror globally
RUN echo 'options(repos = c(CRAN = "https://mirror.truenetwork.ru/CRAN/"))' \
    >> /usr/local/lib/R/etc/Rprofile.site

# Install ksTFL dependencies (Imports + Suggests)
RUN install2.r --error --skipinstalled \
    cli \
    checkmate \
    jsonlite \
    purrr \
    rlang \
    tidyselect \
    digest \
    htmltools \
    rstudioapi \
    testthat \
    knitr \
    rmarkdown \
    Rcpp \
    RcppArmadillo

WORKDIR /home/rstudio/ksTFL
