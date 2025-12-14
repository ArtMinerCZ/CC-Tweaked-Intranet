local mod = {}

-- local pprint = require "pprint"
local array  = require "array"

---Parses the given html into a table that can be rendered using `render_page`
---@param mtml string
---@return table?, string? error
function mod.page_from_mtml(mtml)
  if type(mtml) ~= "string" then return nil, "String expected got " .. type(mtml) .. " instead" end
  local tokens, err = lex(mtml)
  if err then return nil, err end
  return parse(tokens)
end



function lex(mtml)
  local lexer_state = {
    mtml = mtml,
    idx = 1,
    len = #mtml,
    tokens = {},
    line_number = 1,
    previous_newline = 1,
  }

  function lexer_state.next()
    lexer_state.idx = lexer_state.idx + 1
    return lexer_state.idx < lexer_state.len
  end

  function lexer_state.current_char()
    return lexer_state.mtml:sub(lexer_state.idx, lexer_state.idx)
  end

  function lexer_state.error(msg)
    local column = lexer_state.idx - lexer_state.previous_newline
    return "[" .. lexer_state.line_number .. ":" .. column .. "] " .. msg
  end

  while lexer_state.idx <= lexer_state.len do
    if lexer_state.current_char() == "<" then
      if lexer_state.mtml:sub(lexer_state.idx + 1, lexer_state.idx + 1) == "!" then
        skip_comment(lexer_state)
        goto continue
      end

      local err = tokenize_tag(lexer_state)
      if err then return nil, err end

      goto continue
    end

    if lexer_state.current_char() == "\n" then
      lexer_state.line_number = lexer_state.line_number + 1
      lexer_state.previous_newline = lexer_state.idx
      table.insert(lexer_state.tokens, "\n")
      lexer_state.next()
      goto continue
    end

    local err = tokenize_chunk(lexer_state)
    if err then return nil, err end
    ::continue::
  end

  return lexer_state.tokens
end

function skip_comment(lexer_state)
  while lexer_state.current_char() ~= ">" do
    lexer_state.next()
  end
  lexer_state.next()
end

function tokenize_tag(lexer_state)
  local tag = {
    closing = false,
    self_closing = false,
    name = "",
    attributes = {},
  }

  if not lexer_state.next() then return lexer_state.error "Unclosed tag" end
  skip_whitespace(lexer_state)

  if lexer_state.current_char() == "/" then
    tag.closing = true
    if not lexer_state.next() then return lexer_state.error "Unclosed tag" end
  end

  skip_whitespace(lexer_state)
  local tag_name = next_word(lexer_state)
  if not tag_name then
    return lexer_state.error "Expected tag name"
  end
  tag.name = tag_name

  skip_whitespace(lexer_state)
  local err = tokenize_tag_attributes(lexer_state, tag)
  if err then return err end
  if tag.closing then
    if #tag.attributes > 0 then
      return lexer_state.error "Closing tags cannot have attributes"
    end
    tag.attributes = nil
  end

  skip_whitespace(lexer_state)
  if lexer_state.current_char() ~= ">" then
    return lexer_state.error "Invalid tag end"
  end

  lexer_state.next()

  if tag.closing and tag.self_closing then
    return lexer_state.error "Invalid self-closing tag"
  end

  table.insert(lexer_state.tokens, {
    line = lexer_state.line_number,
    column = lexer_state.idx - lexer_state.previous_newline,
    value = tag
  })
end

function tokenize_tag_attributes(lexer_state, tag)
  local current_char = lexer_state.current_char()
  if current_char == ">" then return end

  if current_char == "/" then
    tag.self_closing = true
    lexer_state.next()
    return
  end

  while true do
    if not current_char then
      return lexer_state.error "Unclosed tag"
    end

    local attribute_name = next_word(lexer_state)
    if not attribute_name then
      return lexer_state.error "Expected attribute"
    end

    skip_whitespace(lexer_state)
    if lexer_state.current_char() ~= "=" then
      return lexer_state.error "Expected '='"
    end

    if not lexer_state.next() then
      return lexer_state.error "Expected attribute value"
    end

    skip_whitespace(lexer_state)
    local attribute_value, err = next_attribute_value(lexer_state)
    if err then return err end
    tag.attributes[attribute_name] = attribute_value

    skip_whitespace(lexer_state)

    local current_char = lexer_state.current_char()

    if current_char == ">" then return end
    if current_char == "/" then
      lexer_state.next()
      return
    end

    if current_char ~= "," then
      return lexer_state.error "Expected comma between attributes"
    end

    lexer_state.next()

    skip_whitespace(lexer_state)
  end
end

