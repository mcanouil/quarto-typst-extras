// Typst Extras - Typst Library
// Helpers shared by the Typst Extras modules.
// Included once per render, and only when a module asks for it.
//
// @license MIT
// @copyright 2026 Mickaël Canouil
// @author Mickaël Canouil

/// Render one outline for each float kind that has at least one figure.
///
/// - lists (array): Entries of `(kind: str, title: content)`, in display order.
/// A kind listed twice renders twice, which is a caller error.
///
/// - page-break (bool): Put a weak page break after each rendered list.
#let typst-extras-list-of(lists, page-break: false) = context {
  for entry in lists {
    let floats = figure.where(kind: entry.kind)
    if query(floats).len() > 0 {
      outline(title: entry.title, target: floats)
      if page-break { pagebreak(weak: true) }
    }
  }
}

/// Build the content of a page watermark, for `page(foreground: ..)`.
/// The mark is wrapped in `pdf.artifact`, so screen readers skip it.
///
/// - text (str, none): Text to draw, in bold.
/// - image (str, none): Path of an image to draw. Typst images have no opacity, so fade the file itself.
/// - opacity (ratio): Opacity of the text. Not used for an image.
/// - angle (angle, auto): Rotation. `auto` is `-45deg` for text and `0deg` for an image.
/// - size (length): Text size.
/// - colour (color): Text colour.
/// - position (alignment): Where the mark sits on the page.
/// - width (length, ratio): Width of the image.
#let typst-extras-watermark(
  text: none,
  image: none,
  opacity: 15%,
  angle: auto,
  size: 4em,
  colour: gray,
  position: center + horizon,
  width: 50%,
) = {
  assert(
    (text == none) != (image == none),
    message: "typst-extras-watermark: set exactly one of text and image",
  )
  let is-text = text != none
  let turn = if angle == auto { if is-text { -45deg } else { 0deg } } else { angle }
  let mark = if is-text {
    std.text(weight: "bold", size: size, fill: colour.transparentize(100% - opacity), text)
  } else {
    std.image(image, width: width)
  }
  place(position, pdf.artifact(rotate(turn, mark)))
}

/// Part of the document the content sits in: `"body"`, `"appendix"` or `"supplementary"`.
#let typst-extras-part = state("typst-extras-part", "body")

/// Section settings, from `typst-extras-config`, which Lua binds in the header.
/// The functions below read this state, because the library is included before that binding.
#let typst-extras-config-state = state("typst-extras-config", (
  chapters: false,
  appendix-delimiter: ".",
  supplementary-prefix: "S",
  appendix-title: "Appendix",
  appendix-delim: " \u{2014}",
  number-sections: false,
))

/// Return the prefix of a number at a location. Needs `context`.
/// It is `""` in the body without chapters, `"<chapter>."` in the body with chapters,
/// the appendix letter and `appendix-delimiter` in an appendix,
/// and `supplementary-prefix` in a supplementary section.
/// The appendix letter comes from the heading counter, which `typst-extras-part-start` sets to 0.
///
/// - loc (location, auto): Where to read the part and the heading counter. `auto` is `here()`.
#let typst-extras-prefix(loc: auto) = {
  let at(value) = if loc == auto { value.get() } else { value.at(loc) }
  let config = at(typst-extras-config-state)
  let part = at(typst-extras-part)
  let chapter = at(counter(heading)).first()
  if part == "appendix" {
    numbering("A", calc.max(chapter, 1)) + config.appendix-delimiter
  } else if part == "supplementary" {
    config.supplementary-prefix
  } else if config.chapters {
    str(chapter) + "."
  } else {
    ""
  }
}

/// Return a numbering function that puts the prefix in front of the number.
/// Without a prefix it calls the original numbering, so other numbering stays as it was.
///
/// - original (str, function): Numbering to use without a prefix.
/// - pattern (str): Pattern of the number after the prefix, such as `"1"` or `"(1)"`.
/// The prefix goes after the leading punctuation, so `"(1)"` gives `"(2.1)"`.
/// - loc (location, auto): Where to read the prefix. `auto` is where the number is displayed.
#let typst-extras-wrap(original, pattern, loc: auto) = (..nums) => {
  let prefix = typst-extras-prefix(loc: loc)
  if prefix == "" {
    numbering(original, ..nums)
  } else {
    let number = numbering(pattern, nums.pos().last())
    let lead = number.match(regex("^[^\p{L}\p{N}]*")).end
    number.slice(0, lead) + prefix + number.slice(lead)
  }
}

/// Return where the numbering of a part section starts, before a location. Needs `context`.
/// In an appendix it is the last level-1 heading or part start; in a supplementary section, the part start.
///
/// - part (str): `"appendix"` or `"supplementary"`.
/// - loc (location): Where to look back from.
#let typst-extras-section-start(part, loc) = {
  let start = selector(<typst-extras-part-start>)
  let marks = if part == "appendix" { start.or(heading.where(level: 1)) } else { start }
  query(marks.before(loc)).at(-1, default: none)
}

/// Wrap a theorion numbering, which takes a location and returns a numbering.
/// In the body, the theorion counter gives the number.
/// In an appendix, theorems are counted from the last level-1 heading,
/// and in a supplementary section from the start of the part, so all supplementary sections share one sequence.
/// This counts the theorion figures of the same kind, because the theorion counter does not restart at a part.
///
/// - original (str, function): The current `theorem-numbering`.
/// - pattern (str): Pattern of the number after the prefix.
#let typst-extras-wrap-theorem(original, pattern) = loc => {
  let base = if type(original) == function { original(loc) } else { original }
  let part = typst-extras-part.at(loc)
  if part == "body" {
    return typst-extras-wrap(base, pattern, loc: loc)
  }
  (..nums) => {
    let frame = query(selector(figure).before(loc)).at(-1, default: none)
    let start = typst-extras-section-start(part, loc)
    if frame == none or start == none {
      return typst-extras-wrap(base, pattern, loc: loc)(..nums)
    }
    let count = query(figure.where(kind: frame.kind).after(start.location()).before(frame.location())).len()
    typst-extras-wrap(base, pattern, loc: loc)(count)
  }
}

