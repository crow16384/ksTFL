### Dummy data for tests
NROWS <- 5000

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



###WHODD listing with long texts
whodd_tbl <- tibble(
  Subject = sprintf("SUBJ%03d", 1:30),
  
  ATC_Level1 = c(
    "Cardiovascular system",
    "Cardiovascular system",
    "Cardiovascular system",
    "Nervous system",
    "Nervous system",
    "Nervous system",
    "Alimentary tract and metabolism",
    "Alimentary tract and metabolism",
    "Alimentary tract and metabolism",
    "Respiratory system",
    "Respiratory system",
    "Respiratory system",
    "Anti-infectives for systemic use",
    "Anti-infectives for systemic use",
    "Anti-infectives for systemic use",
    "Musculo-skeletal system",
    "Musculo-skeletal system",
    "Musculo-skeletal system",
    "Dermatologicals",
    "Dermatologicals",
    "Dermatologicals",
    "Genito urinary system and sex hormones",
    "Genito urinary system and sex hormones",
    "Genito urinary system and sex hormones",
    "Hormonal preparations for systemic use",
    "Hormonal preparations for systemic use",
    "Hormonal preparations for systemic use",
    "Blood and blood forming organs",
    "Blood and blood forming organs",
    "Blood and blood forming organs"
  ),
  
  ATC_Level2 = c(
    "Beta blocking agents",
    "Calcium channel blockers",
    "ACE inhibitors",
    "Antidepressants",
    "Antiepileptics",
    "Antipsychotics",
    "Drugs used in diabetes",
    "Drugs for acid related disorders",
    "Vitamins",
    "Drugs for obstructive airway diseases",
    "Cough and cold preparations",
    "Antihistamines for systemic use",
    "Antibacterials for systemic use",
    "Antimycotics for systemic use",
    "Antivirals for systemic use",
    "Anti-inflammatory and antirheumatic products",
    "Muscle relaxants",
    "Drugs for treatment of bone diseases",
    "Antifungals for dermatological use",
    "Emollients and protectives",
    "Corticosteroids dermatological",
    "Sex hormones and modulators",
    "Urologicals",
    "Gynecological antiinfectives",
    "Thyroid therapy",
    "Corticosteroids for systemic use",
    "Parathyroid hormones and analogues",
    "Antithrombotic agents",
    "Antianemic preparations",
    "Blood substitutes and perfusion solutions"
  ),
  
  Preferred_Drug_Name = c(
    "Metoprolol",
    "Amlodipine besylate extended release formulation for chronic hypertension management",
    "Lisinopril <b>20 mg</b> film-coated tablets for essential hypertension",
    "Sertraline hydrochloride",
    "Levetiracetam prolonged-release tablets used in <i>partial onset seizures</i>",
    "Risperidone oral solution with extended titration schedule for schizophrenia spectrum disorders",
    "Insulin glargine recombinant DNA origin solution for injection in pre-filled pen device",
    "Omeprazole gastro-resistant capsules indicated for severe erosive reflux disease treatment",
    "Multivitamin complex containing vitamins A, D, E, K and trace elements for deficiency states",
    "Tiotropium bromide inhalation powder hard capsules",
    "Combination cough syrup with <i>dextromethorphan</i> and guaifenesin for symptomatic relief",
    "Cetirizine dihydrochloride tablets",
    "Amoxicillin and clavulanic acid <b>875 mg/125 mg</b> film-coated tablets",
    "Fluconazole capsules for systemic candidiasis including complicated mucosal involvement",
    "Remdesivir intravenous solution concentrate for infusion in hospitalized patients",
    "Ibuprofen prolonged release tablets for chronic inflammatory conditions including rheumatoid arthritis",
    "Tizanidine tablets with modified dosing instructions in elderly patients with renal impairment",
    "Alendronic acid once weekly tablets for treatment of postmenopausal osteoporosis",
    "Clotrimazole topical cream 1%",
    "White soft paraffin and light liquid paraffin ointment for chronic xerosis management",
    "Hydrocortisone butyrate topical preparation for moderate atopic dermatitis",
    "Estradiol valerate tablets",
    "Tamsulosin hydrochloride modified release capsules",
    "Metronidazole vaginal gel 0.75% for bacterial vaginosis",
    "Levothyroxine sodium tablets for long-term replacement therapy in hypothyroidism",
    "Prednisolone oral tablets with tapering schedule for autoimmune disorders",
    "Teriparatide recombinant human parathyroid hormone analogue injection",
    "Apixaban film-coated tablets for prevention of stroke in <b>non-valvular atrial fibrillation</b>",
    "Ferrous sulfate prolonged release tablets for iron deficiency anemia with gastrointestinal sensitivity",
    "Hydroxyethyl starch solution for infusion used in volume replacement during major surgical procedures"
  )
)



