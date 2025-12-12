local mod = {}

local pprint = require "pprint"

---Parses the given html into a table that can be rendered using `render_page`
---@param mtml string
---@return table?, string? error
function mod.page_from_mtml(mtml)
  if type(mtml) ~= "string" then return nil, "String expected got " .. type(mtml) .. " instead" end
  local tokens, err = lex(mtml)
  if err then return nil, err end
  return parse(tokens)
  -- return tokens
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
    content = {},
    title = "Untitled",
    newlines = {},
    content_length = 0,
  }

  function page.content.push(element)
    page.content.len = (page.content.len or 0) + 1
    table.insert(page.content, element)
  end

  function page.content.pop()
    page.content.len = page.content.len - 1
    return table.remove(page.content)
  end
  
  local tag_name_stack = {}
  local tag_stacks = {
    text_color = { "black" },
    bg_color   = { "white" },
    link       = {},
    nowrap     = 0,
  }

  local previous_command = {
    text_color = "black",
    bg_color = "white",
    link = false,
    nowrap = false,
  }

  page.content.push(shallow_copy_table(previous_command))

  for _, token in ipairs(tokens) do
    -- Add newline
    if token == "\n" then
      page.content.push("\n")
      table.insert(page.newlines, page.content.len)
      goto continue
    end
    
    local token_value = token.value

    -- Add text block
    if type(token_value) ~= "table" then
      append_string(page.content, token_value)
      goto continue
    end

    local tag = token_value

    if tag.self_closing then
      --TODO
      goto continue
    end

    -- Add or remove tag
    if tag.closing then
      if table.remove(tag_name_stack).name ~= tag.name then
        return nil, parser_error(token, "Missing opening tag")
      end
      close_tag(tag_stacks, token_value)
    else
      table.insert(tag_name_stack, {
        name = tag.name,
        line = token.line,
        column = token.column,
      })
      open_tag(tag_stacks, token_value)
    end

    local command = generate_command(tag_stacks)
    append_command(page.content, command, previous_command)

    ::continue::
  end

  -- Remove trailing newlines
  while page.content[page.content.len] == "\n" do
    page.content.pop()
    table.remove(page.newlines)
  end

  -- Remove trailing command
  local leftover_tag = table.remove(tag_name_stack)
  if leftover_tag then
    local err_msg = "[" .. leftover_tag.line .. ":" .. leftover_tag.column .. "] Unclosed tag"
    return nil, err_msg
  end

  if type(page.content[page.content.len]) == "table" then
    page.content.pop()
  end

  return page
end

function open_tag(tag_stacks, token_value)
  local name = token_value.name
  if name == "color" then
    local text_color = tag_stacks.text_color[#tag_stacks.text_color]
    local bg_color = tag_stacks.bg_color[#tag_stacks.bg_color]
    if token_value.attributes.text then
      text_color = token_value.attributes.text
    end
    if token_value.attributes.bg then
      bg_color = token_value.attributes.bg
    end
    table.insert(tag_stacks.text_color, text_color)
    table.insert(tag_stacks.bg_color, bg_color)
  elseif name == "link" then
    table.insert(tag_stacks.link, token_value.attributes.src)
  elseif name == "nowrap" then
    tag_stacks.nowrap = tag_stacks.nowrap + 1
  end
end

function close_tag(tag_stacks, token_value)
  local name = token_value.name
  if name == "color" then
    table.remove(tag_stacks.text_color)
    table.remove(tag_stacks.bg_color)
  elseif name == "link" then
    table.remove(tag_stacks.link)
  elseif name == "nowrap" then
    tag_stacks.nowrap = tag_stacks.nowrap - 1
  end
end

function append_string(page_content, string)
  if string == "" then return end
  if type(page_content[page_content.len]) == "string" then
    page_content[page_content.len] = page_content[page_content.len] .. string
    return
  end
  page_content.push(string)
end

function append_command(page_content, command, previous_command)
  local trimmed_command = {}
  local last_element = page_content[page_content.len]

  for k, v in pairs(command) do
    if previous_command[k] == v then
      goto continue
    end
    trimmed_command[k] = v
    previous_command[k] = v
    ::continue::
  end

  if type(last_element) == "table" then
    for k, v in pairs(trimmed_command) do
      last_element[k] = v
    end
    return
  end

  page_content.push(command)
end

function generate_command(tag_stacks)
  local command = {}
  command.nowrap = tag_stacks.nowrap > 0
  command.link = tag_stacks.link[#tag_stacks.link]
  command.text_color = tag_stacks.text_color[#tag_stacks.text_color]
  command.bg_color = tag_stacks.bg_color[#tag_stacks.bg_color]
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
