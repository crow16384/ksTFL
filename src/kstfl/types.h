// kstfl/types.h — Core data structures for the ksTFL DOCX renderer
// Mirrors the JSON schema structures from spec_schema_v2.json and
// styles_schema_v2.json
//
// Copyright (c) 2026 I.Aleschenkov, V.Larchenko. GPL-3.0 License.

#ifndef KSTFL_TYPES_H
#define KSTFL_TYPES_H

#include <compare>
#include <concepts>
#include <cstdint>
#include <optional>
#include <stdexcept>
#include <string>
#include <unordered_map>
#include <vector>

namespace kstfl {

// ---------------------------------------------------------------------------
// Forward declarations
// ---------------------------------------------------------------------------
struct StyleDef;
struct ColumnSpec;
struct StubColumn;

// ---------------------------------------------------------------------------
// Error types
// ---------------------------------------------------------------------------

/// Exception thrown by any renderer component.
struct RenderError : public std::runtime_error {
  using std::runtime_error::runtime_error;
};

// ---------------------------------------------------------------------------
// Fundamental value types
// ---------------------------------------------------------------------------

/// Physical length stored internally in EMU (English Metric Units).
/// 1 EMU = 1/914400 inch = 1/360000 cm.
/// Twips: 1 twip = 1/20 pt = 1/1440 inch = 635 EMU.
struct Length {
  int64_t emu = 0;

  constexpr Length() = default;
  constexpr explicit Length(int64_t e) : emu(e) {}

  /// Parse a string like "2.54cm", "1in", "72pt", "1440twip", "914400emu",
  /// "50%". For percent, the `reference` EMU is used as the base.
  [[nodiscard]] static Length parse(const std::string &s, int64_t reference_emu = 0);

  // Convenience constructors
  static constexpr Length from_emu(int64_t e) { return Length{e}; }
  static constexpr Length from_twips(int64_t t) { return Length{t * 635}; }
  static constexpr Length from_pt(double p) { return Length{static_cast<int64_t>(p * 12700.0)}; }
  static constexpr Length from_cm(double c) { return Length{static_cast<int64_t>(c * 360000.0)}; }
  static constexpr Length from_in(double i) { return Length{static_cast<int64_t>(i * 914400.0)}; }

  // Conversions
  [[nodiscard]] constexpr int64_t to_twips() const {
    // Round to nearest twip instead of truncating, to minimize systematic error
    return (emu >= 0) ? (emu + 317) / 635 : (emu - 317) / 635;
  }
  [[nodiscard]] constexpr double to_pt() const { return static_cast<double>(emu) / 12700.0; }
  [[nodiscard]] constexpr double to_cm() const { return static_cast<double>(emu) / 360000.0; }
  [[nodiscard]] constexpr double to_in() const { return static_cast<double>(emu) / 914400.0; }
  [[nodiscard]] constexpr int64_t to_emu() const { return emu; }

  // Arithmetic
  constexpr Length operator+(Length rhs) const { return Length{emu + rhs.emu}; }
  constexpr Length operator-(Length rhs) const { return Length{emu - rhs.emu}; }
  constexpr Length operator*(double f) const { return Length{static_cast<int64_t>(emu * f)}; }
  constexpr Length operator/(double f) const { return Length{static_cast<int64_t>(emu / f)}; }
  constexpr auto operator<=>(const Length &rhs) const = default;
};

/// Conservative safety margin subtracted from available page height.
/// Accounts for minor rounding differences between our deterministic layout
/// engine and Word's own line-height / table-row calculations.  Keeping a
/// small unused reserve prevents content from overflowing onto an extra page.
/// Reduced from 15pt after improving CJK text measurement accuracy.
constexpr Length PAGE_SAFETY_MARGIN = Length::from_pt(10.0);

/// Concept for types that support style merging.
template <typename T>
concept Mergeable = requires(T t, const T &other) {
  { t.merge_from(other) };
  { t.merged_with(other) } -> std::same_as<T>;
};

/// CSS-like color stored as RRGGBB hex string (no leading #).
struct Color {
  std::string hex; // "000000", "FF0000", etc.

  Color() = default;
  explicit Color(std::string h) : hex(std::move(h)) {}

  /// Parse "#FF0000" or "FF0000" -> "FF0000"
  [[nodiscard]] static Color parse(const std::string &s);