create_whodd_dummy <- function(n_rows = 30, seed = NULL) {
  
  if (!is.null(seed)) set.seed(seed)
  
  # --- ATC Hierarchy ---
  atc_lvl1 <- c(
    "Cardiovascular system",
    "Nervous system",
    "Alimentary tract and metabolism",
    "Respiratory system",
    "Anti-infectives for systemic use",
    "Musculo-skeletal system",
    "Dermatologicals",
    "Genito urinary system and sex hormones",
    "Hormonal preparations for systemic use",
    "Blood and blood forming organs"
  )
  
  atc_lvl2 <- list(
    "Cardiovascular system" = c("Beta blocking agents", "ACE inhibitors", "Calcium channel blockers"),
    "Nervous system" = c("Antidepressants", "Antiepileptics", "Antipsychotics"),
    "Alimentary tract and metabolism" = c("Drugs used in diabetes", "Acid related disorders", "Vitamins"),
    "Respiratory system" = c("Obstructive airway diseases", "Cough preparations", "Antihistamines"),
    "Anti-infectives for systemic use" = c("Antibacterials", "Antivirals", "Antimycotics"),
    "Musculo-skeletal system" = c("Anti-inflammatory products", "Muscle relaxants", "Bone disease treatment"),
    "Dermatologicals" = c("Topical antifungals", "Corticosteroids", "Emollients"),
    "Genito urinary system and sex hormones" = c("Sex hormones", "Urologicals", "Gynecological antiinfectives"),
    "Hormonal preparations for systemic use" = c("Thyroid therapy", "Systemic corticosteroids"),
    "Blood and blood forming organs" = c("Antithrombotic agents", "Antianemic preparations")
  )
  
  drug_roots <- c(
    "metoprolol", "amlodipine", "lisinopril", "sertraline",
    "levetiracetam", "risperidone", "insulin glargine",
    "omeprazole", "tiotropium", "amoxicillin",
    "fluconazole", "remdesivir", "ibuprofen",
    "tizanidine", "alendronic acid", "clotrimazole",
    "estradiol", "tamsulosin", "levothyroxine",
    "prednisolone", "apixaban", "ferrous sulfate"
  )
  
  forms <- c(
    "film-coated tablets", "prolonged-release tablets",
    "oral solution", "intravenous infusion",
    "topical cream", "modified release capsules",
    "gastro-resistant capsules", "solution for injection"
  )
  
  indications <- c(
    "for chronic management of hypertension and related cardiovascular conditions",
    "indicated in moderate to severe depressive episodes with anxious distress",
    "for treatment of bacterial infections involving respiratory tract",
    "used in management of autoimmune disorders with systemic involvement",
    "for symptomatic relief of obstructive airway disease and bronchospasm",
    "in long-term hormone replacement therapy",
    "for prevention of thromboembolic events in high risk patients",
    "for metabolic control in type 2 diabetes mellitus"
  )
  
  utf8_chars <- c("ä", "ñ", "ß", "µ")
  
  add_utf8 <- function(text) {
    if (runif(1) < 0.4) {
      pos <- sample(1:nchar(text), 1)
      substr(text, pos, pos) <- sample(utf8_chars, 1)
    }
    text
  }
  
  add_html_tags <- function(text) {
    tags <- c("i", "b", "sup", "sub")
    if (runif(1) < 0.6) {
      tag <- sample(tags, 1)
      words <- strsplit(text, " ")[[1]]
      if (length(words) > 3) {
        idx <- sample(2:(length(words)-1), 1)
        words[idx] <- paste0("<", tag, ">", words[idx], "</", tag, ">")
      }
      text <- paste(words, collapse = " ")
    }
    text
  }
  
  generate_drug_name <- function() {
    base <- paste(
      tools::toTitleCase(sample(drug_roots, 1)),
      sample(forms, 1),
      sample(indications, 1)
    )
    base <- add_utf8(base)
    base <- add_html_tags(base)
    stri_trim_both(base)
  }
  
  # --- Generate rows ---
  lvl1_sample <- sample(atc_lvl1, n_rows, replace = TRUE)
  
  lvl2_sample <- mapply(function(l1) {
    sample(atc_lvl2[[l1]], 1)
  }, lvl1_sample)
  
  tibble(
    Subject = sprintf("SUBJ%04d", seq_len(n_rows)),
    ATC_Level1 = lvl1_sample,
    ATC_Level2 = lvl2_sample,
    Preferred_Drug_Name = replicate(n_rows, generate_drug_name())
  )
}

