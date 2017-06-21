--[[
        Tagsets.lua
        
        Note: Tagsets module may be edited to taste after plugin generator copies to destination.
        
        See API doc for nearly complete set of tags, and guide doc for more info.
        
        *** Inclusion of tagsets will force plugin-init module to execute upon Lr startup.
--]]


-- declare return table.
local tagsets = {}



--[[
        Tagset #1
--]]
local t1 = {}
t1.title = "Tagset One"
t1.id = "tagsetOne"
t1.items = {
{ 'com.adobe.label', label = LOC "$$$/Metadata/SampleLabel=Section Label" },
'com.adobe.filename',
'com.adobe.separator',
{ 'com.adobe.caption', height_in_lines = 3 },
}


      
--[[
        Tagset #2
--]]
local t2 = {}
t2.title = "Tagset Two"
t2.id = "tagsetTwo"
t2.items = {
{ 'com.adobe.label', label = LOC "$$$/Metadata/SampleLabel=Section Label" },
'com.adobe.filename',
'com.adobe.separator',
{ 'com.adobe.caption', height_in_lines = 3 },
}
         


-- Note: does not require catalog update if tagsets is empty table.
-- tagsets[1] = t1
-- tagsets[2] = t2


-- Note: does not require catalog update if tagsets is empty table.
return tagsets