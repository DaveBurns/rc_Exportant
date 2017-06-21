--[[
        Main.lua
--]]


local Main, dbg, dbgf = ExtendedExportFilter:newClass{ className='Main', register=true }



--- Constructor for extending class.
--
function Main:newClass( t )
    return ExtendedExportFilter.newClass( self, t )
end



--- Constructor for new instance.
--
function Main:new( t )
    local this = ExtendedExportFilter.new( self, t ) -- note: new export filter class (18/Nov/2013 23:10) requires parameter table (with filter-context or export-settings) and initializes filter id, name, & title.
    this.chgGate = Gate:new{ max=10 }
    return this
end



--- This function will check the status of the Export Dialog to determine 
--  if all required fields have been populated.
--
function Main:updateFilterStatusMethod( name, value )

    local props = self.exportSettings or error( "no es" )

    -- pre 5/Nov/2014 4:47 - async=true, guard=App.guardSilent
    app:pcall{ name=str:fmtx( "^1 - Update Filter Status", self.filterName ), gate=self.chgGate, main=function( call ) -- post 5/Nov/2014 5:11 - gated instead (async implied).

        local propFreshFunc        	
    	if name ~= nil then
    	
    	    -- named property has changed
    	    
            if name == 'pluginManagerPreset' then
                propFreshFunc = app.loadPrefSupportFile -- assure func would probably work here too, but it seems comforting to force a reload when preset changes.
    	    else
       	        --Debug.pause( name )
          	    if name == app:getGlobalPrefKey( 'logVerbose' ) then
          	        app:setVerbose( value )
          	    end
    	        propFreshFunc = app.assurePrefSupportFile
            end
            
        else
  	        propFreshFunc = app.assurePrefSupportFile
        end
        
        -- process stuff not tied to change necessarily.
        if str:is( props.pluginManagerPreset ) then
            local nameSet = tab:createSet( app:getPresetNames() )
            if nameSet[props.pluginManagerPreset] then
                local s, m = LrTasks.pcall( propFreshFunc, app, props.pluginManagerPreset ) -- make sure properties are fresh.
                if s then
                    self:allowExport( "^1 is ready - '^2' has been loaded.", self.filterName, props.pluginManagerPreset )
                else -- note: plugin manager will display details, not point here.
                    self:alertLogWE( { we='w', holdoff=0 }, m ) -- this is new @27/Nov/2013 2:39.
                    self:denyExport( "'^1' exists but has syntax error(s) - choose 'Edit Advanced Settings'\nfrom dropdown above to correct problem.", props.pluginManagerPreset )
                end
            else
                self:denyExport( "'^1' does not exist.", props.pluginManagerPreset )
            end
        else
            self:denyExport( "No (plugin-manager) preset has been selected in 'Main' section." )
        end
        
        self:updateSynopsis()
            
    end }
end



--- This optional function adds the observers for our required fields metachoice and metavalue so we can change
--  the dialog depending if they have been populated.
--
function Main:startDialogMethod()

    local props = self.exportSettings or error( "no es" )

    if not str:is( props.pluginManagerPreset ) then
        props.pluginManagerPreset = 'Default'
    end
    
	view:setObserver( props, 'pluginManagerPreset', Main, Main.updateFilterStatus )
	view:setObserver( props, 'LR_export_destinationType', Main, function( id, _props, name, value )
        if value == 'sourceFolder' then
            if props.LR_collisionHandling == 'overwrite' then
                app:show{ warning="Be VERY careful not to overwrite source files. Lr/Exportant will protect from overwriting the source file being exported, but neither will prevent you from overwriting *other* source files!\n \n*** Double-check your file naming to assure you don't overwrite source files!!" }
            end
        end
	end )
	view:setObserver( props, 'LR_collisionHandling', Main, function( id, _props, name, value )
        if value == 'overwrite' then
            if props.LR_export_destinationType == 'sourceFolder' then
                app:show{ warning="Be VERY careful not to overwrite source files. Lr/Exportant will protect from overwriting the source file being exported, but neither will prevent you from overwriting *other* source files!\n \n*** Double-check your file naming to assure you don't overwrite source files!!" }
            end
        end
	end )
	-- Note: it seems there is already an observer listening for changes to global prop, no need to reproduce here.
	-- however, I don't see how that's possible at the moment, and other places where this property is replicated they are listening.
	-- I think better to overdo than underdo, so here it is:
	view:setObserver( prefs, app:getGlobalPrefKey( 'logVerbose' ), Manager, Manager.prefChangeHandler ) -- cheating a tad, but precedent has been set before..
	view:setObserver( prefs, app:getGlobalPrefKey( 'logVerbose' ), Main, function( _id, _props, key, value ) -- reminder: Main.updateFilterStatus is tied to props - don't use with prefs observer.
	    self:updateSynopsis()
	end )
	-- it still seems to set verbosity twice in a row, *sometimes*, and I'm not sure why (pref change handler is guarded). Oh well, 2x is better than zero.

	self:updateFilterStatusMethod() -- async/guarded.