  [[nodiscard]] bool empty() const { return hex.empty(); }
  bool operator==(const Color &other) const { return hex == other.hex; }
  bool operator!=(const Color &other) const { return !(*this == other); }
};

// ---------------------------------------------------------------------------
// Border types
// ---------------------------------------------------------------------------

/// Allowed border line styles (maps to w:val in OOXML <w:bdr>).
enum class BorderLineStyle {
  None,
  Single,
  Double,
  Dashed,
  Dotted,
  Thick,
  DashSmallGap,
  DotDash,
  DotDotDash,
  Triple,
  ThinThickSmallGap,
  ThickThinSmallGap,
  Wave
};

/// Convert BorderLineStyle to OOXML w:val string.
const char *border_line_style_to_ooxml(BorderLineStyle s);

/// A single border edge (e.g., top, bottom, left, right).
struct Border {
  std::optional<Color> color;
  std::optional<Length> width;
  std::optional<BorderLineStyle> line_style;

  /// Merge: later overrides earlier, nullopt does not override.
  Border merged_with(const Border &other) const;
  /// In-place merge: apply other's non-null fields onto this.
  void merge_from(const Border &other);
};

/// Four-sided borders (plus optional OOXML table inner borders).
struct Borders {
  std::optional<Border> top;
  std::optional<Border> bottom;
  std::optional<Border> left;
  std::optional<Border> right;
  std::optional<Border> insideH; // horizontal inner border (between rows)
  std::optional<Border> insideV; // vertical inner border (between columns)

  Borders merged_with(const Borders &other) const;
  void merge_from(const Borders &other);
};

// ---------------------------------------------------------------------------
// Style property groups
// ---------------------------------------------------------------------------

/// Font properties (maps to <w:rPr> in OOXML).
struct FontProps {
  std::optional<std::string> font_name; // e.g. "Courier New"
  std::optional<double> font_size;      // in pt (half-points in OOXML)
  std::optional<bool> bold;
  std::optional<bool> italic;
  std::optional<bool> underline;
  std::optional<bool> strikethrough;
  std::optional<Color> color;
  std::optional<Color> highlight;

  FontProps merged_with(const FontProps &other) const;
  void merge_from(const FontProps &other);
  bool operator==(const FontProps &other) const;
};

/// Text alignment values.
enum class Alignment { Left, Center, Right, Justify };

/// Convert Alignment to OOXML w:jc value string.
const char *alignment_to_ooxml(Alignment a);

/// Spacing properties for paragraphs.
struct SpacingProps {
  std::optional<Length> before;
  std::optional<Length> after;
  std::optional<double> line_spacing_multiplier; // e.g. 1.0, 1.15, 1.5
  std::optional<Length> exact_line_height;       // if set, emitter uses w:lineRule="exact"

  SpacingProps merged_with(const SpacingProps &other) const;
  void merge_from(const SpacingProps &other);
  bool operator==(const SpacingProps &other) const;
};

/// Indent properties.
struct IndentProps {
  std::optional<Length> left;
  std::optional<Length> right;
  std::optional<Length> first_line;
  std::optional<Length> hanging;

  IndentProps merged_with(const IndentProps &other) const;
  void merge_from(const IndentProps &other);
  bool operator==(const IndentProps &other) const;
};

/// Paragraph properties (maps to <w:pPr> in OOXML).
struct ParagraphProps {
  std::optional<Alignment> alignment;
  std::optional<SpacingProps> spacing;
  std::optional<IndentProps> indents;
  std::optional<bool> widow_control;
  std::optional<bool> keep_next;
  std::optional<bool> keep_lines;
  /// Outline level for TOC/headings (0-8). When set, paragraph is included in
  /// TOC \o and PDF bookmarks.
  std::optional<int> outline_level;

  ParagraphProps merged_with(const ParagraphProps &other) const;
  void merge_from(const ParagraphProps &other);
  bool operator==(const ParagraphProps &other) const;
};

/// Vertical alignment in table cells.
enum class VerticalAlignment { Top, Center, Bottom };

/// Text orientation in table cells.
enum class TextOrientation {
  Horizontal,
  BottomToTop, // btLr
  TopToBottom  // tbRl
};

/// Table cell properties (maps to <w:tcPr> in OOXML).
struct TableCellProps {
  std::optional<Color> background_color;
  std::optional<Borders> borders;
  std::optional<Length> cell_margin_top;
  std::optional<Length> cell_margin_bottom;
  std::optional<Length> cell_margin_left;
  std::optional<Length> cell_margin_right;
  std::optional<VerticalAlignment> vertical_alignment;
  std::optional<TextOrientation> text_orientation;
  std::optional<Length> row_height;

