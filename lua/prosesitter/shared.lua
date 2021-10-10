local log = require("prosesitter/log")
local defaults = require("prosesitter/defaults")
local vale_setup = require("prosesitter/setup/vale")
local langtool_setup = require("prosesitter/setup/langtool")
local util = require("prosesitter/util")
local plugin_path = vim.fn.stdpath("data") .. "/prosesitter"

local M = {}

M.langtool_started = false
M.buf_query = {}
local Cfg = {
	vale_to_hl = { error = "SpellBad", warning = "SpellRare", suggestion = "SpellCap" },
	vale_cfg = plugin_path .. "/vale_cfg.ini",
	vale_bin = false,
	langtool_bin = false,
	default_cmds = true,
	auto_enable = true,
	disabled_ext = {}, -- empty so nothing disabled
	queries = defaults.queries,
	lint_target = defaults.lint_target,
}
M.cfg = Cfg

MarkToMeta = { m = {} }
function MarkToMeta:add(id, meta)
	local buf = vim.api.nvim_get_current_buf()
	if self.m[buf] == nil then
		self.m[buf] = {}
	end
	self.m[buf][id] = meta
end

function MarkToMeta:by_id(id)
	local buf = vim.api.nvim_get_current_buf()
	return self.m[buf][id]
end

function MarkToMeta:by_buf_id(buf, id)
	return self.m[buf][id]
end

function MarkToMeta:buffers()
	local list = {}
	for buf, _ in pairs(self.m) do
		list[#list + 1] = buf
	end
	return list
end

M.mark_to_meta = MarkToMeta
M.ns_placeholders = nil

local function overlay_table(overlay, default)
	for ext, _ in pairs(overlay) do
		default[ext] = overlay[ext]
	end
	return default
end

local function add_merged_queries(queries)
	for _, q in pairs(queries) do
		if q.strings ~= nil and q.comments ~= nil then
			q.both = defaults.merge_queries(q)
		end
	end
end

function Cfg:adjust_cfg(user_cfg)
	if user_cfg == nil then
		return
	end

	for key, _ in pairs(user_cfg) do
		self[key] = user_cfg[key]
	end

	if user_cfg.queries ~= nil then
		add_merged_queries(user_cfg.queries)
		self.queries = overlay_table(user_cfg.queries, defaults.queries)
	end

	if user_cfg.lint_target ~= nil then
		self.lint_target = overlay_table(user_cfg.lint_target, defaults.lint_target)
	end

	if user_cfg.disabled ~= nil then
		self.disabled = overlay_table(user_cfg.disabled, self.disabled)
	end

	for _, lang in ipairs(user_cfg.disabled_ext) do
		self.disabled_ext[lang] = true
	end
end

function M:setup(user_cfg)
	self.cfg:adjust_cfg(user_cfg)

	-- for now vale is not optional
	self.cfg.vale_bin = util:resolve_path(self.cfg.vale_bin, "vale")
	if self.cfg.vale_bin == nil then
		local do_setup = vim.fn.input("vale is not installed, install vale? y/n: ")
		if do_setup == "y" then
			vale_setup.binairy_and_styles()
			vale_setup.default_cfg()
		else
			print("please setup vale manually and adjust your config")
			return false
		end
	end

	-- for now langtool is not optional
	self.cfg.langtool_bin = util:resolve_path(self.cfg.langtool_bin, "languagetool/languagetool-server.jar")
	if self.cfg.langtool_bin == nil then
		local do_setup = vim.fn.input("Language tool not installed, install language tool? y/n: ")
		if do_setup == "y" then
			langtool_setup.binairy()
		else
			print("please set up language tool manually and adjust your config")
			return false
		end
	end

	M.ns_vale = vim.api.nvim_create_namespace("prosesitter_vale")
	M.ns_langtool = vim.api.nvim_create_namespace("prosesitter_langtool")
	M.ns_placeholders = vim.api.nvim_create_namespace("prosesitter_placeholders")
	for _, hl in pairs(self.cfg.vale_to_hl) do
		hl = vim.api.nvim_get_hl_id_by_name(hl)
	end
	return true
end

function M.add_cmds()
	for name, fname in pairs(defaults.cmds) do
		vim.cmd(":command " .. name .. ' lua require("prosesitter").' .. fname .. "()<CR>")
	end
end

return M
