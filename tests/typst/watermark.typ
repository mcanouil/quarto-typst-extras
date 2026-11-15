// Typst Extras - watermark tests
#import "/_extensions/typst-extras/typst-extras.typ": typst-extras-watermark

#set page(foreground: typst-extras-watermark(text: "DRAFT"))

Body text of the first page.

#set page(foreground: typst-extras-watermark(image: "/tests/watermark.svg", position: top + right))

Body text with an image mark.

#set page(foreground: typst-extras-watermark(text: "CORNER", position: bottom + left, angle: 0deg, size: 2em, colour: red, opacity: 40%))

Body text with a corner mark.

#context {
  assert.eq(counter(page).final(), (3,))
}
