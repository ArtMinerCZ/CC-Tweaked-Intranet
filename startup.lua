if os.getComputerLabel() == nil then
	print("Please enter hostname:")
	local hostname = read()
	os.setComputerLabel(hostname)
end

hostname = os.getComputerLabel()

rednet.open("left")
rednet.host("intranet", hostname)

local PAGE_DIR = "pages"

local pages = {}
local colors = {}
local index = {}

-- Load pages and color tables
local function loadPages()
    if not fs.exists(PAGE_DIR) then
        fs.makeDir(PAGE_DIR)
    end

    local files = fs.list(PAGE_DIR)
    for _, file in ipairs(files) do
        if not file:match("%.lua$") and file:match("_color%.lua$") then
            return
        end

        local name = file:gsub("%.lua$", "")
        local path = fs.combine(PAGE_DIR, file)

        local ok, data = pcall(dofile, path)

        if not ok or type(data) ~= table then
            print("Failed to load page:", file)
            return
        end

        pages[name] = data
        table.insert(index, name)
        print("Loaded page:", name)

        -- load color table
        local colorFile = name .. "_color.lua"
        local colorPath = fs.combine(PAGE_DIR, colorFile)

        if not fs.exists(colorPath) then
            colors[name] = {}
            print("No color table found for:", name)
            return
        end

        local ok2, coldata = pcall(dofile, colorPath)
        if not ok2 or type(coldata) ~= "table" then
            colors[name] = {}
            print("Failed to load color table:", colorFile)
            return
        end

        colors[name] = coldata
        print("Loaded color table:", name)
    end
end

loadPages()

print("Intranet server active. Pages loaded:", #index)

-- Main loop
while true do
    local id, request = rednet.receive("intranet")

    if request == "index" then
        os.sleep(1)
        rednet.send(id, index, "intranet")
        print(("Sent index to %d"):format(id))

    elseif pages[request] then
        -- send page text first
        rednet.send(id, pages[request], "intranet")
        print(("Sent page '%s' text to %d"):format(request, id))

        -- then send color table
        rednet.send(id, colors[request] or {}, "intranet")
        print(("Sent page '%s' colors to %d"):format(request, id))

    else
        rednet.send(id, {"404 - Page not found"}, "intranet")
        rednet.send(id, {}, "intranet") -- empty color table
        print(("Unknown page request '%s' from %d"):format(tostring(request), id))
    end
end
