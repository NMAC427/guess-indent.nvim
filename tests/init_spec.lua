local gi = require("guess-indent")

-- LOAD TEST DATA --

-- Load all test cases in the data directory
local test_data_path = "./tests/data/"
local subfolders = vim.fn.readdir(test_data_path)

local test_cases = {}

for _, language in ipairs(subfolders) do
  local language_path = test_data_path .. language .. "/"
  if vim.fn.isdirectory(language_path) ~= 0 then
    local l_test_cases = {}
    local test_files = vim.fn.readdir(language_path, "v:val =~ '\\..*$'")

    for i, file_name in ipairs(test_files) do
      l_test_cases[i] = {
        path = language_path .. file_name,
        name = file_name,
      }
    end

    test_cases[language] = l_test_cases
  end
end

-----------
-- TESTS --
-----------

-- Correctness
describe("guess-indent", function()
  for lang, tc in pairs(test_cases) do
    describe("for " .. lang, function()
      for _, file in ipairs(tc) do
        -- Open a new buffer containing the file
        vim.cmd(":edit! " .. file.path)

        -- Get first line from buffer and try to extract the expectation
        local line = vim.api.nvim_buf_get_lines(0, 0, 1, false)
        local data = loadstring("return " .. line[1]:match("{.*}"))()
        local expectation = data.expected

        if data.disabled then
          print("WARNING: Skipping test case for file '" .. file.path .. "'")
          goto cleanup
        end

        -- Perfom test
        it("should indent: " .. file.name, function()
          local result = gi.guess_from_buffer()
          assert.are.equal(expectation, result)
        end)

        -- Cleanup
        ::cleanup::
        print(vim.cmd(":bdelete!"))
      end
    end)
  end
end)

-- Print newline. Else the the last print statement would not be visible
-- in the output.
print("\n")
