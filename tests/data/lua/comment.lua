-- { expected = nil, disabled = true }

--[[
This is a comment. All the indentation contained inside it should get ignored.
	This line has been indented using a tab.
	This one too.
No indents here...
    Now I used four spaces.
XYZ
	And another tab.
Ok... This should be enought. --]]

--[[
This too is a comment.
	It is different...
It uses a different character sequence to terminate
]]
--

local bar = require("foo")
return bar
