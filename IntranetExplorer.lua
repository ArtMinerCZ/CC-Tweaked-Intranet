rednet.open("left")

--defined header
original_term = term.current()
local version = "v1.0"
local index = nil
local page = nil
local search_id = nil

local site_name = nil
local page_name = nil

local address = nil

scroll_offset = 0

local function send_message(id, type, message)
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
        
              start by pressing ; (grave)
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
    
    print("| Reload | Help | List | eXit |")
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
 
  
    
    page_window = window.create(term.current(),12,3,51,18)
    term.redirect(page_window)
    term.setCursorPos(1,1)
    --prints page as a table
    term.clear()
    if not page then
        printError("404 not found")
    else
        for i = 1, 16 do
        if page_colors == nil then 
            term.setTextColor(colors.white)
        else
            local line_color = page_colors[i + scroll_offset]
            term.setTextColor(tonumber(line_color) or colors.white)
            
        end
            local page_line = page[i + scroll_offset]
            if page_line then print(page_line) else break end
        end
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

local function address_bar()


    term.redirect(original_term)
    header()
    if index then
        write_index()
    end
    
    term.setTextColor(colors.lightGray)
    term.setCursorPos(12,1)
    address = read()
    term.setTextColor(colors.white)
    
    local address_table = {}
    for address_element in string.gmatch(address, "[^/]+") do
        table.insert(address_table, address_element)
    end
    
    local site_id = rednet.lookup("intranet", address_table[1])
    
    --default page "home"
    if address_table[2] == nil then
        address_table[2] = "home"
    end
    local previous_site = nil
    
    if address_table[1] == previous_site then
    else
        --request index and print index
        send_message(site_id, "page_request", "index")
        local site_id, received_payload = rednet.receive("intranet",5)
        index = received_payload[2]
        write_index()
    end
    local previous_site = address_table[1]
    
    --request page
    send_message(site_id, "page_request", address_table[2])
    local site_id, received_payload = rednet.receive("intranet", 5)
    page = received_payload[2]
    page_colors = received_payload[3]
    received_payload = nil
    load_page()
    
       
end  
header()



--looks for keystrokes
local function keystrokes()
while true do
    local event, key = os.pullEvent("key")
        
    if key == keys.s then

    elseif key == keys.r then
        --Reload
        scroll_offset = 0
        write_index()
        load_page()
        
        
        
    elseif key == keys.x then
        term.clear()
        return false
    --scrolling up
    elseif key == keys.up then
        if scroll_offset == 0 then
            --do nothing
        else
            scroll_offset = scroll_offset - 1
            load_page()
            
        end
    --scrolling up
    elseif key == keys.down and scroll_offset < #page-16 then
        scroll_offset = scroll_offset + 1
        load_page()
    elseif key == keys.pageUp then
        scroll_offset = 0
        load_page()
    elseif key == keys.pageDown then
        scroll_offset = #page - 16
        load_page()
    elseif key == keys.grave then
        address_bar()    
    else
        write("")
    end 
end
end

keystrokes()

