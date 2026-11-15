// Bare Typst - Typst Template
// A template that draws a title and the body only.
//
// @license MIT
// @copyright 2026 Mickaël Canouil
// @author Mickaël Canouil

#let article(title: none, doc) = {
  if title != none {
    align(center, text(size: 18pt, weight: "bold", title))
  }
  doc
}
