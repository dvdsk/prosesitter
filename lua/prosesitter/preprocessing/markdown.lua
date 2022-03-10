local util = require "prosesitter.preprocessing.util"

M = {}

local function markdown_split_paragraph(buf, node, meta, req)
	local add = function(row_start, col_start, row_end, col_end)
		meta.content = {{row_start, col_start, row_end, col_end}}
		util.default_fn(buf, node, meta, req)
	end

	local curr_row_s, curr_col_s, par_row_end, par_col_end = util.range(node, meta)
	local add_trimmed = function(trim, child)
		local child_row_start, child_col_start, child_row_end, child_col_end = child:range()
		add(curr_row_s, curr_col_s, child_row_start, child_col_start)
		add(child_row_start, child_col_start+trim, child_row_end, child_col_end-trim)
		curr_row_s = child_row_end
		curr_col_s = child_col_end+trim
	end

	for child in node:iter_children() do
		if child:type() == "emphasis" then
			add_trimmed(1, child)
		elseif child:type() == "strong_emphasis" then
			add_trimmed(2, child)
		elseif child:type() == "code_span" then
			local child_row_start, child_col_start, child_row_end, child_col_end = child:range()
			add(curr_row_s, curr_col_s, child_row_start, child_col_start)
			curr_row_s = child_row_end
			curr_col_s = child_col_end
		else
			-- do not add others node types
		end
	end
	add(curr_row_s, curr_col_s, par_row_end, par_col_end)
end

local function prep(buf, node, meta, req)
	if node:parent():type() == "block_quote" then
		return
	end

	if node:child_count() > 0 then
		markdown_split_paragraph(buf, node, meta, req)
	else
		util.default_fn(buf, node, meta, req)
	end
end

return prep