--- Typst Extras - Lists of floats
--- @module "list-of"
--- @license MIT
--- @copyright 2026 Mickaël Canouil
--- @author Mickaël Canouil
--- @version 0.0.0
--- @brief Add a list of figures, tables, listings or custom floats.
--- @description Turns the `list-of` option into a call of `typst-extras-list-of`, placed before the body.
---   Kinds with no float in the document render nothing.

local options = require(quarto.utils.resolve_path('_modules/options.lua'):gsub('%.lua$', ''))
local emit = require(quarto.utils.resolve_path('_modules/emit.lua'):gsub('%.lua$', ''))
local kinds_module = require(quarto.utils.resolve_path('_modules/kinds.lua'):gsub('%.lua$', ''))

local M = {}

--- Name used in messages.
local MODULE_NAME = 'list-of'

--- Prefix of the Typst figure kind of every Quarto float.
local KIND_PREFIX = 'quarto-float-'

--- Built-in kinds, in default order, with the language key of their title.
--- @type table[]
local BUILTIN_KINDS = {
  { key = 'fig', title_key = 'crossref-lof-title', quarto_option = 'lof' },
  { key = 'tbl', title_key = 'crossref-lot-title', quarto_option = 'lot' },
  { key = 'lst', title_key = 'crossref-lol-title' },
}

--- Keys accepted in the map form, in the order shown in messages.
local MAP_KEYS = { 'kinds', 'titles', 'page-break' }

--- Describe a value for an error message.
--- @param value any
--- @return string
local function describe(value)
  if type(value) == 'table' then
    return 'a ' .. (#value > 0 and 'list' or 'map')
  end
  return tostring(value)
end

--- Build the table of known kinds.
--- @param meta pandoc.Meta The document metadata
--- @return table<string, string> known Map of kind name to its default title
--- @return string[] order Kind names for `true`: built-ins, then custom kinds alphabetically
local function known_kinds(meta)
  local known = {}
  local order = {}
  local language = quarto.doc.language or {}
  for _, builtin in ipairs(BUILTIN_KINDS) do
    known[builtin.key] = language[builtin.title_key] or builtin.key
    order[#order + 1] = builtin.key
  end
  local custom = kinds_module.custom(meta)
  local names = {}
  for name in pairs(custom) do
    if known[name] == nil then
      known[name] = custom[name]
      names[#names + 1] = name
    end
  end
  table.sort(names)
  for _, name in ipairs(names) do
    order[#order + 1] = name
  end
  return known, order
end

--- Normalise the option into kinds, titles and the page-break flag.
--- Stops the render when the value has an unsupported form.
--- @param config any The value of `list-of`
--- @return any kinds `true` or a list of kind names
--- @return table titles Map of kind name to title
--- @return boolean page_break
local function parse(config)
  if config == true then
    return true, {}, false
  end
  if type(config) ~= 'table' then
    options.fail(MODULE_NAME, 'unsupported value ' .. describe(config) ..
      '. Use true, a list of kinds such as [fig, tbl], or a map with kinds, titles and page-break.')
  end
  if options.is_list(config) then
    if #config == 0 then
      options.fail(MODULE_NAME, 'empty list of kinds. Use true, or a list of kinds such as [fig, tbl].')
    end
    return config, {}, false
  end
  options.check_keys(MODULE_NAME, config, MAP_KEYS)
  local kinds = config.kinds
  if kinds == nil then
    kinds = true
  end
  if kinds ~= true and (type(kinds) ~= 'table' or #kinds == 0) then
    options.fail(MODULE_NAME, 'unsupported kinds ' .. describe(kinds) .. '. Use true or a list of kinds.')
  end
  local titles = config.titles or {}
  if type(titles) ~= 'table' then
    options.fail(MODULE_NAME, 'unsupported titles ' .. describe(titles) .. '. Use a map of kind to title.')
  end
  local page_break = config['page-break']
  if page_break == nil then
    page_break = false
  end
  if type(page_break) ~= 'boolean' then
    options.fail(MODULE_NAME, 'unsupported page-break ' .. describe(page_break) .. '. Use true or false.')
  end
  return kinds, titles, page_break
end

--- Warn when a Quarto list option already lists a kind.
--- @param meta pandoc.Meta The document metadata
--- @param kinds string[] The selected kind names
local function warn_overlap(meta, kinds)
  for _, builtin in ipairs(BUILTIN_KINDS) do
    local quarto_option = builtin.quarto_option
    if quarto_option and meta[quarto_option] == true then
      for _, kind in ipairs(kinds) do
        if kind == builtin.key then
          options.warn(MODULE_NAME, 'the kind ' .. kind .. ' is also listed by ' .. quarto_option ..
            ', so the list appears twice. Remove one of them.')
        end
      end
    end
  end
end

--- Add the lists of floats to the document.
--- @param doc pandoc.Pandoc The document
--- @param config table The normalised `typst-extras` options
--- @return pandoc.Pandoc
function M.apply(doc, config)
  local option = config['list-of']
  if option == nil or option == false then
    return doc
  end
  local selected, titles, page_break = parse(option)
  local known, order = known_kinds(doc.meta)
  if selected == true then
    selected = order
  end
  local entries = {}
  for _, kind in ipairs(selected) do
    if type(kind) ~= 'string' or known[kind] == nil then
      options.fail(MODULE_NAME, 'unknown kind ' .. describe(kind) .. '. Known kinds: ' ..
        table.concat(order, ', ') .. '.')
    end
    entries[#entries + 1] = '(kind: ' .. emit.string(KIND_PREFIX .. kind) ..
      ', title: ' .. emit.string(titles[kind] or known[kind]) .. ')'
  end
  warn_overlap(doc.meta, selected)
  emit.library()
  emit.before_body('#typst-extras-list-of((' .. table.concat(entries, ', ') .. ',)' ..
    (page_break and ', page-break: true' or '') .. ')\n')
  return doc
end

return M
