// Typst Extras - appendix and supplementary section tests
#import "/_extensions/typst-extras/typst-extras.typ": (
  typst-extras-appendix-numbering, typst-extras-config-state, typst-extras-heading-label, typst-extras-heading-numbering,
  typst-extras-part,
  typst-extras-part-start, typst-extras-ref, typst-extras-reset-chapter, typst-extras-wrap,
  typst-extras-wrap-theorem,
)

#let config = (
  chapters: false,
  appendix-delimiter: ".",
  supplementary-prefix: "S",
  appendix-title: "Appendix",
  appendix-delim: " :",
  number-sections: true,
  section-prefix: "Section",
  chapter-prefix: "Chapter",
)
#typst-extras-config-state.update(config)
#let kinds = ("quarto-float-fig", "theorem")

#set heading(numbering: "1.1")
#show: body => context { set figure(numbering: typst-extras-wrap(figure.numbering, "1")); body }
#show ref: typst-extras-ref

/// Assert the number the last figure of a kind displays, at the place of the call.
#let figure-reads(expected, kind: "quarto-float-fig") = context {
  let last = query(figure.where(kind: kind).before(here())).last()
  assert.eq(numbering(last.numbering, ..last.counter.at(last.location())), expected)
}

/// Assert the label a reference to a heading renders, or `none` when the reference stays as it is.
#let ref-reads(target, expected, supplement: auto) = context {
  assert.eq(typst-extras-heading-label(query(target).first(), supplement: supplement), expected)
}

/// Assert the number the last heading displays.
#let heading-reads(expected) = context {
  let last = query(selector(heading).before(here())).last()
  assert.eq(numbering(last.numbering, ..counter(heading).at(last.location())), expected)
}

#let fig(body) = figure(body, kind: "quarto-float-fig", supplement: [Figure], caption: body)
#let theorem-numbering = typst-extras-wrap-theorem(loc => "1.1", "1")
#let thm(body) = figure(body, kind: "theorem", supplement: [Theorem], numbering: "1")
#let thm-unnumbered(body) = figure(body, kind: "theorem", supplement: [Theorem], numbering: none)

/// Assert the number the theorem wrap gives the last theorem, at the location of that theorem.
#let theorem-reads(expected) = context {
  let last = query(figure.where(kind: "theorem").before(here())).last()
  let loc = last.location()
  assert.eq(numbering(theorem-numbering(loc), ..last.counter.at(loc)), expected)
}

// Pure numbering functions.
#assert.eq(typst-extras-heading-numbering(1, part: "appendix", config: config), "A")
#assert.eq(typst-extras-heading-numbering(2, 1, part: "appendix", config: config), "B.1")
#assert.eq(typst-extras-heading-numbering(1, 3, 2, part: "appendix", config: config), "A.3.2")
#assert.eq(typst-extras-heading-numbering(1, part: "supplementary", config: config), "S1")
#assert.eq(typst-extras-heading-numbering(2, 1, part: "supplementary", config: config), "S2.1")
#assert.eq(
  typst-extras-heading-numbering(2, part: "supplementary", config: config + (supplementary-prefix: "SM")),
  "SM2",
)
#assert.eq(
  typst-extras-heading-numbering(2, 1, part: "appendix", config: config + (number-sections: false)),
  none,
  message: "sub-headings are unnumbered without number-sections",
)
#assert.eq(typst-extras-heading-numbering(1, part: "appendix", config: config + (number-sections: false)), "A")
#assert.eq(typst-extras-appendix-numbering(2, config: config), "Appendix B :")
#assert.eq(typst-extras-appendix-numbering(2, 1, config: config), "B.1")
#assert.eq(typst-extras-appendix-numbering(2, 1, config: config + (number-sections: false)), none)

= Body <body>
#fig[a]
#fig[b]
#figure-reads("2")
#thm[t]
#thm[u]
#theorem-reads("2")
#ref-reads(<body>, none)

#typst-extras-part-start("appendix", kinds)
#context assert.eq(typst-extras-part.get(), "appendix")
#context assert.eq(
  state("typst-extras-part", "body").get(),
  "appendix",
  message: "templates read the part by the documented state key",
)
#context assert.eq(counter(heading).get(), (0,), message: "the part starts the heading counter again")
#set heading(numbering: typst-extras-appendix-numbering.with(config: config))
= Extra <extra>
#heading-reads("Appendix A :")
#fig[c]
#figure-reads("A.1")
#thm[v]
#theorem-reads("A.1")
== Detail <detail>
#heading-reads("A.1")
#fig[d]
#figure-reads("A.2")

#typst-extras-reset-chapter(kinds)
= More <more>
#fig[e]
#figure-reads("B.1")
#thm[w]
#theorem-reads("B.1")
#thm-unnumbered[w2]
#thm[w3]
#theorem-reads("B.2")
#ref-reads(<extra>, "Appendix A")
#ref-reads(<detail>, "Appendix A.1")
#ref-reads(<more>, "Appendix B")
#ref-reads(<extra>, "Appendix A", supplement: [Section])
#ref-reads(<extra>, "Appendix A", supplement: [Chapter])
#ref-reads(<extra>, "A", supplement: [])
#ref-reads(<detail>, "A.1", supplement: [])
#ref-reads(<detail>, "Annex A.1", supplement: [Annex])
#ref-reads(<extra>, "Supporting annex A", supplement: [Supporting annex])

// The bibliography title in an appendix stays unnumbered, and does not step the heading counter.
#bibliography("/tests/appendix.bib", full: true)
#context {
  let title = query(selector(heading).before(here())).last()
  assert.eq(title.body, [Bibliography])
  assert.eq(title.numbering, none, message: "the bibliography title is unnumbered")
  assert.eq(counter(heading).get(), (2,), message: "the bibliography title does not step the heading counter")
}

#typst-extras-part-start("supplementary", kinds)
#set heading(numbering: typst-extras-heading-numbering.with(part: "supplementary", config: config))
= First supplement <supp>
#heading-reads("S1")
#fig[f]
#figure-reads("S1")
#thm[x]
#theorem-reads("S1")
== Sub <supp-sub>
= Second supplement
#fig[g]
#figure-reads("S2", kind: "quarto-float-fig")
#thm[y]
#theorem-reads("S2")
#heading-reads("S2")
#ref-reads(<supp>, "S1")
#ref-reads(<supp-sub>, "S1.1")
#ref-reads(<supp>, "S1", supplement: [])
#ref-reads(<supp>, "S1", supplement: [Section])
#ref-reads(<supp>, "S1", supplement: [Chapter])
#ref-reads(<supp>, "Table S1", supplement: [Table])
#ref-reads(<body>, none)

// The reference rule renders the label as a link.
See @extra and @supp-sub.
#context assert.eq(query(link).len(), 2, message: "each part reference renders as a link")
