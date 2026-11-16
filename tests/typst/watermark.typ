// Typst Extras - watermark tests
#import "/_extensions/typst-extras/typst-extras.typ": typst-extras-watermark

/// Assert that a watermark places an artefact at a position, with the given rotation, and return the drawn mark.
#let drawn(mark, position, angle) = {
  assert.eq(mark.func(), place, message: "the watermark is placed on the page")
  assert.eq(mark.alignment, position)
  let artifact = mark.body
  assert.eq(artifact.func(), pdf.artifact, message: "the watermark is an artefact, so screen readers skip it")
  let turned = artifact.body
  assert.eq(turned.func(), rotate)
  assert.eq(turned.angle, angle)
  // A text mark carries its text style, so its text is the child of the styled element.
  if turned.body.has("child") { turned.body.child } else { turned.body }
}

#let text-mark = drawn(typst-extras-watermark(text: "DRAFT"), center + horizon, -45deg)
#assert.eq(text-mark.func(), text)
#assert.eq(text-mark.text, "DRAFT")

#let image-mark = drawn(
  typst-extras-watermark(image: "/tests/watermark.svg", position: top + right),
  top + right,
  0deg,
)
#assert.eq(image-mark.func(), image)
#assert.eq(image-mark.width, 50%)

#let corner-mark = drawn(
  typst-extras-watermark(text: "CORNER", position: bottom + left, angle: 0deg, size: 2em, colour: red, opacity: 40%),
  bottom + left,
  0deg,
)
#assert.eq(corner-mark.text, "CORNER")

#set page(foreground: typst-extras-watermark(text: "DRAFT"))

Body text of the first page.

#set page(foreground: typst-extras-watermark(image: "/tests/watermark.svg", position: top + right))

Body text with an image mark.

#set page(foreground: typst-extras-watermark(text: "CORNER", position: bottom + left, angle: 0deg, size: 2em, colour: red, opacity: 40%))

Body text with a corner mark.

#context {
  assert.eq(counter(page).final(), (3,))
}
