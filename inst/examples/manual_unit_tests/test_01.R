#### TEST 01_01 ####
spec_01_01 <- create_table(demography_tbl_01) %>% 
           add_title(c("Demographics Table", "Safety Population")) %>% 
           add_title(c("Third separate title"), styleRef = "font_italic") %>% 
           add_footnote(c("This is the test unit 01 01", "Second line of footnote")) %>% 
           define_cols(c(value, stat, trt_a, trt_b, trt_c),
                       label = c("Parameter<br>  Value", "Statistics", 
                                  "Miracle Drug 1<p>(N=100)", "Miracle Drug 2<p>(N=100)", "Placebo<p>(N=100)")) %>% 
           define_cols(param, isVisible = F) %>% 
           define_cols(value, labelStyleRef = "text_left") %>% 
           compute_cols(
             firstOf(param),
             c_addrow("above", value_from = param, styleRef = "font_bold")
           )

create_report(spec_01_01) %>% write_doc("test_01_01",metaPath = meta_dir)

### TEST 01_02 ####
spec_01_02 <- create_table(demography_tbl_01) %>% 
  add_title(c("Demographics Table", "Safety Population")) %>% 
  add_title(c("Third separate title"), styleRef = "font_italic") %>% 
  add_footnote(c("This is the test unit 01 02", "Second line of footnote")) %>% 
  define_cols(c(value, stat, trt_a, trt_b, trt_c),
              label = c("Parameter<br>  Value", "Statistics", 
                        "Miracle Drug 1<p>(N=100)", "Miracle Drug 2<p>(N=100)", "Placebo<p>(N=100)")) %>% 
  define_cols(param, isVisible = F) %>% 
  define_cols(value, labelStyleRef = "text_left") %>% 
  compute_cols(
    firstOf(param),
    c_merge(c(param, value))
  )

create_report(spec_01_02) %>% write_doc("test_01_02")


### TEST 01_03 ####
#same as TEST 01_02 but with additional styling
spec_01_03 <- create_table(demography_tbl_01) %>% 
  add_title(c("Demographics Table", "Safety Population")) %>% 
  add_title(c("Third separate title"), styleRef = "font_italic") %>% 
  add_footnote(c("This is the test unit 01 03", "Second line of footnote")) %>% 
  define_cols(c(value, stat, trt_a, trt_b, trt_c),
              label = c("Parameter<br>  Value", "Statistics", 
                        "Miracle Drug 1<br>(N=100)", "Miracle Drug 2<br>(N=100)", "Placebo<br>(N=100)")) %>% 
  define_cols(c(trt_a, trt_b, trt_c), valueStyleRef = 'text_center') %>% 
  define_cols(param, isVisible = F) %>% 
  define_cols(value, labelStyleRef = "text_left", colWidth = '5cm') %>% 
  compute_cols(
    firstOf(param),
    c_merge(c(param, value), styleRef = 'font_bold')
  ) %>% 
  compute_cols(
    !is.na(value),
    c_style(value, styleRef = 'indent_1')
  ) %>% set_document(contentWidth = '70%')

#print(spec_01_03) ####
create_report(spec_01_03) %>% write_doc("test_01_03",metaPath = meta_dir)

