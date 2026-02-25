// kstfl/json_parser.h — Parse spec JSON, template JSON, data JSON into C++ structures
//
// Uses nlohmann/json (header-only, bundled in src/vendor/).
//
// Copyright (c) 2026 KeyStat Solutions. MIT License.

#ifndef KSTFL_JSON_PARSER_H
#define KSTFL_JSON_PARSER_H

#include "types.h"
#include <string>

namespace kstfl {

/// Parse a complete spec JSON file (containing _metadata + N spec entries).
/// @param json_path Path to the spec JSON file.
/// @return Parsed TFLDocument with all specs.
TFLDocument parse_spec_json(const std::string& json_path);

/// Parse a complete spec JSON from a string (for testing / Rcpp).
TFLDocument parse_spec_json_string(const std::string& json_str);

/// Parse a styles template JSON file.
/// @param json_path Path to the template JSON file.
/// @return Parsed StylesTemplate.
StylesTemplate parse_template_json(const std::string& json_path);

/// Parse a styles template JSON from a string.
StylesTemplate parse_template_json_string(const std::string& json_str);

/// Parse a data JSON file (column-oriented { "col": [values...] }).
/// @param json_path Path to the data JSON file.
/// @return Parsed DataTable.
DataTable parse_data_json(const std::string& json_path);

/// Parse a data JSON from a string.
DataTable parse_data_json_string(const std::string& json_str);

}  // namespace kstfl

#endif  // KSTFL_JSON_PARSER_H
