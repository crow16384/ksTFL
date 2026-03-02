
#library(ksTFL)
devtools::load_all()
suppressPackageStartupMessages({
  library(tidyr)
  library(dplyr)
  library(tibble)
  library(stringr)
  library(stringi)
  library(tictoc)
})

out_dir  <- file.path(getwd(), "tmp", "output")
dir.create(out_dir, showWarnings = FALSE, recursive = TRUE)
meta_dir <- file.path(out_dir, "meta")
dir.create(meta_dir, showWarnings = FALSE, recursive = TRUE)

cat("Output directory:", out_dir, "\n")

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

#############################################
##Common doc headers/footers
tfl_reset_options()
tfl_set_options(
  add_header(c("Miracle Drug" , "CONFIDENTIAL", "KeyStat LLC.")),
  add_footer(c("Test Outputs", "Page {PAGE} of {NUMPAGES}")),
  add_footer(c("Program: test_03.R")),
  output_directory = out_dir
)
###########################
