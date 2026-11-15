// Typst Extras - counter carry tests
// A book template resets the float and equation counters at each level-1 heading.
// The carry keeps one sequence across supplementary chapters.
//
// @license MIT
// @copyright 2026 Mickaël Canouil
// @author Mickaël Canouil

#import "/_extensions/typst-extras/typst-extras.typ": typst-extras-carry-mark, typst-extras-carry-restore

#let kinds = ("quarto-float-fig", "quarto-callout-Note")

#show heading.where(level: 1): it => {
  for kind in kinds {
    counter(figure.where(kind: kind)).update(0)
  }
  counter(math.equation).update(0)
  it
}
#set math.equation(numbering: "(1)")

/// Assert the value of a counter at the place of the call.
#let counter-reads(target, expected) = context {
  assert.eq(target.get().first(), expected)
}

= Supp one
#figure([a], caption: [A], kind: "quarto-float-fig", supplement: [Figure])
#figure([n], caption: [N], kind: "quarto-callout-Note", supplement: [Note])
$ x $ <eq-one>
#counter-reads(counter(figure.where(kind: "quarto-float-fig")), 1)

#typst-extras-carry-mark()
= Supp two
#typst-extras-carry-restore(kinds)
#counter-reads(counter(figure.where(kind: "quarto-float-fig")), 1)
#figure([b], caption: [B], kind: "quarto-float-fig", supplement: [Figure])
#figure([m], caption: [M], kind: "quarto-callout-Note", supplement: [Note])
$ y $
#counter-reads(counter(figure.where(kind: "quarto-float-fig")), 2)
#counter-reads(counter(figure.where(kind: "quarto-callout-Note")), 2)
#counter-reads(counter(math.equation), 2)

= Body
#counter-reads(counter(figure.where(kind: "quarto-float-fig")), 0)
