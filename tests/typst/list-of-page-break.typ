// Typst Extras - list of floats page break tests
#import "/_extensions/typst-extras/typst-extras.typ": typst-extras-list-of

#figure([a], kind: "quarto-float-fig", supplement: [Figure], caption: [One])
#figure([c], kind: "quarto-float-lst", supplement: [Listing], caption: [Code])

#typst-extras-list-of(
  (
    (kind: "quarto-float-fig", title: [Figures]),
    (kind: "quarto-float-tbl", title: [Tables]),
    (kind: "quarto-float-lst", title: [Listings]),
  ),
  page-break: true,
)

After the lists.

#context {
  assert.eq(counter(page).final(), (3,), message: "each rendered list must be followed by a page break")
}
