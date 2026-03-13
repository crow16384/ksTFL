set.seed(5645)
generate_multilingual_tibble <- function(n_rows, 
                                         n_cols, 
                                         languages = c("en", "es", "fr", "de", "it", "pt", "ja", "zh", "ar", "ru"),
                                         length_range = c(5, 50),
                                         use_api = FALSE) {
  
  # Sample text templates by language (fallback if API fails)
  text_templates <- list(
    en = c("The quick brown fox jumps over the lazy dog", 
           "Lorem ipsum dolor sit amet consectetur adipiscing elit",
           "Data science is transforming how we understand the world",
           "Machine learning algorithms can predict future trends",
           "Open source software powers the modern internet",
           "Artificial intelligence is revolutionizing many industries",
           "Cloud computing enables scalable infrastructure solutions",
           "Cybersecurity protects digital assets from threats",
           "Blockchain technology offers decentralized data storage",
           "Quantum computing promises exponential processing power"),
    es = c("El rápido zorro marrón salta sobre el perro perezoso",
           "La ciencia de datos está transformando nuestro mundo",
           "Los algoritmos de aprendizaje automático predicen tendencias",
           "El software de código abierto impulsa internet moderno",
           "La inteligencia artificial revoluciona muchas industrias",
           "La computación en la nube permite soluciones escalables",
           "La ciberseguridad protege los activos digitales",
           "La tecnología blockchain ofrece almacenamiento descentralizado"),
    fr = c("Le rapide renard brun saute par dessus le chien paresseux",
           "La science des données transforme notre compréhension",
           "Les algorithmes d'apprentissage automatique prédisent l'avenir",
           "Le logiciel open source alimente l'internet moderne",
           "L'intelligence artificielle révolutionne de nombreuses industries",
           "Le cloud computing permet des solutions d'infrastructure évolutives",
           "La cybersécurité protège les actifs numériques",
           "La technologie blockchain offre un stockage décentralisé"),
    de = c("Der schnelle braune Fuchs springt über den faulen Hund",
           "Datenwissenschaft verändert unser Verständnis der Welt",
           "Maschinelles Lernen kann zukünftige Trends vorhersagen",
           "Open-Source-Software treibt das moderne Internet an",
           "Künstliche Intelligenz revolutioniert viele Branchen",
           "Cloud Computing ermöglicht skalierbare Infrastrukturlösungen",
           "Cybersicherheit schützt digitale Assets vor Bedrohungen",
           "Blockchain-Technologie bietet dezentrale Datenspeicherung"),
    it = c("La volpe marrone veloce salta sopra il cane pigro",
           "La scienza dei dati sta trasformando il nostro mondo",
           "Gli algoritmi di machine learning predicono le tendenze",
           "Il software open source alimenta internet moderno",
           "L'intelligenza artificiale sta rivoluzionando molte industrie",
           "Il cloud computing consente soluzioni infrastrutturali scalabili",
           "La sicurezza informatica protegge le risorse digitali",
           "La tecnologia blockchain offre archiviazione dati decentralizzata"),
    pt = c("A rápida raposa marrom pula sobre o cão preguiçoso",
           "A ciência de dados está transformando nosso mundo",
           "Algoritmos de aprendizado de máquina preveem tendências",
           "Software de código aberto impulsiona a internet moderna",
           "A inteligência artificial está revolucionando muitas indústrias",
           "A computação em nuvem permite soluções escaláveis",
           "A cibersegurança protege ativos digitais de ameaças",
           "A tecnologia blockchain oferece armazenamento descentralizado"),
    ja = c("素早い茶色のキツネが怠け者の犬を飛び越える",
           "データサイエンスは世界の理解を変えています",
           "機械学習アルゴリズムは将来のトレンドを予測できます",
           "オープンソースソフトウェアが現代のインターネットを支えています",
           "人工知能は多くの産業に革命をもたらしています",
           "クラウドコンピューティングはスケーラブルなインフラソリューションを可能にします",
           "サイバーセキュリティはデジタル資産を脅威から保護します",
           "ブロックチェーン技術は分散型データストレージを提供します"),
    zh = c("敏捷的棕色狐狸跳过懒狗",
           "数据科学正在改变我们理解世界的方式",
           "机器学习算法可以预测未来趋势",
           "开源软件为现代互联网提供动力",
           "人工智能正在彻底改变许多行业",
           "云计算使可扩展的基础设施解决方案成为可能",
           "网络安全保护数字资产免受威胁",
           "区块链技术提供分散的数据存储"),
    ar = c("الثعلب البني السريع يقفز فوق الكلب الكسول",
           "علم البيانات يحول فهمنا للعالم",
           "خوارزميات التعلم الآلي يمكنها التنبؤ بالاتجاهات المستقبلية",
           "البرمجيات مفتوحة المصدر تدعم الإنترنت الحديث",
           "الذكاء الاصطناعي يحدث ثورة في العديد من الصناعات",
           "الحوسبة السحابية تمكن حلول البنية التحتية القابلة للتطوير"),
    ru = c("Быстрая коричневая лиса прыгает через ленивую собаку",
           "Наука о данных меняет наше понимание мира",
           "Алгоритмы машинного обучения могут предсказывать будущие тенденции",
           "Программное обеспечение с открытым исходным кодом питает современный интернет",
           "Искусственный интеллект революционизирует многие отрасли",
           "Облачные вычисления обеспечивают масштабируемые инфраструктурные решения",
           "Кибербезопасность защищает цифровые активы от угроз")
  )
  
  # Function to fetch lorem ipsum from API
  fetch_lorem_api <- function(lang, n_words) {
    tryCatch({
      # Using Bacon Ipsum API as fallback (English only, but realistic)
      response <- request("https://baconipsum.com/api/") |>
        req_url_query(
          type = "all-meat",
          sentences = ceiling(n_words / 10),
          format = "text"
        ) |>
        req_perform() |>
        resp_body_string()
      
      # Trim to approximate word count
      words <- strsplit(response, "\\s+")[[1]]
      if (length(words) > n_words) {
        words <- words[1:n_words]
      }
      paste(words, collapse = " ")
    }, error = function(e) {
      NULL
    })
  }
  
  # Function to generate text of varying length
  generate_text <- function(lang, min_words, max_words, use_api) {
    n_words <- sample(min_words:max_words, 1)
    
    # Try API first if requested
    if (use_api) {
      api_text <- fetch_lorem_api(lang, n_words)
      if (!is.null(api_text)) {
        return(api_text)
      }
    }
    
    # Fallback to template-based generation
    if (lang %in% names(text_templates)) {
      templates <- text_templates[[lang]]
      
      # Build text by repeating and sampling from templates
      text_pieces <- character()
      current_length <- 0
      
      while (current_length < n_words) {
        piece <- sample(templates, 1)
        piece_words <- strsplit(piece, "\\s+")[[1]]
        remaining <- n_words - current_length
        
        if (length(piece_words) > remaining) {
          piece_words <- piece_words[1:remaining]
        }
        
        text_pieces <- c(text_pieces, paste(piece_words, collapse = " "))
        current_length <- current_length + length(piece_words)
      }
      
      return(paste(text_pieces, collapse = ". "))
    } else {
      # Default to English if language not found
      return(generate_text("en", min_words, max_words, use_api = FALSE))
    }
  }
  
  # Generate columns as a list
  col_list <- list()
  
  for (i in 1:n_cols) {
    col_name <- paste0("text_col_", i)
    
    # Randomly select language for each column
    col_lang <- sample(languages, 1)
    
    # Generate text for each row
    col_data <- map_chr(1:n_rows, ~generate_text(
      lang = col_lang,
      min_words = length_range[1],
      max_words = length_range[2],
      use_api = use_api
    ))
    
    col_list[[col_name]] <- col_data
  }
  
  # Create tibble from the list
  result <- as_tibble(col_list)
  
  return(result)
}