  TableCellProps merged_with(const TableCellProps &other) const;
  void merge_from(const TableCellProps &other);
};

/// Composite style definition (font + paragraph + table cell).
struct StyleDef {
  std::string id; // style identifier
  std::optional<FontProps> font;
  std::optional<ParagraphProps> paragraph;
  std::optional<TableCellProps> table_style;

  StyleDef merged_with(const StyleDef &other) const;
  void merge_from(const StyleDef &other);
  /// Equality for font + paragraph only (used for TOC-heading style
  /// deduplication).
  bool operator==(const StyleDef &other) const;
};

/// Maps style IDs to style definitions.
using StyleMap = std::unordered_map<std::string, StyleDef>;

// ---------------------------------------------------------------------------
// Page geometry
// ---------------------------------------------------------------------------

/// Standard paper sizes.
enum class PageSize { A4, A3, Letter, Legal, Executive };

/// Page orientation.
enum class Orientation { Portrait, Landscape };

/// Page margins including header/footer distances.
struct PageMargins {
  Length top;
  Length bottom;
  Length left;
  Length right;
  Length header_distance; // distance from page edge to header content
  Length footer_distance; // distance from page edge to footer content
};

/// Page margins override — optional fields distinguish "not set" from "set to
/// 0".
struct PageMarginsOverride {
  std::optional<Length> top;
  std::optional<Length> bottom;
  std::optional<Length> left;
  std::optional<Length> right;
  std::optional<Length> header_distance;
  std::optional<Length> footer_distance;
};

/// Page config override — optional fields so that spec only overrides
/// template values for explicitly specified fields.
struct PageConfigOverride {
  std::optional<PageSize> size;
  std::optional<Orientation> orientation;
};

/// Full page configuration.
struct PageConfig {
  PageSize size = PageSize::A4;
  Orientation orientation = Orientation::Landscape;
  PageMargins margins;

  /// Physical page dimensions (computed from size + orientation).
  [[nodiscard]] Length page_width() const;
  [[nodiscard]] Length page_height() const;

  /// Usable content area.
  [[nodiscard]] Length usable_width() const;
  [[nodiscard]] Length usable_height() const;
};

// ---------------------------------------------------------------------------
// Styles template (from styles_schema_v2.json)
// ---------------------------------------------------------------------------

/// Table style configuration from template.
struct TableStyleConfig {
  // Structural properties (non-overridable by specs)
  struct Structural {
    std::optional<StyleDef> all_headers;
    std::optional<StyleDef> table_body;
    std::optional<Border> header_top_border;
    std::optional<Border> header_bottom_border;
    std::optional<Border> table_bottom_border;
  };

  // Default row styles
  std::optional<StyleDef> header_row;
  std::optional<StyleDef> body_row;

  // Layout
  std::optional<Alignment> table_alignment; // table alignment on page (left/center/right)
  std::optional<Length> top_empty_line;     // spacer row after header
  std::optional<Length> bottom_empty_line;  // spacer row before bottom border
  std::optional<Borders> table_borders;
  bool allow_row_break_across_pages = false; // rows can split across pages
  bool repeat_header_on_each_page = true;    // header repeated on each page
  std::optional<Length> default_cell_margin_top;
  std::optional<Length> default_cell_margin_bottom;
  std::optional<Length> default_cell_margin_left;
  std::optional<Length> default_cell_margin_right;

