
**We are pleased to announce the release of ksTFL — an R package built to close the gap in regulatory-compliant clinical reporting.**

R excels at statistical analysis, but producing submission-quality Tables, Figures, and Listings (TFLs) in well-formatted DOCX has always been an uphill battle — stitching together packages, wrestling with pagination, and fighting to meet industry standards. **ksTFL was created to solve exactly that.**

It wraps the best ideas from existing reporting tools into a simple, declarative language — a compact set of composable functions that can produce virtually any clinical output format.

**What makes it different:**

**Data stays clean.** Input datasets remain planar and analysis-ready — no merged cells, inserted rows, or display-only columns. Formatting, pagination, and styling are declared independently and applied at render time — maintainable, traceable, and validation-ready.

**Extremely fast.** A built-in C++ rendering engine with pixel-perfect text shaping produces styled DOCX with deterministic pagination. Large datasets and batch runs of hundreds of outputs complete in seconds.

**Minimalistic but flexible.** Tables, figures, listings, conditional styling, spanning headers, column grouping, page breaks — all through a small, consistent API. One language. One pipeline. One R session.

**Submission-quality output.** Precise font metrics, reproducible layouts, configurable templates — meeting regulatory formatting expectations out of the box.

**Multi-document assembly with TOC.** Combine multiple TFLs into a single DOCX with an auto-generated multi-level Table of Contents — ideal for submission packages or study report appendices.

**Reproducible.** Specs are serializable to JSON and can be replayed from stored metadata without re-running original code.

Pre-compiled binaries for R 4.4/4.5 on Linux, Windows, and macOS:

📦 Releases: https://github.com/crow16384/ksTFL-release
📖 Docs: https://crow16384.github.io/ksTFL-release/
📖 Real examples: https://crow16384.github.io/ksTFL-release/articles/Real_Examples_with_ksTFL.html

**Give it a try** — explore the docs, run the examples, and see how ksTFL fits your workflow.
Issues & suggestions: https://github.com/crow16384/ksTFL-release/issues

#RStats #ClinicalTrials #Pharma #Biostatistics #TFL #RPackage #ClinicalProgramming #KeyStat

---

# Версия на русском языке

**Мы рады представить ksTFL — R-пакет, созданный для того, чтобы закрыть давний пробел в экосистеме R: отсутствие полноценного решения для формирования регуляторно-совместимых клинических отчётов.**

R отлично справляется со статистическим анализом, но создание submission-quality таблиц, рисунков и листингов (TFL) в отформатированном DOCX всегда было непростой задачей — приходилось комбинировать множество пакетов, бороться с пагинацией и подгонять вывод под требования индустрии. **ksTFL создан, чтобы решить именно эту проблему.**

Пакет вобрал лучшие идеи существующих инструментов отчётности и обернул их в простой декларативный язык — компактный набор комбинируемых функций, позволяющий создать практически любой формат клинического вывода.

**Чем он отличается:**

**Данные остаются чистыми.** Входные датасеты остаются плоскими и готовыми к анализу — без объединённых ячеек, вставленных строк и служебных столбцов. Форматирование, пагинация и стилизация задаются отдельно и применяются на этапе рендеринга — данные остаются поддерживаемыми, прослеживаемыми и готовыми к валидации.

**Исключительная скорость.** Встроенный C++ движок рендеринга с попиксельно точным формированием текста создаёт стилизованные DOCX с детерминированной пагинацией. Большие датасеты и пакетная генерация сотен выходных файлов выполняются за секунды.

**Минималистично, но гибко.** Таблицы, рисунки, листинги, условная стилизация, объединяющие заголовки, группировка столбцов, разрывы страниц — всё через компактный и единообразный API. Один язык. Один пайплайн. Одна R-сессия.

**Качество submission-level.** Точные метрики шрифтов, воспроизводимая вёрстка, настраиваемые шаблоны — соответствие регуляторным требованиям к оформлению из коробки.

**Сборка документов с оглавлением.** Объединение нескольких TFL в один DOCX с автоматически генерируемым многоуровневым оглавлением (Table of Contents) — идеально для submission-пакетов и приложений к отчётам по исследованиям.

**Воспроизводимость.** Спецификации сериализуются в JSON и могут быть воспроизведены из сохранённых метаданных без повторного запуска исходного кода.

Предкомпилированные бинарные пакеты для R 4.4/4.5 на Linux, Windows и macOS:

📦 Релизы: https://github.com/crow16384/ksTFL-release
📖 Документация: https://crow16384.github.io/ksTFL-release/
📖 Примеры реальных отчётов: https://crow16384.github.io/ksTFL-release/articles/Real_Examples_with_ksTFL.html

**Попробуйте** — изучите документацию, запустите примеры и оцените, как ksTFL впишется в ваш рабочий процесс.
Вопросы и предложения: https://github.com/crow16384/ksTFL-release/issues

#RStats #ClinicalTrials #Pharma #Biostatistics #TFL #RPackage #ClinicalProgramming #KeyStat