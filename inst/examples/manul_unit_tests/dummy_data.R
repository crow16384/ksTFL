### Dummy data for tests

set.seed(2025)
demography_tbl_01 <- tibble(
  param = c(
    "Age", "Age", "Age",
    "Sex", "Sex", "Sex",
    "Race", "Race", "Race", "Race", "Race",
    "Ethnicity", "Ethnicity", "Ethnicity"
  ),
  value = c(
    NA, NA, NA,
    NA, "Male", "Female",
    NA, "White", "Black or African American", "Asian", "Other",
    NA, "Hispanic or Latino", "Not Hispanic or Latino"
  ),
  stat = c(
    "n", "Mean (SD)", "Min - Max",
    "n", "n (%)", "n (%)",
    "n", "n (%)", "n (%)", "n (%)", "n (%)",
    "n", "n (%)", "n (%)"
  ),
  trt_a = c(
    "100", "45.2 (12.1)", "18 - 75", 
    "100", "52 (52%)", "48 (48%)",
    "100", "70 (70%)", "20 (20%)", "5 (5%)", "5 (5%)",
    "100", "15 (15%)", "85 (85%)"
  ),
  trt_b = c(
    "98", "47.8 (11.5)", "21 - 73", 
    "98", "50 (51%)", "48 (49%)",
    "98", "65 (66%)", "22 (22%)", "6 (6%)", "5 (5%)",
    "98", "12 (12%)", "86 (88%)"
  ),
  trt_c = c(
    "102", "44.1 (13.0)", "19 - 78", 
    "102", "55 (54%)", "47 (46%)",
    "102", "72 (71%)", "18 (18%)", "7 (7%)", "5 (5%)",
    "102", "18 (18%)", "84 (82%)"
  )
)

###Simple AE table with two categries and N/events
ae_tbl_01 <- tibble(
  category = c(
    # AESI: Infections
    "AESI: Infections", "AESI: Infections", "AESI: Infections",
    "AESI: Infections", "AESI: Infections", "AESI: Infections",
    
    # AESI: Gastrointestinal
    "AESI: Gastrointestinal", "AESI: Gastrointestinal", "AESI: Gastrointestinal",
    "AESI: Gastrointestinal", "AESI: Gastrointestinal", "AESI: Gastrointestinal"
  ),
  
  soc = c(
    # Infections SOCs
    "Infections and infestations", "Infections and infestations", 
    "Infections and infestations",
    "Respiratory, thoracic and mediastinal disorders",
    "Respiratory, thoracic and mediastinal disorders",
    "Respiratory, thoracic and mediastinal disorders",
    
    # GI SOCs
    "Gastrointestinal disorders", "Gastrointestinal disorders",
    "Gastrointestinal disorders",
    "Hepatobiliary disorders", "Hepatobiliary disorders",
    "Hepatobiliary disorders"
  ),
  
  pt = c(
    # Infections PTs
    "COVID-19",
    "Pneumonia bacterial",
    "Sepsis",
    "Upper respiratory tract infection",
    "Lower respiratory tract infection",
    "Bronchitis",
    
    # GI PTs
    "Diarrhoea",
    "Nausea",
    "Vomiting",
    "Alanine aminotransferase increased",
    "Aspartate aminotransferase increased",
    "Hepatitis"
  ),
  
  trt_a_npct = c(
    "12 (12.0%)", "8 (8.0%)", "3 (3.0%)",
    "10 (10.0%)", "6 (6.0%)", "5 (5.0%)",
    "15 (15.0%)", "18 (18.0%)", "9 (9.0%)",
    "4 (4.0%)", "3 (3.0%)", "1 (1.0%)"
  ),
  
  trt_a_e = c(
    14, 9, 3,
    12, 7, 6,
    20, 22, 11,
    5, 4, 1
  ),
  
  trt_b_npct = c(
    "9 (9.2%)", "5 (5.1%)", "2 (2.0%)",
    "7 (7.1%)", "4 (4.1%)", "3 (3.1%)",
    "11 (11.2%)", "14 (14.3%)", "6 (6.1%)",
    "2 (2.0%)", "2 (2.0%)", "0 (0.0%)"
  ),
  
  trt_b_e = c(
    11, 6, 2,
    8, 5, 3,
    15, 16, 7,
    2, 2, 0
  )
)

library(tibble)

