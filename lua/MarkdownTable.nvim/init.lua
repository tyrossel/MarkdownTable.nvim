
local debug = {}
local log = function (text)
	table.insert(debug, text)
end
local get_markdown_table
local function print_log_and_flush()
	local _, last_char, _ = get_markdown_table()
	vim.api.nvim_buf_set_lines(0, last_char[1] + 1, last_char[1] + 1, false, debug)
	debug = {}
end

local function trim(s)
   return (s:gsub("^%s*(.-)%s*$", "%1"))
end

get_markdown_table = function ()
	local initial_cursor_pos = vim.api.nvim_win_get_cursor(0)

	-- Go to end of the table and get line
	vim.api.nvim_feedkeys("}k$", "x", false)
	local last_char = vim.api.nvim_win_get_cursor(0)

	vim.api.nvim_feedkeys("{", "x", false)
	local first_char = vim.api.nvim_win_get_cursor(0)

	-- Get whole table
	local lines = vim.api.nvim_buf_get_lines(0, first_char[1], last_char[1], false)

	-- Replace cursor where it was
	vim.api.nvim_win_set_cursor(0, initial_cursor_pos)

	return first_char, last_char, lines
end

local is_lign_row = function (line)
	return not string.match(line, "[^ :%-|]")
end

-- Use a separation row for getting the alignments of each column
local compute_alignments = function (sep_line)
	local i_col = 1
	local pos = 1
	local prev_pos = 1
	local alignments = {}
	while true do
		pos = string.find(sep_line, "|", prev_pos + 1)
		if pos == nil then break end

		local cell = string.sub(sep_line, prev_pos + 1, pos - 1)
		cell = trim(cell)
		if string.sub(cell, 1, 1) == ":" and string.sub(cell, -1, -1) == ":" then
			alignments[i_col] = "centered"
		elseif string.sub(cell, -1, -1) == ":" then
			alignments[i_col] = "right"
		elseif string.sub(cell, 1, 1) == ":" then
			alignments[i_col] = "left"
		else
			alignments[i_col] = "default"
		end
		prev_pos = pos
		i_col = i_col + 1
	end
	return alignments
end

local compute_widths_and_alignments = function (lines)
	local max_widths = {}
	local alignments = {}

	for i = 1, #lines do

		-- If "|" is not the first char, add it upfront.
		if string.sub(lines[i], 1, 1) ~= "|" then
			lines[i] = "|"..lines[i]
		end

		-- If this is a 'line' row, then skip it for width check
		if is_lign_row(lines[i]) then
			alignments = compute_alignments(lines[i])
			goto continue
		end

		-- Computing the length of each column by taking the widest trimmed cell length
		local i_col = 1
		local pos = 1
		local prev_pos = 1
		while true do
			pos = string.find(lines[i], "|", prev_pos + 1)
			if pos == nil then break end

			if max_widths[i_col] == nil then max_widths[i_col] = 0 end
			if alignments[i_col] == nil then alignments[i_col] = "left" end
			local cell = string.sub(lines[i], prev_pos + 1, pos - 1)
			cell = trim(cell)
			if string.len(cell) > max_widths[i_col] then
				max_widths[i_col] = math.max(3, string.len(cell))
			end
			prev_pos = pos
			i_col = i_col + 1
		end
		::continue::
	end
	return max_widths, alignments
end