df <- generate_multilingual_tibble(
   n_rows = 1000, 
   n_cols = 10, 
   length_range = c(1, 10)
 )
cats <- tibble(cat1=rep(c('Category 1', 'Category 2', 'Category 3', 'Category 4'),250), cat2=rep(c('Sub-Category 1', 'Sub-Category 2'),500))

df <- cats %>% bind_cols(df)

############################################################################################
spec_long <- create_table(df) %>% 
  add_title(c("Listing 1.1: ", "Testing of the listing of differnt languages and text lengths"), toclevel = 1) %>% 
  add_title("(random data)") %>% 
  add_footnote("footnote line 1", styleRef = 'b') %>% 
  add_footnote("footnote line 2", styleRef = 'i') %>% 
  add_footnote("footnote line 3") %>% 
  add_footnote("footnote line 4", styleRef = f_combine('fs_7','fc_red')) %>% 
  define_cols(
    contains('col_'),
    label =  paste0('Column ', c(1:10)),
    labelStyleRef = 'to_90'
  ) %>% 
  define_cols(
    c(cat1, cat2),
    label = c('Category', 'Sub-Category'),
    colWidth = '3cm',
    isID = T
  ) %>% 
  add_span_header(3:5, 'Spannig header 1') %>% 
  add_span_header(7:11, 'Spannig header 2', stubOrder = 1) %>% 
  add_span_header(3:12, 'Spannig header 3', stubOrder = 2) 
  
  
r_long_1 <- create_report(spec_long)
write_doc(r_long_1, "showcases_15_long_listing_1_1")


######################################################################
spec_long <- create_table(df) %>% 
  add_title(c("Listing 1.1: ", "Testing of the listing of differnt languages and text lengths"), toclevel = 1) %>% 
  add_title("(random data)") %>% 
  add_footnote("footnote line 1", styleRef = 'b') %>% 
  add_footnote("footnote line 2", styleRef = 'i') %>% 
  add_footnote("footnote line 3") %>% 
  add_footnote("footnote line 4", styleRef = f_combine('fs_7','fc_red')) %>% 
  define_cols(
    contains('col_'),
    label =  paste0('Column ', c(1:10)),
    labelStyleRef = 'to_90'
  ) %>% 
  define_cols(
    c(cat1, cat2),
    label = c('Category', 'Sub-Category'),
    colWidth = '3cm',
    isID = T
  ) %>% 
  define_cols(9, isColBreak = T) %>% ##with colBreak enabled the row height is still calculated as if all columns were on the same page. 
  add_span_header(3:5, 'Spannig header 1') %>% 
  add_span_header(7:11, 'Spannig header 2', stubOrder = 1) %>% 
  add_span_header(3:12, 'Spannig header 3', stubOrder = 2) 


r_long_1 <- create_report(spec_long)
write_doc(r_long_1, "showcase_15_long_listing_1_2")
