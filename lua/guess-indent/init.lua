local utils = require("guess-indent.utils")
local config = require("guess-indent.config")

local M = {}

local function setup_commands()
  -- :GuessIndent supports several arguments that can all be provided
  -- Arguments:
  --  <bufnr>   - A specific buffer number (the first will be used)
  --  context   - Respect the current file context (editorconfig or filetype/buftype exclusions)
  --  auto_cmd  - Same as "context" but is included to support the legacy API
  --  silent    - Disable notification of indentation detection
  vim.api.nvim_create_user_command("GuessIndent", function(args)
    local arguments = {}
    for _, arg in ipairs(args.fargs) do
      local num = tonumber(arg)
      if num then
        if not arguments.bufnr then
          arguments.bufnr = num
        end
      else
        arguments[arg] = true
      end
    end
    -- support "context" or "auto_cmd" for supporting legacy calls
    M.set_from_buffer(arguments.bufnr, arguments.context or arguments.auto_cmd, arguments.silent)
  end, { nargs = "*", desc = "Guess indentation for buffer" })
end

local function setup_autocommands()
  local augroup = vim.api.nvim_create_augroup("GuessIndent", { clear = true })
  vim.api.nvim_create_autocmd("BufReadPost", {
    group = augroup,
    desc = "Guesss indentation when loading a file",
    callback = function(args)
      M.set_from_buffer(args.buf, true, true)
    end,
  })
  vim.api.nvim_create_autocmd("BufNewFile", {
    group = augroup,
    desc = "Guess indentation when saving a new file",
    callback = function(args)
      vim.api.nvim_create_autocmd("BufWritePost", {
        buffer = args.buf,
        once = true,
        group = augroup,
        callback = function(wargs)
          M.set_from_buffer(wargs.buf, true, true)
        end,
      })
    end,
  })
end

-- Return true if the string looks like an inline comment.
-- SEE: https://en.wikipedia.org/wiki/Comparison_of_programming_languages_(syntax)#Inline_comments
---@param line string
---@return boolean
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
---@param line string
---@return string?
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

---@param bufnr integer
---@param name string
---@param value any
local function set_buffer_opt(bufnr, name, value)
  -- Setting an option takes *significantly* more time than reading it.
  -- This wrapper function only sets the option if the new value differs
  -- from the current value.
  local current = vim.bo[bufnr][name]
  if value ~= current then
    vim.bo[bufnr][name] = value
  end
end

---@param indentation integer|"tabs"? the number of spaces to indent or "tabs"
---@param bufnr integer? the buffer to set the indentation for (default is current buffer)
---@param silent boolean? whether or not to skip notification of change
local function set_indentation(indentation, bufnr, silent)
  bufnr = bufnr or vim.api.nvim_get_current_buf()

  local notification = "Failed to detect indentation style."
  if indentation == "tabs" then
    for opt, value in pairs(config.on_tab_options) do
      set_buffer_opt(bufnr, opt, value)
    end
    notification = "Did set indentation to tabs."
  elseif type(indentation) == "number" and indentation > 0 then
    for opt, value in pairs(config.on_space_options) do
      if value == "detected" then
        value = indentation
      end
      set_buffer_opt(bufnr, opt, value)
    end
    notification = ("Did set indentation to %s space(s)."):format(indentation)
  end
  if not silent then
    vim.notify(notification)
  end
end

