local M = {}

local default_config = {
  auto_cmd = true,
  verbose = 0,
}

-- The current active config
M.values = vim.deepcopy(default_config)

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
})
