# ksTFL Suggested Commands

## Install R packages (always use Russian CRAN mirror)
```bash
R -q -e "options(repos=c(CRAN='https://mirror.truenetwork.ru/CRAN/')); install.packages('...')"
```

## Testing
```bash
R -q -e "devtools::test()"
R -q -e "testthat::test_dir('tests/testthat')"
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
