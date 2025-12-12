local mod = {}

local Array = {}

---Creates a new array. Module can also be called directly to do the same thing.
---@param list table
---@return table
function mod.new(list)
  if type(list) ~= "table" then return nil end
  list.len = #list

  for k, v in pairs(Array) do
    list[k] = v
  end

  return list
end

function Array.push(self, element)
  self.len = self.len + 1
  table.insert(self, element)
end

function Array.pop(self)
  if self.len <= 0 then return nil end
  self.len = self.len - 1
  return table.remove(self)
end

function Array.last(self)
  return self[self.len]
end

function Array.to_list(self)
  for k, _ in pairs(self) do
    if type(k) == "string" then
      self[k] = nil
    end
  end
end

setmetatable(mod, {
  __call = function (_, ...)
    return mod.new(...)
  end
})

return mod

