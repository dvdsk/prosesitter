local log = require("prosesitter/log")
local marks = require("prosesitter/on_event/marks/marks")
local check = require("prosesitter/on_event/check/check")
local parsers = require("nvim-treesitter.parsers")

local api = vim.api
local M = {}

local function node_in_range(A, B, node)
	local a, _, b, _ = node:range()
	if a <= B and b >= A then -- TODO sharpen bounds
		return true
	else
		return false
	end
end

local function key(node)
	local row_start, col_start, row_end, col_end = node:range()
	local keystr = { row_start, col_start, row_end, col_end }
	return table.concat(keystr, "\0")
end

local prose_queries = {}
local function get_nodes(bufnr, start_l, end_l)
	local parser = parsers.get_parser(bufnr)
	local lang = parser:lang()
	local prose_query = prose_queries[lang]
	local nodes = {}

	parser:for_each_tree(function(tstree, _)
		local root_node = tstree:root()
		if not node_in_range(start_l, end_l, root_node) then
			return -- return in this callback skips to checking the next tree
		end

		for _, node in prose_query:iter_captures(root_node, bufnr, start_l, end_l + 1) do
			if node_in_range(start_l, end_l, node) then
				nodes[key(node)] = node
			end
		end
	end)
	return nodes
end

local function delayed_on_bytes(...)
	local args = { ... }
	vim.defer_fn(function()
		M.on_bytes(unpack(args))
	end, 25)
end

local cfg_by_buf = nil
local query = require("vim.treesitter.query")
function M.attach(bufnr)
	if not api.nvim_buf_is_loaded(bufnr) or api.nvim_buf_get_option(bufnr, "buftype") ~= "" then
		return false
	end

	local ok, parser = pcall(vim.treesitter.get_parser, bufnr)
	if not ok then
		return false
	end

	local lang = parser:lang()
	if not prose_queries[lang] then
		prose_queries[lang] = query.parse_query(lang, cfg_by_buf[bufnr])
	end

	parser:register_cbs({ on_bytes = delayed_on_bytes })

	local info = vim.fn.getbufinfo(bufnr)
	local last_line = info[1].linecount
	M.on_bytes(bufnr, nil, 0, nil, nil, last_line, nil, nil, last_line, nil, nil)
end

local BufMemory = {}
function BufMemory:reset()
	for i, _ in ipairs(self) do self[i] = nil end
end
function BufMemory:no_change(buf, start_row)
	local line =api.nvim_buf_get_lines(buf, start_row, start_row + 1, false)[1]

	if self[buf] == nil then
		self[buf] = line
		return false
	elseif self[buf] == line then
		return true
	else
		self[buf] = line
		return false
	end
end

local lintreq = nil
function M.on_bytes(
	buf,
	_, --changed_tick,
	start_row,
	_, --start_col,
	_, --start_byte,
	old_row,
	_, --old_col,
	_, --old_byte,
	new_row,
	_, --new_col,
	_ --new_byte
)
	-- -- stop calling on lines if the plugin was just disabled
	local cfg = cfg_by_buf[buf]
	if cfg == nil then
		return true
	end

	if BufMemory:no_change(buf, start_row) then
		return
	end

	-- on deletion it seems like new row is always '-0' while old_row is not '-0' (might be the number of rows deleted)
	-- TODO check if this condition never happens in any other case
	-- do not clean up highlighting extmarks, they are still needed in case of undo
	local lines_removed = (new_row == -0 and old_row ~= -0)
	local change_start = start_row
	local change_end = start_row + old_row
	if lines_removed then
		marks.remove_placeholders(buf, change_start, change_end)
		return
	end

	-- log.trace("lines changed: " .. change_start .. " till " .. change_end)
	local nodes = get_nodes(buf, change_start, change_end)
	for _, node in pairs(nodes) do
		lintreq:add_node(buf, node)
	end

	if not check.schedualled then
		check.schedual()
	end
end

function M.setup(shared)
	cfg_by_buf = shared.cfg.by_buf
	check:setup(shared, marks.mark_results)
	lintreq = check:get_lintreq()
	marks.setup(shared)
end

function M.disable()
	BufMemory:reset()
	check:disable()
end

return M
