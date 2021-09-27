local log = require("prosesitter/log")
local defaults = require("prosesitter/defaults")
local install = require("prosesitter/install")
local plugin_path = vim.fn.stdpath("data") .. "/prosesitter"

local M = {}

M.cfg = {
	by_buf = {},
	by_ext = defaults.query_by_ext,
	vale_to_hl = { error = "SpellBad", warning = "SpellRare", suggestion = "SpellCap" },
	vale_bin = false,
	vale_cfg = plugin_path .. "/vale_cfg.ini",
}

M.mark_to_hover = {}
M.ns_placeholders = nil
M.ns_marks = nil

function M:adjust_cfg(user_cfg)
	if user_cfg == nil then
		return
	end

	for key, value in pairs(user_cfg) do
		if self.cfg[key] == nil then
			print("fatal error: unknown key: '" .. key .. "' in user config")
		end

		self.cfg[key] = value
	end
end

function M:setup(cfg)
	self:adjust_cfg(cfg)

	if not self:vale_installed() then
		local do_setup = vim.fn.input("Vale is not installed, install vale? y/n: ")
		if do_setup == "y" then
			install.binairy_and_styles()
			install.default_cfg()
		else
			print("please setup vale manually and adjust your config")
			return false
		end
	end

	M.ns_marks = vim.api.nvim_create_namespace("prosesitter_marks")
	M.ns_placeholders = vim.api.nvim_create_namespace("prosesitter_placeholders")
	for _, hl in pairs(self.cfg.vale_to_hl) do
		hl = vim.api.nvim_get_hl_id_by_name(hl)
	end
	return true
end

function M:vale_installed()
	local ok = 1
	-- check any user set vale bin path
	if self.cfg.vale_bin ~= false then
		if vim.fn.filereadable(self.cfg.vale_bin) == ok then
			return true
		end
	end

	if vim.fn.exepath("vale") ~= "" then
		self.cfg.vale_bin = "vale"
		return true
	end

	local plugin_installed_vale_path = plugin_path .. "/vale"
	if vim.fn.filereadable(plugin_installed_vale_path) == ok then
		self.cfg.vale_bin = plugin_installed_vale_path
		return true
	end

	return false
end

return M