big_listing <- create_whodd_dummy(n_rows = NROWS, seed = 123)


stat_table_01 <- tribble(
  ~section, ~endpoint, ~subgroup, ~period, ~complex_pci, ~non_complex_pci, ~p_value,
  
  # =========================
  # Composite endpoints
  # =========================
  "Composite endpoints, % (n)", "Target lesion failure", NA, "30-day", "1.4% (137)", "0.8% (208)", "<0.0001",
  "Composite endpoints, % (n)", "Target vessel failure", NA, "30-day", "1.4% (144)", "0.8% (221)", "<0.0001",
  "Composite endpoints, % (n)", "Patient-oriented composite endpoint", NA, "30-day", "1.9% (186)", "1.1% (300)", "<0.0001",
  
  "Composite endpoints, % (n)", "Target lesion failure", NA, "1-year", "4.2% (408)", "2.8% (727)", "<0.0001",
  "Composite endpoints, % (n)", "Target vessel failure", NA, "1-year", "4.8% (471)", "3.3% (837)", "<0.0001",
  "Composite endpoints, % (n)", "Patient-oriented composite endpoint", NA, "1-year", "7.9% (774)", "6.0% (1532)", "<0.0001",
  
  # =========================
  # Death
  # =========================
  "Death, % (n)", "Any death", NA, "30-day", "0.8% (81)", "0.5% (127)", "<0.001",
  "Death, % (n)", "Cardiac death", NA, "30-day", "0.7% (66)", "0.4% (97)", "<0.001",
  
  "Death, % (n)", "Any death", NA, "1-year", "2.6% (256)", "1.9% (490)", "<0.0001",
  "Death, % (n)", "Cardiac death", NA, "1-year", "1.6% (157)", "1.2% (298)", "0.001",
  
  # =========================
  # Myocardial infarction
  # =========================
  "Myocardial infarction, % (n)", "Any myocardial infarction", NA, "30-day", "0.8% (83)", "0.4% (100)", "<0.0001",
  "Myocardial infarction, % (n)", "Target vessel myocardial infarction", NA, "30-day", "0.7% (73)", "0.3% (87)", "<0.0001",
  "Myocardial infarction, % (n)", "Target vessel Q-wave myocardial infarction", NA, "30-day", "0.2% (16)", "0.1% (30)", "0.28",
  "Myocardial infarction, % (n)", "Target vessel non-Q-wave myocardial infarction", NA, "30-day", "0.6% (57)", "0.2% (57)", "<0.0001",
  "Myocardial infarction, % (n)", "Non-target vessel myocardial infarction", NA, "30-day", "0.1% (10)", "0.0% (13)", "0.09",
  
  "Myocardial infarction, % (n)", "Any myocardial infarction", NA, "1-year", "1.5% (151)", "1.1% (272)", "<0.001",
  "Myocardial infarction, % (n)", "Target vessel myocardial infarction", NA, "1-year", "1.2% (117)", "0.8% (199)", "<0.001",
  "Myocardial infarction, % (n)", "Target vessel Q-wave myocardial infarction", NA, "1-year", "0.2% (22)", "0.2% (52)", "0.69",
  "Myocardial infarction, % (n)", "Target vessel non-Q-wave myocardial infarction", NA, "1-year", "1.0% (95)", "0.6% (147)", "<0.0001",
  "Myocardial infarction, % (n)", "Non-target vessel myocardial infarction", NA, "1-year", "0.4% (35)", "0.3% (77)", "0.40",
  
  # =========================
  # Clinically driven revascularisation
  # =========================
  "Clinically driven target lesion revascularisation, % (n)", "All", NA, "30-day", "0.4% (42)", "0.3% (84)", "0.15",
  "Clinically driven target lesion revascularisation, % (n)", "PCI", NA, "30-day", "0.4% (42)", "0.3% (79)", "0.08",
  "Clinically driven target lesion revascularisation, % (n)", "CABG", NA, "30-day", "0.0% (0)", "0.0% (6)", "0.13",
  
  "Clinically driven target lesion revascularisation, % (n)", "All", NA, "1-year", "2.1% (210)", "1.5% (381)", "<0.0001",
  "Clinically driven target lesion revascularisation, % (n)", "PCI", NA, "1-year", "2.0% (192)", "1.4% (350)", "<0.0001",
  "Clinically driven target lesion revascularisation, % (n)", "CABG", NA, "1-year", "0.2% (23)", "0.1% (35)", "0.04",
  
  # =========================
  # Clinically driven target vessel revascularisation
  # =========================
  "Clinically driven target vessel revascularisation, % (n)", "All", NA, "30-day", "0.5% (55)", "0.4% (102)", "0.04",
  "Clinically driven target vessel revascularisation, % (n)", "PCI", NA, "30-day", "0.5% (55)", "0.4% (93)", "0.01",
  "Clinically driven target vessel revascularisation, % (n)", "CABG", NA, "30-day", "0.0% (0)", "0.0% (11)", "0.04",
  
  "Clinically driven target vessel revascularisation, % (n)", "All", NA, "1-year", "2.9% (285)", "2.0% (515)", "<0.0001",
  "Clinically driven target vessel revascularisation, % (n)", "PCI", NA, "1-year", "2.7% (260)", "1.8% (464)", "<0.0001",
  "Clinically driven target vessel revascularisation, % (n)", "CABG", NA, "1-year", "0.3% (31)", "0.2% (60)", "0.17",
  
  # =========================
  # Stent thrombosis
  # =========================
  "Stent thrombosis, % (n)", "Definite", NA, "30-day", "0.3% (31)", "0.2% (58)", "0.13",
  "Stent thrombosis, % (n)", "Probable", NA, "30-day", "0.3% (34)", "0.2% (48)", "0.01",
  "Stent thrombosis, % (n)", "Definite and probable", NA, "30-day", "0.6% (65)", "0.4% (104)", "<0.001",
  
  "Stent thrombosis, % (n)", "Definite", NA, "1-year", "0.5% (49)", "0.4% (97)", "0.11",
  "Stent thrombosis, % (n)", "Probable", NA, "1-year", "0.4% (41)", "0.2% (53)", "<0.001",
  "Stent thrombosis, % (n)", "Definite and probable", NA, "1-year", "0.9% (90)", "0.6% (148)", "<0.001",
  
  # =========================
  # Bleeding
  # =========================
  "Bleeding, % (n)", "Any bleeding", NA, "30-day", "0.9% (86)", "0.7% (174)", "0.05",
  "Bleeding, % (n)", "BARC 3–5", NA, "30-day", "0.3% (26)", "0.2% (46)", "0.11",
  
  "Bleeding, % (n)", "Any bleeding", NA, "1-year", "2.4% (232)", "2.0% (511)", "0.03",
  "Bleeding, % (n)", "BARC 3–5", NA, "1-year", "0.8% (76)", "0.5% (126)", "<0.01"
)

