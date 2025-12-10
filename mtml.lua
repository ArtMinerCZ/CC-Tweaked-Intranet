local mod = {}

---Parses the given html into a table that can be rendered using "render_page"
---@param mtml string
---@return table?, string? error
function mod.parse_mtml(mtml)
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
        while lexer_state.current_char() ~= ">" do
          lexer_state.next()
        end
        lexer_state.next()
        goto continue
      end
      local err = tokenize_tag(lexer_state)
      if err then return nil, err end
    else
      local err = tokenize_chunk(lexer_state)
      if err then return nil, err end
    end
    ::continue::
  end

  return lexer_state.tokens
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

  table.insert(lexer_state.tokens, { pos = lexer_state.idx, value = tag })
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

    if lexer_state.current_char() == "\n" then
      lexer_state.line_number = lexer_state.line_number + 1
      lexer_state.previous_newline = lexer_state.idx
    end

    lexer_state.next()
  end

  table.insert(lexer_state.tokens, { pos = lexer_state.idx, value = lexer_state.mtml:sub(start, lexer_state.idx - 1 ) })
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
  local parsed_page = {}
  local tag_name_stack = {}
  local tag_stacks = {}

  for _, token in ipairs(tokens) do
    if type(token) ~= "table" then
      append_string(parsed_page, token)
      goto continue
    end

    if token.self_closing then
      --TODO
      goto continue
    end

    if token.closing then
      --TODO
    end

    table.insert(tag_name_stack, token.name)
    tag_stacks[token.name] = tag_stacks[token.name] or {}
    table.insert(tag_stacks[token.name], token.attributes)
    append_string(parsed_page, token)

    ::continue::
  end
end

function append_string(parsed_page, string)
  if type(parsed_page[#parsed_page]) == "string" then
    parsed_page[#parsed_page] = parsed_page[#parsed_page] .. string
    return
  end
  table.insert(parsed_page, string)
end

function append_command(parsed_page)
  --TODO
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
