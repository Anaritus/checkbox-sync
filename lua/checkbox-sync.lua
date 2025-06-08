local utils = require("checkbox-sync.utils")

local M = {}

---@class CheckboxSync.Config
M.config = {

	---@type string
	todo_status = "[-]",

	---@type boolean
	insert_leave = true,
}

---Update node status under cursor. Will not trigger update of upper nodes
---
---@param node TSNode? Node to update. Defaults to node under cursor
---@param down boolean? If true, will update immediate children instead of self
---@return number?, number?
function M.update(node, down)
	local parser = utils.get_parser()
	assert(parser:lang() == "markdown", "Callback should be called only inside of markdown!")
	local cur_list_item = utils.get_list_item(node or utils.get_current())
	if not cur_list_item then
		return
	end

	local status, row, col = utils.get_status(cur_list_item, M.config.todo_status)
	if not status then
		return
	end

	local _, list_match = utils.parsed_query:iter_matches(cur_list_item, 0)()
	if not list_match then
		return
	end

	local list = list_match[1][1]
	local has_empty = false
	local has_done = false
	local has_todo = false
	local update_children = down and (status == "[ ]" or status == "[x]")
	for item in list:iter_children() do
		local item_status, item_row, item_col = utils.get_status(item, M.config.todo_status)
		if vim.tbl_contains({
			M.config.todo_status,
			"[ ]",
			"[x]",
		}, item_status) then
			if update_children then
				assert(item_col and item_row, "Will never fire, needed for lua ls")
				utils.replace_status(status, item_row, item_col, M.config.todo_status)
			end
		end
		if item_status == "[x]" then
			has_done = true
		end
		if item_status == "[ ]" then
			has_empty = true
		end
		if item_status == M.config.todo_status then
			has_todo = true
		end
	end
	if update_children then
		return
	end
	local new_status = status
	if has_empty then
		new_status = (has_done or has_todo) and M.config.todo_status or "[ ]"
	elseif has_todo then
		new_status = M.config.todo_status
	elseif has_done then
		new_status = "[x]"
	end
	if new_status ~= status then
		assert(col and row, "Will never fire, needed for lua ls")
		utils.replace_status(new_status, row, col, M.config.todo_status)
	end
	return row, col
end

---Update all ancestors of checkbox under cursor
---
---@param node TSNode? When specified, updates ancestors of the given node instead
function M.update_ancestors(node)
	local cur_node = utils.get_list_item(node or utils.get_current()):parent()

	if not cur_node then
		return
	end

	local row, col = M.update(cur_node)
	if not (row and col) then
		return
	end

	cur_node = utils.refetch_node(row, col)
	M.update_ancestors(cur_node)
end

---@param opts CheckboxSync.Config?
function M.setup(opts)
	M.config = vim.tbl_extend("force", M.config, opts)
	if M.config.insert_leave then
		vim.api.nvim_create_autocmd("InsertLeave", {
			pattern = "*.md",
			callback = function()
				M.update_ancestors()
			end,
		})
	end
end

return M
