--[[
        ExtendedExportFilter.lua
--]]


local ExtendedExportFilter, dbg, dbgf = ExportFilter:newClass{ className='ExtendedExportFilter', register=true }



--- Constructor for extending class.
--
function ExtendedExportFilter:newClass( t )
    return ExportFilter.newClass( self, t )
end



--- Constructor for new instance.
--
function ExtendedExportFilter:new( t )
    local o = ExportFilter.new( self, t ) -- note: new export filter class (18/Nov/2013 23:10) requires parameter table (with filter-context or export-settings) and initializes filter id, name, & title.
    return o
end



--- This optional function adds the observers for our required fields metachoice and metavalue so we can change
--  the dialog depending if they have been populated.
--
function ExtendedExportFilter:startDialogMethod()
    self:logV( "start dialog method has not been overridden." )
end



-- reminder: this won't be called unless derived class provided an end-dialog function - if so, the method should be provided too.
function ExtendedExportFilter:endDialogMethod()
    app:error( "end dialog method has not been overridden." )
end



--- This function will create the section displayed on the export dialog 
--  when this filter is added to the export session.
--
function ExtendedExportFilter:sectionForFilterInDialogMethod()-- vf, props )
    app:error( "do override this" )    	
end



--- Should render photo method.
function ExtendedExportFilter:shouldRenderPhotoMethod( photo )
    return true -- in case extended class does not override
end


--- Post process rendered photos (overrides base class).
--
--  @usage reminder: videos are not considered rendered photos (won't be seen by this method).
--
function ExtendedExportFilter:postProcessRenderedPhotosMethod()
    app:error( "o" ) -- ya gotta do this one yerself.
end



--- Called from update-filter-status method, to ensure main filter.
--
--  @usage preferrably called in edb when LR-export-filters.. changes, since that catches it at earliest point,
--      <br>    on the down side, if multiple filters are present, you have to set through the prompt multiple times. - oh well, user shouldn't make that mistake more than once or twice..
--
function ExtendedExportFilter:requireMainFilterInDialog()
    local props = self.exportSettings or error( "no es" )
    local s, m = self:requireFilterInDialog( "com.robcole.Exportant.Main" )
    if s then
        assert( str:is( props.pluginManagerPreset, "plugin manager preset" ), "no plugin manager preset" )
        return true
    else
        if not str:is( props.pluginManagerPreset ) then
            props.pluginManagerPreset = 'Default'
        end
        return false
    end
    -- never reaches here
end



-- call in post-process photos method, to be sure.
function ExtendedExportFilter:requireMainFilterInPost()
    local s, m = self:requireFilterInPost( "com.robcole.Exportant.Main" )
    if s then
        return true
    else
        self:logW( m ) -- fully descriptive error message.
        local s, m = self:cancelExport()
        if s then
            self:log( "Export canceled." )
        else
            self:logW( m )
        end
        return false
    end
    -- never reaches here.
end



--- This function will check the status of the Export Dialog to determine 
--  if all required fields have been populated.
--
function ExtendedExportFilter:updateFilterStatusMethod( name, value )
    self:logV( "update filter method has not been overridden." )
end



--  Initialize photo, video, & union arrays, plus candidates & union-cache.
--
--  Note: cache-params should include file-format in raw-ids array.
--
--  I confess, this is a method born from laziness ;-}.
--
function ExtendedExportFilter:initPhotos( params )
    local rendInfo = self:peruseRenditions( params )
    if rendInfo then -- always (normally) the case
        return rendInfo.photos, rendInfo.videos, rendInfo.union, rendInfo.candidates, rendInfo.unionCache
    else
        return {}, {}, {}, {}, lrMeta:createCache{} -- happens sometimes in anomalous situations.
    end
end



function ExtendedExportFilter:getSectionTitle()
    return str:fmtx( "^1 - ^2", app:getAppName(), self.title )
end



-- method calling "boot-strap" functions:


function ExtendedExportFilter.startDialog( propertyTable)
    app:error( "Start dialog must be overridden." ) -- since for filter assurance class must be specified explicitly.
end



--- This function will create the section displayed on the export dialog 
--  when this filter is added to the export session.
--
function ExtendedExportFilter.sectionForFilterInDialog( vf, propertyTable )
    app:error( "do override" )
end



--[[ *** save for possible future resurrection:
function ExtendedExportFilter.endDialog( propertyTable)
    app:error( "End dialog must be overridden." ) -- since for filter assurance class must be specified explicitly.
    -- actually, there is no need for this method, but for debugging and to hold space for future..
end
--]]



--- This function obtains access to the photos and removes entries that don't match the metadata filter.
--
--  @usage called *before* post-process-rendered-photos function (no cached metadata).
--  @usage base class has no say (need not be called).
--
function ExtendedExportFilter.shouldRenderPhoto( exportSettings, photo )
    app:error( "do override" )
end



--- Post process rendered photos.
--
function ExtendedExportFilter.postProcessRenderedPhotos( functionContext, filterContext )
    app:error( "O" )
end



-- Note: there are not base class export settings.

ExtendedExportFilter:inherit( ExportFilter ) -- inherit *non-overridden* members.



return ExtendedExportFilter
