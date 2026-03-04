curr_path <- file.path(getwd(),"inst", "examples", "prezi");

source(file.path(curr_path, 'init.r'))

source(file.path(data.path, 'lb_lst_01.r')) 

spec_lbl_01 <- create_table(data) %>% 
  add_title(c("Перечень 16.1", "Лабораторные показатели<sup> Бла бла</sup> ❌"), toclevel = 1) %>% 
  add_subtitle("Пациент: #ByGroup1, Пол: #ByGroup2, Возраст: #ByGroup3", toclevel = 2) %>% 
  add_footnote('* - Значение за границой нормы') %>% 
  define_cols(c(col_01, col_02, col_03), isVisible = F, isGrouping = T) %>% #ISSUE: when isGrouping is active the TOC entries are repeated for every break - TOC entry must appear only once per unique title/subtitle
  define_cols(!starts_with('col_'), labelStyleRef = f_combine('to_90','al', 'va_t', 'indent_1')) %>% 
  define_cols(PH, isColBreak = T) %>%
  
  #ISSUE: When define_cols is called several times (as two calls below) the specified properties and styles should be merged with last-win strategy for matching columms.
  #i.e. in this case for col_04, col_05 the combined style 'indent_1' + 'i' should be created, similar to what the f_combine does. Think about best possible logic!
  define_cols(c(col_04, col_05, col_06), isID = T, valueStyleRef = 'indent_1') %>% 
  define_cols(c(col_04, col_05), valueStyleRef = 'i') %>% 
  
  define_cols(col_06,colWidth = '10%') %>% 
  define_cols(7:15,
              colWidth = '6%',
              label = c('Билирубин','Глюкоза','Кетоны','Нитриты','pH','Белок',
                        'Эритроциты','Удельная<br>плотность<br>мочи', 'Лейкоциты'), 
              ) %>% 
  compute_cols(
    (as.numeric(PH) >5) %>% replace_na(F),
    c_style(PH, styleRef = 'fc_red'),
    c_glue(PH, 'after', text = '➕')
  ) %>% 
  compute_cols(
    firstOf(col_01),
    ##ISSUE: Adding add row action breaks the table when isGrouping is active:
    #1) Table layout is completely broken + rows height is not auto-adjusted for wrapped values in cells.
    #2) #byGorupX in subtitles stop working
    #3) Added row incorrectly split across pages when group changes. Added row should remain on the same page where its parent row.
    c_addrow('above', value_from = col_01, styleRef = 'b') 
  )


r_lbl_01 <- create_report(spec_lbl_01)
write_doc(r_lbl_01, "listing_16_1", toc = T)

print(spec_lbl_01)

print(spec_lbl_01)

