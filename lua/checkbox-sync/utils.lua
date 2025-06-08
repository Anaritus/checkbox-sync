local M = {}

local ts = vim.treesitter

function M.get_parser()
	return require("nvim-treesitter.parsers").get_parser()
end

---@return TSNode
function M.get_current()
	local cur_node = M.refetch_node()
	assert(cur_node, "This aint a tree!")
	return cur_node
end

---@param node TSNode
---@return TSNode?
function M.get_list_item(node)
	if node:type() == "list_item" then
		return node
	end
	local parent = node:parent()
	if parent == nil then
		return nil
	end
	return M.get_list_item(parent)
end

local query = [[
(list) @list
]]
M.parsed_query = ts.query.parse("markdown", query)

---@param list_item TSNode
---@param todo_status string
---@return string?, number?, number?
function M.get_status(list_item, todo_status)
	assert(list_item:type() == "list_item", "Item should be of type list_item")
	local body = list_item:child(1)
	assert(body, "At this point should not fire. Somthing is wrong with parser if it does")
	local row, col = body:start()
	if body:type() == "task_list_marker_checked" or body:type() == "task_list_marker_unchecked" then
		return ts.get_node_text(body, 0), row, col
	end

	-- Kinda hacky (esp with lua and utf-8), but works.
	-- Reason is, at this point we know that we are inside of a list item.
	local status = ts.get_node_text(body, 0):sub(0, 3)
	if status ~= todo_status then
		return nil
	end
	return status, row, col
end

---@param new_status string
---@param row number
---@param col number
---@param todo_status string
function M.replace_status(new_status, row, col, todo_status)
	assert(
		vim.tbl_contains({
			"[ ]",
			"[x]",
			todo_status,
		}, new_status),
		"Invalid status"
	)
	assert(row, "Row must be specified!")
	assert(col, "Col must be specified!")

	local line = vim.api.nvim_buf_get_lines(0, row, row + 1, false)[1]
	local new_line = line:sub(0, col) .. new_status .. line:sub(col + 4, #line + 1)
	vim.api.nvim_buf_set_lines(0, row, row + 1, false, { new_line })
end

---@param row number?
---@param col number?
---@return TSNode?
function M.refetch_node(row, col)
	local parser = M.get_parser()
	parser:invalidate()
	if row and col then
		return ts.get_node({
			pos = { row, col },
		})
	end
	return ts.get_node()
end
return M
