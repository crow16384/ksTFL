
curr_path <- file.path(getwd(),"tmp", "prezi");

source(file.path(curr_path, 'init.r'))

source(file.path(data.path, 'ae_tbl_01.r')) 

#############################################################
# Простая таблица НЯ
#############################################################

#  AESOC                       AEDECOD                OKZL_rate_c OKZH_rate_c OKZA_rate_c PLA_rate_c OKZL_rd              OKZH_rd       OKZA_rd
#   <chr>                       <chr>                  <chr>       <chr>       <chr>       <chr>      <chr>                <chr>         <chr>  
# 1 At Least One AESI           ""                     171 (21.3)  145 (19.1)  316 (20.2)  101 (23.5) -2.22 [-7.13, 2.52]  -4.26 [-9.14… -3.17 …
# 2 Infections and infestations ""                     171 (21.3)  145 (19.1)  316 (20.2)  101 (23.5) -2.22 [-7.13, 2.52]  -4.26 [-9.14… -3.17 …
# 3 Infections and infestations "Abdominal abscess"    0 (0)       1 (0.1)     1 (0.1)     0 (0)      --                   0.12 [-0.74,… 0.06 […
# 4 Infections and infestations "Abscess limb"         2 (0.2)     0 (0)       2 (0.1)     0 (0)      0.23 [-0.65, 0.9]    --            0.11 […
# 5 Infections and infestations "Acute sinusitis"      2 (0.2)     1 (0.1)     3 (0.2)     1 (0.2)    -0.01 [-1.08, 0.68]  -0.11 [-1.17… -0.06 …
# 6 Infections and infestations "Bacterial vaginosis"  0 (0)       1 (0.1)     1 (0.1)     0 (0)      --                   0.12 [-0.74,… 0.06 […
# 7 Infections and infestations "Body tinea"           0 (0)       1 (0.1)     1 (0.1)     2 (0.5)    -0.47 [-1.66, -0.01] -0.35 [-1.55… -0.4 […
# 8 Infections and infestations "Breast abscess"       1 (0.1)     0 (0)       1 (0.1)     0 (0)      0.12 [-0.74, 0.73]   --            0.06 […
# 9 Infections and infestations "Bronchitis"           8 (1)       13 (1.8)    21 (1.4)    9 (2.2)    -1.23 [-3.15, 0.11]  -0.36 [-2.29… -0.75 …
#10 Infections and infestations "Bronchitis bacterial" 1 (0.1)     0 (0)       1 (0.1)     0 (0)      0.11 [-0.76, 0.7]    --            0.05 […


### формируем объект спецификации

