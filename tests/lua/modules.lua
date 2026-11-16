-- Typst Extras - Module tests
-- Runs the real emit and options modules against a minimal Quarto API.
-- Run with: quarto pandoc lua tests/lua/modules.lua
--
-- @license MIT
-- @copyright 2026 Mickaël Canouil
-- @author Mickaël Canouil

local root = arg[0]:gsub('tests/lua/[^/]*$', '')
if root == '' then root = './' end
local extension_dir = root .. '_extensions/typst-extras/'
-- `require` gets absolute paths from `resolve_path`; the bare `?.lua` template resolves them.
package.path = package.path .. ';?.lua'
local failures = 0
local logged = { error = {}, warning = {} }
local included = {}

quarto = {
  utils = {
    resolve_path = function(path)
      return extension_dir .. path
    end,
  },
  log = {
    error = function(message) logged.error[#logged.error + 1] = message end,
    warning = function(message) logged.warning[#logged.warning + 1] = message end,
  },
  doc = {
    include_file = function(location, path)
      included[#included + 1] = { kind = 'file', location = location, text = path }
    end,
    include_text = function(location, text)
      included[#included + 1] = { kind = 'text', location = location, text = text }
    end,
  },
}

local emit = dofile(extension_dir .. '_modules/emit.lua')
local options = require(quarto.utils.resolve_path('_modules/options.lua'):gsub('%.lua$', ''))
local math_alt = dofile(extension_dir .. '_modules/math-alt.lua')
local watermark = dofile(extension_dir .. '_modules/watermark.lua')

local function check(name, actual, expected)
  if actual == expected then
    print('ok - ' .. name)
  else
    failures = failures + 1
    print('not ok - ' .. name .. ' (expected ' .. tostring(expected) .. ', got ' .. tostring(actual) .. ')')
  end
end

check('string escapes backslash', emit.string('a\\b'), '"a\\\\b"')
check('string escapes double quote', emit.string('a"b'), '"a\\"b"')
check('string escapes newline', emit.string('a\nb'), '"a\\nb"')
check('string leaves hash as written', emit.string('#a'), '"#a"')

emit.library()
emit.library()
check('library included once', #included, 1)
check('library included in header', included[1].location, 'in-header')
check('library path', included[1].text, 'typst-extras.typ')

emit.header('H')
emit.before_body('B')
check('header location', included[2].location .. ':' .. included[2].text, 'in-header:H')
check('before_body location', included[3].location .. ':' .. included[3].text, 'before-body:B')

local block = pandoc.MetaMap({
  watermark = pandoc.MetaInlines({ pandoc.Str('DRAFT') }),
  sections = pandoc.MetaMap({ enabled = pandoc.MetaBool(true) }),
  ['list-of'] = pandoc.MetaList({ pandoc.MetaInlines({ pandoc.Str('a') }), pandoc.MetaInlines({ pandoc.Str('b') }) }),
})
local meta = pandoc.Meta({ extensions = pandoc.MetaMap({ ['typst-extras'] = block }) })
local read = options.read(meta)
check('read string', read.watermark, 'DRAFT')
check('read boolean', read.sections.enabled, true)
check('read list', table.concat(read['list-of'], ','), 'a,b')
check('read absent block', next(options.read(pandoc.Meta({}))), nil)
local warnings_before = #logged.warning
check('read ignores a top-level block', next(options.read(pandoc.Meta({ ['typst-extras'] = block }))), nil)
check('read warns about a top-level block', #logged.warning, warnings_before + 1)
check('read points a top-level block to extensions',
  logged.warning[#logged.warning]:find('options: .*Move it under extensions: typst%-extras:') ~= nil, true)

local function read_fails_with(fields, fragment)
  local passed, message = pcall(options.read, pandoc.Meta({ extensions = pandoc.MetaMap({ ['typst-extras'] = fields }) }))
  return not passed and message:find(fragment, 1, true) ~= nil
end
check('read unknown key fails', read_fails_with(pandoc.MetaMap({ watermrk = pandoc.MetaBool(true) }),
  'options: unknown key watermrk. Known keys: list-of, watermark, sections.'), true)
check('read block that is not a map fails', read_fails_with(pandoc.MetaBool(true),
  'options: extensions.typst-extras must be a map.'), true)
check('read keeps an empty list apart from an empty map',
  options.is_list(options.read(pandoc.Meta({ extensions = pandoc.MetaMap({ ['typst-extras'] = pandoc.MetaMap({
    ['list-of'] = pandoc.MetaList({}),
  }) }) }))['list-of']), true)

options.warn('mod', 'careful')
check('warn prefix', logged.warning[#logged.warning], '[typst-extras] mod: careful')

local errors_before = #logged.error
local ok, err = pcall(options.fail, 'mod', 'broken')
check('fail raises', ok, false)
check('fail message', err:match('%[typst%-extras%].*$'), '[typst-extras] mod: broken')
check('fail does not log the message a second time', #logged.error, errors_before)

local quarto_error = error
error = function() end
ok = pcall(options.fail, 'mod', 'broken')
error = quarto_error
check('fail raises when error only logs, as in Quarto filters', ok, false)

check('math alt inline call', math_alt.open_call(false, 'x squared'),
  '#math.equation(block: false, alt: "x squared", ')
check('math alt display call', math_alt.open_call(true, 'a'), '#math.equation(block: true, alt: "a", ')
check('math alt escapes quote, backslash and newline', math_alt.open_call(true, 'a "b" \\c\nd'),
  '#math.equation(block: true, alt: "a \\"b\\" \\\\c\\nd", ')
check('math alt straightens curly quotes', math_alt.open_call(false, '\u{201C}a\u{201D} \u{2019}b'),
  '#math.equation(block: false, alt: "\\"a\\" \'b", ')

local function header_after(config)
  local before = #included
  watermark.apply(pandoc.Pandoc({}), config)
  return included[#included].text, #included - before
end

local function fails_with(config, fragment)
  local passed, message = pcall(watermark.apply, pandoc.Pandoc({}), config)
  return not passed and message:find(fragment, 1, true) ~= nil
end

check('watermark absent adds nothing', select(2, header_after({})), 0)
check('watermark string form', (header_after({ watermark = 'DRAFT "v2"' })),
  '#set page(foreground: typst-extras-watermark(text: "DRAFT \\"v2\\""))\n')
check('watermark map form', (header_after({ watermark = {
  text = 'A', opacity = '20%', angle = '-30deg', size = '3em', colour = '#cc0000', position = 'top-left',
} })),
  '#set page(foreground: typst-extras-watermark(text: "A", opacity: 20%, angle: -30deg, size: 3em, ' ..
  'colour: rgb("#cc0000"), position: top + left))\n')
check('watermark image form', (header_after({ watermark = { image = 'a.svg', width = '8cm' } })),
  '#set page(foreground: typst-extras-watermark(image: "a.svg", width: 8cm))\n')
check('watermark text and image fail', fails_with({ watermark = { text = 'a', image = 'b' } }, 'watermark: set text or image, not both'), true)
check('watermark opacity with image fails', fails_with({ watermark = { image = 'b', opacity = '10%' } }, 'opacity does not apply'), true)
check('watermark bad position fails', fails_with({ watermark = { text = 'a', position = 'middle' } }, 'unsupported position middle'), true)
check('watermark bad opacity fails', fails_with({ watermark = { text = 'a', opacity = '0.2' } }, 'unsupported opacity 0.2'), true)
check('watermark bad angle fails', fails_with({ watermark = { text = 'a', angle = '45' } }, 'unsupported angle 45'), true)
check('watermark bad size fails', fails_with({ watermark = { text = 'a', size = 'big' } }, 'unsupported size big'), true)
check('watermark bad colour fails', fails_with({ watermark = { text = 'a', colour = 'rgb(1)' } }, 'unsupported colour rgb(1)'), true)
check('watermark hostile colour fails with the module prefix', fails_with({ watermark = { text = 'a',
  colour = 'red); #panic("x"' } }, '[typst-extras] watermark: unsupported colour red); #panic("x". Use'), true)
check('watermark unknown key fails', fails_with({ watermark = { text = 'a', colr = 'red' } }, 'unknown key colr'), true)
check('watermark size with an unknown unit fails', fails_with({ watermark = { text = 'a', size = '4xx' } }, 'unsupported size 4xx'), true)
check('watermark size in pt', (header_after({ watermark = { text = 'a', size = '48pt' } })),
  '#set page(foreground: typst-extras-watermark(text: "a", size: 48pt))\n')
check('watermark opacity above 100% fails', fails_with({ watermark = { text = 'a', opacity = '150%' } },
  'unsupported opacity 150%. Use a percentage from 0% to 100%.'), true)
check('watermark opacity below 0% fails', fails_with({ watermark = { text = 'a', opacity = '-5%' } },
  'unsupported opacity -5%'), true)
check('watermark width with an unknown unit fails', fails_with({ watermark = { image = 'a.svg', width = '8xx' } },
  'unsupported width 8xx'), true)
check('watermark width with a one-letter unit fails', fails_with({ watermark = { image = 'a.svg', width = '8x' } },
  'unsupported width 8x'), true)
check('watermark width as a percentage', (header_after({ watermark = { image = 'a.svg', width = '40%' } })),
  '#set page(foreground: typst-extras-watermark(image: "a.svg", width: 40%))\n')
check('watermark opacity of 100% passes', (header_after({ watermark = { text = 'a', opacity = '100%' } })),
  '#set page(foreground: typst-extras-watermark(text: "a", opacity: 100%))\n')

local list_of = dofile(extension_dir .. '_modules/list-of.lua')
local function list_fails_with(value, fragment)
  local config = options.read(pandoc.Meta({ extensions = pandoc.MetaMap({
    ['typst-extras'] = pandoc.MetaMap({ ['list-of'] = value }),
  }) }))
  local passed, message = pcall(list_of.apply, pandoc.Pandoc({}), config)
  return not passed and message:find(fragment, 1, true) ~= nil
end
check('list-of unknown map key fails', list_fails_with(pandoc.MetaMap({
  kind = pandoc.MetaList({ pandoc.MetaInlines({ pandoc.Str('tbl') }) }),
}), 'list-of: unknown key kind. Known keys: kinds, titles, page-break.'), true)
check('list-of empty list fails', list_fails_with(pandoc.MetaList({}), 'list-of: empty list of kinds.'), true)

local function list_of_body(value)
  local config = options.read(pandoc.Meta({ extensions = pandoc.MetaMap({
    ['typst-extras'] = pandoc.MetaMap({ ['list-of'] = value }),
  }) }))
  list_of.apply(pandoc.Pandoc({}), config)
  return included[#included].text
end
local function kinds_list(...)
  local items = {}
  for _, kind in ipairs({ ... }) do
    items[#items + 1] = pandoc.MetaInlines({ pandoc.Str(kind) })
  end
  return pandoc.MetaList(items)
end
check('list-of lists a duplicate kind once, at its first position', list_of_body(kinds_list('tbl', 'fig', 'tbl')),
  '#typst-extras-list-of(((kind: "quarto-float-tbl", title: "tbl"), (kind: "quarto-float-fig", title: "fig"),))\n')
check('list-of lists a duplicate kind once in the map form', list_of_body(pandoc.MetaMap({
  kinds = kinds_list('fig', 'fig'),
})), '#typst-extras-list-of(((kind: "quarto-float-fig", title: "fig"),))\n')

local sections = dofile(extension_dir .. '_modules/sections.lua')
local parts_module = require(quarto.utils.resolve_path('_modules/parts.lua'):gsub('%.lua$', ''))

local function chapters_meta(extra)
  local fields = { crossref = pandoc.MetaMap({ chapters = pandoc.MetaBool(true) }) }
  for key, value in pairs(extra or {}) do
    fields[key] = value
  end
  return pandoc.Meta(fields)
end

local function section_doc(meta)
  return pandoc.Pandoc({
    pandoc.Header(1, 'One'),
    pandoc.Para('a'),
    pandoc.Header(2, 'Sub'),
    pandoc.Header(1, 'Notes', pandoc.Attr('', { 'unnumbered' })),
  }, meta)
end

quarto.doc.language = { ['crossref-apx-prefix'] = 'Annexe', ['callout-tip-title'] = 'Astuce' }
PANDOC_WRITER_OPTIONS = { number_sections = true }

local function sections_fail_with(value, fragment)
  local passed, message = pcall(sections.settings, pandoc.Meta({}), { sections = value })
  return not passed and message:find(fragment, 1, true) ~= nil
end
check('sections block that is not a map fails', sections_fail_with(true,
  'sections: unsupported value true. Use a map with appendix-delimiter, supplementary-prefix.'), true)
check('sections unknown key fails', sections_fail_with({ ['appendix-delim'] = '' },
  'sections: unknown key appendix-delim. Known keys: appendix-delimiter, supplementary-prefix.'), true)

local defaults = sections.settings(pandoc.Meta({}), {})
check('sections default chapters', defaults.chapters, false)
check('sections default appendix-delimiter', defaults['appendix-delimiter'], '.')
check('sections default supplementary-prefix', defaults['supplementary-prefix'], 'S')
check('sections default appendix-title from language', defaults['appendix-title'], 'Annexe')
check('sections default appendix-delim', defaults['appendix-delim'], ' \u{2014}')
check('sections number-sections from writer options', defaults['number-sections'], true)
check('sections default section-prefix', defaults['section-prefix'], 'Section')
check('sections default chapter-prefix', defaults['chapter-prefix'], 'Chapter')

local custom = sections.settings(pandoc.Meta({
  crossref = pandoc.MetaMap({
    chapters = pandoc.MetaBool(true),
    ['appendix-title'] = pandoc.MetaInlines({ pandoc.Str('Annex') }),
    ['appendix-delim'] = pandoc.MetaInlines({ pandoc.Str(':') }),
    ['sec-prefix'] = pandoc.MetaInlines({ pandoc.Str('Part') }),
  }),
}), { sections = { ['appendix-delimiter'] = '', ['supplementary-prefix'] = 'SM' } })
check('sections chapters from crossref', custom.chapters, true)
check('sections appendix-title from crossref', custom['appendix-title'], 'Annex')
check('sections appendix-delim from crossref', custom['appendix-delim'], ':')
check('sections section-prefix from crossref', custom['section-prefix'], 'Part')
check('sections appendix-delimiter option', custom['appendix-delimiter'], '')
check('sections supplementary-prefix option', custom['supplementary-prefix'], 'SM')

check('sections config literal', sections.config_literal(defaults),
  '(chapters: false, appendix-delimiter: ".", supplementary-prefix: "S", appendix-title: "Annexe", ' ..
  'appendix-delim: " \u{2014}", number-sections: true, section-prefix: "Section", chapter-prefix: "Chapter")')

local kinds = sections.kinds(pandoc.Meta({
  crossref = pandoc.MetaMap({ custom = pandoc.MetaList({
    pandoc.MetaMap({ key = pandoc.MetaInlines({ pandoc.Str('vid') }) }),
  }) }),
}))
check('sections kinds', table.concat(kinds, ','),
  'quarto-float-fig,quarto-float-tbl,quarto-float-lst,quarto-float-vid,' ..
  'quarto-callout-Note,quarto-callout-Astuce,quarto-callout-Warning,quarto-callout-Important,quarto-callout-Caution')

local before = #included
local flat = sections.apply(section_doc(pandoc.Meta({})), {})
check('sections without chapters adds nothing', #included - before, 0)
check('sections without chapters keeps blocks', #flat.blocks, 4)

local warned = #logged.warning
before = #included
PANDOC_WRITER_OPTIONS = { number_sections = false }
local unnumbered = sections.apply(section_doc(chapters_meta()), {})
check('sections chapters without number-sections warns', #logged.warning, warned + 1)
check('sections warning names number-sections',
  logged.warning[#logged.warning]:find('sections: crossref.chapters needs number-sections', 1, true) ~= nil, true)
check('sections chapters without number-sections adds nothing', #included - before, 0)
check('sections chapters without number-sections keeps blocks', #unnumbered.blocks, 4)

PANDOC_WRITER_OPTIONS = { number_sections = true }
before = #included
local book = sections.apply(section_doc(chapters_meta({ book = pandoc.MetaMap({}) })), {})
check('sections in a book adds nothing', #included - before, 0)
check('sections in a book keeps blocks', #book.blocks, 4)

before = #included
local numbered = sections.apply(section_doc(chapters_meta()), {})
local reset = '#typst-extras-reset-chapter(("quarto-float-fig", "quarto-float-tbl", "quarto-float-lst", ' ..
  '"quarto-callout-Note", "quarto-callout-Astuce", "quarto-callout-Warning", "quarto-callout-Important", ' ..
  '"quarto-callout-Caution",))'
check('sections inserts a reset before each numbered heading', #numbered.blocks, 6)
check('sections reset before first heading', numbered.blocks[1].text, reset)
check('sections reset format', numbered.blocks[1].format, 'typst')
check('sections reset before sub-heading', numbered.blocks[4].text, reset)
check('sections no reset before unnumbered heading', numbered.blocks[6].t, 'Header')
local header_text = included[#included - 1].text
check('sections header location', included[#included - 1].location, 'in-header')
check('sections header binds config', header_text:find('#let typst-extras-config = (chapters: true,', 1, true) ~= nil, true)
check('sections header wraps equations',
  header_text:find('#let equation-numbering = typst-extras-wrap(equation-numbering, "(1)")', 1, true) ~= nil, true)
check('sections header wraps callouts',
  header_text:find('#let callout-numbering = typst-extras-wrap(callout-numbering, "1")', 1, true) ~= nil, true)
check('sections header wraps theorems',
  header_text:find('#let theorem-numbering = typst-extras-wrap-theorem(theorem-numbering, "1")', 1, true) ~= nil, true)
check('sections header inherits one theorem level',
  header_text:find('#let theorem-inherited-levels = 1', 1, true) ~= nil, true)
check('sections before-body location', included[#included].location, 'before-body')
check('sections before-body sets figure numbering', included[#included].text,
  '#typst-extras-config-state.update(typst-extras-config)\n' ..
  '#show: body => context { set figure(numbering: typst-extras-wrap(figure.numbering, "1")); body }\n')

local active_settings = { chapters = true, ['number-sections'] = true }
check('sections chapters active', sections.chapters_active(pandoc.Meta({}), active_settings), true)
check('sections chapters inactive without number-sections',
  sections.chapters_active(pandoc.Meta({}), { chapters = true, ['number-sections'] = false }), false)
check('sections chapters inactive without chapters',
  sections.chapters_active(pandoc.Meta({}), { chapters = false, ['number-sections'] = true }), false)
check('sections chapters inactive in a book',
  sections.chapters_active(pandoc.Meta({ book = pandoc.MetaMap({}) }), active_settings), false)

before = #included
sections.emit_numbering(defaults)
local flat_header = included[#included - 1].text
check('sections emit_numbering adds header and before-body', #included - before, 2)
check('sections emit_numbering writes chapters as given',
  flat_header:find('#let typst-extras-config = (chapters: false,', 1, true) ~= nil, true)
check('sections emit_numbering wraps theorems without the option',
  flat_header:find('#let theorem-numbering = typst-extras-wrap-theorem(theorem-numbering, "1")', 1, true) ~= nil, true)
check('sections emit_numbering keeps theorem levels without the option',
  flat_header:find('theorem-inherited-levels', 1, true), nil)
check('sections emit_numbering sets figure numbering',
  included[#included].text:find('set figure(numbering: typst-extras-wrap(figure.numbering, "1"))', 1, true) ~= nil, true)

local filtered = sections.insert_resets(section_doc(pandoc.Meta({})), { 'quarto-float-fig' }, function(header)
  return header.level == 1
end)
check('sections insert_resets follows the predicate', #filtered.blocks, 6)
check('sections insert_resets quotes the kinds', filtered.blocks[1].text, '#typst-extras-reset-chapter(("quarto-float-fig",))')
check('sections insert_resets skips the sub-heading', filtered.blocks[4].t, 'Header')
check('sections insert_resets predicate sees the unnumbered heading', filtered.blocks[5].t, 'RawBlock')

--- Stringify each block of a document, with raw Typst kept as written and headings marked by level.
local function outline_of(doc)
  local parts = {}
  for _, block in ipairs(doc.blocks) do
    if block.t == 'RawBlock' then
      parts[#parts + 1] = 'raw:' .. block.text:match('^#([%w-]+)')
    elseif block.t == 'Header' then
      parts[#parts + 1] = 'h' .. block.level .. ':' .. pandoc.utils.stringify(block)
    else
      parts[#parts + 1] = pandoc.utils.stringify(block)
    end
  end
  return table.concat(parts, ' | ')
end

local function classed(level, text, class)
  return pandoc.Header(level, text, pandoc.Attr('', { class }))
end

local function parts_doc(meta)
  return pandoc.Pandoc({
    pandoc.Header(1, 'Intro'),
    classed(1, 'Extra', 'appendix'),
    pandoc.Para('x'),
    classed(2, 'Deep', 'appendix'),
    classed(1, 'Supp', 'supplementary'),
    pandoc.Para('s'),
    pandoc.Header(1, 'Methods'),
    pandoc.Div({ classed(1, 'Inside', 'appendix') }),
    classed(1, 'More', 'appendix'),
    pandoc.Para('m'),
  }, meta)
end

local apx_meta = pandoc.Meta({})
before = #included
warned = #logged.warning
local moved = sections.special(parts_doc(apx_meta), {})
check('sections special moves appendix then supplementary sections', outline_of(moved),
  'h1:Intro | h1:Methods | Inside | ' ..
  'raw:typst-extras-part-start | raw:set | h1:Extra | x | h2:Deep | ' ..
  'raw:typst-extras-reset-chapter | h1:More | m | ' ..
  'raw:typst-extras-part-start | raw:set | h1:Supp | s')
check('sections special warns about a deeper heading', #logged.warning, warned + 1)
check('sections special warning names level-1 and the heading',
  logged.warning[#logged.warning]:find('sections: .*level%-1.*Deep') ~= nil, true)
check('sections special removes the class from a moved heading', moved.blocks[6].classes:includes('appendix'), false)
check('sections special keeps the class on a deeper heading', moved.blocks[8].classes:includes('appendix'), true)
check('sections special appendix start', moved.blocks[4].text,
  '#typst-extras-part-start("appendix", (' .. '"quarto-float-fig", "quarto-float-tbl", "quarto-float-lst", ' ..
  '"quarto-callout-Note", "quarto-callout-Astuce", "quarto-callout-Warning", "quarto-callout-Important", ' ..
  '"quarto-callout-Caution",))')
check('sections special appendix heading numbering', moved.blocks[5].text,
  '#set heading(numbering: typst-extras-appendix-numbering.with(config: typst-extras-config))')
check('sections special supplementary heading numbering', moved.blocks[13].text,
  '#set heading(numbering: typst-extras-heading-numbering.with(part: "supplementary", config: typst-extras-config))')
check('sections special emits the numbering once', #included - before, 2)
local special_header = included[#included - 1].text
check('sections special keeps the body flat', special_header:find('(chapters: false,', 1, true) ~= nil, true)
check('sections special keeps theorem levels', special_header:find('theorem-inherited-levels', 1, true), nil)
check('sections special adds the reference rule', included[#included].text:find('#show ref: typst-extras-ref', 1, true) ~= nil, true)
check('sections special in a document keeps the heading numbering of the parts',
  included[#included].text:find('typst-extras-book-heading-numbering', 1, true), nil)

before = #included
local shifted = sections.special(pandoc.Pandoc({
  pandoc.Header(2, 'Intro'),
  classed(2, 'Extra', 'appendix'),
  classed(3, 'Detail', 'appendix'),
  pandoc.Header(2, 'Methods'),
}, pandoc.Meta({})), {})
check('sections special uses the top heading level of the document', outline_of(shifted),
  'h2:Intro | h2:Methods | raw:typst-extras-part-start | raw:set | h2:Extra | h3:Detail')

before = #included
local untouched = sections.special(section_doc(pandoc.Meta({})), {})
check('sections special without classes adds nothing', #included - before, 0)
check('sections special without classes keeps blocks', #untouched.blocks, 4)

local book_meta = pandoc.Meta({ book = pandoc.MetaMap({}) })
before = #included
warned = #logged.warning
local in_book = sections.special(parts_doc(book_meta), {})
check('sections special marks a supplementary chapter in a book and moves nothing', outline_of(in_book),
  'h1:Intro | h1:Extra | x | h2:Deep | raw:typst-extras-body-mark | raw:typst-extras-part-start | ' ..
  'h1:Supp | s | raw:typst-extras-carry-mark | raw:typst-extras-body-restore | h1:Methods | Inside | h1:More | m')
check('sections special in a book marks the body before the part start', in_book.blocks[5].text,
  '#typst-extras-body-mark()')
check('sections special in a book marks the supplementary counters when it leaves the part', in_book.blocks[9].text,
  '#typst-extras-carry-mark()')
check('sections special in a book goes back to the body and restores the heading counter', in_book.blocks[10].text,
  '#typst-extras-body-restore()')
check('sections special in a book removes the supplementary class', in_book.blocks[7].classes:includes('supplementary'), false)
check('sections special in a book keeps the appendix class', in_book.blocks[2].classes:includes('appendix'), true)
check('sections special in a book warns about appendix classes and a deeper heading',
  #logged.warning, warned + 3)
check('sections special in a book points to appendices',
  logged.warning[warned + 1]:find('sections: .*"Extra".*use the book\'s appendices: list') ~= nil, true)
check('sections special in a book points a deeper heading to appendices',
  logged.warning[warned + 2]:find('sections: .*"Deep".*use the book\'s appendices: list') ~= nil, true)
check('sections special in a book does not ask for a level-1 heading',
  logged.warning[warned + 2]:find('Move the class to a level-1 heading', 1, true), nil)
check('sections special in a book warns about the appendix class of a later chapter',
  logged.warning[warned + 3]:find('"More"', 1, true) ~= nil, true)
check('sections special in a book emits the numbering once', #included - before, 2)
check('sections special in a book keeps the body flat',
  included[#included - 1].text:find('(chapters: false,', 1, true) ~= nil, true)
check('sections special in a book keeps the book theorem levels',
  included[#included - 1].text:find('theorem-inherited-levels', 1, true), nil)
check('sections special in a book adds the reference rule',
  included[#included].text:find('#show ref: typst-extras-ref', 1, true) ~= nil, true)
check('sections special in a book wraps the heading numbering of the book',
  included[#included].text:find('set heading(numbering: typst-extras-book-heading-numbering(heading.numbering, ' ..
    'config: typst-extras-config))', 1, true) ~= nil, true)

local appendices_marker = '<!-- quarto-file-metadata: {"bookItemType":"appendix"} -->'
before = #included
warned = #logged.warning
local supplementary_last = sections.special(pandoc.Pandoc({
  pandoc.Header(1, 'Intro'),
  classed(1, 'Supp', 'supplementary'),
  classed(1, 'Supp two', 'supplementary'),
  pandoc.Div({
    pandoc.RawBlock('html', appendices_marker),
    pandoc.Header(1, 'Appendices', pandoc.Attr('appendices', { 'unnumbered' })),
  }, pandoc.Attr('', { 'quarto-book-part' })),
  pandoc.Header(1, 'Appendix'),
}, book_meta), {})
check('sections special in a book starts a run of supplementary chapters once', outline_of(supplementary_last),
  'h1:Intro | raw:typst-extras-body-mark | raw:typst-extras-part-start | h1:Supp | ' ..
  'raw:typst-extras-carry-mark | h1:Supp two | raw:typst-extras-carry-restore | raw:typst-extras-carry-mark | ' ..
  'raw:typst-extras-body-restore | ' ..
  'Appendices | h1:Appendix')
check('sections special in a book marks the counters before a later supplementary chapter',
  supplementary_last.blocks[5].text, '#typst-extras-carry-mark()')
check('sections special in a book carries the counters over a later supplementary chapter',
  supplementary_last.blocks[7].text, '#typst-extras-carry-restore(' .. '("quarto-float-fig", "quarto-float-tbl", ' ..
  '"quarto-float-lst", "quarto-callout-Note", "quarto-callout-Astuce", "quarto-callout-Warning", ' ..
  '"quarto-callout-Important", "quarto-callout-Caution",))')
check('sections special in a book does not warn before the appendices', #logged.warning, warned)

warned = #logged.warning
local two_runs = sections.special(pandoc.Pandoc({
  pandoc.Header(1, 'Intro'),
  classed(1, 'Supp', 'supplementary'),
  pandoc.Header(1, 'Body'),
  classed(1, 'Late', 'supplementary'),
}, book_meta), {})
check('sections special in a book resumes the supplementary part in a second run', outline_of(two_runs),
  'h1:Intro | raw:typst-extras-body-mark | raw:typst-extras-part-start | h1:Supp | raw:typst-extras-carry-mark | ' ..
  'raw:typst-extras-body-restore | h1:Body | raw:typst-extras-body-mark | raw:typst-extras-part-resume | h1:Late | ' ..
  'raw:typst-extras-carry-restore')
check('sections special in a book resumes the supplementary part by name', two_runs.blocks[9].text,
  '#typst-extras-part-resume("supplementary")')
check('sections special in a book does not warn about a second run of supplementary chapters', #logged.warning, warned)

before = #included
local plain_book = sections.special(section_doc(book_meta), {})
check('sections special in a book without supplementary chapters adds nothing', #included - before, 0)
check('sections special in a book without supplementary chapters keeps blocks', #plain_book.blocks, 4)

local function both_classes(level)
  return pandoc.Header(level, 'Both', pandoc.Attr('', { 'appendix', 'supplementary' }))
end
warned = #logged.warning
local both = sections.special(pandoc.Pandoc({ pandoc.Header(1, 'Intro'), both_classes(1) }, pandoc.Meta({})), {})
check('sections special takes appendix for a heading with both classes', outline_of(both),
  'h1:Intro | raw:typst-extras-part-start | raw:set | h1:Both')
check('sections special warns once about a heading with both classes', #logged.warning, warned + 1)
check('sections special names both classes',
  logged.warning[#logged.warning]:find('sections: the heading "Both" has both the .appendix and .supplementary ' ..
    'classes, so it is an appendix. Remove one of them.', 1, true) ~= nil, true)
warned = #logged.warning
sections.special(pandoc.Pandoc({ pandoc.Header(1, 'Intro'), both_classes(1) }, book_meta), {})
check('sections special in a book names both classes',
  logged.warning[warned + 1] ~= nil and
  logged.warning[warned + 1]:find('the heading "Both" has both the .appendix and .supplementary', 1, true) ~= nil,
  true)

local start = parts_module.start_blocks('supplementary', { 'quarto-float-fig' })
check('parts start_blocks starts the part', start[1].text, '#typst-extras-part-start("supplementary", ("quarto-float-fig",))')
check('parts start_blocks sets the heading numbering', start[2].text,
  '#set heading(numbering: typst-extras-heading-numbering.with(part: "supplementary", config: typst-extras-config))')

PANDOC_WRITER_OPTIONS = { number_sections = false }
local plain = sections.special(pandoc.Pandoc({
  pandoc.Header(1, 'Intro'),
  classed(1, 'Extra', 'appendix'),
  pandoc.Header(2, 'Detail'),
}, pandoc.Meta({})), {})
check('sections special without number-sections leaves sub-headings unnumbered',
  plain.blocks[#plain.blocks].classes:includes('unnumbered'), true)
check('sections special without number-sections numbers the appendix heading',
  plain.blocks[#plain.blocks - 1].classes:includes('unnumbered'), false)
PANDOC_WRITER_OPTIONS = { number_sections = true }

before = #included
local combined = sections.apply(pandoc.Pandoc({
  pandoc.Header(1, 'Intro'),
  pandoc.Header(1, 'Methods'),
  classed(1, 'Extra', 'appendix'),
  classed(1, 'Supp', 'supplementary'),
}, chapters_meta()), {})
check('sections apply with chapters and parts', outline_of(combined),
  'raw:typst-extras-reset-chapter | h1:Intro | raw:typst-extras-reset-chapter | h1:Methods | ' ..
  'raw:typst-extras-part-start | raw:set | h1:Extra | ' ..
  'raw:typst-extras-part-start | raw:set | h1:Supp')
check('sections apply emits the numbering once with chapters and parts', #included - before, 2)
check('sections apply with chapters and parts numbers the body by chapter',
  included[#included - 1].text:find('(chapters: true,', 1, true) ~= nil, true)
check('sections apply with chapters and parts inherits one theorem level',
  included[#included - 1].text:find('#let theorem-inherited-levels = 1', 1, true) ~= nil, true)

if failures > 0 then
  os.exit(1)
end