local function format_separation_row (line, max_widths, alignements)
	local i_col = 1
	local pos = 1
	local prev_pos = 1
	local new_line = ""
	local col_width = 0
	local n_col = 0
	while true do
		pos = string.find(line, "|", prev_pos + 1)
		if pos == nil then break end

		new_line = new_line.."| "
		col_width = math.max(3, max_widths[i_col])
		if alignements[i_col] == "centered" then
			new_line = new_line..":"..string.rep("-", col_width - 2)..": "
		elseif alignements[i_col] == "right" then
			new_line = new_line..string.rep("-", col_width - 1)..": "
		elseif alignements[i_col] == "left" then
			new_line = new_line..":"..string.rep("-", col_width - 1).." "
		else
			new_line = new_line..string.rep("-", col_width).." "
		end
		prev_pos = pos
		i_col = i_col + 1
		n_col = n_col + 1
	end
	new_line = new_line.."|"
	-- If the lign is incomplete (has less columns than other lines)
	-- Add some empty cells at the end of the lign
	if n_col < #max_widths then
		new_line = new_line..string.rep("|", #max_widths - n_col)
		new_line = format_separation_row(new_line, max_widths, alignements)
	end
	return new_line
end

local function format_row(line, max_widths, alignements)

	local i_col = 1
	local pos = 1
	local prev_pos = 1
	local new_line = ""
	local n_col = 0

	if is_lign_row(line) then
		new_line = format_separation_row(line, max_widths, alignements)
	else
		while true do
			pos = string.find(line, "|", prev_pos + 1)
			if pos == nil then break end

			new_line = new_line.."| "
			local cell = string.sub(line, prev_pos + 1, pos - 1)
			cell = trim(cell)
			if string.len(cell) < 3 then cell = cell..string.rep(" ", 3 -string.len(cell)) end
			local n_spaces = max_widths[i_col] - string.len(cell)
			if alignements[i_col] == "centered" then
				n_spaces = n_spaces / 2
				new_line = new_line..string.rep(" ", n_spaces)..cell
				if max_widths[i_col] % 2 ~= string.len(cell) % 2 then
					n_spaces = n_spaces + 1
				end
				new_line = new_line..string.rep(" ", n_spaces).." "
			elseif alignements[i_col] == "right" then
				new_line = new_line..string.rep(" ", n_spaces)..cell.." "
			else
				new_line = new_line..cell..string.rep(" ", n_spaces).." "
			end
			prev_pos = pos
			i_col = i_col + 1
			n_col = n_col + 1
		end
		new_line = new_line.."|"
		-- If the lign is incomplete (has less columns than other lines)
		-- Add some empty cells at the end of the lign
		if n_col < #max_widths then
			new_line = new_line..string.rep("|", #max_widths - n_col)
			new_line = format_row(new_line, max_widths, alignements)
		end
		new_line = new_line..string.sub(line, prev_pos + 1)
	end
	return new_line
end

local format_all_rows = function (lines, max_widths, alignements)
	for i = 1, #lines do
		lines[i] = format_row(lines[i], max_widths, alignements)
	end
end

local function format_table ()
	local first_char, last_char, lines = get_markdown_table()
	local max_widths, aligns = compute_widths_and_alignments(lines)

	format_all_rows(lines, max_widths, aligns)
	vim.api.nvim_buf_set_lines(0, first_char[1], last_char[1], false, lines)

end

MarkdownTableFormat = function ()
	format_table()

	vim.api.nvim_echo({{"Markdown Table formatted"}}, false, {})
end

local function column_under_cursor()
	local line = vim.api.nvim_get_current_line()
	local cursor = vim.api.nvim_win_get_cursor(0)
	local pos = 1
	local prev_pos = 1
	local col = 1

	while true do
		pos = string.find(line, "|", prev_pos + 1)
		if pos == nil then break end

		if pos <= cursor[2] then
			col = col + 1
		else
			return col
		end
		prev_pos = pos
	end
	return col
end

local function column_find_start(line, n_col)
	local pos = 0
	local i_col = 1
	while i_col <= n_col do
		pos = string.find(line, '|', pos + 1)
		if pos == nil then break end
		i_col = i_col + 1
	end
	return pos
end

local function get_cell_text (lines, r, c)
	local begin_pos = column_find_start(lines[r], c)
	local end_pos = column_find_start(lines[r], c + 1)
	local content = string.sub(lines[r], begin_pos + 1, end_pos - 1)
	return trim(content)
end

local function set_cell_text (lines, r, c, text)
	local begin_pos = column_find_start(lines[r], c)
	local end_pos = column_find_start(lines[r], c + 1)
	lines[r] = string.sub(lines[r], 1, begin_pos)..trim(text)..string.sub(lines[r],end_pos)
	return lines
end

MarkdownTableColDelete = function ()
	local current_col = column_under_cursor()

	format_table()

	local first_char, last_char, table_lines = get_markdown_table()
	local column_title = get_cell_text(table_lines, 1, current_col)
	local begin_pos = column_find_start(table_lines[1], current_col)
	local end_pos = column_find_start(table_lines[1], current_col + 1)
	for i = 1,#table_lines do
		table_lines[i] = string.sub(table_lines[i], 1, begin_pos)..string.sub(table_lines[i], end_pos+1)
	end
	vim.api.nvim_buf_set_lines(0, first_char[1], last_char[1], false, table_lines)

	format_table()

	vim.api.nvim_echo({{"MarkdownTable: column "..current_col.." deleted: "..column_title}}, false, {})
end

MarkdownTableColInsert = function ()
	local current_col = column_under_cursor()

	format_table()

	local first_char, last_char, lines = get_markdown_table()
	local max_widths, align = compute_widths_and_alignments(lines)
	local pos = column_find_start(lines[1], current_col)
	for i = 1,#lines do
		lines[i] = lines[i]:sub(1, pos).."|"..lines[i]:sub(pos+1)
		-- lines[i] = format_row(lines[i], max_widths, align)
	end
	vim.api.nvim_buf_set_lines(0, first_char[1], last_char[1], false, lines)

	format_table()

	vim.api.nvim_echo({{"MarkdownTable: column "..current_col.." inserted"}}, false, {})
end

MarkdownTableColToggleAlign = function ()
	local col = column_under_cursor()
	local first_char, last_char, lines = get_markdown_table()
	local max_widths, align = compute_widths_and_alignments(lines)

	-- Modify alignment
	if align[col] == "right" then align[col] = "centered"
	elseif align[col] == "centered" then align[col] = "left"
	else align[col] = "right" end

	format_all_rows(lines, max_widths, align)
	vim.api.nvim_buf_set_lines(0, first_char[1], last_char[1], false, lines)

	local column_title = get_cell_text(lines, 1, col)
	vim.api.nvim_echo({{"MarkdownTable: column "..col.." ("..column_title..") : "
						.."alignment changed to "..align[col]}}, false, {})
end

MarkdownTableColSwap = function ()
	local col_1 = column_under_cursor()
	local col_2 = col_1 - 1
	if col_2 == 0 then return end

	local first_char, last_char, lines = get_markdown_table()

	for i =1, #lines do
		local cell_1 = get_cell_text(lines, i, col_1)
		local cell_2 = get_cell_text(lines, i, col_2)
		lines = set_cell_text(lines, i, col_1, cell_2)
		lines = set_cell_text(lines, i, col_2, cell_1)
	end
	local max_widths, alignements = compute_widths_and_alignments(lines)
	format_all_rows(lines, max_widths, alignements)

	vim.api.nvim_buf_set_lines(0, first_char[1], last_char[1], false, lines)

	local column_title_1 = get_cell_text(lines, 1, col_1)
	local column_title_2 = get_cell_text(lines, 1, col_2)
	vim.api.nvim_echo({{"MarkdownTable: swapped column "..
							col_2.." ("..column_title_2..") with column "..
							col_1.." ("..column_title_1..")"}}, false, {})

end
