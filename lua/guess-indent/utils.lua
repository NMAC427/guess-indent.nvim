local M = {}

function M.v_print(level, ...)
  if level <= vim.opt.verbose:get() then
    print(...)
  end
end

return M
