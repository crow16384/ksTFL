// kstfl/docx_drawing.cpp — drawing emission helpers for DocxEmitter

#include "docx_emitter.h"

namespace kstfl {

static constexpr const char *WP_NS_DRAWING = "http://schemas.openxmlformats.org/drawingml/2006/wordprocessingDrawing";
static constexpr const char *A_NS_DRAWING = "http://schemas.openxmlformats.org/drawingml/2006/main";
static constexpr const char *PIC_NS_DRAWING = "http://schemas.openxmlformats.org/drawingml/2006/picture";

// ---------------------------------------------------------------------------
// Helper: emit an inline <w:drawing> for a Figure spec
// ---------------------------------------------------------------------------

void DocxEmitter::emit_figure_drawing(XmlWriter &w, const std::string &r_id, int64_t cx_emu, int64_t cy_emu, int img_id,
                                      const std::optional<ParagraphProps> &paragraph_props) const {
  w.start_element("w:p");
  if (paragraph_props.has_value()) { emit_para_props(w, *paragraph_props); }
  w.start_element("w:r");
  w.start_element("w:drawing");

  w.start_element("wp:inline");
  w.namespace_decl("wp", WP_NS_DRAWING);
  w.attribute("distT", (int64_t)0);
  w.attribute("distB", (int64_t)0);
  w.attribute("distL", (int64_t)0);
  w.attribute("distR", (int64_t)0);

  w.start_element("wp:extent");
  w.attribute("cx", cx_emu);
  w.attribute("cy", cy_emu);
  w.end_element();

  w.start_element("wp:effectExtent");
  w.attribute("l", (int64_t)0);
  w.attribute("t", (int64_t)0);
  w.attribute("r", (int64_t)0);
  w.attribute("b", (int64_t)0);
  w.end_element();

  w.start_element("wp:docPr");
  w.attribute("id", (int64_t)img_id);
  w.attribute("name", "Image " + std::to_string(img_id));
  w.end_element();

  w.start_element("wp:cNvGraphicFramePr");
  w.start_element("a:graphicFrameLocks");
  w.namespace_decl("a", A_NS_DRAWING);
  w.attribute("noChangeAspect", "1");
  w.end_element();
  w.end_element(); // wp:cNvGraphicFramePr

  w.start_element("a:graphic");
  w.namespace_decl("a", A_NS_DRAWING);

  w.start_element("a:graphicData");
  w.attribute("uri", std::string(PIC_NS_DRAWING));

  w.start_element("pic:pic");
  w.namespace_decl("pic", PIC_NS_DRAWING);

  w.start_element("pic:nvPicPr");
  w.start_element("pic:cNvPr");
  w.attribute("id", (int64_t)0);
  w.attribute("name", "Figure");
  w.end_element();
  w.start_element("pic:cNvPicPr");
  w.end_element();
  w.end_element(); // pic:nvPicPr

  w.start_element("pic:blipFill");
  w.start_element("a:blip");
  w.attribute("r:embed", r_id);
  w.end_element();
  w.start_element("a:stretch");
  w.start_element("a:fillRect");
  w.end_element();
  w.end_element();
  w.end_element(); // pic:blipFill

  w.start_element("pic:spPr");
  w.start_element("a:xfrm");
  w.start_element("a:off");
  w.attribute("x", (int64_t)0);
  w.attribute("y", (int64_t)0);
  w.end_element();
  w.start_element("a:ext");
  w.attribute("cx", cx_emu);
  w.attribute("cy", cy_emu);
  w.end_element();
  w.end_element(); // a:xfrm
  w.start_element("a:prstGeom");
  w.attribute("prst", "rect");
  w.start_element("a:avLst");
  w.end_element();
  w.end_element(); // a:prstGeom
  w.end_element(); // pic:spPr

  w.end_element(); // pic:pic
  w.end_element(); // a:graphicData
  w.end_element(); // a:graphic

  w.end_element(); // wp:inline
  w.end_element(); // w:drawing
  w.end_element(); // w:r
  w.end_element(); // w:p
}

} // namespace kstfl
