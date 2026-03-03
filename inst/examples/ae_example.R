source("inst/examples/init.R")

ae_raw <- list(
  list(soc = "Infections and Infestations", pts = data.frame(
    PT       = c("Nasopharyngitis", "Upper Respiratory Tract Infection",
                 "Urinary Tract Infection", "Bronchitis", "Sinusitis",
                 "Influenza", "Pneumonia"),
    N_DrugA  = c(15, 8, 5, 4, 3, 2, 1),
    P_DrugA  = c(12.5, 6.7, 4.2, 3.3, 2.5, 1.7, 0.8),
    N_Placebo = c(10, 6, 4, 2, 3, 1, 0),
    P_Placebo = c(8.3, 5.0, 3.3, 1.7, 2.5, 0.8, 0.0),
    stringsAsFactors = FALSE
  )),
  list(soc = "Gastrointestinal Disorders", pts = data.frame(
    PT       = c("Nausea", "Diarrhoea", "Vomiting", "Abdominal Pain Upper",
                 "Constipation", "Dyspepsia", "Abdominal Distension",
                 "Gastroesophageal Reflux Disease"),
    N_DrugA  = c(12, 6, 5, 4, 3, 3, 2, 1),
    P_DrugA  = c(10.0, 5.0, 4.2, 3.3, 2.5, 2.5, 1.7, 0.8),
    N_Placebo = c(8, 5, 3, 3, 4, 2, 1, 1),
    P_Placebo = c(6.7, 4.2, 2.5, 2.5, 3.3, 1.7, 0.8, 0.8),
    stringsAsFactors = FALSE
  )),
  list(soc = "Nervous System Disorders", pts = data.frame(
    PT       = c("Headache", "Dizziness", "Somnolence", "Tremor",
                 "Paraesthesia", "Migraine"),
    N_DrugA  = c(18, 4, 3, 2, 2, 1),
    P_DrugA  = c(15.0, 3.3, 2.5, 1.7, 1.7, 0.8),
    N_Placebo = c(14, 3, 2, 1, 1, 1),
    P_Placebo = c(11.7, 2.5, 1.7, 0.8, 0.8, 0.8),
    stringsAsFactors = FALSE
  )),
  list(soc = "Musculoskeletal and Connective Tissue Disorders", pts = data.frame(
    PT       = c("Back Pain", "Arthralgia", "Myalgia", "Pain in Extremity",
                 "Musculoskeletal Pain", "Neck Pain", "Muscle Spasms"),
    N_DrugA  = c(10, 7, 5, 4, 3, 2, 2),
    P_DrugA  = c(8.3, 5.8, 4.2, 3.3, 2.5, 1.7, 1.7),
    N_Placebo = c(9, 5, 4, 3, 2, 2, 1),
    P_Placebo = c(7.5, 4.2, 3.3, 2.5, 1.7, 1.7, 0.8),
    stringsAsFactors = FALSE
  )),
  list(soc = "General Disorders and Administration Site Conditions", pts = data.frame(
    PT       = c("Fatigue", "Pyrexia", "Oedema Peripheral", "Asthenia",
                 "Chest Pain", "Influenza Like Illness", "Malaise"),
    N_DrugA  = c(9, 5, 4, 3, 2, 2, 1),
    P_DrugA  = c(7.5, 4.2, 3.3, 2.5, 1.7, 1.7, 0.8),
    N_Placebo = c(7, 3, 3, 2, 1, 1, 1),
    P_Placebo = c(5.8, 2.5, 2.5, 1.7, 0.8, 0.8, 0.8),
    stringsAsFactors = FALSE
  )),
  list(soc = "Skin and Subcutaneous Tissue Disorders", pts = data.frame(
    PT       = c("Rash", "Pruritus", "Dermatitis", "Urticaria",
                 "Dry Skin", "Erythema"),
    N_DrugA  = c(6, 5, 3, 2, 2, 1),
    P_DrugA  = c(5.0, 4.2, 2.5, 1.7, 1.7, 0.8),
    N_Placebo = c(4, 3, 2, 1, 1, 1),
    P_Placebo = c(3.3, 2.5, 1.7, 0.8, 0.8, 0.8),
    stringsAsFactors = FALSE
  )),
  list(soc = "Respiratory, Thoracic and Mediastinal Disorders", pts = data.frame(
    PT       = c("Cough", "Dyspnoea", "Oropharyngeal Pain",
                 "Nasal Congestion", "Epistaxis", "Wheezing"),
    N_DrugA  = c(8, 4, 3, 3, 2, 1),
    P_DrugA  = c(6.7, 3.3, 2.5, 2.5, 1.7, 0.8),
    N_Placebo = c(6, 3, 2, 2, 1, 1),
    P_Placebo = c(5.0, 2.5, 1.7, 1.7, 0.8, 0.8),
    stringsAsFactors = FALSE
  )),
  list(soc = "Metabolism and Nutrition Disorders", pts = data.frame(
    PT       = c("Decreased Appetite", "Hypokalaemia",
                 "Hyperglycaemia", "Dehydration", "Hyperlipidaemia"),
    N_DrugA  = c(5, 3, 3, 2, 1),
    P_DrugA  = c(4.2, 2.5, 2.5, 1.7, 0.8),
    N_Placebo = c(3, 2, 2, 1, 1),
    P_Placebo = c(2.5, 1.7, 1.7, 0.8, 0.8),
    stringsAsFactors = FALSE
  )),
  list(soc = "Psychiatric Disorders", pts = data.frame(
    PT       = c("Insomnia", "Anxiety", "Depression", "Restlessness"),
    N_DrugA  = c(6, 4, 3, 1),
    P_DrugA  = c(5.0, 3.3, 2.5, 0.8),
    N_Placebo = c(5, 3, 2, 1),
    P_Placebo = c(4.2, 2.5, 1.7, 0.8),
    stringsAsFactors = FALSE
  )),
  list(soc = "Cardiac Disorders", pts = data.frame(
    PT       = c("Palpitations", "Tachycardia", "Bradycardia",
                 "Atrial Fibrillation"),
    N_DrugA  = c(4, 3, 2, 1),
    P_DrugA  = c(3.3, 2.5, 1.7, 0.8),
    N_Placebo = c(2, 2, 1, 1),
    P_Placebo = c(1.7, 1.7, 0.8, 0.8),
    stringsAsFactors = FALSE
  )),
  list(soc = "Eye Disorders", pts = data.frame(
    PT       = c("Vision Blurred", "Dry Eye", "Conjunctivitis"),
    N_DrugA  = c(3, 2, 1),
    P_DrugA  = c(2.5, 1.7, 0.8),
    N_Placebo = c(2, 1, 1),
    P_Placebo = c(1.7, 0.8, 0.8),
    stringsAsFactors = FALSE
  )),
  list(soc = "Vascular Disorders", pts = data.frame(
    PT       = c("Hypertension", "Hypotension", "Hot Flush"),
    N_DrugA  = c(5, 2, 2),
    P_DrugA  = c(4.2, 1.7, 1.7),
    N_Placebo = c(4, 1, 1),
    P_Placebo = c(3.3, 0.8, 0.8),
    stringsAsFactors = FALSE
  )),
  list(soc = "Renal and Urinary Disorders", pts = data.frame(
    PT       = c("Pollakiuria", "Dysuria", "Haematuria"),
    N_DrugA  = c(3, 2, 1),
    P_DrugA  = c(2.5, 1.7, 0.8),
    N_Placebo = c(2, 1, 1),
    P_Placebo = c(1.7, 0.8, 0.8),
    stringsAsFactors = FALSE
  )),
  list(soc = "Investigations", pts = data.frame(
    PT       = c("Blood Pressure Increased", "Weight Increased",
                 "Alanine Aminotransferase Increased",
                 "Blood Creatinine Increased"),
    N_DrugA  = c(4, 3, 2, 1),
    P_DrugA  = c(3.3, 2.5, 1.7, 0.8),
    N_Placebo = c(3, 2, 1, 1),
    P_Placebo = c(2.5, 1.7, 0.8, 0.8),
    stringsAsFactors = FALSE
  ))
)

