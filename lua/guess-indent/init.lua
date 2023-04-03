local utils = require("guess-indent.utils")
local config = require("guess-indent.config")

local M = {}

local function setup_commands()
  vim.cmd([[
    command! -nargs=? GuessIndent :lua require("guess-indent").set_from_buffer("<args>")
  ]])
end

local function setup_autocommands()
  vim.cmd([[
    augroup GuessIndent
      autocmd!
      autocmd BufReadPost * silent lua require("guess-indent").set_from_buffer("auto_cmd")
      " Run once when saving for new files
      autocmd BufNewFile * autocmd BufWritePost <buffer=abuf> ++once silent lua require("guess-indent").set_from_buffer("auto_cmd")
    augroup END
  ]])
end

-- Return true if the string looks like an inline comment.
-- SEE: https://en.wikipedia.org/wiki/Comparison_of_programming_languages_(syntax)#Inline_comments
local function is_comment_inline(line)
  -- Check if it starts with a comment prefix
  -- stylua: ignore start
  return not not (
    line:match("^//") or    -- C style
    line:match("^#") or     -- Python, Shell, Perl
    line:match("^%-%-") or  -- Lua, Haskell
    line:match("^%%") or    -- TeX
    line:match("^;")        -- Lisp, Assembly
  )
  -- stylua: ignore end
end

-- Only check beginning of line. Else we would need an actual parser to
-- determine if a line contains a valid block comment start.
-- Returns either a LUA pattern to match the closing block comment or
-- nil if this line doesn't start a block comment.
--
-- SEE: https://en.wikipedia.org/wiki/Comparison_of_programming_languages_(syntax)#Block_comments
local function is_comment_block_start(line)
  if line:match("^/%*") then
    -- C style  /*  */
    return "%*/"
  elseif line:match("^<!%-%-") then
    -- HTML  <!--  -->
    return "%-%->"
  end

  return nil
end

