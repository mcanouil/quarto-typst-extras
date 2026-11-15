--- Typst Extras - Float kinds
--- @module "kinds"
--- @license MIT
--- @copyright 2026 Mickaël Canouil
--- @author Mickaël Canouil
--- @version 0.0.0
--- @brief Read the custom float kinds of a document.
--- @description Reads `crossref.custom` from the metadata, because Quarto's `crossref` Lua global is not set after Quarto's filters.

local M = {}

--- Collect the custom kinds declared in `crossref.custom`.
--- @param meta pandoc.Meta The document metadata
--- @return table<string, string> Map of kind name to its title
function M.custom(meta)
  local kinds = {}
  local crossref = meta.crossref
  if pandoc.utils.type(crossref) ~= 'table' or crossref.custom == nil then
    return kinds
  end
  for _, entry in ipairs(crossref.custom) do
    if entry.key ~= nil then
      local name = pandoc.utils.stringify(entry.key)
      local description = entry['latex-list-of-description']
      kinds[name] = description and pandoc.utils.stringify(description) or name
    end
  end
  return kinds
end

return M