# Assemble into a single data frame.
# `Term` is the unified stub column (SOC rows + PT rows).
# `SOC_group` is the hidden noprint GROUP column.
# `row_type` flags SOC (0) vs PT (1) rows for conditional styling.

rows <- list()
for (entry in ae_raw) {
  soc_name <- entry$soc
  pts      <- entry$pts
  
  # SOC summary row — aggregate across PTs
  soc_n_drug  <- max(pts$N_DrugA)   # at-least-one-PT subject count proxy
  soc_p_drug  <- max(pts$P_DrugA)
  soc_n_plac  <- max(pts$N_Placebo)
  soc_p_plac  <- max(pts$P_Placebo)
  
  rows[[length(rows) + 1]] <- data.frame(
    SOC_group = soc_name,
    Term      = soc_name,
    N_DrugA   = soc_n_drug,
    P_DrugA   = soc_p_drug,
    N_Placebo = soc_n_plac,
    P_Placebo = soc_p_plac,
    row_type  = 0L,
    stringsAsFactors = FALSE
  )
  
  # PT detail rows
  for (i in seq_len(nrow(pts))) {
    rows[[length(rows) + 1]] <- data.frame(
      SOC_group = soc_name,
      Term      = pts$PT[i],
      N_DrugA   = pts$N_DrugA[i],
      P_DrugA   = pts$P_DrugA[i],
      N_Placebo = pts$N_Placebo[i],
      P_Placebo = pts$P_Placebo[i],
      row_type  = 1L,
      stringsAsFactors = FALSE
    )
  }
}

df_ae <- do.call(rbind, rows)
rownames(df_ae) <- NULL

cat("AE dataset:", nrow(df_ae), "rows across",
    length(ae_raw), "SOCs\n\n")

df_ae <- tibble(df_ae)

df_long <- df_ae %>%
  pivot_longer(
    cols = c(N_DrugA, P_DrugA, N_Placebo, P_Placebo),
    names_to = c(".value", "Treatment"),
    names_pattern = "^(N|P)_(.*)$"
  ) |> mutate(Treatment=if_else(Treatment=="DrugA", "Drug A",Treatment,""))

df_long2 <- df_ae %>%
  pivot_longer(
    cols = c(N_DrugA, P_DrugA, N_Placebo, P_Placebo),
    names_to = c("Metric", "Treatment"),
    names_sep = "_",
    values_to = "Value"
  )

