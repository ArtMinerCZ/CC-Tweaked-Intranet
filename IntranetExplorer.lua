rednet.open("left")

--defined header
original_term = term.current()
local version = "v0.2"
local index = nil
local page = nil
local search_id = nil
scroll_offset = 0

local first_time = true
local function header()
    term.clear()
    
    if first_time then
        term.setCursorPos(13,4)
        print([[
Welcome to Intranet Explorer v0.2
        
              start by pressing S to search
        
              made by ArtMinerCZ]])
        
        first_time = false
    end
    
    term.setCursorPos(0, 1)
    print((">Intranet Explorer %s"):format(version))
    paintutils.drawLine(11,3, 11, 20, colors.gray)
    paintutils.drawLine(1,2, 51,2, colors.blue)
    
    term.setCursorPos(1,2)
    
    print("Search | Request | Help | eXit")
    term.setBackgroundColor(colors.black)
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
   -- rednet.send(search_id, page_request, "intranet")
   -- page_id, page = rednet.receive("intranet", 10)
    
    page_window = window.create(term.current(),12,3,51,18)
    term.redirect(page_window)
    term.setCursorPos(1,1)
    --prints page as a table
    term.clear()
    if not page then
        printError("404 not found")
    else
        for i = 1, 16 do
            local page_line = page[i + scroll_offset]
            if page_line then print(page_line) else break end
        end
    end
    --scroll bar
    term.redirect(original_term)
    
    if not page then
        --nothing
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

local function request_page(page_request)
    page = nil
    rednet.send(search_id, page_request, "intranet")
    page_id, page = rednet.receive("intranet", 5)
    load_page()
end
    
local function connection()
    search_id = rednet.lookup("intranet", query)
    rednet.send(search_id, "index", "intranet")
    receive_id, index = rednet.receive("intranet", 5)
    --local receive_id, page = rednet.receive()
    
    --writing index
    header()
    write_index()
    request_page("home")
end

local function request()
    header()
    write_index()
    
    term.setCursorPos(12,3)
    print("Type in your page request, from index")
    term.setCursorPos(13,4)
    local request = read()
    request_page(request)
end

local function search()
    header()
    term.setCursorPos(12,3)
    print("Type in your search request:")
    
    term.setCursorPos(13,4)
    search_id = nil
    query = read()
    local lookup_id = rednet.lookup("intranet", query)
    --failsaft
    search_id = lookup_id
    
    if not lookup_id then
        printError("404 not found")
        sleep(2)
        header()
        
    else
    
        term.setCursorPos(12,6)
        print(("Found %s at address %d"):format(query, search_id))
        term.setCursorPos(12,7)
        print("Proceed to connection? Y/N")
        term.setCursorPos(12,8)
        local event, key = os.pullEvent("key")
        if key == keys.y then
            textutils.slowPrint("Connecting...",50)
            connection()
        elseif key == keys.z then
            textutils.slowPrint("Connecting...",50)
            connection()
        else
            print("Connecting canceled")
            sleep(2)
            header()
        end
    local lookup_id = nil
    end
end




header()

--looks for keystrokes
while true do
    local event, key = os.pullEvent("key")
        
    if key == keys.s then
        --initiates web lookout
            
        search(query)
    elseif key == keys.r then
        --initiates web request, requires found web
        if not receive_id then
            printError("Missing connection")
            sleep(2)
            header()
        else
            request()
        end
    elseif key == keys.x then
        term.clear()
        error("Program ended", 0)
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
        
    else
        write("")
    end 
end

