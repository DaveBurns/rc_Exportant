--[[
        mHelp.lua
--]]


local Help = {}


local dbg, dbgf = Object.getDebugFunction( 'Help' ) -- Usually not registered for conditional dbg support via plugin-manager, but can be (in Init.lua).



--[[
        Synopsis:           Provides help text as quick tips.
        
        Notes:              Accessed directly from plugin menu.
        
        Returns:            X
--]]        
function Help.general()

    app:call( Call:new{ name="General Help", main=function( call )
    
        local m = {}
        m[#m + 1] = str:fmtx( "This plugin has two kinds of help:\n1. In context (plugin UI, log file...).\n2. On the web (often comprehensive and current...)." )
        m[#m + 1] = str:fmtx( "Visit the 'Plugin Manager' for administration and configuration - it's on Lightroom's 'File' menu (the most important sections are at the top *and* bottom)." )
        m[#m + 1] = str:fmtx( "This plugin works by inserting as post-process action in export dialog box." )
        
        dia:quickTips( m )
        
    end } )
end


Help.general()
    
    
