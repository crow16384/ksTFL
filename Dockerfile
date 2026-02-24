FROM rocker/verse:latest

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
