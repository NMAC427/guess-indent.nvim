local M = {}

---@class GuessIndentConfig
---@field auto_cmd boolean? Whether to create autocommand to automatically detect indentation
---@field override_editorconfig boolean? Whether or not to override indentation set by Editorconfig
---@field filetype_exclude string[]? Filetypes to ignore indentation detection in
---@field buftype_exclude string[]? Buffer types to ignore indentation detection in

---@class GuessIndentConfigModule: GuessIndentConfig
---@field set_config fun(GuessIndentConfig)

---@type GuessIndentConfig
local default_config = {
  auto_cmd = true,
  override_editorconfig = false,
  filetype_exclude = {
    "netrw",
    "tutor",
  },
  buftype_exclude = {
    "help",
    "nofile",
    "terminal",
    "prompt",
  },
}

-- The current active config
M.values = vim.deepcopy(default_config)

---@param user_config GuessIndentConfig
function M.set_config(user_config)
  if not user_config then
    user_config = {}
  end

  M.values = vim.tbl_extend("force", default_config, user_config)
end

-- This metatable allows for easier access to the config values. Instead of
-- writing `config.values.key` you can just write `config.key`.
return setmetatable(M, {
  __index = function(t, key)
    if key == "set_config" then
      return t.set_config
    else
      return t.values[key]
    end
  end,
}) --[[@as GuessIndentConfigModule]]
