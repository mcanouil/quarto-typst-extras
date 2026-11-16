// Typst Extras - chapter numbering when the template leaves headings unnumbered
#import "/_extensions/typst-extras/typst-extras.typ": (
  typst-extras-config-state, typst-extras-prefix, typst-extras-reset-chapter, typst-extras-wrap,
)

#typst-extras-config-state.update((
  chapters: true,
  appendix-delimiter: ".",
  supplementary-prefix: "S",
  appendix-title: "Appendix",
  appendix-delim: " :",
  number-sections: true,
  section-prefix: "Section",
  chapter-prefix: "Chapter",
))

#show: body => context { set figure(numbering: typst-extras-wrap(figure.numbering, "1")); body }
#let equation-numbering = typst-extras-wrap("(1)", "(1)")
#let kinds = ("quarto-float-fig",)

#let figure-reads(expected) = context {
  let last = query(figure.where(kind: "quarto-float-fig").before(here())).last()
  assert.eq(numbering(last.numbering, ..last.counter.at(last.location())), expected)
}

#let fig(body) = figure(body, kind: "quarto-float-fig", supplement: [Figure], caption: body)

#typst-extras-reset-chapter(kinds)
= One
#context assert.eq(typst-extras-prefix(), "", message: "an unnumbered level-1 heading gives no chapter prefix")
#fig[a]
#figure-reads("1")

#typst-extras-reset-chapter(kinds)
= Two
#fig[b]
#figure-reads("2")
#math.equation(block: true, numbering: equation-numbering, $ a $)
#context {
  let last = query(math.equation.where(block: true).before(here())).last()
  assert.eq(numbering(last.numbering, ..counter(math.equation).at(last.location())), "(1)")
}