ae_tbl_02 <- tibble(
  category = c(
    # =========================
    # AESI: Infections
    # =========================
    "AESI: Infections",                         # AESI total
    "AESI: Infections",                         # SOC total
    "AESI: Infections",
    "AESI: Infections",
    "AESI: Infections",
    "AESI: Infections",                         # SOC total
    "AESI: Infections",
    "AESI: Infections",
    "AESI: Infections",
    
    # =========================
    # AESI: Gastrointestinal
    # =========================
    "AESI: Gastrointestinal",                   # AESI total
    "AESI: Gastrointestinal",                   # SOC total
    "AESI: Gastrointestinal",
    "AESI: Gastrointestinal",
    "AESI: Gastrointestinal",                   # SOC total
    "AESI: Gastrointestinal",
    "AESI: Gastrointestinal"
  ),
  
  soc = c(
    # Infections
    NA,                                         # AESI total
    "Infections and infestations",               # SOC total
    "Infections and infestations",
    "Infections and infestations",
    "Infections and infestations",
    "Respiratory, thoracic and mediastinal disorders",  # SOC total
    "Respiratory, thoracic and mediastinal disorders",
    "Respiratory, thoracic and mediastinal disorders",
    "Respiratory, thoracic and mediastinal disorders",
    
    # Gastrointestinal
    NA,                                         # AESI total
    "Gastrointestinal disorders",               # SOC total
    "Gastrointestinal disorders",
    "Gastrointestinal disorders",
    "Hepatobiliary disorders",                  # SOC total
    "Hepatobiliary disorders",
    "Hepatobiliary disorders"
  ),
  
  pt = c(
    # Infections
    NA,                     # AESI total
    NA,     # SOC total
    "COVID-19",
    "Pneumonia bacterial",
    "Sepsis",
    NA,           # SOC total
    "Upper respiratory tract infection",
    "Lower respiratory tract infection",
    "Bronchitis",
    
    # Gastrointestinal
    NA,               # AESI total
    NA,      # SOC total
    "Diarrhoea",
    "Nausea",
    NA,         # SOC total
    "Alanine aminotransferase increased",
    "Hepatitis"
  ),
  
  trt_a_npct = c(
    "30 (30.0%)",   # AESI total
    "18 (18.0%)",   # SOC total
    "12 (12.0%)",
    "8 (8.0%)",
    "3 (3.0%)",
    "15 (15.0%)",   # SOC total
    "10 (10.0%)",
    "6 (6.0%)",
    "5 (5.0%)",
    
    "22 (22.0%)",   # AESI total
    "18 (18.0%)",   # SOC total
    "15 (15.0%)",
    "18 (18.0%)",
    "5 (5.0%)",     # SOC total
    "4 (4.0%)",
    "1 (1.0%)"
  ),
  
  trt_a_e = c(
    44,
    26,
    14,
    9,
    3,
    18,
    12,
    7,
    6,
    
    29,
    23,
    20,
    22,
    6,
    5,
    1
  ),
  
  trt_b_npct = c(
    "22 (22.4%)",
    "14 (14.3%)",
    "9 (9.2%)",
    "5 (5.1%)",
    "2 (2.0%)",
    "10 (10.2%)",
    "7 (7.1%)",
    "4 (4.1%)",
    "3 (3.1%)",
    
    "16 (16.3%)",
    "13 (13.3%)",
    "11 (11.2%)",
    "14 (14.3%)",
    "3 (3.1%)",
    "2 (2.0%)",
    "0 (0.0%)"
  ),
  
  trt_b_e = c(
    30,
    17,
    11,
    6,
    2,
    13,
    8,
    5,
    3,
    
    19,
    17,
    15,
    16,
    3,
    2,
    0
  )
)


##vitals CHG
library(tibble)

vitals_tbl_01 <- tibble(
  parameter = c(
    rep("Систолическое Давление (mmHg)", 6),
    rep("Диастолическое Давление (mmHg)", 6),
    rep("Частота Сердечных Сокращений (bpm)", 6)
  ),
  
  analysis = rep(
    c("Визит 0", "Визит 0", "Визит 0",
      "Изменение от 'Визит 0'", "Изменение от 'Визит 0'", "Изменение от 'Визит 0'"),
    3
  ),
  
  stat = rep(
    c("n", "Среднее", "СО"),
    6
  ),
  
  trt_a = c(
    # SBP
    '100', '128.4', '12.50',
    '98',  '-5.6',  '10.20',
    
    # DBP
    '100', '78.2', '8.45',
    '98',  '-3.1', '6.35',
    
    # HR
    '100', '72.5', '9.83',
    '97',  '-2.4', '7.26'
  ),
  
  trt_b = c(
    # SBP
    '98', '130.1', '11.84',
    '96', '-2.3', '9.7',
    
    # DBP
    '98', '79.5', '7.94',
    '96', '-1.2', '6.15',
    
    # HR
    '98', '73.8', '10.12',
    '95', '-0.8', '6.98'
  )
)

vitals_tbl_01_02 <- vitals_tbl_01 %>% mutate(across(starts_with('trt_'), ~aligndec(.x,indent = 2)))

attr(vitals_tbl_01$parameter, "label") <- ""
attr(vitals_tbl_01$analysis,  "label") <- ""
attr(vitals_tbl_01$stat,      "label") <- "Параметр/<br>  Визит/<br>    Статистика"
attr(vitals_tbl_01$trt_a,     "label") <- "Терапия A<p>(N=20)"
attr(vitals_tbl_01$trt_b,     "label") <- "Терапия B<p>(N=50)"

attr(vitals_tbl_01_02$stat,      "label") <- "Параметр/<br>  Визит/<br>    Статистика"
attr(vitals_tbl_01_02$trt_a,     "label") <- "Терапия A<p>(N=20)"
attr(vitals_tbl_01_02$trt_b,     "label") <- "Терапия B<p>(N=50)"

