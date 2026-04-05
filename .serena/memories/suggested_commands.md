# ksTFL Suggested Commands

## Install R packages (always use Russian CRAN mirror)
```bash
R -q -e "options(repos=c(CRAN='https://mirror.truenetwork.ru/CRAN/')); install.packages('...')"
```

## Testing
```bash
# Preferred (works without devtools; exposes internal functions to tests)
R -q -e "pkgload::load_all('.'); testthat::test_dir('tests/testthat')"

# Single test file
R -q -e "pkgload::load_all('.'); testthat::test_file('tests/testthat/test-18-cpp-units.R')"

# With devtools (if installed)
R -q -e "devtools::test()"
```

## Build & install (needed after C++ changes before testing)
```bash
R CMD INSTALL .
```

## Full package check
```bash
R -q -e "devtools::check()"
```

## Regenerate docs/NAMESPACE
```bash
R -q -e "devtools::document()"
```

## C++ compile database
```bash
./tools/gen_compile_commands.sh
```

## Start Serena MCP server (auto via VS Code mcp.json)
```bash
./tools/start_serena.sh /path/to/project
```
