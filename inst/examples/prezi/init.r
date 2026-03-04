
devtools::load_all()
suppressPackageStartupMessages({
  library(tidyr)
  library(dplyr)
  library(tibble)
  library(stringr)
  library(stringi)
  library(tictoc)
})

data.path <- file.path(curr_path, 'structures')
out_dir  <- file.path(data.path, "..", "output")
dir.create(out_dir, showWarnings = FALSE, recursive = TRUE)
meta_dir <- file.path(out_dir, "meta")
dir.create(meta_dir, showWarnings = FALSE, recursive = TRUE)

##############################################################
# Определение глобальных параметров для репортов
##############################################################

tfl_reset_options() #сброс настроек пакета к дефолтным

tfl_set_options(
  # Определяем глобальные Header и Footers документа
  add_header(c("KeyStat LLC." , "CONFIDENTIAL", "Page {PAGE} of {NUMPAGES}")),
  add_header("Study: Miracle Drug 001"),
  add_footer(c("<i>Example Outputs</i>", "<i>For presentation purposes</i>")), #Два значения: будут мощены справа и слева.
  add_footer(c("Program: some_program.R")),
  #Задаем директорию вывода по умолчанию
  output_directory = out_dir
)

#########


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



