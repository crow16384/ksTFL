suppressPackageStartupMessages({
  #library(ksTFL)
  devtools::load_all()
  library(dplyr)
  library(tidyr)
  library(tibble)
  library(stringr)
  library(purrr)
  library(httr2)
})

out_dir <- file.path(getwd(), "tmp", "showcase_output")
dir.create(out_dir, recursive = TRUE, showWarnings = FALSE)
meta_dir <- file.path(out_dir, "meta")
dir.create(meta_dir, recursive = TRUE, showWarnings = FALSE)

tfl_reset_options()
tfl_set_options(
  add_header(c("CRO Example LLC.", "CONFIDENTIAL", "Page {PAGE} of {NUMPAGES}")),
  add_header("Study: Miracle Drug 001"),
  add_footer(c("Showcase examples", "Program: inst/examples/showcase")),
  output_directory = out_dir,
  footnotePlace = "repeated",
  meta_directory = file.path(out_dir, "meta")
)

cat("Showcase output:", out_dir, "\n")

aligndec <- function(var, na.rep="", indent=0) {
  var <- replace_na(as.character(var), na.rep)
  pos1 <- str_locate(var,"^[\\[\\]\\(\\)A-Za-zА-Яа-я\\+\\-=<> ]*\\d*[.| |,|;]")[,"end"] #определяем положение точки или первого пробела.
  var[is.na(pos1)] <- paste0(var[is.na(pos1)], " ") #если точка\пробел не найдены, то добавляем пробел в конец для выравнивания по нему
  
  lens <- str_length(var) #вычисляем длинну компонентов
  allpos <- coalesce(pos1, lens) #для тех компонентов в которых мы не нашли точку\пробел заменяем позицию на длину.
  left <- str_sub(var,0, allpos) #левая часть строки до точки
  right <- str_sub(var, allpos+1) #правая часть строки после точки
  llen <- str_length(left) 
  llenm <- max(llen, na.rm = T) #максимальная длина левой части для padding
  
  trimws(sprintf("%s%s%s", paste(rep(" ", indent),collapse = ''), format(left, width = llenm, justify = 'right'), right), which = 'right')
  
}

