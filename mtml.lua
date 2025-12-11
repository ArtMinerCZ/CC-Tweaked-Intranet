local mod = {}

---Parses the given html into a table that can be rendered using `render_page`
---@param mtml string
---@return table?, string? error
function mod.page_from_mtml(mtml)
  if type(mtml) ~= "string" then return nil, "String expected got " .. type(mtml) .. " instead" end
  local tokens, err = lex(mtml)
  if err then return nil, err end
  return tokens
  -- return parse(tokens)
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
      table.insert(lexer_state.tokens, { newline_position = lexer_state.idx })
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
  elseif current_char == "\"" then
    lexer_state.next()
    while lexer_state:current_char() ~= "\"" do
      lexer_state.next()
    end
    lexer_state.next()
  end
  if start == lexer_state.idx then
    return nil, lexer_state.error "Expected attribute value"
  end
  return lexer_state.mtml:sub(start, lexer_state.idx - 1)
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
    content = {{
      text_color = "black",
      background_color = "white",
      word_wrap = false,
      link = false,
    }},
    title = "",
    newlines = {}
  }
  
  local tag_name_stack = {}
  local tag_stacks = {
    text_color = {},
    background_color = {},
    link = {},
    nowrap = 1,
  }

  for _, token in ipairs(tokens) do
    local token_value = token.value

    local newline_position = token.newline_position
    if newline_position then
      table.insert(page.newlines, newline_position)
    end

    if type(token_value) ~= "table" then
      append_string(page.content, token_value)
      goto continue
    end

    local tag = token_value

    if tag.self_closing then
      --TODO
      goto continue
    end

    if tag.closing then
      if table.remove(tag_name_stack).name ~= tag.name then
        return nil, parser_error(token, "Missing opening tag")
      end
      local err = close_tag(tag_stacks, token)
      if err then return err end
    end

    table.insert(tag_name_stack, tag.name)
    open_tag(tag_stacks, token)

    local command = generate_command(tag_stacks)
    append_command(page.content, command)

    ::continue::
  end

  local leftover_tag = table.remove(tag_name_stack)
  if leftover_tag then
    local err_msg = "[" .. leftover_tag.line .. ":" .. leftover_tag.column .. "] Unclosed tag"
    return nil, err_msg
  end

  return page
end

function open_tag(tag_stacks, token_value)
  local name = token_value.name
  if name == "color" then
    if token_value.attributes.text then
      table.insert(tag_stacks.text_color, token_value.attributes.text)
    end
    if token_value.attributes.background then
      table.insert(tag_stacks.background_color, token_value.attributes.background)
    end
  elseif name == "link" then
    table.insert(tag_stacks.link, token_value.attributes.src)
  elseif name == "nowrap" then
    tag_stacks.nowrap = tag_stacks.nowrap + 1
  end
end

function close_tag(tag_stacks, token_value)
  local name = token_value.name
  if name == "color" then
    if token_value.attributes.text then
      table.remove(tag_stacks.text_color)
    end
    if token_value.attributes.background then
      table.remove(tag_stacks.background_color)
    end
  elseif name == "link" then
    table.remove(tag_stacks.link)
  elseif name == "nowrap" then
    tag_stacks.nowrap = tag_stacks.nowrap - 1
  end
end

function append_string(page_content, string)
  if string == "" then return end
  if type(page_content[#page_content]) == "string" then
    page_content[#page_content] = page_content[#page_content] .. string
    return
  end
  table.insert(page_content, string)
end

function append_command(page_content, command)
  local last_command = nil
  local i = #page_content
  while i > 0 do
    if type(page_content[i]) == "table" then
      last_command = page_content[i]
      break
    end
    i = i - 1
  end

  -- If the last element was a command simply update it instead of adding a new command
  if i == #page_content then
    for k, _ in pairs(command) do
      last_command[k] = command[k]
    end
    return
  end

  local new_command = {}

  for k, v in pairs(command) do
    if last_command[k] == v then
      goto continue
    end
    new_command[k] = v
    ::continue::
  end

  table.insert(page_content, new_command)
end

function generate_command(tag_stacks)
  local command = {}

  command.nowrap = tag_stacks.nowrap > 0
  command.text_color = tag_stacks.text_color[#tag_stacks.text_color]
  command.background_color = tag_stacks.background_color[#tag_stacks.background_color]
  command.link = tag_stacks.link[#tag_stacks.link]
  if command.link == nil then
    command.link = false
  end

  return command
end

function parser_error(token, msg)
  return "[" .. token.line .. ":" .. token.column .. "] " .. msg
end



---Renders the page to the given terminal with the set scroll amount
---@param term table
---@param parsed_page table
---@param scroll integer
---@return table link_locations
function mod.render_page(term, parsed_page, scroll)
  --TODO
end

---Returns the link at a specific location on the screen
---@param click_x integer
---@param click_y integer
---@return string | nil
function mod.get_link_at(link_locations, click_x, click_y)
  --TODO
end

return mod
