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
local page_window = window.create(term.current(),12,3,51,18)
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
    
local first_time = true
local function header()
    term.clear()
    
    if first_time then
        term.setCursorPos(13,4)
        print([[
Welcome to Intranet Explorer v1.0
        
              start by pressing ;/§ (grave)
              to access the address bar
                              
              made by ArtMinerCZ]])
        
        first_time = false
    end
    
    term.setCursorPos(0, 1)
    print((">IE %s"):format(version))
    paintutils.drawLine(11,3, 11, 20, colors.gray)
    
    term.setBackgroundColor(colors.red)
    term.setCursorPos(9,1)
    print("<>")
    
    paintutils.drawLine(1,2, 51,2, colors.blue)
    
    term.setCursorPos(1,2)
    
    print("| Reload | Help | eXit |")
    term.setBackgroundColor(colors.black)
    term.setCursorPos(11,1)
    print("|________________________________________")
end

local function write_index()
    term.setCursorPos(1,3)
    if not index then
        --nic
    else
        for _, index_line in pairs(index) do
            print(index_line)
        end
    end
end
 
local function load_page()
    term.redirect(page_window)
    term.setCursorPos(1,1)
    
    --prints page as a table
    term.clear()
    if not page then
        printError("404 not found")
        return
    end
    
    for i = 1, 16 do
    if page_colors == nil then 
            term.setTextColor(colors.white)
    else
        local line_color = page_colors[i + scroll_offset]
        
        term.setTextColor(line_color or colors.white)
            
    end
    local page_line = page[i + scroll_offset]
    if page_line then print(page_line) else break end
    end
    
    --scroll bar
    term.redirect(original_term)
    
    if not page then
        --nothing
    elseif page == index then
        request_page("home")
    
    else
        term.setBackgroundColor(colors.gray)
        paintutils.drawLine(11,3, 11,18)
    
        local total = #page
        local visible = 16
        local scroll_max = math.max(1, total - visible)
    
        local ratio = scroll_offset / scroll_max
        local bar_pos = math.floor(ratio*15)
    
    
    
        term.setCursorPos(11, 3 + bar_pos)
        write("\18")
        term.setBackgroundColor(colors.black)
    end
        
end
 
local function address_bar(address)
 
    scroll_offset = 1
    term.redirect(original_term)
    header()
    if index then
        write_index()
    end
    
    term.setTextColor(colors.lightGray)
    term.setCursorPos(12,1)
    os.queueEvent("key", keys.backspace)
    
    if not address then
        address = read()
    else
        print(address)
    end
    
    if address == "local/history" then
        page = nil
        index = nil
        page_colors = nil
        

        write_index()
        load_page()
        return
    end
    
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
        write_index()
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
    
    term.redirect(page_window)
    buttons = mtml.render_page(page_window, parsed_mtml, scroll_offset)
    term.redirect(original_term)
    
    address = nil
end

header()

--looks for keystrokes
local function keystrokes()
    while true do
        local _, key = os.pullEvent("key")

        if writing == true then key = nil end
        if key == keys.h then
            -- ???
        elseif key == keys.r then
            --Reload
            scroll_offset = 1
            write_index()

            term.redirect(page_window)
            buttons = mtml.render_page(page_window, parsed_mtml, scroll_offset)
            term.redirect(original_term)

        elseif key == keys.x then
            term.clear()
            return false

        --scrolling up
        elseif key == keys.up then
            if scroll_offset == 1 then
                --do nothing
            else
                scroll_offset = scroll_offset - 1

            	term.redirect(page_window)
        		buttons = mtml.render_page(page_window, parsed_mtml, scroll_offset)
       			term.redirect(original_term)

            end
        --scrolling up
        elseif key == keys.down then
            scroll_offset = scroll_offset + 1

            term.redirect(page_window)
        	buttons = mtml.render_page(page_window, parsed_mtml, scroll_offset)
       		term.redirect(original_term)

        elseif key == keys.pageUp then
            if scroll_offset > 16 then 
                scroll_offset = scroll_offset - 16
            else scroll_offset = 1 end

            term.redirect(page_window)
        	buttons = mtml.render_page(page_window, parsed_mtml, scroll_offset)
       		term.redirect(original_term)

        elseif key == keys.pageDown then
            scroll_offset = scroll_offset + 18

            term.redirect(page_window)
        	buttons = mtml.render_page(page_window, parsed_mtml, scroll_offset)
       		term.redirect(original_term)
        
        elseif key == keys.grave then
            address_bar()
        else
            write("")
        end
    end
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
        
        term.redirect(page_window)
        buttons = mtml.render_page(page_window, parsed_mtml, scroll_offset)
        term.redirect(original_term)
    end
end

local function mouse_click()
    while true do
        local _, _, px, py = os.pullEvent("mouse_click")
        if px > 11 and py > 2 then
            x = px - 11
            y = py - 2 + scroll_offset - 1
            
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
parallel.waitForAny(keystrokes, mouse_click)
