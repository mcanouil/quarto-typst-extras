# Typst Extras Extension For Quarto

A Quarto extension that adds lists of floats, chapter numbering, alternative text for formulas, appendix and supplementary sections, and watermarks to any Typst format, so you do not write that Typst yourself.

## Installation

```bash
quarto add mcanouil/quarto-typst-extras@0.1.0
```

This will install the extension under the `_extensions` subdirectory.

If you are using version control, you will want to check in this directory.

## Documentation

The full documentation lives at <https://m.canouil.dev/quarto-typst-extras/>: every option, the Typst book behaviour, the validation messages, the limitations, and worked examples.

[`example.qmd`](example.qmd) is a short, standalone starting point you can copy.

Every module acts on Typst output only.
In other formats, the extension leaves the document as it is, except that alternative text on a formula is removed.

## Licence

[MIT](https://github.com/mcanouil/quarto-typst-extras?tab=MIT-1-ov-file#readme).
