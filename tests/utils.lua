local M = {}

-- Load all test cases in the data directory
function M.load_test_cases()
  local test_data_path = "./tests/data/"
  local subfolders = vim.fn.readdir(test_data_path)

  local test_cases = {}

  for _, language in ipairs(subfolders) do
    local language_path = test_data_path .. language .. "/"
    if vim.fn.isdirectory(language_path) ~= 0 then
      local l_test_cases = {}
      local test_files = vim.fn.readdir(language_path, "v:val !~ '^\\.\\|\\~$'")

      for i, file_name in ipairs(test_files) do
        l_test_cases[i] = {
          path = language_path .. file_name,
          name = file_name,
        }
      end

      test_cases[language] = l_test_cases
    end
  end

  return test_cases
end

return M
