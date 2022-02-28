local config = require("guess-indent.config")

local M = {}

function M.v_print(level, ...)
  if level <= config.verbose then
    print(...)
  end
end

return M
