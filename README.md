# CC: Tweaked Intranet

This project aims to create the base of Internet in Minecraft by using CC: Tweaked.

This repository contains various files that are utilized to achieve this goal.

## How it Works

Using the Rednet system, a Computer running the server program (referred to as "server" throughout this document) will register itself as a host on the `intranet` protocol using its label as the "domain".  
Using a second Computer, a Player can use the [`IntranetExplorer.lua`](explorer/IntranetExplorer.lua) programm (or any other Lua programm that can work with this system) to connect to the server using the domain. This does require both computers to have a wireless modem and for the Server to be loaded.  
When connecting, the server will send the computer the content of the page the Player connects to (By default `home.lua` if no subpage was defined) or an error, should there not be any page to serve.

### Pages

Pages are saved as `.lua` files in a `pages` directory on the Server. Creating a page called `home.lua` will result in it being used as the root page of the site (i.e. connecting to `example.com` will be the same as loading `example.com/home`).  
The pages use MTML (MineText Markup Language), a HTML-inspired format that is used to style the page and add features like textboxes and buttons. The MTML format is explained in detail on the [Julsen MC Server Wiki](https://julsenmcserver.miraheze.org/wiki/MTML).

### Addons

The Server supports the creation of "addons". Addons are additional Lua files stored in the `addons` directory, that are used whenever the player enters text in a textbox or presses a button.

Creating an addon is relatively easy. Simply create a lua file in the `addons` folder with the following base-structure:  
```lua
local addon = {}

function addon.input()
    return {}
end

function addon.receive_input(sender_id, input_id, input_value)
    return ""
end

return addon
```

`addon.input()` is used by the Server to determine the IDs to associate with this addon, so that it can call the `addon.receive_input` function for it.  
The returned value needs to be a table where the keys match the IDs you want to support. The values don't matter and are discarded by the Server during the loading (Example: `{search = true}` and `{search = "yes"}` are both equally valid to use).

`addon.receive_input(sender_id, input_id, input_value)` is called by the Server whenever the Player presses a button, or presses Enter in a textbox whos ID matches one provided in `addon.input`.  
The `sender_id` will be the ID of the computer from where the request came, `input_id` will be the ID of the input and `input_value` the actual value sent. For a button press will the value always be `true`.

The returned value needs to be a String containing optional MTML formatted text to display.

## Installation

For the intranet system to work do you need at least 1 Computer with an Ender Modem running the server and another with an Ender Modem running a software capable of handling the intranet protocol and parsing MTML.

### Server

To install the server, run the following in your Computer:
```shell
wget run https://raw.githubusercontent.com/ArtMinerCZ/CC-Tweaked-Intranet/refs/heads/main/server_update.lua
```

This will imediately execute the software, asking you for a domain to use (this can be anything). If you want to later change the domain, rename the computer using the label command.  
To add pages and addons, you'll have to terminate the current programm which can be done either by using <kbd>⌃Ctrl</kbd> + <kbd>T</kbd> or by pressing <kbd>T</kbd> followed by <kbd>Y</kbd>. After that can you add pages in the `pages/` directory and Addons in the `addons/` directory.

### Intranet Explorer

To install the Intranet Explorer, execute the following in your Computer:
```shell
wget run https://raw.githubusercontent.com/Andre601/CC-Tweaked-Intranet/refs/heads/main/installer.lua
```

> [!NOTE]
> Intranet Explorer uses Basalt v5.2 for the UI and you may be required to go through its installation process. Simply accept the recommended defaults for the installation of it.

After that, run `IntranetExplorer` to start the Explorer. If you want it to be loaded whenever the computer starts, rename the `IntranetExplorer.lua` file to `startup.lua` or move it to a `startup/` directory.

## Protocol

The Intranet uses two protocol names, `intranet` and `intranet_admin` through rednet to send and receive data. Each server registers itself as a host on both protocols, using their custom name (domain) as the host name.

Assuming you want to create a custom Intranet Explorer compatible with the `intranet` protocol, you'll need to be aware of the following:

### Rednet Messages

Messages are send through rednet on the `intranet` protocol following a specific structure.

For messages send by the explorer, the following structure is used:
```lua
{"<type>", <value>}
```

`<type>` can be any of the following:

- `page_request`: Requesting all page names from the server or a specific page's content. The second entry needs to be either `index` to receive a list of page names, or the name of the page to view.
- `indexer`: Requesting information from the server, including address, description, keywords, etc. See the responses below for the full table.
- `button_press`: Informing the Server that a button has been pressed. The second entry needs to be the button ID.
- `textbox_input`: Informing the Server, that content from a Textbox was submitted. The second entry needs to be a table where the first value is the Textbox ID and the second the submitted text.

The Server can respond with a rednet message following a similar structure. A notable difference is, that the second value is not guaranteed to exist!

The following types can be returned:

- `index`: Sends a list of page names the Server has currently loaded. The second value will be a table of page names.
- `page`: Sends content for a specific page to the explorer. The second value is the raw MTML page content.
- `404 - Page not found`: Send whenever a `page_request` request was made that wasn't containing `index` or a valid page name. Contains no other entries.

In addition can the following table be returned when `indexer` is used as request:
```lua
{"<address>", {"<keyword>"[, "<keyword>", ...]}, "<display_name>", "<description>"}
```

## Events

The Intranet uses and supports certain custom events.

### `page_resize`

Queued when the page size is retrieved before the final page render. Contains the width and height of the page.

Example:
```lua
local event, width, height = os.pullEvent("page_resize")
```

### `addressChange`

Queued after the page was rendered. Contains the address of the page.

Example:
```lua
local event, address = os.pullEvent("addressChange")
```
