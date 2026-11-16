// Typst Extras - section-aware numbering tests
#import "/_extensions/typst-extras/typst-extras.typ": (
  typst-extras-config-state, typst-extras-part, typst-extras-prefix, typst-extras-reset,
  typst-extras-reset-chapter, typst-extras-wrap, typst-extras-wrap-theorem,
)

#let config = (
  chapters: true,
  appendix-delimiter: ".",
  supplementary-prefix: "S",
  appendix-title: "Appendix",
  appendix-delim: " :",
  number-sections: true,
  section-prefix: "Section",
  chapter-prefix: "Chapter",
)
#typst-extras-config-state.update(config)

#set heading(numbering: "1.1")
#show: body => context { set figure(numbering: typst-extras-wrap(figure.numbering, "1")); body }
#let equation-numbering = typst-extras-wrap("(1)", "(1)")
#let kinds = ("quarto-float-fig", "quarto-float-tbl")

/// Assert the number the last figure of a kind displays, at the place of the call.
#let figure-reads(expected, kind: "quarto-float-fig") = context {
  let last = query(figure.where(kind: kind).before(here())).last()
  assert.eq(numbering(last.numbering, ..last.counter.at(last.location())), expected)
}

/// Assert the number the last equation displays, at the place of the call.
#let equation-reads(expected) = context {
  let last = query(math.equation.where(block: true).before(here())).last()
  assert.eq(numbering(last.numbering, ..counter(math.equation).at(last.location())), expected)
}

#let fig(body) = figure(body, kind: "quarto-float-fig", supplement: [Figure], caption: body)

#context assert.eq(typst-extras-prefix(), "0.", message: "the prefix uses the heading counter")

#typst-extras-reset-chapter(kinds)
= One
#fig[a]
#figure-reads("1.1")
#fig[b]
#figure-reads("1.2")
#math.equation(block: true, numbering: equation-numbering, $ a $)
#equation-reads("(1.1)")

== Sub-heading
#typst-extras-reset-chapter(kinds)
=== Sub-sub-heading
#fig[c]
#figure-reads("1.3", kind: "quarto-float-fig")

#typst-extras-reset-chapter(kinds)
= Two
#fig[d]
#figure-reads("2.1")
#fig[e]
#figure-reads("2.2")
#math.equation(block: true, numbering: equation-numbering, $ b $)
#equation-reads("(2.1)")

// A plain figure counter reset does not reach the per-kind counters.
#counter(figure).update(0)
= Three
#fig[f]
#figure-reads("3.3")

#typst-extras-reset(kinds)
#fig[g]
#figure-reads("3.1")

#typst-extras-reset-chapter(kinds)
= Four
#fig[h]
#figure-reads("4.1")

#typst-extras-reset-chapter(kinds)
#heading(numbering: none)[Not a chapter]
#fig[i]
#figure-reads("4.2", kind: "quarto-float-fig")

// A theorem numbering takes a location and returns a pattern or a function.
#context {
  let theorem = typst-extras-wrap-theorem(loc => "1.1", "1")
  assert.eq(numbering(theorem(here()), 9, 7), "4.7", message: "the prefix comes from the heading, not the counter")
}

// The prefix follows the part.
#typst-extras-part.update("supplementary")
#context assert.eq(typst-extras-prefix(), "S")
#fig[j]
#figure-reads("S3")
#typst-extras-part.update("appendix")
#counter(heading).update(0)
#context assert.eq(typst-extras-prefix(), "A.", message: "the appendix letter starts at A before the first heading")
#counter(heading).update(2)
#context assert.eq(typst-extras-prefix(), "B.", message: "the appendix letter follows the heading counter of the part")
#typst-extras-part.update("body")
#counter(heading).update(4)

// Without chapters the original numbering is used, whether a pattern or a function.
#typst-extras-config-state.update(config + (chapters: false))
#context {
  assert.eq(typst-extras-prefix(), "")
  assert.eq(numbering(typst-extras-wrap("(1)", "(1)"), 5), "(5)")
  assert.eq(numbering(typst-extras-wrap(n => "<" + str(n) + ">", "1"), 5), "<5>")
  let theorem = typst-extras-wrap-theorem(loc => "1.1", "1")
  assert.eq(numbering(theorem(here()), 7), "7")
}
#fig[k]
#figure-reads("4")