spec_ae_01 <- create_table(data %>% head(n=35), #параметр cols опциональный. При необходимости позволяет выбрать нужные колонки в нужном для репорта порядке.
                            #можно также указать data как выражение [к примеру data %>% select(<cols>)], но есть нюанс. Но такой подход лучше не использовать,
                            #т.к. в этом случает в объекте будет создана новая копия данных, вместо теневой ссылки на исходный датасет.
                      cols = c(AESOC, AEDECOD, OKZL_rate_c, OKZH_rate_c, OKZA_rate_c, PLA_rate_c, OKZL_rd, OKZH_rd, OKZA_rd)) %>% 
  #Определяем заголовки таблицы.
  #Заголовки заданные внутри одной функции как c('xx',xx',...) будут отображены как один параграф, но с переносом строки
  add_title(c("Table 1.1", 
              "Adverse Events of Special Interest (Defined by Sponsor’s PT) by System Organ Class (SOC) and Preferred Term (PT): Infections. Placebo-Controlled Period. Pool #2a."),
             #toclevel - опциональный параметр. Сообщает движку рендера о том, что данный заголовок должен быть помечен как кандидат для Оглавления.
             toclevel = 1) %>% 
  #следующий вызов add_titles добавляет новый параграф.
  #styleRef определяет имя стиля. Есть стили предопределенные пакетом, которые можно комбинировать, 
  #                               а так же можно определять стиль с помощью функции add_style() самомстоятельно (читаем доки)
  add_title("Safety Population",styleRef = 'font_italic') %>% 
  #Добавляем футноты. логика точно такая же как и для заголовков
  add_footnote("Abbreviations: AE, adverse event; AESI, adverse event of special interest; CI, confidence interval; OKZ, Olokizumab; N, number of patients in treatment arm; n, number of patients with at least one adverse event",
               styleRef = "tw_70") %>% 
  add_footnote(c("Note: MedDRA version 25.1", "Note: OKZ Low dose = Olokizumab sc 64 mg q4w", "Note: OKZ High dose = Olokizumab sc 64 mg q2w"),
               styleRef = "tw_70") %>% 
  # Определяем атрибуты колонок
  # Мы хотим чтобы AESOC, AEDECOD в нашей таблице отображались в одной колонке, где значение из AESOC будет отображаться как заголовок единожды для группы AEDECOD.
  # для этого мы устанавливаем для AESOC параметр isVisible=F, что делает колонку невидимой в документе
  define_cols(AESOC, isVisible = F) %>% 
  #для колонки AEDECOD определяем заголовок и выравниваем его влево
  define_cols(AEDECOD, label = 'System Organ Class<br>  Preferred Term', labelStyleRef = 'text_left') %>%  #тег <br> определяет перенос строки
  #определяем заголовки для остальных колонок. define_cols() позволяет делать это как отдельно для выбраной колонки (как выше), так и для группы колонок:
  define_cols(
    c(OKZL_rate_c, OKZH_rate_c, OKZA_rate_c, PLA_rate_c),
    label = c("OKZ Low Dose<br>(N=782)<br>n(%)", "OKZ High Dose<br>(N=742)<br>n(%)", "OKZ All Doses<br>(N=1524)<br>n(%)", "Placebo<br>(N=454)<br>n(%)"),
    #Задаем ширину колонок при необходимости. (Подробнее см. ниже)
    colWidth = "8%" #можно указать одно значение. оно будет установлено для всех перечисленных колонок
  ) %>% 
  #для обращения к колонкам во всех функциях пакет поддерживает синтаксих tidyselect. Для примера зададим названия оставшихся колонок так:
  define_cols(
    ends_with('_rd'), #колонки название которых заканчивется на _rd
    label = c("OKZ Low Dose", "OKZ High Dose","OKZ All Doses"), #Нужно только понимать, что количество элементов вектора должно совпадать с количеством выбранных колонок!
    colWidth = "15%"
  ) %>% 
  ##Дополнительно выравняем колонки со значениями по центру
  ##Дополнительные вызовы define_cols() со ссылкой на те же колонки не переопределяет их полностью, а лишь дополняет новыми данными
  define_cols(c(ends_with('_rd'), ends_with('_c')), valueStyleRef = 'text_center') %>% 
  #Далее определим общие заголовки для групп колонок.
  add_span_header(
    ends_with('_rate_c'),
    label = 'Rates'      
  ) %>% 
  add_span_header(
    ends_with('_rd'),
    label = 'Risk difference (%) vs Placebo (95% CI)',
     #ВАЖНО: если мы хотим сделать два общих заголовка на одном уровне, то нужно явно указать stubOrder параметр.
     # в противном случае каждый новый вызов add_span_header() будет создавать новый уровень общего заголовка в таблице.
    stubOrder = 1 #Здесь мы даем понять пакету, что наши два заголовка располагаются на одном горизонтальном уровне.
  ) %>% 
  #Далее определяем правила вывода значений категорий. все модификации значений в ячейках производятся с помощью compute_cols()
  compute_cols(
    #в нашем примере данных значение колонки AEDECOD является пустой строкой там, где мы хотим видить значение AESOC.
    #поэтому выражение будет простым:
    AEDECOD == "", #для строк таблицы где указанное выражение истинно будут применяться правила перечисляемые в виде функций с префиксом `c_`
    #фунция c_merge() указывает пакету объеденить перечисленные колонки в одну и поместить в таблицу значение первой из перечисленных колонок.
    #не смотря на то, что колонка AESOC скрыта из нашего репорта, ее значение может быть использовано:
    c_merge(c(AESOC,AEDECOD)) 
  ) %>% 
  #Предположим, что дополнительно мы хотим выделить значения на строке 'At Least One AESI' жирным курсивом:
  compute_cols(
    AESOC == "At Least One AESI",
    #функия c_style() определяет стиль для ячеек на строках где условие выше истинно.
    #стили, как встроенные так и созданные через add_style() могут комбинироваться. 
    # Если мы хотим жирный курсив, то не нужно определять новый стиль 'bold_italic' - можно просто перечислить стили комбинацию которых мы хотим получить.
    # для этого в пакете используется фунция f_combine()
    c_style(AEDECOD, styleRef = f_combine('font_italic', 'font_bold')) 
     ##c_style(everything(), styleRef = f_combine('font_italic', 'font_bold')) #А можем вот так выделить всю строку указав everything() т.е. все колонки. Или перечислив нужные по именам
  ) %>% 
  #далее мы хотим сделать отступ реальных значений AEDECOD, чтобы указать их принадлежность к конкретному AESOC 
  compute_cols(
    AEDECOD != "", #все строки где AEDECOD не пустой...
    #... будут иметь отступ. `indent_1`, `indent_2` и т.д. встроенные стили которые задают стандартный отступ MS Word. _1 - 5мм, _2 - 10мм и т.д.
    #таким образом нет необходимости вставлять лидирующие пробелы в значение в данных.
    c_style(AEDECOD, styleRef = 'indent_1') 
  ) %>% 
  ## для дальнейшей стилизации, можем, к примеру вставить пустую строку под заголовком таблицы.
  compute_cols(
    #firstRow() встроенная функция helper указывающая на первую строку в таблице. 
    #так же есть и другие вспомогательные встроенные функции [lastRow, firstOf, lastOf, rowNumber, everyNth, firstOfBlock] - см. документацию.
    firstRow(), 
    #c_addrow() добавляет строку выше или ниже текущей, заданной условием. 
    #Добавленная строка также может содержать значение из текущей строки переданное в параметре value_from, а также ссылку на стиль
    c_addrow('above') #в данном случае мы просто добавляем пустую строку выше
  ) %>% 
  define_cols(OKZL_rd, isColBreak = T) %>% 
  define_cols(c(AESOC,AEDECOD), isID = T)