function next_attribute_value(lexer_state)
  local start = lexer_state.idx
  local current_char = lexer_state.current_char()
  if current_char:find("%d") then
    while lexer_state.current_char():find("%d") do
      lexer_state.next()
    end
    return lexer_state.mtml:sub(start, lexer_state.idx - 1)
  elseif current_char == "\"" then
    lexer_state.next()
    while lexer_state:current_char() ~= "\"" do
      lexer_state.next()
    end
    lexer_state.next()
    return lexer_state.mtml:sub(start + 1, lexer_state.idx - 2)
  end
end

function tokenize_chunk(lexer_state)
  local start = lexer_state.idx
  while lexer_state.idx <= lexer_state.len do
    if not lexer_state.current_char() then break end
    if lexer_state.current_char() == "<" then break end

    if lexer_state.current_char() == "\n" then break end

    lexer_state.next()
  end

  table.insert(lexer_state.tokens, {
    line = lexer_state.line_number,
    column = lexer_state.idx - lexer_state.previous_newline,
    value = lexer_state.mtml:sub(start, lexer_state.idx - 1 )
  })
end

function skip_whitespace(lexer_state)
  while lexer_state.current_char():find("%s") do
    if lexer_state.current_char() == "\n" then
      lexer_state.line_number = lexer_state.line_number + 1
      lexer_state.previous_newline = lexer_state.idx
    end
    lexer_state.next()
  end
end

function next_word(lexer_state)
  local start = lexer_state.idx
  while true do
    if not lexer_state.current_char() then break end
    if not lexer_state.current_char():find("%l") then break end
    lexer_state.next()
  end
  if start == lexer_state.idx then return nil end
  return lexer_state.mtml:sub(start, lexer_state.idx - 1)
end



function parse(tokens)
  local page = {
    content = array {},
    title = "Untitled",
    newlines = { 1 },
  }

  local tag_name_stack = {}
  local tag_stacks = {
    text_color = array { "white" },
    bg_color   = array { "black" },
    link       = array {},
    nowrap     = 0,
  }

  local previous_command = {
    text_color = "white",
    bg_color = "black",
    link = false,
    nowrap = false,
  }

  page.content:push(shallow_copy_table(previous_command))

  for _, token in ipairs(tokens) do
    -- Add newline
    if token == "\n" then
      page.content:push("\n")
      table.insert(page.newlines, page.content.len + 1)
      goto continue
    end

    local token_value = token.value

    -- Add text block
    if type(token_value) ~= "table" then
      append_string(page.content, token_value)
      goto continue
    end

    local tag = token_value
    local command

    local prefix_text = ""

    -- Parse tag
    if tag.self_closing then
      local command, err = command_from_self_closing_tag(tag, page)
      if err then return nil, err end
      page.content:push(command)
      goto continue
    elseif tag.closing then
      if table.remove(tag_name_stack).name ~= tag.name then
        return nil, parser_error(token, "Missing opening tag")
      end
      local err = close_tag(tag_stacks, tag)
      if err then return nil, err end
      command = generate_command(tag_stacks)
    else
      table.insert(tag_name_stack, {
        name = tag.name,
        line = token.line,
        column = token.column,
      })
      local err
      prefix_text, err = open_tag(tag_stacks, tag, page.content)
      if err then return nil, err end
      command = generate_command(tag_stacks)
    end

    append_command(page.content, command, previous_command)
    append_string(page.content, prefix_text)

    ::continue::
  end

  -- Check for unclosed tag
  local leftover_tag = table.remove(tag_name_stack)
  if leftover_tag then
    local err_msg = "[" .. leftover_tag.line .. ":" .. leftover_tag.column .. "] Unclosed tag"
    return nil, err_msg
  end

  -- Remove trailing newlines
  while page.content:last() == "\n" do
    page.content:pop()
    table.remove(page.newlines)
  end

  -- Remove trailing commands
  local last_element = page.content:last()
  if type(last_element) == "table" then
    if not last_element.hr then
      page.content:pop()
    end
  end

  page.line_count = #page.newlines

  return page
end

function command_from_self_closing_tag(tag, page)
  local name = tag.name
  local command = {}
  if name == "hr" then
    command.hr = tag.attributes.line or "-"
  elseif name == "textbox" then
    command.textbox = tag.attributes
  end
  return command, nil
end

function open_tag(tag_stacks, token_value, page_content)
  local name = token_value.name
  if name == "color" then
    local text_color = tag_stacks.text_color:last()
    local bg_color = tag_stacks.bg_color:last()
    if token_value.attributes.text then
      text_color = token_value.attributes.text
    end
    if token_value.attributes.bg then
      bg_color = token_value.attributes.bg
    end
    tag_stacks.text_color:push(text_color)
    tag_stacks.bg_color:push(bg_color)
  elseif name == "link" then
    tag_stacks.link:push(token_value.attributes.src)
    tag_stacks.text_color:push("blue")
    return string.char(187)
  elseif name == "nowrap" then
    tag_stacks.nowrap = tag_stacks.nowrap + 1
  end