stat_table_01 <- stat_table_01 %>% select(-subgroup) %>% 
  pivot_wider(id_cols = c(section, endpoint),names_from = period,values_from = c(complex_pci, non_complex_pci, p_value)) %>% 
  relocate(section, endpoint, `complex_pci_30-day`, `non_complex_pci_30-day`, `p_value_30-day`, `complex_pci_1-year`, `non_complex_pci_1-year`, `p_value_1-year`)
  
stat_table_02 <- tribble(
  ~parameter, ~subgroup, ~complex_pci, ~non_complex_pci, ~p_value,
  
  "Age, years (mean±SD)", NA, "64.9±11.1 (10,241)", "63.9±11.3 (26,957)", "<0.0001",
  "Male", NA, "78.4% (8,024/10,241)", "75.1% (20,233/26,957)", "<0.0001",
  "Diabetes mellitus", NA, "32.1% (3,256/10,159)", "27.0% (7,123/26,413)", "<0.0001",
  "Hypertension", NA, "70.3% (6,652/9,461)", "66.8% (16,188/24,223)", "<0.0001",
  "Hypercholesterolaemia", NA, "61.7% (5,631/9,133)", "59.2% (13,831/23,346)", "<0.0001",
  "Current smoker", NA, "24.2% (2,039/8,443)", "27.2% (5,858/21,545)", "<0.0001",
  "Left ventricular ejection fraction, % (mean±SD)", NA, "52.7±12.1 (4,320)", "54.1±11.4 (11,131)", "<0.0001",
  "Renal impairment*", NA, "8.2% (823/10,089)", "6.6% (1,725/26,318)", "<0.0001",
  "Previous myocardial infarction", NA, "26.0% (2,502/9,614)", "21.6% (5,350/24,809)", "<0.0001",
  "Previous PTCA", NA, "28.1% (2,736/9,732)", "25.2% (6,290/24,955)", "<0.0001",
  "Previous CABG", NA, "6.7% (647/9,724)", "5.2% (1,291/24,838)", "<0.0001",
  
  "Clinical presentation", "Chronic coronary syndrome", "52.8% (5,399/10,235)", "41.8% (11,273/26,938)", "<0.0001",
  "Clinical presentation", "Acute coronary syndrome", "47.2% (4,836/10,235)", "58.2% (15,665/26,938)", "<0.0001"
)
