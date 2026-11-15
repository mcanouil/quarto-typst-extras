// Bare Typst - Typst Show Rules
// Passes the title to the template.
//
// @license MIT
// @copyright 2026 Mickaël Canouil
// @author Mickaël Canouil

#show: doc => article(
$if(title)$
  title: [$title$],
$endif$
  doc,
)
