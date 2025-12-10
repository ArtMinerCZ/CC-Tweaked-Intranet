mtml = require "mtml"
pprint = require "pprint"

local test_mtml = [[<color text="red">test<color/>]]

local tokens, err = mtml.parse_mtml(test_mtml)
if err then
  error(err)
end

pprint.pprint(tokens)