local function set_indentation(indentation)
  local function set_buffer_opt(buffer, name, value)
    -- Setting an option takes *significantly* more time than reading it.
    -- This wrapper function only sets the option if the new value differs
    -- from the current value.
    local current = vim.api.nvim_buf_get_option(buffer, name)
    if value ~= current then
      vim.api.nvim_buf_set_option(buffer, name, value)
    end
  end

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
  -- Line loading configuration
  -- Instead of loading all lines at once, load them lazily in chunks.
  local max_num_lines = 1028
  local chunk_size = 64

  -- How many lines use spaces / tabs
  local space_lines_count = 0
  local tab_lines_count = 0

  -- How many spaces / tabs were used on the previous lines
  local last_space_count = 0
  local last_tab_count = 0

  -- How many spaces are used for indentation
  local spaces = {}

  -- This stack keeps track of all indentation levels (absolute) in the
  -- current indentation block. This is used to calculate the current
  -- relative indentation based on the difference to the next smaller
  -- absolute indentation in teh current block.
  local spaces_indent_stack = { 0 }

  -- Verbose Statistics
  local v_num_lines_loaded = 0
  local v_lines_iterated = 0

  -- Optional multiline comment termination pattern that we're matching against.
  local multiline_pattern = nil

  for chunk_start = 0, (max_num_lines - 1), chunk_size do
    -- Load new chunk
    local lines = vim.api.nvim_buf_get_lines(0, chunk_start, math.min(chunk_start + chunk_size, max_num_lines), false)
    v_num_lines_loaded = v_num_lines_loaded + #lines

    -- Check each line for its indentation
    for l_idx, line in ipairs(lines) do
      l_idx = l_idx + chunk_start
      v_lines_iterated = l_idx

      local space_count = 0
      local tab_count = 0

      -- Ignore empty lines. They screw up the last_xxx_count variables
      if not line:find("[^%s]") then
        goto next_line
      end

      -- Check if multiline comment terminates here
      if multiline_pattern then
        if line:match(multiline_pattern) then
          multiline_pattern = nil
        end
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
          -- We must check if the line is a comment. If it is,
          -- then we must skip it. Ideally this would be done using a
          -- tool like treesitter.

          -- If the line starts with whitespace followed by a letter or
          -- number it very likely isn't the start of a comment.
          if c_idx ~= 1 and char:match("[%w%d]") then
            break
          end

          -- Take the first 10 non whitespace characters of the line.
          local subline = line:sub(c_idx, c_idx + 9)

          -- Inline / single line comments
          if is_comment_inline(subline) then
            goto next_line
          end

          -- Start of a multiline comment
          -- For now, we only consider multiline comments that start at the
          -- beginning (excluding whitespace) of a line.
          multiline_pattern = is_comment_block_start(subline)
          if multiline_pattern then
            -- Check if the comment ends on this line

            if line:match(multiline_pattern) then
              multiline_pattern = nil
            end

            goto next_line
          end

          -- This line isn't a comment -> exit the loop
          break
        end
      end

      if tab_count ~= 0 and space_count == 0 and last_space_count == 0 then
        -- Is using tabs
        tab_lines_count = tab_lines_count + 1
      end

      if space_count ~= 0 and tab_count == 0 and last_tab_count == 0 then
        -- Is using spaces
        -- Update stack of current indentation levels
        while spaces_indent_stack[#spaces_indent_stack] > space_count do
          table.remove(spaces_indent_stack)
        end

        -- Get abs. indentation of previous level in current block
        local prev_indent = 0
        if spaces_indent_stack[#spaces_indent_stack] == space_count then
          prev_indent = spaces_indent_stack[#spaces_indent_stack - 1]
        else
          prev_indent = spaces_indent_stack[#spaces_indent_stack]
          table.insert(spaces_indent_stack, space_count)
        end

        -- Delta is the current relative indentation
        local delta = space_count - prev_indent
        spaces[delta] = (spaces[delta] or 0) + 1
        space_lines_count = space_lines_count + 1
      end

      if space_count == 0 and tab_count == 0 then
        spaces_indent_stack = { 0 }
      end

      last_space_count = space_count
      last_tab_count = tab_count

      -- We have gathered enough evidence to stop early
      if math.abs(space_lines_count - tab_lines_count) >= 128 then
        goto prepare_result
      end

      ::next_line::
    end
  end

  ::prepare_result::

  -- Verbose debug output
  utils.v_print(1, "Guess Indent")
  utils.v_print(1, "Lines using tabs:", tab_lines_count)
  utils.v_print(1, "Lines using spaces:", space_lines_count)
  if space_lines_count ~= 0 then
    for k, v in pairs(spaces) do
      utils.v_print(1, k, "space:", v)
    end
  end
  utils.v_print(1, "Lines loaded:", v_num_lines_loaded)
  utils.v_print(1, "Lines iterated:", v_lines_iterated)

  -- Get most common indentation style
  if tab_lines_count > space_lines_count and tab_lines_count > 0 then
    return "tabs"
  elseif space_lines_count > 0 then
    local max_count = -1
    local max_spaces = 4

    for n_spaces, count in pairs(spaces) do
      if count > max_count then
        max_count = count
        max_spaces = n_spaces
      end
    end

    -- There must be a clear majority, else return nil
    if max_count < space_lines_count * 0.5 then
      return nil
    end

    return max_spaces
  else
    -- Failed to detect indentation
    return nil
  end
end

-- Set the indentation based on the contents of the current buffer.
-- The argument `context` should only be set to `auto_cmd` if this function gets
-- called by an auto command.
function M.set_from_buffer(context)
  if context == "auto_cmd" then
    -- editorconfig interoperability
    if not config.override_editorconfig then
      local editorconfig = vim.b.editorconfig
      if editorconfig and (editorconfig.indent_style or editorconfig.indent_size or editorconfig.tab_width) then
        utils.v_print(1, "Excluded because of editorconfig settings.")
        return
      end
    end

    -- Filter
    local filetype = vim.bo.filetype
    local buftype = vim.bo.buftype

    utils.v_print(1, "File type:", filetype)
    utils.v_print(1, "Buffer type:", buftype)

    for _, ft in ipairs(config.filetype_exclude) do
      if ft == filetype then
        utils.v_print(1, "Excluded because of filetype.")
        return
      end
    end

    for _, bt in ipairs(config.buftype_exclude) do
      if bt == buftype then
        utils.v_print(1, "Excluded because of buftype.")
        return
      end
    end
  end

  local indentation = M.guess_from_buffer()
  set_indentation(indentation)
end

function M.setup(options)
  setup_commands()
  config.set_config(options)

  -- Create AutoCmd
  if config.auto_cmd then
    setup_autocommands()
  end
end

return M
