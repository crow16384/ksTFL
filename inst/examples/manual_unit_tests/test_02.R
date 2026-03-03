###TEST 02 Unit

### TEST 02_01 ####
spec_02_01 <- create_table(ae_tbl_01) %>% 
  add_title(c("Table 2.1 AESI by SOC and PT", "Safety Population")) %>% 
  add_title(c("(Test unit 02)"), styleRef = "font_italic") %>% 
  add_footnote(c("This is the test unit 02 01", "Second line of footnote")) %>% 
  define_cols(c(pt, starts_with('trt_')),
              label = c("AESI<br>  MedDRA SOC<br>    MedDRA Preferred Term", "n (%)", 
                        "Events", "n (%)", "Events")) %>%
  add_span_header(starts_with('trt_a'), label = 'Miracle Drug A<p>(N=100)') %>% 
  add_span_header(starts_with('trt_b'), label = 'Miracle Drug B<p>(N=90)', stubOrder = 1) %>% 
  add_span_header(starts_with('trt'), label = 'Miracle Treatments', stubOrder = 2) %>%
  define_cols(c(category, soc), isVisible = F) %>% 
  define_cols(pt, labelStyleRef = "text_left") %>% 
  define_cols(starts_with('trt_'), valueStyleRef = 'indent_2') %>% 
  compute_cols(firstRow(), c_addrow('above')) %>% 
  compute_cols(lastRow(),  c_addrow('below')) %>% 
  compute_cols(
    firstOf(category),
    c_addrow("above", value_from = category, styleRef = "font_bold")
  ) %>% 
  compute_cols(
    firstOf(category, soc),
    c_addrow("above", value_from = soc, styleRef = f_combine("font_bold", "indent_1"))
  ) %>% 
  compute_cols(
    !is.na(pt),
    c_style(pt, "indent_2")
  ) 
  
create_report(spec_02_01) %>% write_doc("test_02_01",metaPath = meta_dir)


### TEST 02_02 ####
ae_tbl_02_01 <- ae_tbl_02 %>% 
  mutate(across(starts_with('trt_'), aligndec),
         trt_a_e = if_else(trt_a_e>20, paste0(trt_a_e,'<sup>a</sup>'), as.character(trt_a_e)),
         trt_b_e = if_else(trt_b_e>20, paste0(trt_b_e,'<sup>a</sup>'), as.character(trt_b_e)),
         spacing = NA_character_
         ) %>% 
   relocate(category, soc, pt, trt_a_npct, trt_a_e, spacing, trt_b_npct, trt_b_e)

spec_02_02 <- create_table(ae_tbl_02_01) %>% 
  ##style for thin row height for separator between groups
  add_style(id = "separator",
            s_table_style(row_height = "5pt")) %>% ##Issue - row_height for table row is not respected.
  add_title(c("Table 2.2 AESI by SOC and PT", "Safety Population")) %>% 
  add_subtitle(c("(Test unit 02)"), styleRef = "font_italic") %>% 
  #add_footnote(c("This is <sup>the</sup> <b>test</b> unit 02 02, a < b > c, x < 5, x > 3")) %>% 
  add_footnote(c("This is the test unit 02 02, <b>k < b</b>, a<b, a > 4, x>5  >🐈")) %>% 
  add_footnote(c("<sup>a</sup> Number of events exceeds 20 (> 20) 10<sup>3</sup>/>\u0298L"), styleRef = 'text_red') %>% 
  define_cols(c(pt, starts_with('trt_')),
              label = c("AESI<br>  MedDRA SOC<br>    MedDRA Preferred Term", "n (%)", 
                        "Events", "n (%)", "Events")) %>%
  add_span_header(starts_with('trt_a'), label = 'Miracle Drug A<p>(N=100)') %>% 
  add_span_header(starts_with('trt_b'), label = 'Miracle Drug B<p>(N=90)', stubOrder = 1) %>% 
  define_cols(c(category, soc), isVisible = F) %>% 
  define_cols(spacing, colWidth = '0.2cm', label = ' ') %>% 
  define_cols(pt, labelStyleRef = "text_left") %>% 
  define_cols(contains('_e'), colWidth = '8%') %>% 
  define_cols(contains('_npct'), colWidth = '13%') %>% 
  define_cols(contains('trt_'), valueStyleRef = 'indent_1') %>% 
  compute_cols(lastRow(),  c_addrow('below',styleRef = 'separator')) %>% 
  compute_cols(
    firstOf(category),
    c_merge(c(category, soc, pt), styleRef = 'font_bold'),
    c_addrow('above',styleRef = 'separator')
  ) %>% 
  compute_cols(
    !is.na(soc) & is.na(pt),
    c_merge(c(soc,pt), styleRef = f_combine("font_bold", "indent_1"))
  ) %>% 
  compute_cols(
    !is.na(pt),
    c_style(pt, "indent_2")
  ) %>% 
  ##just for fun :)
  compute_cols(
    str_detect(trt_a_e, 'sup'),
    c_style(trt_a_e, f_combine("text_red","font_bold"))
  ) %>% 
  compute_cols(
    str_detect(trt_b_e, 'sup'),
    c_style(trt_b_e, f_combine("text_red","font_bold"))
  ) %>% 
  set_document(contentWidth = '80%')

create_report(spec_02_02) %>% write_doc("test_02_02",metaPath = meta_dir)


### TEST 02_03 ####
spec_02_03 <- create_table(vitals_tbl_01_02) %>% 
  add_title(c("Таблица 2.3 Жизненные Показатели", "Популяция Безопасности")) %>% 
  add_subtitle(c("Test unit 02 03")) %>% 
  add_footnote(c("This is the test unit 02 03")) %>% 
  compute_cols(
    firstOf(parameter),
    c_addrow('above', value_from = parameter, styleRef = 'font_bold')
  ) %>% 
  compute_cols(
    firstOf(parameter, analysis),
    c_addrow('above', value_from = analysis, styleRef = 'indent_1')
  ) %>% 
  define_cols(c(stat, starts_with('trt_')), colWidth = c('40%','10%','10%')) %>% 
  define_cols(stat, valueStyleRef = 'indent_2', labelStyleRef = 'text_left') %>%
  define_cols(c(parameter, analysis), isVisible = F) %>% 
  set_document(contentWidth = '80%')

create_report(spec_02_03) %>% write_doc("test_02_03",metaPath = meta_dir)