# Repeated footer
spec_ae_01_rep <- spec_ae_01 %>% set_document(footnotePlace = "repeated",contentWidth = "70%")
spec_ae_01_docfoot <- spec_ae_01 %>% set_document(footnotePlace = "doc_footer", contentWidth = "60%")
spec_ae_01_lp <- spec_ae_01 %>% set_document(footnotePlace = "last_page", contentWidth = "80%")

# создаем объект репорта из спецификации выше
create_report(spec_ae_01_rep) %>% write_doc("table_1_1_rep",metaPath = meta_dir)
create_report(spec_ae_01_docfoot) %>% write_doc("table_1_1_docfoot",metaPath = meta_dir)
create_report(spec_ae_01_lp) %>% write_doc("table_1_1_lp",metaPath = meta_dir)


# При инициализации create_table() пакет пытается в автоматическом режиме подобрать ширины колонок исходя из длинны значений в колонках.
# Если колнок много или ширина самой таблицы небольшая, то автоматический подбор может не справиться, тогда ширины можно скорректировать вручную.
# чтобы посмотреть автоматически определенную ширину для каждой колонки можно вызвать функцию print() передав ей объект спецификации.

#print(r_ae_01) # в консоль будет выведена полная информация о репорте:

#нас интерсует таблица с переменными (вызов ДО ручного определения ширин колонок):
#─── Columns ───────────────────────────────────────────────────────────────
#Name        | Label                                 | Type   | Format | Missings | Width | Flags | Styles      
#───────────────────────────────────────────────────────────────────────────────────────────────────────────────
#AESOC       | AESOC                                 | string | %s     |         | 0.0cm | x     |               #для исключенных колонок ширина устанавливаетс в 0.0
#AEDECOD     | System Organ Class<br> Preferred Term | string | %s     |         | 27.9% |       | L: text_left
#OKZL_rate_c | OKZ Low Dose<br>(N=782)<br>n(%)       | string | %s     |         | 7.7%  |       |             
#OKZH_rate_c | OKZ High Dose<br>(N=742)<br>n(%)      | string | %s     |         | 7.7%  |       |             
#OKZA_rate_c | OKZ All Doses<br>(N=1524)<br>n(%)     | string | %s     |         | 7.7%  |       |             
#PLA_rate_c  | Placebo<br>(N=454)<br>n(%)            | string | %s     |         | 7.0%  |       |             
#OKZL_rd     | OKZ Low Dose                          | string | %s     |         | 14.0% |       |             
#OKZH_rd     | OKZ High Dose                         | string | %s     |         | 14.0% |       |             
#OKZA_rd     | OKZ All Doses                         | string | %s     |         | 14.0% |       |             

#Зная значения Width из таблицы, мы можем легко скорректировать ширины колонок используя define_cols(..,colWidth) и опираясь на автоматически полученные ширины.

#Значения таблицы после корректировки ширин колонок (заданы в коде выше):
#─── Columns ───────────────────────────────────────────────────────────────
#Name        | Label                                 | Type   | Format | Missings | Width | Flags | Styles      
#───────────────────────────────────────────────────────────────────────────────────────────────────────────────
#AESOC       | AESOC                                 | string | %s     |         | 0.0cm | x     |             
#AEDECOD     | System Organ Class<br> Preferred Term | string | %s     |         | 23.0% |       | L: text_left
#OKZL_rate_c | OKZ Low Dose<br>(N=782)<br>n(%)       | string | %s     |         | 8%    |       |             
#OKZH_rate_c | OKZ High Dose<br>(N=742)<br>n(%)      | string | %s     |         | 8%    |       |             
#OKZA_rate_c | OKZ All Doses<br>(N=1524)<br>n(%)     | string | %s     |         | 8%    |       |             
#PLA_rate_c  | Placebo<br>(N=454)<br>n(%)            | string | %s     |         | 8%    |       |             
#OKZL_rd     | OKZ Low Dose                          | string | %s     |         | 15%   |       |             
#OKZH_rd     | OKZ High Dose                         | string | %s     |         | 15%   |       |             
#OKZA_rd     | OKZ All Doses                         | string | %s     |         | 15%   |       |               
  
## Обратите внимание - мы задали вручную ширины колонок для _rate_c 8%, для _rd 15%. 
 # Ширина колонки AEDECOD, которую мы не определяли вручную, автоматически пересчиталась, чтобы покрыть 100% ширины репорта.
 # т.е. колонки которые заданы вручную фиксируют свое значение, а остальные пересчитываются пропорцианально их исходным значениям




  
  





