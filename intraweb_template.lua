rednet.open("left")
rednet.host("intranet", "template")
local index = {"home"}

local home ={
"Welcome to example website",
"",
"each page is 40 characters wide"
}
--[[template for page:
local page_name ={
"line1",
"line2",
...
"final line"
}
]]




while true do
    local id_request, request = rednet.receive("intranet")
    if request == "index" then
        rednet.send(id_request, index, "intranet")
        --rednet.send(id_request, home)
        
        print(("Index request successful, from %d"):format(id_request))
    elseif request == "home" then
        rednet.send(id_request, home, "intranet")
        print(("Page request successful, from %d"):format(id_request))

--[[template for response:
    elseif request == "page_name" then
        rednet.send(id_request, page_name, "intranet")
        print(("page-name req. successful, from %d"):format(id_request))
    
to use this, simply change page_name for whatever
name you have chosen ]]    
    
    end   
end
    
