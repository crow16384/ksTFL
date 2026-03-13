source(file.path(getwd(),'inst','examples','showcase','structures','dummy_data.R'))
source(file.path(getwd(),'inst','examples','showcase','structures','lb_lst_01.r')) 

spec_lbl_01 <- create_table(data) %>% 
  add_title(c("Перечень 16.1", "Лабораторные показатели<sup> Бла бла</sup> ❌"), toclevel = 1) %>% 
  add_subtitle("Пациент: #ByGroup1, Пол: #ByGroup2, Возраст: #ByGroup3", toclevel = 2) %>% 
  add_footnote('* - Значение за границой нормы') %>% 
  define_cols(c(col_01, col_02, col_03), isVisible = F, isGrouping = T) %>% 
  define_cols(!starts_with('col_'), labelStyleRef = f_combine('al', 'va_t', 'to_90', 'indent_1')) %>% 
  #define_cols(PH, isColBreak = T) %>%
  define_cols(c(col_04, col_05, col_06), isID = T, valueStyleRef = 'indent_1') %>% 
  define_cols(c(col_04, col_05), valueStyleRef = 'i') %>% 
  add_span_header(9:13, label = "Test span header 1") %>% 
  define_cols(col_06,colWidth = '10%') %>% 
  define_cols(7:15,
              colWidth = '6%',
              label = c('Билирубин','Глюкоза','Кетоны','Нитриты','pH','Белок',
                        'Эритроциты','Удельная плотность<br>мочи', 'Лейкоциты'), 
  ) %>% 
  compute_cols(
    (as.numeric(PH) >5) %>% replace_na(F),
    c_style(PH, styleRef = 'fc_red'),
    c_glue(PH, 'after', text = '➕')
  ) %>% 
  compute_cols(
    firstOf(col_01),
    c_addrow('above', value_from = col_01, styleRef = 'b') 
  ) %>% set_document(docTemplate = 'Listings')

spec_lbl_02 <- spec_lbl_01 %>% 
  add_span_header(7:15, label = "Test span header 2", labelStyleRef = 'ac')

r_lbl_01 <- create_report(spec_lbl_01)
r_lbl_02 <- create_report(spec_lbl_02)

write_doc(r_lbl_01, "listing_16_1.1", toc = T)
write_doc(r_lbl_02, "listing_16_1.2", toc = T)


