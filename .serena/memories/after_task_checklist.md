# ksTFL — After Task Completion Checklist

1. Run relevant tests: `R -q -e "devtools::test()"`
2. If exported functions changed: regenerate docs: `R -q -e "devtools::document()"`
3. If C++ code changed: rebuild compile DB: `./tools/gen_compile_commands.sh`
4. Cover edge cases in tests: empty inputs, all-NA columns, invalid user inputs
5. Keep C++ unit harness in sync across:
   - `src/cpp_tests.cpp`
   - `src/RcppExports.cpp`
   - `src/init.cpp`
   - `R/RcppExports.R`
   - `tests/testthat/test-18-cpp-units.R`
6. Preserve backward compatibility unless breakage is explicitly requested
