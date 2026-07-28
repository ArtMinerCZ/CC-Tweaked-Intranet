local basalt = require("basalt")

current_address = nil


basalt.use("bigfont")

screen_width, screen_height = term.getSize()
    
local main = basalt.createFrame()


         

local header = main:addFrame({

    x = 1,
    y = 1,
    
    width = screen_width,
    height = 4,
    
    background = colors.blue,

})

header:addBigFont({ x = screen_width - 10, y = 2, text = ">IE", fontSize = 1, background = colors.blue })

local title = header:addLabel({

    x = 1,
    y = 1,
    
    text=">Intranet Explorer 2.0",
    
})

local input = header:addInput({
    x = 2,
    y = 3,
    width = screen_width - 15,
    placeholder = "Click to search",
})

local xButton = header:addButton({

    x = screen_width,
    y = 1,
    width = 1,
    height = 1,
    background = colors.red,
    text = "X",
})
    :onClick(function()
    basalt.stop()
    end)




local divider = main:addLabel({y=5, text = "-[------------------------------------------------------------------------------------------"})
local scrollFrame = main:addFrame({

    x=1,
    y=6,
    
    width = screen_width,
    height = screen_height - 5,
    
    scrollable = true,
    scrollbar = "auto",
    background = colors.black,
    
    })



local program = scrollFrame:addProgram({
    x = 1,
    y = 1,
    
    width = 60,
    height = 100,
    
    

    })

basalt.schedule(function()
    while true do
        local _, width, height = os.pullEvent("page_resize")
        
        program.width = width
        program.height = height
    end
end)

basalt.schedule(function()
    while true do
        local _, address = os.pullEvent("addressChange")
        
        currentAddress = address
        input.placeholder = address
    end
end)
            
program:execute("explorer/render.lua")

program:onScroll(function(self, direction)
    scrollFrame:scrollBy(0, direction)
end)

input:onEnter(function()
    program:sendEvent("search_querry", input.text)
    
    input.placeholder = input.text
    
    input.text = ""
end)

-- FAVORITES

local favorites = {}
local currentAddress

local favoritesDropdown = main:addDropdown()
    :setPosition(1, 5)
    :setSize(20, 5)
    :setText("Favorites")

favoritesDropdown.z = 10
favoritesDropdown.dropdownHeight = 5
favoritesDropdown.showScrollBar = true

local addFavoriteButton = main:addButton({
    x = 21,
    y = 5,
    width = 3,
    height = 1,
    text = "+",
    background = colors.lime,
    foreground = colors.black,
})

addFavoriteButton.z = 10

local function saveFavorites()
    local file = fs.open("explorer/favorites.lua", "w")
    file.write(textutils.serialize(favorites))
    file.close()
end

local function openFavorite(address)
    input.placeholder = address
    favoritesDropdown:setText("Favorites")
    program:sendEvent(
        "search_querry",
        address
    )

    favoritesDropdown.selected = nil
    favoritesDropdown.selectedText = "Favorites"
end

local function refreshFavorites()
    favoritesDropdown:clear()

    for _, address in ipairs(favorites) do
        local selectedAddress = address

        favoritesDropdown:addItem({
            text = selectedAddress,

            callback = function()
                openFavorite(selectedAddress)
            end,
        })
    end

    favoritesDropdown:setText("Favorites")
end

do
    local file = fs.open("explorer/favorites.lua", "r")
    local data = textutils.unserialize(file.readAll())
    file.close()

    if type(data) == "table" then
        favorites = data
        favoritesDropdown:setSize(20, #favorites + 1)
    end
end

addFavoriteButton:onClick(function()
    if not currentAddress or currentAddress == "" then
        return
    end

    for _, address in ipairs(favorites) do
        if address == currentAddress then
            return
        end
    end

    table.insert(favorites, currentAddress)

    saveFavorites()
    refreshFavorites()
end)

basalt.schedule(function()
    while true do
        local _, address = os.pullEvent("addressChange")

        currentAddress = address
        input.placeholder = address
    end
end)

refreshFavorites()


basalt.run()
