local defaults = require "prosesitter.config.defaults"
local q = require "vim.treesitter.query"
local prep = require "prosesitter.preprocessing.preprocessing"
local util = require "prosesitter.preprocessing.util"
local lintreq = require "prosesitter.linter.lintreq"
local test_util = require("prosesitter.tests.test_util")

local function fill_buf(buf, path)
	local lines = test_util.lines("preprocessing/"..path)
	vim.api.nvim_buf_set_lines(buf, 0, -1, false, lines)
end

FakeReq = { list = {} }
function FakeReq:add(_, row, start_col, end_col)
    self.list[#self.list + 1] = { text = text, row = row, start_col = start_col, end_col = end_col }
end

local buf = vim.api.nvim_create_buf(false, false)
describe("preprocessing", function()
    after_each(function()
        vim.api.nvim_buf_delete(buf, { force = true })
        buf = vim.api.nvim_create_buf(false, false)
    end)

	it("minimal markdown", function()
		fill_buf(buf, "minimal.md")
		vim.bo[buf].filetype = "markdown"

        local ok, parser = pcall(vim.treesitter.get_parser, buf)
        assert(ok, "failed to get parser")
		parser:parse()

        local query_str = defaults.queries.markdown.strings
        local query = q.parse_query(parser:lang(), query_str)

        local tree = parser:trees()[1]
        local root = tree:root()

		local lr = lintreq.new()
		local prepfn = prep.get_fn("markdown")
        for _, node, meta in query:iter_captures(root, buf, 0, -1) do
			prepfn(buf, node, meta, lr)
        end
		assert.are_same(0, lr.meta_by_mark[1][1].col_start, "first line should start at col 0")
        local req = lr:build()
		assert.are.same("1nd paragraph. Italic, bold, and code 2nd paragraph italics or bold ", req.text)
	end)

	it("markdown basic emphasis", function()
		fill_buf(buf, "emphasis.md")
		vim.bo[buf].filetype = "markdown"
        local ok, parser = pcall(vim.treesitter.get_parser, buf)
        assert(ok, "failed to get parser")

        local query_str = defaults.queries.markdown.strings
        local query = q.parse_query(parser:lang(), query_str)

        local tree = parser:trees()[1]
        local root = tree:root()

		local lr = lintreq.new()
		local prepfn = prep.get_fn("markdown")
        for _, node, meta in query:iter_captures(root, buf, 0, -1) do
			prepfn(buf, node, meta, lr)
        end
        local req = lr:build()
		assert.are.same("1nd paragraph. Italic, bold and code 2nd paragraph italics or bold ", req.text)
	end)

	it("markdown paragraphs", function()
		fill_buf(buf, "paragraphs.md")
		vim.bo[buf].filetype = "markdown"
        local ok, parser = pcall(vim.treesitter.get_parser, buf)
        assert(ok, "failed to get parser")

        local query_str = defaults.queries.markdown.strings
        local query = q.parse_query(parser:lang(), query_str)

        local tree = parser:trees()[1]
        local root = tree:root()

		local lr = lintreq.new()
		local prepfn = prep.get_fn("markdown")
        for _, node, meta in query:iter_captures(root, buf, 0, -1) do
			prepfn(buf, node, meta, lr)
        end
        local req = lr:build()
		assert.are.same("chapter Italics Paragraphs are separated by a blank line. 2nd paragraph. Italic, bold, and code. Itemized lists alternatively italics or bold look like:", req.text)
	end)
end)
