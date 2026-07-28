local mtml = require("mtml")

peripheral.find("modem", rednet.open)

--defined header
local original_term = term.current()
local version = "v1.0"
local index = nil
local received_page = nil
local search_id = nil
local parsed_mtml
local site_name = nil
local page_window = term.current()
local scroll_offset = 1
local address = nil
local browsing_history = {" Browsing history:"}
local buttons = nil
local site_id = nil

local writing = false

scroll_offset = 1

local function send_message(id, type, message)
    if (id == nil) or (not id) then
        printError("Error 404")
        return
    end
    local payload = {type, message}
    rednet.send(id, payload, "intranet")
end

local function address_bar(address)
 
    scroll_offset = 1
    term.setTextColor(colors.white)
    
    local address_table = {}
    for address_element in string.gmatch(address, "[^/]+") do
        table.insert(address_table, address_element)
    end
    
    site_id = rednet.lookup("intranet", address_table[1])
    
    if site_id == nil then
        term.setCursorPos(13,4)
        printError("Error 404: Not found") 
        return    
    end
    --default page "home"
    if address_table[2] == nil then
        address_table[2] = "home"
    end
    local previous_site = nil
    
    if address_table[1] == previous_site then
    else
        --request index and print index
        send_message(site_id, "page_request", "index")
        local site_id, received_payload = rednet.receive("intranet", 5)
        index = received_payload[2]
        
    end
    local previous_site = address_table[1]
    
    --request page
    send_message(site_id, "page_request", address_table[2])
    site_id, received_payload = rednet.receive("intranet", 5)
    received_page = received_payload[2]
    received_payload = nil
    --adding page to history
    if received_page then
        table.insert(browsing_history, #browsing_history .. " | " .. textutils.formatTime(os.time()) .. " | " .. address)
    end
    --page_window = window.create(term.current(), 12,3,51,18)
    parsed_mtml, err = mtml.page_from_mtml(received_page)
    
    if not parsed_mtml then
        printError(err)
        return
    end

    local page_width, page_height = mtml.get_page_size(parsed_mtml)
    os.queueEvent("page_resize", page_width, page_height)

    
    buttons = mtml.render_page(page_window, parsed_mtml, scroll_offset)
    

    os.queueEvent("addressChange", address)
    
    
    address = nil
end




local function handle_button_response()
    local response_payload = nil
    local _, response_payload = rednet.receive("intranet", 5)
    if type(response_payload) == "table" and response_payload[2] then
        local response_page = response_payload[2]
        parsed_mtml, err = mtml.page_from_mtml(response_page)

        if not parsed_mtml then
            printError(err)
            return
        end
        local page_width, page_height = mtml.get_page_size(parsed_mtml)
        os.queueEvent("page_resize", page_width, page_height)
        
        buttons = mtml.render_page(page_window, parsed_mtml, scroll_offset)
        
    end
end

local function mouse_click()
    while true do
        local _, _, px, py = os.pullEvent("mouse_click")
        if true then
            x = px
            y = py
            
            --debug
            --write((y-1)*40+x)
            
            if buttons and #buttons > 0 then
                --print("1")
                local pressed = mtml.get_button_at(buttons,x,y)
                if pressed and pressed.button ~= nil then
                    send_message(site_id, "button_press", pressed["button"])
                    handle_button_response()
                elseif pressed and pressed.link ~= nil then
                    print(pressed.link)
                    address_bar(pressed.link)
                elseif pressed and pressed.textbox ~= nil then
                    term.setCursorPos(px,py)
                    writing = true
                    local textbox_input = read()
                    local payload = {pressed.textbox, textbox_input}
                    send_message(site_id, "textbox_input", payload)
                    writing = false
                    handle_button_response()
                end
            end
            
        end
    end
end

local function searchBarInput()
    while true do
        local _, querry = os.pullEvent("search_querry")
        address_bar(querry)
    end
end

local function resizeRender()
    while true do
        os.pullEvent("term_resize")
        
        if parsed_mtml then
        buttons = mtml.render_page(page_window, parsed_mtml, scroll_offset)
        end
    end
end

parallel.waitForAny(mouse_click, searchBarInput, resizeRender)