end

function close_tag(tag_stacks, token_value)
  local name = token_value.name
  if name == "color" then
    tag_stacks.text_color:pop()
    tag_stacks.bg_color:pop()
  elseif name == "link" then
    tag_stacks.link:pop()
    tag_stacks.text_color:pop()
  elseif name == "nowrap" then
    tag_stacks.nowrap = tag_stacks.nowrap - 1
  end
end

function append_string(page_content, string)
  if string == "" then return end
  if
    type(page_content:last()) == "string" and
    page_content:last() ~= "\n"
  then
    page_content[page_content.len] = page_content:last() .. string
    return
  end
  page_content:push(string)
end

function append_command(page_content, command, previous_command)
  local trimmed_command = {}
  local command_is_empty = true
  local last_element = page_content:last()

  for k, v in pairs(command) do
    if previous_command[k] == v then
      goto continue
    end
    command_is_empty = false
    trimmed_command[k] = v
    previous_command[k] = v
    ::continue::
  end

  if command_is_empty then return end

  if type(last_element) == "table" then
    for k, v in pairs(trimmed_command) do
      last_element[k] = v
    end
    return
  end

  page_content:push(trimmed_command)
end

function generate_command(tag_stacks)
  local command = {}
  command.nowrap = tag_stacks.nowrap > 0
  command.link = tag_stacks.link:last()
  command.text_color = tag_stacks.text_color:last()
  command.bg_color = tag_stacks.bg_color:last()
  if command.link == nil then
    command.link = false
  end

  return command
end

function parser_error(token, msg)
  return "[" .. token.line .. ":" .. token.column .. "] " .. msg
end

function shallow_copy_table(original)
  local copy = {}
  for k, v in pairs(original) do
    copy[k] = v
  end
  return copy
end



---Renders the page to the given terminal with the set scroll amount
---@param terminal table
---@param page table
---@param scroll integer
---@return table link_locations
function mod.render_page(terminal, page, scroll)
  local ctx = {
    term = terminal,
    nowrap = false,
    links = array {}
  }
  ctx.width, ctx.heigth = terminal.getSize()
  
  if scroll < 1 then scroll = 1 end
  if scroll > page.line_count then scroll = page.line_count end
  local start_idx = page.newlines[scroll]
  local end_idx = page.newlines[(scroll + ctx.heigth)] or page.content.len
  local is_first_iteration = true

  terminal.setBackgroundColor(colors.black)
  terminal.setTextColor(colors.white)
  terminal.setCursorPos(1, 1)
  terminal.clear()
  
  while start_idx < end_idx do
    local element = page.content[start_idx]

    if type(element) == "table" then
      for name, value in pairs(element) do
        RENDER_FUNCTIONS[name](ctx, value)
      end
    else
      render_text(ctx, element)
    end

    start_idx = start_idx + 1
    is_first_iteration = false
  end

  return ctx.links
end

RENDER_FUNCTIONS = {
  text_color = function(ctx, color)
    ctx.term.setTextColor(colors[color] or colors.black)
  end,
  bg_color = function(ctx, color)
    ctx.term.setBackgroundColor(colors[color] or colors.white)
  end,
  nowrap = function(ctx, is_enabled)
    ctx.nowrap = is_enabled
  end,
  link = function(ctx, src)
    if src then
      ctx.links.push({
        start = get_cursor_idx(ctx.term),
        src = src,
      })
    else
      local last_link = ctx.links:last()
      if last_link then
        last_link["end"] = get_cursor_idx(ctx.term)
      end
    end
  end,
  hr = function(ctx, line)
    fill_line_end_with(ctx, line)
  end
}

function get_cursor_idx(terminal)
  local x, y = terminal.getCursorPos()
  local width, _ = terminal.getSize()
  return (y - 1) * width + x
end

function render_text(ctx, text)
  if text == "\n" then
    fill_line_end_with(ctx, " ")
    local _, y = ctx.term.getCursorPos()
    ctx.term.setCursorPos(1, y + 1)
    return
  end

  --TODO Add word wrapping
  ctx.term.write(text)
end

function fill_line_end_with(ctx, line)
  local idx, _ = ctx.term.getCursorPos()
  local len = #line
  while idx <= ctx.width do
    ctx.term.write(line)
    idx = idx + len
  end
end

---Returns the link at a specific location on the screen
---@param click_x integer
---@param click_y integer
---@return string | nil
function mod.get_link_at(link_locations, click_x, click_y)
  --TODO
end

return mod