---Guess the indentation of the current buffer
---@param bufnr integer? the buffer to guess indentation for (default is current buffer)
---@return integer|"tabs"? indentation
function M.guess_from_buffer(bufnr)
  bufnr = bufnr or vim.api.nvim_get_current_buf()
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
  -- How many spaces are used for indentation relative to the previous level
  local relative_spaces = {}

  -- This stack keeps track of all indentation levels (absolute) in the
  -- current indentation block. This is used to calculate the current
  -- relative indentation based on the difference to the next smaller
  -- absolute indentation in the current block.
  local spaces_indent_stack = { 0 }

  -- Verbose Statistics
  local v_num_lines_loaded = 0
  local v_lines_iterated = 0

  -- Optional multiline comment termination pattern that we're matching against.
  local multiline_pattern = nil

  -- Other
  local filetype = vim.bo.filetype

  for chunk_start = 0, (max_num_lines - 1), chunk_size do
    -- Load new chunk
    local lines =
      vim.api.nvim_buf_get_lines(bufnr, chunk_start, math.min(chunk_start + chunk_size, max_num_lines), false)
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

      -- Special case for Google C++ (#15)
      if
        filetype == "cpp"
        and (line:match("^%s*public:") or line:match("^%s*private:") or line:match("^%s*protected:"))
      then
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
        spaces[space_count] = (spaces[space_count] or 0) + 1

        -- Update stack of current indentation levels
        local last_popped_indent = space_count
        while spaces_indent_stack[#spaces_indent_stack] > space_count do
          last_popped_indent = table.remove(spaces_indent_stack)
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
        relative_spaces[delta] = (relative_spaces[delta] or 0) + 1
        space_lines_count = space_lines_count + 1

        -- Also account for deindentation
        local deindent_delta = last_popped_indent - space_count
        if deindent_delta ~= 0 then
          relative_spaces[deindent_delta] = (relative_spaces[deindent_delta] or 0) + 1
        end
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
    utils.v_print(1, "Relative Indentation")
    for k, v in pairs(relative_spaces) do
      utils.v_print(1, " ", k, "spaces:", v)
    end

    utils.v_print(1, "Absolute Indentation")
    for k, v in pairs(spaces) do
      utils.v_print(1, " ", k, "spaces:", v)
    end
  end
  utils.v_print(1, "Lines loaded:", v_num_lines_loaded)
  utils.v_print(1, "Lines iterated:", v_lines_iterated)

  -- Get most common indentation style
  if tab_lines_count > space_lines_count and tab_lines_count > 0 then
    return "tabs"
  elseif space_lines_count > 0 then
    local max_score = -1
    local max_spaces = 4

    utils.v_print(1, "Spaces Scoring")

    for n_spaces, relative_count in pairs(relative_spaces) do
      -- Compute score
      -- This is where the main SPACE HEURISTIC lives
      local log_n_spaces = math.log(n_spaces)
      local score = relative_count / space_lines_count

      for abs_spaces, abs_count in pairs(spaces) do
        -- Check if this indentation would work for other lines in the file
        if (abs_spaces % n_spaces) == 0 then
          score = score + (abs_count / space_lines_count) * (log_n_spaces / math.log(abs_spaces + 1))
        end
      end

      -- Large penalty for absurdly large indentation
      if n_spaces > 8 then
        score = score - 1
      end

      utils.v_print(1, " ", n_spaces, "score:", score)

      if score > max_score then
        max_score = score
        max_spaces = n_spaces
      end
    end

    -- There must be a clear majority, else return nil
    if max_score < 0.75 then
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
---@param bufnr? buffer number to set the indentation for (default is the current buffer)
---@param context boolean? respect the current buffer context (excluded filetypes/buffers, editorconfig)
---@param silent boolean? whether or not to skip notification
function M.set_from_buffer(bufnr, context, silent)
  bufnr = bufnr or vim.api.nvim_get_current_buf()
  if context then
    if not vim.api.nvim_buf_is_valid(bufnr) then
      return
    end
    -- editorconfig interoperability
    if not config.override_editorconfig then
      local editorconfig = vim.b[bufnr].editorconfig
      if editorconfig and (editorconfig.indent_style or editorconfig.indent_size or editorconfig.tab_width) then
        utils.v_print(1, "Excluded because of editorconfig settings.")
        return
      end
    end

    -- Filter
    local filetype = vim.bo[bufnr].filetype
    local buftype = vim.bo[bufnr].buftype

    utils.v_print(1, "File type:", filetype)
    utils.v_print(1, "Buffer type:", buftype)

    if vim.tbl_contains(config.filetype_exclude, filetype) then
      utils.v_print(1, "Excluded because of filetype.")
      return
    end

    if vim.tbl_contains(config.buftype_exclude, buftype) then
      utils.v_print(1, "Excluded because of buftype.")
      return
    end
  end

  local indentation = M.guess_from_buffer(bufnr)
  set_indentation(indentation, bufnr, silent)
end

---@param options GuessIndentConfig
function M.setup(options)
  setup_commands()
  config.set_config(options)

  -- Create AutoCmd
  if config.auto_cmd then
    setup_autocommands()
  end
end

return M
