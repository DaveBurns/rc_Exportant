--[[
        ExportSettingOverrides.lua
--]]


local ExportSettingOverrides, dbg, dbgf = ExtendedExportFilter:newClass{ className='ExportSettingOverrides', register=true }



--- Constructor for extending class.
--
function ExportSettingOverrides:newClass( t )
    return ExtendedExportFilter.newClass( self, t )
end



--- Constructor for new instance.
--
function ExportSettingOverrides:new( t )
    local o = ExtendedExportFilter.new( self, t )
    o.enablePropName = 'parmsEnable'
    return o
end



--- This function will check the status of the Export Dialog to determine 
--  if all required fields have been populated.
--
function ExportSettingOverrides:updateFilterStatusMethod( name, value )

    local props = self.exportSettings

    app:call( Call:new{ name=str:fmtx( "^1 - Update Filter Status", self.filterName ), async=true, guard=App.guardSilent, main=function( context )

        -- base class method no longer of concern once overridden in extended class.

        repeat -- once
        
            if not props.parmsEnable then
                self:allowExport( "^1 is disabled.", self.filterName )
                break
            else
                app:assurePrefSupportFile( props.pluginManagerPreset )
                self:allowExport()
            end
            
        	-- Process changes to named properties.
        	
        	if name ~= nil then
        	
                if name == '' then
                end
                
            end
            
            -- process stuff not tied to change necessarily.

            local status = self:requireMainFilterInDialog() -- denies export if main not present.
            if not status then
                break -- update synopsis and return.
            end
            
        until true
        
        self:updateSynopsis()
        
    end } )
end




--- This optional function adds the observers for our required fields metachoice and metavalue so we can change
--  the dialog depending if they have been populated.
--
function ExportSettingOverrides:startDialogMethod()

    local props = self.exportSettings
        
	view:setObserver( props, 'pluginManagerPreset', ExportSettingOverrides, ExportSettingOverrides.updateFilterStatus )
	
	view:setObserver( props, 'parmsEnable', ExportSettingOverrides, ExportSettingOverrides.updateFilterStatus )
	for i = 1, 7 do
	    view:setObserver( props, 'parmLr_' .. i, ExportSettingOverrides, ExportSettingOverrides.updateFilterStatus )
	    view:setObserver( props, 'parmName_' .. i, ExportSettingOverrides, ExportSettingOverrides.updateFilterStatus )
	    view:setObserver( props, 'parmValue_' .. i, ExportSettingOverrides, ExportSettingOverrides.updateFilterStatus )
	    view:setObserver( props, 'parmType_' .. i, ExportSettingOverrides, ExportSettingOverrides.updateFilterStatus )
	end
	
	view:setObserver( props, 'LR_exportFiltersFromThisPlugin', ExportSettingOverrides, ExportSettingOverrides.updateFilterStatus )

	self:updateFilterStatusMethod() -- async/guarded.

end




