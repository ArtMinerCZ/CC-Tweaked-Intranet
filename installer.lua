if not fs.exists("explorer") then
    fs.makeDir("explorer")
end

if not fs.exists("explorer/favorites.lua") then
    fs.open("explorer/favorites.lua", "r")
end

if not fs.exists("basalt.lua") then
    shell.run("wget run https://basalt.madefor.cc/2.5/install.lua")
end

shell.run("wget https://raw.githubusercontent.com/ArtMinerCZ/CC-Tweaked-Intranet/refs/heads/main/explorer/array.lua explorer/array.lua")
shell.run("wget https://raw.githubusercontent.com/ArtMinerCZ/CC-Tweaked-Intranet/refs/heads/main/explorer/mtml.lua explorer/mtml.lua")

shell.run("wget https://raw.githubusercontent.com/ArtMinerCZ/CC-Tweaked-Intranet/refs/heads/main/explorer/render.lua explorer/render.lua")

shell.run("wget https://raw.githubusercontent.com/ArtMinerCZ/CC-Tweaked-Intranet/refs/heads/main/explorer/IntranetExplorer.lua IntranetExplorer.lua")

