local gi = require("guess-indent")
local t = require("plenary.async.tests")

local test_cases = require("tests.utils").load_test_cases()

-- Check that all files indentation gets detected correctly.
t.describe("guess-indent", function()
  for lang, tc in pairs(test_cases) do
    t.describe("for " .. lang, function()
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
        t.it("should indent: " .. file.name, function()
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
