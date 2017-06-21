--[[
        ExtendedExport.lua
--]]


local ExtendedExport, dbg, dbgf = Export:newClass{ className = 'ExtendedExport' }



--[[
        To extend special export class, which as far as I can see,
        would never be necessary, unless this came from a template,
        and plugin author did not want to change it, but extend instead.
--]]
function ExtendedExport:newClass( t )
    return Export.newClass( self, t )
end



--[[
        Called to create a new object to handle the export dialog box functionality.
--]]        
function ExtendedExport:newDialog( t )

    local o = Export.newDialog( self, t )
    return o
    
end



--[[
        Called to create a new object to handle the export functionality.
--]]        
function ExtendedExport:newExport( t )

    local o = Export.newExport( self, t )
    return o
    
end



--   E X P O R T   D I A L O G   B O X   M E T H O D S


--[[
        Export parameter change handler. This would be in base property-service class.
        
        Note: can not be method, since calling sequence is fixed.
        Probably best if derived class just overwrites this if property
        change handling is desired
--]]        
function ExtendedExport:propertyChangeHandlerMethod( props, name, value )
    app:call( Call:new{ name = "Extended Export - Property Change Handler Method", guard = App.guardSilent, main = function( context, props, name, value )
        Export.propertyChangeHandlerMethod( self, props, name, value )
        dbg( "Extended export property changed" )
    end }, props, name, value )
end



--[[
        Called when dialog box is opening.
        
        Maybe derived type just overwrites this one, since property names must be hardcoded
        per export.
        
        Another option would be to just add all properties to the change handler, then derived
        function can just ignore changes, or not.
--]]        
function ExtendedExport:startDialogMethod( props )
	Export.startDialogMethod( self, props ) -- @8/Jan/2012 this is a no-op, but that may change.
	view:setObserver( props, 'noname', ExtendedExport, Export.propertyChangeHandler )
end



--[[
        Called when dialog box is closing.
--]]        
function ExtendedExport:endDialogMethod( props )
    Export.endDialogMethod( self, props )
end



--[[
        Fetch top sections of export dialog box.
        
        Base export class replicates plugin manager top section.
        Override to change or add to sections.
--]]        
function ExtendedExport:sectionsForTopOfDialogMethod( vf, props )
    local sections = Export.sectionsForTopOfDialogMethod( self, vf, props )
    
    local s1 = {
        -- title
        -- synopsis...
    }
    
    --s1[#s1 + 1] = vf:row {
    --}
    
	if not tab:isEmpty( sections ) then
	    if not tab:isEmpty( s1 ) then
    	    tab:appendArray( sections, { s1 } ) -- append in place.
    	    return sections
    	else
    	    return sections
    	end
	elseif not tab:isEmpty( s1 ) then
	    return { s1 }
	else
	    return {}
	end
    
end



--[[
        Fetch bottom sections of export dialog box.
        
        Base export class returns nothing.
        Override to change or add to sections.
--]]        
function ExtendedExport:sectionsForBottomOfDialogMethod( vf, props )
    local sections = Export.sectionsForBottomOfDialogMethod( self, vf, props )
    
    local s1 = {
        -- title
        -- synopsis...
    }
    
    --s1[#s1 + 1] = vf:row {
    --}
    
	if not tab:isEmpty( sections ) then
	    if not tab:isEmpty( s1 ) then
    	    tab:appendArray( sections, { s1 } ) -- append in place.
    	    return sections
    	else
    	    return sections
    	end
	elseif not tab:isEmpty( s1 ) then
	    return { s1 }
	else
	    return {}
	end
    
end



--   E X P O R T   M E T H O D S



--[[
        Called immediately after creating the export object which assigns
        function-context and export-context member variables.
        
        This is the one to override if you want to change everything about
        the rendering process (preserving nothing from the base export class).
--]]        
function ExtendedExport:processRenderedPhotosMethod()
    Export.processRenderedPhotosMethod( self )
end



--[[
        Remove photos not to be rendered, or whatever.
        
        Default behavior is to do nothing except assume
        all exported photos will be rendered. Override
        for something different...
--]]
function ExtendedExport:checkBeforeRendering()
    Export.checkBeforeRendering( self )
end



--[[
        Process one rendered photo.
        
        Called in the renditions loop. This is the method to override if you
        want to do something different with the photos being rendered...
--]]
function ExtendedExport:processRenderedPhoto( rendition, photoPath )
    Export.processRenderedPhoto( self, rendition, photoPath )
end



--[[
        Process one rendering failure.
        
        process-rendered-photo or process-rendering-failure -
        one or the other will be called depending on whether
        the photo was successfully rendered or not.
        
        Default behavior is to log an error and keep on truckin'...
--]]
function ExtendedExport:processRenderingFailure( rendition, message )
    Export.processRenderingFailure( self, rendition, message )
end



--[[
        Handle special export service...
        
        Note: The base export service method essentially divides the export
        task up and calls individual methods for doing the pieces. This is
        the one to override to change what get logged at the outset of the
        service, or you the partitioning into sub-tasks is not to your liking...
--]]
function ExtendedExport:service()
    Export.service( self )
end



--[[
        Handle special export finale...
--]]
function ExtendedExport:finale( service, status, message )
    app:logInfo( str:format( "^1 finale, ^2 rendered.", service.name, str:plural( self.nPhotosRendered, "photo" ) ) )
    Export.finale( self, service, status, message )
end



-----------------------------------------------------------------------------------------



--   E X P O R T   S E T T I N G S

-- ExtendedExport.showSections = { 'exportLocation', 'postProcessing' }
ExtendedExport.hideSections = nil -- {}
-- ExtendedExport.allowFileFormats = { 'JPEG' }
-- ExtendedExport.allowColorSpaces = { 'sRGB' }
local exportParams = {}
exportParams[#exportParams + 1] = { key = 'pluginName', default = app:getPluginName() } -- sortofa a dummy, but helps identify plugin implementing export service.
ExtendedExport.exportPresetFields = exportParams
ExtendedExport.canExportVideo = true



-- Direct inheritance so extended function members are recognized by Lightroom.
ExtendedExport:inherit( Export )


return ExtendedExport