/// Reset the counter of each figure kind, and the equation counter.
///
/// - kinds (array): Figure kinds, such as `("quarto-float-fig",)`.
#let typst-extras-reset(kinds) = {
  for kind in kinds {
    counter(figure.where(kind: kind)).update(0)
  }
  counter(math.equation).update(0)
}

/// Reset the counters when the next heading is a numbered level-1 heading.
/// The Lua filter puts this before every heading, because Pandoc applies
/// `shift-heading-level-by` after the filters, so only Typst knows the final level.
///
/// - kinds (array): Figure kinds, such as `("quarto-float-fig",)`.
#let typst-extras-reset-chapter(kinds) = context {
  let next = query(selector(heading).after(here())).at(0, default: none)
  if next != none and next.level == 1 and next.numbering != none {
    typst-extras-reset(kinds)
  }
}

/// Start an appendix or supplementary part: set the part, start the heading counter again,
/// reset the float and equation counters, and mark the place for theorem numbers.
/// The caller then sets the heading numbering of the part, because set rules in a function stay inside it:
/// `typst-extras-appendix-numbering` or `typst-extras-heading-numbering.with(part: "supplementary")`.
///
/// - part (str): `"appendix"` or `"supplementary"`.
/// - kinds (array): Figure kinds to reset, such as `("quarto-float-fig",)`.
#let typst-extras-part-start(part, kinds) = {
  typst-extras-part.update(part)
  counter(heading).update(0)
  typst-extras-reset(kinds)
  [#metadata(part) <typst-extras-part-start>]
}

/// Mark the counters before a heading whose template resets them, so `typst-extras-carry-restore` can restore them.
/// A book resets float and equation counters at each level-1 heading,
/// so the mark goes before each supplementary chapter after the first.
#let typst-extras-carry-mark() = [#metadata("carry") <typst-extras-carry>]

/// Restore the counters of each figure kind, and the equation counter, to their values at the last carry mark.
/// Put it after the heading, so supplementary chapters keep one sequence.
///
/// - kinds (array): Figure kinds, such as `("quarto-float-fig",)`.
#let typst-extras-carry-restore(kinds) = context {
  let mark = query(selector(<typst-extras-carry>).before(here())).last().location()
  for kind in kinds {
    let target = counter(figure.where(kind: kind))
    target.update(target.at(mark))
  }
  counter(math.equation).update(counter(math.equation).at(mark))
}

/// Number a heading in an appendix or a supplementary section.
/// An appendix gives `A`, `A.1`, `A.1.1`; a supplementary section gives `S1`, `S1.1`.
/// Without `number-sections`, sub-headings are unnumbered.
///
/// - nums (int): The heading counter.
/// - part (str): `"appendix"` or `"supplementary"`.
/// - config (dictionary): Section settings, as in `typst-extras-config`.
#let typst-extras-heading-numbering(..nums, part: "appendix", config: (:)) = {
  let levels = nums.pos()
  if levels.len() > 1 and not config.number-sections {
    return none
  }
  if part == "appendix" {
    numbering("A.1", ..levels)
  } else {
    config.supplementary-prefix + numbering("1.1", ..levels)
  }
}

/// Number a heading in an appendix, with the label on level-1 headings:
/// `appendix-title`, the letter, then `appendix-delim`, such as `Appendix A :`.
/// The title follows, so a level-1 heading reads `Appendix A : Title`; sub-headings read `A.1`.
/// Use it in a set rule, not a show-set rule, so headings that set their own numbering,
/// such as the bibliography title, keep it.
///
/// - nums (int): The heading counter.
/// - config (dictionary): Section settings, as in `typst-extras-config`.
#let typst-extras-appendix-numbering(..nums, config: (:)) = {
  let levels = nums.pos()
  if levels.len() > 1 {
    return typst-extras-heading-numbering(..levels, part: "appendix", config: config)
  }
  config.appendix-title + " " + numbering("A", levels.first()) + config.appendix-delim
}

/// Return the label of a heading in an appendix, such as `Appendix A` or `Appendix A.1`,
/// or in a supplementary section, such as `S1` or `S1.1`. Needs `context`.
/// It is `none` for a heading in the body or an unnumbered heading.
///
/// - target (content): The heading.
#let typst-extras-heading-label(target) = {
  if target.numbering == none {
    return none
  }
  let loc = target.location()
  let part = typst-extras-part.at(loc)
  if part == "body" {
    return none
  }
  let config = typst-extras-config-state.at(loc)
  let levels = counter(heading).at(loc)
  if part == "appendix" {
    config.appendix-title + " " + numbering("A.1", ..levels)
  } else {
    config.supplementary-prefix + numbering("1.1", ..levels)
  }
}

/// Render a reference to a heading in an appendix or a supplementary section with its label,
/// in place of the supplement that Quarto writes, such as `Section`. Other references stay as they are.
/// Use it as `show ref: typst-extras-ref`.
///
/// - it (content): The reference.
#let typst-extras-ref(it) = context {
  let target = it.element
  let label = if target != none and target.func() == heading { typst-extras-heading-label(target) }
  if label == none { it } else { link(target.location(), label) }
}
