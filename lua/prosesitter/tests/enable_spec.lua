local ps = require("prosesitter")
local test_util = require("prosesitter/tests/test_util")
local state = require("prosesitter/state")

local cwd = vim.loop.cwd()
vim.cmd("set rtp+=" .. cwd)

test_util.setup()

describe("Check manually enabling", function()
	it("test", function()
		assert.truthy("Pass.")

		-- if file ~= "comments/code.c" then
		-- 	return
		-- end

		local bufnr = vim.api.nvim_create_buf(false, false)
		vim.api.nvim_win_set_buf(0, bufnr)
		vim.bo[bufnr].filetype = "python"
		local content = {
			"def test_function():",
			"    print(\"spell erro\")",
		}
		vim.api.nvim_buf_set_lines(bufnr, 0, -1, false, content)

		local ok, err = ps.enable()
		assert.message(err).is_true(ok)

		local function check()
			return #state.issues.m[bufnr].langtool > 0
		end

		ok, _ = vim.wait(2500, check, 500, false)
		assert.is_true(ok)

		local details = vim.api.nvim_buf_get_extmarks(bufnr, state.ns_marks, 0, -1, { details = true })

		local marks = {}
		for _, mark in ipairs(details) do
			local id = mark[1]
			local issues = state.issues:for_buf_id(bufnr, id)
			marks[#marks + 1] = {
				row = mark[2],
				col_start = mark[3],
				col_end = mark[4].end_col,
				severity = issues:severity(),
				sources = issues:sources(),
			}
		end

		local correct_marks = {}
		assert.are.same(marks, correct_marks)

		vim.api.nvim_buf_delete(bufnr, { force = true })
	end)
end)
