local M = {}

local function setup_commands()
  vim.cmd [[
    command! GuessIndent :lua require("guess-indent").set_from_buffer()
  ]]
end

local function setup_autocommands()
  vim.cmd [[
    augroup GuessIndent
      autocmd!
      autocmd BufReadPost * :GuessIndent
    augroup END
  ]]
end

-- https://github.com/hrsh7th/nvim-cmp/blob/main/lua/cmp/config/context.lua
-- For this to work, you must execute the following command first:
--   :syntax sync minlines=2 maxlines=2
local function is_comment(l_idx, c_idx)
  for _, syn_id in ipairs(vim.fn.synstack(l_idx, c_idx)) do
    syn_id = vim.fn.synIDtrans(syn_id)
    local syn_name = vim.fn.synIDattr(syn_id, "name")
    if syn_name:sub(-7) == "Comment" then
      return true
    end
  end

  return false
end

local function is_comment_fast(char)
 -- Return true for any non alphanumeric or space character
 -- This is far from perfect but significantly faster
 return not char:match("[%w%s]")
end

local function set_indentation(indentation)
  if indentation == nil then
    return
  end

  local set_buffer_opt = vim.api.nvim_buf_set_option

  if indentation == "tabs" then
    set_buffer_opt(0, "expandtab", false)
    print("Did set indentation to tabs.")
  elseif type(indentation) == "number" and indentation > 0 then
    set_buffer_opt(0, "expandtab", true)
    set_buffer_opt(0, "tabstop", indentation)
    set_buffer_opt(0, "softtabstop", indentation)
    set_buffer_opt(0, "shiftwidth", indentation)
    print("Did set indentation to", indentation, "spaces.")
  else
    print("Failed to detect indentation style.")
  end
end

function M.guess_from_buffer()
  local lines = vim.api.nvim_buf_get_lines(0, 0, 1024, false)

  -- How many lines use spaces / tabs
  local space_lines_count = 0
  local tab_lines_count = 0

  -- How many spaces / tabs were used on the previous lines
  local last_space_count = 0
  local last_tab_count = 0

  -- How many spaces are used for indentation
  local spaces = {}
  local prev_space_delta = 0

  -- Check each line for its indentation
  for l_idx, line in ipairs(lines) do
    local space_count = 0
    local tab_count = 0

    local line_is_empty = true

    -- Ignore empty lines. They screw up the last_xxx_count variables
    if #line == 0 then
      goto next_line
    end

    -- Calculate indentation for this line
    for c_idx = 1, math.min(#line, 72) do

      local char = line:sub(c_idx, c_idx)
      if char == " " then
        space_count = space_count + 1
      elseif char == "\t" then
        tab_count = tab_count + 1
      else
        -- If line is a comment then discard indentation
        if c_idx ~= 1 and is_comment_fast(char) then
          goto next_line
        end

        line_is_empty = false
        break
      end
    end

    -- Line only contains whitespace -> skip
    if line_is_empty then
      goto next_line
    end


    if tab_count ~= 0 and space_count == 0 and last_space_count == 0 then
      -- Is using tabs
      tab_lines_count = tab_lines_count + 1
    end

    if space_count ~= 0 and tab_count == 0 and last_tab_count == 0 then
      -- Is using spaces
      local delta = math.abs(last_space_count - space_count)

      if delta == 0 then
        delta = prev_space_delta
      else
        prev_space_delta = delta
      end

      spaces[delta] = (spaces[delta] or 0) + 1
      space_lines_count = space_lines_count + 1
    end

    last_space_count = space_count
    last_tab_count = tab_count

    -- We have gathered enough evidence to stop early
    if math.abs(space_lines_count - tab_lines_count) >= 128 then
      break
    end

    ::next_line::
  end


  -- Get most common indentation style
  if (tab_lines_count > space_lines_count and tab_lines_count > 0) then
    return "tabs"
  elseif (space_lines_count > 0) then
    local max_count = -1
    local max_spaces = 4

    for n_spaces, count in pairs(spaces) do
      if count > max_count then
        max_count = count
        max_spaces = n_spaces
      end
    end

    return max_spaces
  else
    -- Failed to detect indentation
    return nil
  end
end

function M.set_from_buffer()
  local indentation = M.guess_from_buffer()
  set_indentation(indentation)
end

function M.setup(opts)
  setup_commands()

  -- Set default values
  opts = opts or {}

  if opts.auto_cmd == nil then
    opts.auto_cmd = true
  end

  -- Apply options
  if opts.auto_cmd then
    setup_autocommands()
  end
end

return M