end



--- This function will create the section displayed on the export dialog 
--  when this filter is added to the export session.
--
function Main:sectionForFilterInDialogMethod()-- vf, props )

    -- there are no sections defined in base class.
    local props = self.exportSettings or error( "no es" )
    
    local it -- section
    
    app:pcall{ name="Main - Section For Filter In Dialog", async=false, main=function( call ) -- shouldn't need to be guarded - is called from task.
    
        -- note: synopsis updater is overridden, so no need for enable-prop-name
        it = { title = self:getSectionTitle(), spacing=5, synopsis=bind( self.synopsisPropName ) } -- minimal spacing, add more where needed.
        
        -- space - vertical implied
        local function space( n )
            it[#it + 1] = vf:spacer{ height=n or 5 }
        end
    
        -- separator - full horizontal, implied.
        local function sep()
            it[#it + 1] = vf:separator { fill_horizontal=1 }
        end
    
    	local metaPresetItems = lightroom:getMetaPresetItems( app:getPref( 'metaPresetSubstring', props.pluginManagerPreset ) )
    	metaPresetItems[#metaPresetItems + 1] = { separator=true }
    	metaPresetItems[#metaPresetItems + 1] = { title="None", value=nil }
    	
    	-- Note: call.context is cleaned up when call returns, so can't be used for aux-properties.
    	-- Although I'm not real crazy about using export settings as scratch pad, I dunno how else to do it a.t.m.
    	-- Maybe they're not saved if not declared - hmm..: that would be cool (I should check ###2).
    	local pluginManagerPresetPopup = app.prefMgr:makePresetPopup {
            call = nil,
            sort = true,
            props = props, -- would prefer aux-props here, but dunno how to finagle it.
            valueBindTo = props,	        -- object: export settings..
            valueKey = 'pluginManagerPreset', -- ultimate target property name/key (export setting).
            viewOptions = {
                fill_horizontal = 1,
                tooltip = "\"advanced settings\" will be reloaded automatically before use, so no need to explicitly reload here, unless you just want to force-check syntax.",
            },
    	}
    
        space()
        local labelWidth = LrUUID.generateUUID() -- tired of widths tied to unrelated sections..
        
    	it[#it + 1] = vf:row {
    		vf:static_text{
    		    title = "Plugin Manager Preset: ",
    		    width = share( labelWidth ),
    		},
    		pluginManagerPresetPopup,
    	}
            
        space()
    	it[#it + 1] = vf:row {
    		vf:checkbox {
    		    title = "Log Verbose",
    		    bind_to_object = prefs,
    		    value = app:getGlobalPrefBinding( 'logVerbose' ),
    		    width = share( labelWidth ),
    		    tooltip = "Plugin-wide verbosity.",
    		},
    	    vf:push_button {
    	        title = "Show Logs",
    	        action = function()
    	            app:showLogFile()
    	        end,
    	        tooltip = "Open log file in default app for .log files.",
    	    },
    	    vf:push_button {
    	        title = "Clear Logs",
    	        action = function()
    	            app:clearLogFile()
    	        end,
    	        tooltip = "Clear logs by deleting log file.",
    	    },
    	}
        	
    	space()
    	sep()
    	space()
    	
    	it[#it + 1] = self:sectionForFilterInDialogGetStatusView() -- implemented in base class for consistency.
        	
        -- 'it' section has been built successfully.
        	
    end, finale=function( call )
        self:sectionForFilterInDialogFinale( call ) -- standard finale which closes ets (if open) and displays error box (if error).
    end }
    
	return it
	
end



function Main:endDialogMethod()
    -- reserved for future
end



function Main:shouldRenderPhotoMethod( photo )
    return true
end



--- Post process rendered photos (overrides base class).
--
--  @usage reminder: videos are not considered rendered photos (won't be seen by this method).
--
function Main:postProcessRenderedPhotosMethod()

    -- convenience variables, left as is for historical reasons.
    local functionContext, filterContext = self.functionContext, self.filterContext
    local exportSettings = filterContext.propertyTable
    assert( exportSettings == self.exportSettings, "export settings mismatch" )
    
    app:call( Service:new{ name=str:fmtx( "^1 - Post Process Rendered Photos", self.filterName ), preset=exportSettings.pluginManagerPreset, progress=true, main=function( call )
    
        assert( exportSettings, "no es" )

        -- this may be accademic at this point, but doesn't hurt:
        local presetNameSet = tab:createSet( app:getPresetNames() )
        if presetNameSet[exportSettings.pluginManagerPreset] then -- exists
            self:log( "Plugin manager preset exists: ^1", exportSettings.pluginManagerPreset ) -- if backing file did not exist, there would have been an error in service perform bootstrap.
        else
            self:logW( "Plugin manager preset does not exist: ^1", presetName )
            local s, m = self:cancelExport()
            if s then
                self:log( "Export canceled." )
            else
                self:logW( m )
            end
            return
        end

        local photos, videos, union, candidates, unionCache = self:initPhotos{ rawIds={ 'path', 'fileFormat' }, call=call } -- no fmt-ids.
        if not photos then
            return -- export was canceled - pertinent info logged..
        end
        
        -- this *is* the main filter, so no need to require it.
        -- but good opportunity to log filter list, so not repeated in other filters.
        
        -- note: first may not be 1, if another plugin has top spot.
        local filters, first, last, total = self:getFilters()
        assert( total > 0, "hmm..." )
        self:log()
        self:log( "^1 Export filters are from this plugin", total )
        self:log( "--------------------------------------" )
        for i = 1, last do
            local id = filters[i]
            if id then -- filter from this plugin
                self:log( "^1. ^2", i, id )
            else
                self:log( "^1. Filter from some other plugin", i )
            end
        end
        self:log()
        if first == 1 then
            self:log( "Top filter is from this plugin." )
        else
            self:log( "Top filter is from some other plugin." )
        end
        self:log( "There is no way to tell whether bottom filter is from this plugin, or whether there are filters from other plugins below." )
        self:log()
        
        local renditionOptions = {
            plugin = _PLUGIN, -- ###3 I have no idea what this does, or if it's better to set it or not (usually it's not set).
            --renditionsToSatisfy = renditions, -- filled in below.
            filterSettings = function( renditionToSatisfy, exportSettings )
                --assert( exportSettings, "no es" )
                -- reminder: you can't change 'LR_tokenCustomString' at this point - I guess export service needs it fixed since renditionToSatisfy filename is fixed.
                --local newPath = renditionToSatisfy.destinationPath -- by default return unmodified.
                self:log( "Rendition path: ^1", renditionToSatisfy.destinationPath ) -- shorcut - path will not be changed by this export filter.
                --local photo = renditionToSatisfy.photo
                return nil -- newPath
                
            end, -- end of rendition filter function
        } -- closing rendition options
        
        -- No need to pare down renditions
                
        -- Reminder: selective abortion beyond this point is hit n' miss, which is way renditions were paired down, if need be - granted Lr will still present the "skipped" ones in a box..

        for sourceRendition, renditionToSatisfy in filterContext:renditions( renditionOptions ) do
            repeat
                local srcPhoto = sourceRendition.photo
                if sourceRendition.wasSkipped then
                    Debug.pause( "Source rendition was skipped." )
                    self:log( "Source rendition was skipped." )
                    break
                end
                assert( srcPhoto == renditionToSatisfy.photo, "rendition photo mismatch" )
                -- reminder: skip-render when export in progress is problematic.
                local srcPhotoPath = unionCache:getRawMetadata( srcPhoto, 'path' )
                -- note: nothing special to do for videos here.
                local success, pathOrMessage = sourceRendition:waitForRender()
                if success then -- exported virtual copy or waited for upstream to render..
                    renditionToSatisfy:renditionIsDone( true ) -- control error message: keeps it from blaming the export filter for "failed" export.
                else -- problem exporting original, which in my case is due to something in metadata blocks that Lightroom does not like.
                    local errm = pathOrMessage or "?"
                    self:logW( "Unable to export '^1', error message: ^2. This may not cause a problem with this export, but may indicate a problem with this plugin, or with the source photo.", renditionToSatisfy.destinationPath, errm )
                        -- Note: if export is canceled, path-or-message can be nil despite success being false. ###3 - this may have been a flukey glitch - dunno.
                    renditionToSatisfy:renditionIsDone( false, errm.." - see log file for more info." )
                end
                
            until true
        end
    end, finale=function( call )
        self:postProcessRenderedPhotosFinale( call )
    end } )
end



function Main.startDialog( propertyTable )
    local filter = ExtendedExportFilter.assureFilter( Main, propertyTable )
    filter:startDialogMethod()
end



function Main:updateSynopsis()
    local props = self.exportSettings
    local syn
    if str:is( props.pluginManagerPreset ) then
        local nameSet = tab:createSet( app:getPresetNames() )
        if nameSet[props.pluginManagerPreset] then
            syn = props.pluginManagerPreset
        else
            syn = "*** Plugin Manager Preset is MISSING: "..props.pluginManagerPreset
        end
    else
        syn = "*** Plugin Manager Preset is BLANK"
    end
    if app:isVerbose() then
        syn = syn .. " (verbose)"
    end
    props[self.synopsisPropName] = syn
end



--- This function will create the section displayed on the export dialog 
--  when this filter is added to the export session.
--
function Main.sectionForFilterInDialog( vf, propertyTable )

    local filter = ExtendedExportFilter.assureFilter( Main, propertyTable )
    return filter:sectionForFilterInDialogMethod() -- vf? ###2 (I have outstanding question, but probably won't get answered - users dont know, and Adobe wont be bothered..).

end


-- reminder: update status filter function need not be implemented, as long as ID passed to listener reg func is this class.
--[[
function Main.updateFilterStatus( id, props, name, value )
    local filter = ExtendedExportFilter.assureFilter( Main, props )
    filter:updateFilterStatusMethod( name, value )
end
--]]



function Main.endDialog( propertyTable)
    local filter = ExtendedExportFilter.assureFilter( Main, propertyTable )
    filter:endDialogMethod()
end



--- This function obtains access to the photos and removes entries that don't match the metadata filter.
--
--  @usage called *before* post-process-rendered-photos function (no cached metadata).
--  @usage base class has no say (need not be called).
--
function Main.shouldRenderPhoto( exportSettings, photo )
    local filter = ExtendedExportFilter.assureFilter( Main, exportSettings )
    return filter:shouldRenderPhotoMethod( photo )
end



--- Post process rendered photos.
--
function Main.postProcessRenderedPhotos( functionContext, filterContext )

    local filter = ExtendedExportFilter.assureFilter( Main, filterContext.propertyTable, { functionContext=functionContext, filterContext=filterContext } )
    assert( filter.filterContext, "no filter context" )
    filter:postProcessRenderedPhotosMethod()

end



Main.exportPresetFields = {
	{ key = 'pluginManagerPreset', default = "Default" },
	--{ key = 'logVerbose', default = false },
}



Main:inherit( ExtendedExportFilter ) -- inherit *non-overridden* members.



return Main