  Structural structural;
};

/// Named text styles from template.
struct TextStyles {
  StyleDef default_style;
  StyleDef doc_header;
  StyleDef doc_footer;
  StyleDef titles;
  StyleDef subtitles;
  StyleDef footnotes;
  StyleDef table_header;
  StyleDef table_body;
  StyleDef toc_title;
  StyleDef toc_entry;
  StyleDef figure_caption;
};

/// Figure defaults from template styles.
struct FigureStyleConfig {
  std::optional<Alignment> alignment;
  std::optional<Length> space_before;
  std::optional<Length> space_after;
  std::string caption_position = "below"; // above | below
  std::string caption_text_style_ref = "figureCaption";
};

/// Complete styles template.
struct StylesTemplate {
  PageConfig page;
  TextStyles text_styles;
  TableStyleConfig table_style;
  FigureStyleConfig figure_style;
  std::optional<bool> widow_control;
};

// ---------------------------------------------------------------------------
// Column model
// ---------------------------------------------------------------------------

/// Column format specification.
struct ColumnFormat {
  std::optional<std::string> type;            // "character", "numeric", "integer", "date", "logical"
  std::optional<std::string> format;          // e.g. "0.00", "%Y-%m-%d"
  std::optional<std::string> missings;        // replacement text for NA/missing
  std::optional<std::string> col_width_raw;   // raw width string (e.g. "15%", "2in") — resolved later
  std::optional<std::string> value_style_ref; // styleRef for body values
};

/// Single column definition.
struct ColumnSpec {
  std::string id;    // column identifier key
  std::string label; // display label
  int col_order = 0; // sort order
  bool is_visible = true;
  bool is_id = false;        // ID column repeats on page breaks
  bool is_grouping = false;  // triggers dynamic subtitles and group breaks
  bool is_col_break = false; // horizontal segment boundary
  bool dedupe = false;       // suppress consecutive duplicate values
  bool is_paging = false;    // deprecated; value change forces page break
  ColumnFormat format;
  std::optional<std::string> label_style_ref; // styleRef for column label

  // Resolved widths (populated by StyleResolver)
  Length resolved_width;
};

// ---------------------------------------------------------------------------
// Stub columns (spanning headers)
// ---------------------------------------------------------------------------

/// A spanning header entry.
struct StubColumn {
  std::string label;
  int stub_order = 0;            // descending sort order for depth
  std::vector<std::string> cols; // column IDs spanned
  std::optional<std::string> label_style_ref;

  // Resolved span width (populated during header grid build)
  Length resolved_width;
};

// ---------------------------------------------------------------------------
// Text groups (titles, subtitles, footnotes, bodyText)
// ---------------------------------------------------------------------------

/// A text group with order and styling.
struct TextGroup {
  std::vector<std::string> text; // lines within the group
  int order = 0;
  std::vector<std::string> style_refs; // style refs merged in order (R side may pass multiple)
  // Placement flags
  bool body_placement = false; // true = render in body area, false = header/footer section
  // TOC: when > 0, first occurrence of this title is marked as TC field at this
  // level (1-9)
  int toc_level = 0;
};

// ---------------------------------------------------------------------------
// Header / Footer rows
// ---------------------------------------------------------------------------

/// A single header or footer row (3-column layout: left, center, right).
struct HeaderFooterRow {
  std::string left;
  std::string center;
  std::string right;
  int order = 0;
  std::optional<std::string> style_ref;
};

// ---------------------------------------------------------------------------
// styleRows actions (from row_style_actions_schema_v0.json)
// ---------------------------------------------------------------------------

/// Style action: apply styleRef to specific columns in a row.
struct StyleAction {
  std::vector<std::string> cols;
  std::string style_ref;
};

/// Merge action: horizontally merge cells.
struct MergeAction {
  std::vector<std::string> cols;        // columns to merge (min 2)
  std::optional<std::string> style_ref; // optional override style
};

/// Add-row action: insert synthetic row above or below.
struct AddRowAction {
  enum class Position { Above, Below };
  Position pos = Position::Below;
  std::string value_from; // column whose value populates the synthetic row
  std::optional<std::string> style_ref;
};

/// Page-break action: force page break before this row.
struct PageBreakAction {};

/// Clear action: blank the display text of specified visible cells.
struct ClearAction {
  std::vector<std::string> cols; // target visible column ids
};

/// Glue action: concatenate a value to the text of specified visible cells.
struct GlueAction {
  std::vector<std::string> cols;       // target visible column ids
  std::string position;                // "before" or "after"
  std::optional<std::string> glue_col; // source data column (visible or hidden)
  std::optional<std::string> text;     // literal text (mutually exclusive with glue_col)
  std::string separator;               // inserted between existing text and glued value
                                       // when both sides are non-empty; "" = direct concat
};

/// Complete set of actions for a single data row.
struct RowActionSet {
  std::vector<StyleAction> styles;
  std::vector<ClearAction> clears;
  std::vector<MergeAction> merges;
  std::vector<GlueAction> glues;
  std::vector<AddRowAction> add_rows;
  std::vector<PageBreakAction> page_breaks;

  [[nodiscard]] bool empty() const {
    return styles.empty() && clears.empty() && merges.empty() && glues.empty() && add_rows.empty() &&
           page_breaks.empty();
  }
};

// ---------------------------------------------------------------------------
// Data table (column-oriented)
// ---------------------------------------------------------------------------

/// Column-oriented data table loaded from data JSON.
struct DataTable {
  std::vector<std::string> col_names;
  /// Each column is a vector of string values (pre-formatted).
  std::unordered_map<std::string, std::vector<std::string>> columns;
  size_t n_rows = 0;

