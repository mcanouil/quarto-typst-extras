// Typst Extras - list of floats tests
#import "/_extensions/typst-extras/typst-extras.typ": typst-extras-list-of

#figure([a], kind: "quarto-float-fig", supplement: [Figure], caption: [One])
#figure([b], kind: "quarto-float-fig", supplement: [Figure], caption: [Two])
#figure([c], kind: "quarto-float-lst", supplement: [Listing], caption: [Code])

#typst-extras-list-of((
  (kind: "quarto-float-fig", title: [Figures]),
  (kind: "quarto-float-tbl", title: [Tables]),
  (kind: "quarto-float-lst", title: [Listings]),
))

Before the empty lists.

#typst-extras-list-of(
  ((kind: "quarto-float-tbl", title: [Tables]),),
  page-break: true,
)

After the empty lists.

#context {
  let outlines = query(outline)
  assert.eq(outlines.len(), 2, message: "expected two outlines")
  assert.eq(outlines.map(o => o.title), ([Figures], [Listings]))
  assert.eq(counter(page).final(), (1,), message: "empty lists must not add a page")
}
