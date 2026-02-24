Run the ksTFL example script

This folder contains a runnable example script `ksTFL_example.R` demonstrating a full ksTFL pipeline (create specs, define styles, combine report, and save). The script uses `mtcars` and writes metadata/data files via `save_report()`.

How to run

1. Install and load the package (from source or devtools):

```r
# from package root
# devtools::load_all()
# or install and then:
# devtools::install()
library(ksTFL)
```

2. Run the example script (adjust paths if needed):

```r
source(system.file("examples", "ksTFL_example.R", package = "ksTFL"))
```

Or run directly from the package tree:

```r
# from repository root
Rscript inst/examples/ksTFL_example.R
```

Expected output

- The script calls `save_report()` which writes one main JSON spec file and any table data JSONs / copied figure files into a `metaPath` directory (temporary by default). The script prints the returned `res` object which contains paths and filenames produced.

Notes

- `save_report()` performs schema validation via the package's internal serializer; the serializer is not an exported function and is invoked by `save_report()` automatically.
- If you want the exact JSON produced, run the script and inspect the files listed in the printed `res` object.