  [[nodiscard]] const std::vector<std::string> &col(const std::string &name) const;
};

// ---------------------------------------------------------------------------
// Document information (from spec JSON `document` section)
// ---------------------------------------------------------------------------

/// Document type enum.
enum class DocType { Table, Figure, Text };

/// Footnote placement strategy.
enum class FootnotePlace {
  DocFooter, // place footnotes inside the Word footer part (w:ftr), below
             // footer rows
  Repeated,  // place footnotes under the table on every page
  LastPage   // place footnotes under the table on the last page only
};

/// Document info from spec JSON.
struct DocumentInfo {
  DocType doc_type = DocType::Table;
  bool has_data = true;
  bool glue_num_type = false; // informational: number type was auto-generated
  int doc_order = 0;
  bool is_continues = false;                    // if true, titles don't repeat on subsequent pages
  std::optional<std::string> content_width_raw; // e.g. "100%", "16cm", "6.5in"
  FootnotePlace footnote_place = FootnotePlace::Repeated;
  std::optional<Length> top_empty_line;    // spacer row after table header
  std::optional<Length> bottom_empty_line; // spacer row before table bottom border
};

/// Figure-specific rendering options.
struct FigureInfo {
  std::optional<std::string> width;  // e.g. "70%", "6in", "12cm"
  std::optional<std::string> height; // e.g. "50%", "4in", "8cm"
  std::string scale_mode = "fixed";  // fixed | fitWidth | fitPage
  std::string device = "svg";        // png | jpeg | jpg | svg
};

// ---------------------------------------------------------------------------
// Single TFL specification
// ---------------------------------------------------------------------------

/// A complete parsed TFL specification.
struct TFLSpec {
  std::string key; // spec key (e.g. "spec1_abc123def456")
  DocumentInfo document;

  // Attributes
  PageConfigOverride page_override; // overrides from attribs.documentStyle.page
  bool has_page_override = false;
  PageMarginsOverride margin_overrides; // explicit margin overrides (optional per field)
  StyleMap spec_styles;                 // per-spec style definitions

  // Content sections
  std::vector<HeaderFooterRow> headers;
  std::vector<HeaderFooterRow> footers;

  // Table structure
  std::vector<StubColumn> stub_columns;
  std::vector<ColumnSpec> columns;      // ordered by colOrder, filtered by isVisible
  std::vector<RowActionSet> style_rows; // one per data row (parsed JSON strings)

  // Text
  std::vector<TextGroup> titles;
  std::vector<TextGroup> subtitles;
  std::vector<TextGroup> footnotes;
  std::vector<TextGroup> body_text;

  // Data reference
  std::string data_ref;    // links to data JSON file
  std::string figure_path; // for Figure docType: path to image file
  FigureInfo figure;
};

// ---------------------------------------------------------------------------
// Top-level document (entire report)
// ---------------------------------------------------------------------------

/// Metadata from spec JSON `_metadata` section.
struct ReportMetadata {
  std::string out_dir;
  std::string doc_file_name;
  std::string datetime;
  bool insert_toc = false;
  std::string toc_title = "Table of Contents";
};

/// A complete parsed TFL document (N specs from a single spec JSON).
struct TFLDocument {
  ReportMetadata metadata;
  std::vector<TFLSpec> specs; // ordered by docOrder
};

// ---------------------------------------------------------------------------
// Renderer configuration
// ---------------------------------------------------------------------------

/// Runtime configuration for the renderer.
struct RendererConfig {
  /// If true, data values are already formatted strings; no numeric formatting
  /// needed.
  bool data_values_preformatted = true;

  /// Additional font search directories.
  std::vector<std::string> font_dirs;

  /// Path to embedded fallback font (Liberation Sans).
  std::string fallback_font_path;

  /// Use field codes (PAGE/NUMPAGES) for page numbering vs literal text.
  bool use_field_codes = true;

