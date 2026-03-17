replay_report("16c_no_rowbreak_with_repeat.docx",
              meta_dir = meta_dir,
              output_path = file.path(out_dir,"16c_no_rowbreak_with_repeat_replay.docx"))

replay_report("03_narrative_figure_table.docx",meta_dir = meta_dir,
              output_path = file.path(out_dir,"03_narrative_figure_table_replay.docx"))

replay_report(c("16c_no_rowbreak_with_repeat.docx",
                "10_ae_template_ru_real_counts.docx",
                "premium_07_submission_ru_default.docx",
                "03_narrative_figure_table.docx"), meta_dir = meta_dir,
              output_path = file.path(out_dir,"Combined replay.docx"),
              insertTOC = T, 
              tocTitle     = "Combined Table of Contents")