--- This function will create the section displayed on the export dialog 
--  when this filter is added to the export session.
--
function ExportSettingOverrides:sectionForFilterInDialogMethod()

    local props = self.exportSettings
        
    local it = { title = self:getSectionTitle(), spacing=5, synopsis=bind( self.synopsisPropName ) } -- minimal spacing, add more where needed.
    
    -- space - vertical implied
    local function space( n )
        it[#it + 1] = vf:spacer{ height=n or 5 }
    end

    -- separator - full horizontal, implied.
    local function sep()
        it[#it + 1] = vf:separator { fill_horizontal=1 }
    end

    space()
    local labelWidth = LrUUID.generateUUID() -- tired of widths tied to unrelated sections..
    
	it[#it + 1] = vf:row {
	    vf:spacer{ width = share( labelWidth ) },
	    vf:checkbox {
	        title = self.title,
	        value = bind 'parmsEnable',
		    width = share 'eso_ena_width',
		    tooltip = "Do not enable this unless you know what you are doing (hint: see instructions on the web).",
	    },
	}
	it[#it + 1] = vf:row {
		vf:spacer { width = share( labelWidth ) },
		vf:separator { width = share 'eso_ena_width' },
	}
	space( 7 )
	it[#it + 1] = vf:row {
        vf:spacer{ width=share( labelWidth ) },
	    vf:static_text {
	        title = "LR",
	        enabled = bind 'parmsEnable',
	    },
	    vf:static_text {
	        title = "Name",
	        width_in_chars = 15, 
	        enabled = bind 'parmsEnable',
	    },
	    vf:static_text {
	        title = "Value",
	        width_in_chars = 15, 
	        enabled = bind 'parmsEnable',
	    },
	    vf:static_text {
	        title = "Type",
	        enabled = bind 'parmsEnable',
	    },
	}
	for i = 1, 7 do
    	it[#it + 1] = 
    		vf:row {
    		    vf:static_text {
    		        title = str:fmtx( "Export Setting #^1", i ),
				    width = share( labelWidth ),
	                enabled = bind 'parmsEnable',
    		    },
    		    vf:checkbox {
    		        title = "",
    		        value = bind( str:fmtx( 'parmLr_^1', i ) ),
    		        --width_in_chars = 2,
    		        tooltip = "Check this box unless export setting is known to be supplied by a plugin.",
    		        enabled = bind 'parmsEnable',
    		    },
    		    vf:edit_field {
    		        value = bind( str:fmtx( 'parmName_^1', i ) ),
    		        width_in_chars = 15, 
    		        tooltip = "Possible names can be had by looking at export presets in text editor, for example, to set resolution explicitly the name must be 'size_resolution' (exactly - without the apostrophes)",
    		        enabled = bind 'parmsEnable',
    		    },
    		    vf:edit_field {
    		        value = bind( str:fmtx( 'parmValue_^1', i ) ),
    		        width_in_chars = 15, 
    		        tooltip = "Value must be appropriate for the name - see export preset...",
    		        enabled = bind 'parmsEnable',
    		    },
    		    vf:popup_menu {
    		        value = bind( str:fmtx( 'parmType_^1', i ) ),
    		        tooltip = "Type must be appropriate for the value - see export preset... (note: 'String' means \"Text\", 'Boolean' means \"true\" or \"false\" - don't enter quotes).",
    		        items = {
    		            { title = "String", value = 'string' },
    		            { title = "Number", value = 'number' },
    		            { title = "Boolean", value = 'boolean' },
    		        },
    		        enabled = bind 'parmsEnable',
    		    },
    		}
	end
    	
	space()
	sep()
	space()
	
	it[#it + 1] = self:sectionForFilterInDialogGetStatusView()

	return it
	
end



--- This function obtains access to the photos and removes entries that don't match the metadata filter.
--
--  @usage called *before* post-process-rendered-photos function.
--  @usage base class has no say (need not be called).
--
function ExportSettingOverrides:shouldRenderPhotoMethod( photo )

    local exportSettings = self.exportSettings
    -- assert( exportSettings, "no es" )

    --Debug.lognpp( exportSettings )
    --Debug.showLogFile()
    
    -- local fileFormat = photo:getRawMetadata( 'fileFormat' )

    return true -- it's not up to this export filter to decide not to export, it's up to custom-export-check function, if implemented.

end



--- Post process rendered photos (overrides base class).
--
--  @usage reminder: videos are not considered rendered photos (won't be seen by this method).
--
function ExportSettingOverrides:postProcessRenderedPhotosMethod()

    local functionContext, filterContext = self.functionContext, self.filterContext
    local exportSettings = filterContext.propertyTable

    app:call( Service:new{ name=str:fmtx( "^1 - Post Process Rendered Photos", self.filterName ), preset=exportSettings.pluginManagerPreset, progress=true, main=function( call )
    
        assert( exportSettings, "no es" )
        assert( exportSettings.parmsEnable ~= nil, "parms-enable not init" )
        
        if exportSettings.parmsEnable then
            self:log( "Filter is enabled." )
        else
            self:log( "Filter is disabled, so it won't do anything." )
            self:passRenditionsThrough()
            return
        end

        local photos, videos, union, candidates, unionCache = self:initPhotos{ rawIds={ 'fileFormat' }, call=call }
        if not photos then
            return
        end

        local status = self:requireMainFilterInPost()
        if not status then
            return
        end
        
        local renditionOptions = {
            plugin = _PLUGIN, -- ###3 I have no idea what this does, or if it's better to set it or not (usually it's not set).
            --renditionsToSatisfy = renditions, -- filled in below.
            filterSettings = function( renditionToSatisfy, exportSettings )
                assert( exportSettings, "no es" )
                assert( exportSettings.parmsEnable, "parms-enable should be pre-checked" )
                
                -- reminder: you can't change 'LR_tokenCustomString' at this point - I guess export service needs it fixed since renditionToSatisfy filename is fixed.
                local newPath = renditionToSatisfy.destinationPath -- by default return unmodified.
                self:log( "Rendition path: ^1", newPath )

                local photo = renditionToSatisfy.photo
                
                for i = 1, 7 do
                    local name = exportSettings['parmName_' .. i ]
                    if str:is( name ) then
                        local typ = exportSettings['parmType_' .. i ]
                        if str:is( typ ) then
                            local raw = exportSettings['parmValue_' .. i ]
                            local value
                            if typ == 'string' then
                                value = rawValue
                            elseif typ == 'boolean' then
                                value = bool:booleanFromString( raw )
                            elseif typ == 'number' then
                                value = num:numberFromString( raw )
                            else
                                error( "pgm fail" )
                            end
                            if exportSettings['parmLr_' .. i] then
                                name = 'LR_' .. name
                            end
                            --Debug.pause( name, value )
                            if exportSettings[name] ~= value then
                                self:logV( "Overriding setting of '^1', from: '^2', to: '^3'", name, exportSettings[name], value )
                                exportSettings[name] = value
                            else
                                self:logV( "'^1' is already set to: '^2', so shan't be overridden.", name, value )
                            end
                        else
                            app:error( "Export setting type must be set correctly." )
                        end
                    end
                end
                
                return nil -- newPath
                
            end, -- end of rendition filter function
        } -- closing rendition options
        
        local renditions
        renditions = candidates
        renditionOptions.renditionsToSatisfy = renditions -- could just set this to nil for slightly greater efficiency ###3 - probably doesn't matter enough to talk about..
        
        -- Reminder: selective abortion beyond this point is hit n' miss, which is way renditions were paired down, if need be - granted Lr will still present the "skipped" ones in a box..

        for sourceRendition, renditionToSatisfy in filterContext:renditions( renditionOptions ) do
            repeat
                local srcPhoto = sourceRendition.photo
                if sourceRendition.wasSkipped then
                    Debug.pause( "Source rendition was skipped." )
                    self:log( "Source rendition was skipped." )
                    break
                end
                
                -- reminder: skip-render when export in progress is problematic.
                local srcPhotoPath = srcPhoto:getRawMetadata( 'path' )
                local success, pathOrMessage = sourceRendition:waitForRender()
                
                if success then -- "rendered" file passed from upstream down to me.
                    if unionCache:getRawMetadata( srcPhoto, 'fileFormat' ) == 'VIDEO' then
                        self:logV( "Passing video downstream, dunno if any pertinent export params were changed..." )
                    else
                        self:logV( "Photo rendition from upstream being sent downstream - dunno if any pertinent export params were changed..." )
                    end
                    renditionToSatisfy:renditionIsDone( true ) -- reminder: rendition loop must be entered, since that's where the rendition options get used, but after that, the job is done..
                else -- problem exporting original, which in my case is due to something in metadata blocks that Lightroom does not like.
                    local errm = pathOrMessage or "?"
                    self:logW( "Unable to export '^1', error message: ^2. This may not cause a problem with this export, but may indicate a problem with this plugin, or with the source photo.", renditionToSatisfy.destinationPath, errm )
                        -- Note: if export is canceled, path-or-message can be nil despite success being false. ###3 - this may have been a flukey glitch - dunno.
                    renditionToSatisfy:renditionIsDone( false, errm.." - see warning in log file for more info." )
                end
                
            until true
        end
    end, finale=function( call )
        self:postProcessRenderedPhotosFinale( call )
    end } )
end



function ExportSettingOverrides.startDialog( props )
    local filter = ExtendedExportFilter.assureFilter( ExportSettingOverrides, props )
    filter:startDialogMethod()
end



function ExportSettingOverrides.sectionForFilterInDialog( vf, props )
    local filter = ExtendedExportFilter.assureFilter( ExportSettingOverrides, props )
    return filter:sectionForFilterInDialogMethod()
end



-- reminder: update status filter function need not be implemented, as long as ID passed to listener reg func is this class.
--[[
function ExportSettingOverrides.updateFilterStatus( id, props, name, value )
    local filter = ExtendedExportFilter.assureFilter( ExportSettingOverrides, props )
    filter:updateFilterStatusMethod( name, value )
end
--]]



function ExportSettingOverrides.shouldRenderPhoto( props, photo )
    local filter = ExtendedExportFilter.assureFilter( ExportSettingOverrides, props )
    return filter:shouldRenderPhotoMethod( photo )
end



--- Post process rendered photos.
--
function ExportSettingOverrides.postProcessRenderedPhotos( functionContext, filterContext )
    local filter = ExtendedExportFilter.assureFilter( ExportSettingOverrides, filterContext.propertyTable, { functionContext=functionContext, filterContext=filterContext } )
    filter:postProcessRenderedPhotosMethod()
end



ExportSettingOverrides.exportPresetFields = {

	{ key = 'parmsEnable', default = false },
	{ key = 'parmLr_1', default = true },
	{ key = 'parmName_1', default = "size_resolution" },
	{ key = 'parmValue_1', default = "300" },
	{ key = 'parmType_1', default = "number" },
	{ key = 'parmLr_2', default = true },
	{ key = 'parmName_2', default = "" },
	{ key = 'parmValue_2', default = "" },
	{ key = 'parmType_2', default = "" },
	{ key = 'parmLr_3', default = true },
	{ key = 'parmName_3', default = "" },
	{ key = 'parmValue_3', default = "" },
	{ key = 'parmType_3', default = "" },
	{ key = 'parmLr_4', default = true },
	{ key = 'parmName_4', default = "" },
	{ key = 'parmValue_4', default = "" },
	{ key = 'parmType_4', default = "" },
	{ key = 'parmLr_5', default = true },
	{ key = 'parmName_5', default = "" },
	{ key = 'parmValue_5', default = "" },
	{ key = 'parmType_5', default = "" },
	{ key = 'parmLr_6', default = true },
	{ key = 'parmName_6', default = "" },
	{ key = 'parmValue_6', default = "" },
	{ key = 'parmType_6', default = "" },
	{ key = 'parmLr_7', default = true },
	{ key = 'parmName_7', default = "" },
	{ key = 'parmValue_7', default = "" },
	{ key = 'parmType_7', default = "" },
	
}



ExportSettingOverrides:inherit( ExtendedExportFilter ) -- inherit *non-overridden* members.



return ExportSettingOverrides