  /// Enable debug output / logging.
  bool verbose = false;
};

// ---------------------------------------------------------------------------
// Logical row model (output of LogicalTableBuilder)
// ---------------------------------------------------------------------------

/// Classification of a row in the final stream.
enum class LogicalRowType {
  DataRow,      // original data row
  SyntheticRow, // inserted by add_row action
  GroupBreak    // marks a grouping boundary (not rendered directly)
};

/// A single cell in the logical row.
struct LogicalCell {
  std::string text;                    // display text
  std::string col_id;                  // which column this cell belongs to
  bool is_merged = false;              // part of a horizontal merge
  bool is_merge_leader = false;        // first cell in a merge group
  int merge_span = 1;                  // number of columns spanned (1 = no merge)
  Length merged_width;                 // combined width if merge_leader
  std::vector<std::string> style_refs; // cell-level style overrides (applied in order via merge_from)
  bool is_deduped = false;             // blanked by apply_dedupe() — glue skips these
};

/// A row in the logical row stream (after styleRows processing).
struct LogicalRow {
  LogicalRowType type = LogicalRowType::DataRow;
  size_t source_index = 0; // original data row index (or parent index if synthetic)
  std::vector<LogicalCell> cells;
  std::optional<std::string> row_style_ref;
  bool force_page_break = false;                             // explicit page break before this row
  bool is_group_boundary = false;                            // grouping value changed
  bool is_oversized = false;                                 // row height exceeds available page body
  Length capped_height;                                      // for oversized rows: max height within page
  std::unordered_map<std::string, std::string> group_values; // current grouping col values

  // Measured height (populated by TextMeasurer)
  Length measured_height;
};

// ---------------------------------------------------------------------------
// Header grid (table header rows including stub columns)
// ---------------------------------------------------------------------------

/// Vertical merge state for header grid cells.
enum class VMergeState {
  None,    // no vertical merge
  Restart, // start of a vertical merge group
  Continue // continuation of a vertical merge group (empty cell)
};

/// A cell in the header grid.
struct HeaderGridCell {
  std::string label;
  int col_span = 1;
  int row_span = 1;
  Length width;
  std::optional<std::string> style_ref;
  VMergeState v_merge = VMergeState::None; // vertical merge state
  // Carries the column's text_orientation so the measurer can swap
  // width/height when the label is rendered rotated.
  std::optional<TextOrientation> text_orientation;
  // Index of the first column in spec.columns that this cell covers.
  // Used by the emitter to map header cells to segment column indices
  // when invisible columns create gaps in the index space.
  size_t source_col_index = 0;
};

/// The complete header grid (one or more rows).
struct HeaderGrid {
  std::vector<std::vector<HeaderGridCell>> rows;
  Length total_height;             // measured total header height
  std::vector<Length> row_heights; // per-row measured heights
};

// ---------------------------------------------------------------------------
// Pagination result
// ---------------------------------------------------------------------------

/// A single page in the paginated output.
struct PageSlice {
  size_t page_number = 0; // 1-based
  size_t first_row = 0;   // index into logical row stream
  size_t last_row = 0;    // index into logical row stream (inclusive)
  bool is_first_page = true;
  bool is_last_page = true;

  // What content appears on this page
  bool has_titles = true;
  bool has_subtitles = true;
  bool has_footnotes = false;                       // whether footnotes render on this page
  std::vector<std::string> dynamic_subtitle_values; // resolved #ByGroupX values

  // Heights reserved
  Length header_section_height;
  Length titles_height;
  Length subtitles_height;
  Length table_header_height;
  Length body_height;
  Length footnotes_height;
  Length footer_section_height;
};

/// A horizontal segment (from isColBreak).
struct HorizontalSegment {
  size_t segment_index = 0;
  std::vector<size_t> column_indices; // indices into TFLSpec::columns
  std::vector<PageSlice> pages;
  std::vector<Length> row_heights; // per-segment row heights (indexed by row)
};

/// Complete pagination result for one spec.
struct PaginationResult {
  std::vector<HorizontalSegment> segments;
  size_t total_pages = 0;
};

// ---------------------------------------------------------------------------
// Inline markup model
// ---------------------------------------------------------------------------

/// Run-level style overrides from inline markup.
struct InlineRunStyle {
  bool bold_override = false;
  bool italic_override = false;
  bool underline_override = false;
  bool strikethrough_override = false;
  bool superscript = false;
  bool subscript = false;
};

/// A single run of text with uniform styling.
struct TextRun {
  std::string text;
  InlineRunStyle style;
};

/// A paragraph (sequence of runs).
struct ParsedParagraph {
  std::vector<TextRun> runs;
};

/// A parsed cell (sequence of paragraphs).
struct ParsedCell {
  std::vector<ParsedParagraph> paragraphs;
};

} // namespace kstfl

#endif // KSTFL_TYPES_H
