--[[
        ExportAsVirtualCopy.lua
--]]


local ExportAsVirtualCopy, dbg, dbgf = ExtendedExportFilter:newClass{ className='ExportAsVirtualCopy', register=true }



local dialogEnding



--- Constructor for extending class.
--
function ExportAsVirtualCopy:newClass( t )
    return ExtendedExportFilter.newClass( self, t )
end



--- Constructor for new instance.
--
function ExportAsVirtualCopy:new( t )
    local o = ExtendedExportFilter.new( self, t )
    o.enablePropName = 'expVirtualCopy'
    return o
end



--- This function will check the status of the Export Dialog to determine 
--  if all required fields have been populated.
--
function ExportAsVirtualCopy:updateFilterStatusMethod( name, value )

    local props = self.exportSettings

    app:call( Call:new{ name=str:fmtx( "^1 - Update Filter Status", self.filterName ), async=true, guard=App.guardSilent, main=function( context )

        -- base class method no longer of concern once overridden in extended class.

        repeat -- once
        
            if not props.expVirtualCopy then
                self:allowExport( "^1 is disabled.", self.filterName )
                break
            else
                app:assurePrefSupportFile( props.pluginManagerPreset )
                self:allowExport()
            end
            
        	-- Process changes to named properties.
        	
        	if name ~= nil then
        	
                if name == '' then
                elseif name == 'pluginManagerPreset' then
                    self:updatePluginPresetDependentItems()
                end
        	    
            end

            -- process stuff not tied to change necessarily.

            if props.expVirtualCopy then
                if props.LR_collisionHandling == 'overwrite' then
                    if not dialogEnding then
                        local filters, first, last, total, names = self:getFilters()
                        if filters[1] == self.id then
                            self:log( "'^1' is top filter - good (it must be above *all* others).", self.filterName )
                        else
                            self:logV( "This filter must be at top, but '^1' is (note: it must be above *all* others). Either disable it, or raise it up.", names[1] )
                            self:denyExport( "'^1' must be top filter (note: it must be above *all* others). Either disable it, or raise it up.", self.filterName, names[1] )
                        end
                    end
                else
                    if str:is( props.LR_publish_connectionName ) then -- publish services do not expose overwrite option.
                        props.LR_collisionHandling = 'overwrite' -- to maximize odds for success elsewhere.
                    else -- ask first.
                        if dia:isOk( "Collision handling must be set to 'Overwrite WITHOUT WARNING' in 'Export Location' section. Want me to go ahead and set that for you, if so, then click 'OK', (or would you prefer to do it yourself? - if so, then click 'Cancel'). Note: if 'Export Location' section is not accessible, you'll have to let this plugin do it, if that's OK. If not OK, then you'll have to uncheck '^1'.", self.filterName ) then
                            props.LR_collisionHandling = 'overwrite'
                        else
                            self:denyExport( "Collision handling must be set to 'Overwrite WITHOUT WARNING' in 'Export Location' section, or uncheck '^1'.", self.filterName )
                            break
                        end
                    end
                end
            -- else ..
            end
            
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
function ExportAsVirtualCopy:startDialogMethod()

    local props = self.exportSettings
       
	view:setObserver( props, 'pluginManagerPreset', ExportAsVirtualCopy, ExportAsVirtualCopy.updateFilterStatus )
	
	view:setObserver( props, 'relDevPreset', ExportAsVirtualCopy, ExportAsVirtualCopy.updateFilterStatus )
	view:setObserver( props, 'metaPreset', ExportAsVirtualCopy, ExportAsVirtualCopy.updateFilterStatus )
	view:setObserver( props, 'saveXmp', ExportAsVirtualCopy, ExportAsVirtualCopy.updateFilterStatus )
	view:setObserver( props, 'snapEna', ExportAsVirtualCopy, ExportAsVirtualCopy.updateFilterStatus )
	view:setObserver( props, 'snapFmt', ExportAsVirtualCopy, ExportAsVirtualCopy.updateFilterStatus )
	view:setObserver( props, 'expVirtualCopy', ExportAsVirtualCopy, ExportAsVirtualCopy.updateFilterStatus )
	view:setObserver( props, 'expCopyName', ExportAsVirtualCopy, ExportAsVirtualCopy.updateFilterStatus )

	view:setObserver( props, 'LR_exportFiltersFromThisPlugin', ExportAsVirtualCopy, ExportAsVirtualCopy.updateFilterStatus )
	
	self:updateFilterStatusMethod() -- async/guarded.

end



function ExportAsVirtualCopy:updatePluginPresetDependentItems()
    local props = self.exportSettings
	local devPresetItems = lightroom:getDevPresetItems( app:getPref( 'devPresetFolderSubstring', props.pluginManagerPreset ) )
	devPresetItems[#devPresetItems + 1] = { separator=true }
	devPresetItems[#devPresetItems + 1] = { title="None", value=nil }
	props.devPresetItems = devPresetItems
	local metaPresetItems = lightroom:getMetaPresetItems( app:getPref( 'metaPresetSubstring', props.pluginManagerPreset ) )
	metaPresetItems[#metaPresetItems + 1] = { separator=true }
	metaPresetItems[#metaPresetItems + 1] = { title="None", value=nil }
	props.metaPresetItems = metaPresetItems
end



--- This function will create the section displayed on the export dialog 
--  when this filter is added to the export session.
--
function ExportAsVirtualCopy:sectionForFilterInDialogMethod()

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

    self:updatePluginPresetDependentItems()

    space()
    local labelWidth = LrUUID.generateUUID() -- tired of widths tied to unrelated sections..
   
	it[#it + 1] = vf:row {
	    vf:spacer{ width = share( labelWidth ) },
	    vf:checkbox {
	        title = self.title,
	        value = bind 'expVirtualCopy',
			width = share 'eavc_ena_width',
			tooltip = "Check box to create virtual copy and export that instead of original - useful for applying relative develop preset, metadata preset, or for copy-name based export file-naming.",
	    },
	}
	it[#it + 1] = vf:row {
		vf:spacer { width = share( labelWidth ) },
		vf:separator { width = share 'eavc_ena_width' },
	}
	space( 7 )
	it[#it + 1] = vf:row {
	    vf:static_text {
	        title = "Exported Copy Name",
			width = share( labelWidth ),
			enabled = bind 'expVirtualCopy',
	    },
		vf:edit_field {
			value = bind 'expCopyName',
			enabled = bind 'expVirtualCopy',
			width_in_chars = 35,
			tooltip = "Copy name when exporting as virtual copy. Note: it's a temporary copy, so name doesn't much matter - it just distinguishes copies created for exporting (hands off) vs. yours that you edit...",
		},
	}
	it[#it + 1] = vf:spacer{ height=7 }
	it[#it + 1] = 
		vf:row {
		    vf:column {
  				width = share( labelWidth ),
    		    vf:static_text {
    		        title = "Develop Preset",
    				enabled = bind 'expVirtualCopy',
    		    },
    		    vf:checkbox {
    		        title = "Apply Absolutely",
    		        value = bind 'devPresetAbs',   
    		        tooltip = "If checked, preset will applied absolutely (just as it would be in Lr proper); if unchecked, it will be applied relatively - i.e. numeric values in preset will be added to (or subtracted from) existing settings.",
    				enabled = bind 'expVirtualCopy',
    		    },
    		},
			vf:popup_menu {
				value = bind 'relDevPreset',
				enabled = bind 'expVirtualCopy',
				items = bind 'devPresetItems',
				width_in_chars = WIN_ENV and 37 or 32,
				tooltip = "Develop preset to apply to virtual copy prior to exporting it, when exporting as virtual copy.",
			},
		}
	it[#it + 1] = 
		vf:row {
		    vf:static_text {
		        title = "Metadata Preset",
				width = share( labelWidth ),
				enabled = bind 'expVirtualCopy',
		    },
			vf:popup_menu {
				value = bind 'metaPreset',
				enabled = bind 'expVirtualCopy',
				items = bind 'metaPresetItems',
				width_in_chars = WIN_ENV and 37 or 32,
				tooltip = "Metadata preset to apply to virtual copy prior to exporting it, when exporting as virtual copy.",
			},
		}
		
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
function ExportAsVirtualCopy:shouldRenderPhotoMethod( photo )

    local exportSettings = self.exportSettings
    --assert( exportSettings, "no es" )

    --Debug.lognpp( exportSettings )
    --Debug.showLogFile()
    
    --local fileFormat = photo:getRawMetadata( 'fileFormat' )
    
    return true -- it's not up to this export filter to decide not to export, it's up to custom-export-check function, if implemented.

end



--- Post process rendered photos (overrides base class).
--
--  @usage reminder: videos are not considered rendered photos (won't be seen by this method).
--
function ExportAsVirtualCopy:postProcessRenderedPhotosMethod()

    local functionContext, filterContext = self.functionContext, self.filterContext
    local exportSettings = filterContext.propertyTable
   
    app:call( Service:new{ name=str:fmtx( "^1 - Post Process Rendered Photos", self.filterName ), preset=exportSettings.pluginManagerPreset, progress=true, main=function( call )

        assert( exportSettings, "no es" )
        
        if exportSettings.expVirtualCopy then
            self:log( "Filter is enabled." )
        else
            self:log( "Filter is disabled, so it won't do anything." )
            self:passRenditionsThrough() -- photos and/or video.
            return
        end
        
        local virtualCopies
        local virtualCopyLookup
        local pathFromVirtualCopy

        local photos, videos, union, candidates, unionCache = self:initPhotos{ rawIds={ 'fileFormat' }, call=call }
        if not photos then
            return
        end
        
        local status = self:requireMainFilterInPost()
        if not status then
            return
        end
        
        local filters, first, last, total, names = self:getFilters()
        if filters[1] == self.id  then
            self:log( "'^1' is top filter - good (it must be above *all* others).", self.filterName )
        else
            if #photos > 0 then
                self:logW( "This filter must be top, but it's not - '^1' is (note: it must be above *all* others). Either disable it, or raise it up.", names[1] )
                local s, m = self:cancelExport() -- this used to be a pass-renditions-through( errm ) call here, but it seems @11/Nov/2013 4:26, that as long as export hasn't progressed too far,
                    -- e.g. there has been no prompt via this filter, then canceling it would be preferred to waiting for all renditions and then failing them.
                if s then
                    self:log( "Export canceled." )
                else
                    self:logW( m )
                end
            else
                self:logV( "Video only (no photos exported) - passing video renditions through.." )
                -- self:passRenditionsThrough( str:fmtx( "^1 must be top filter, but it's not.", self.id ) ) - no reason to fail videos.
                self:passRenditionsThrough() -- send videos downstream without trippin'.
            end
            return
        end
        
        virtualCopies = {}
        virtualCopyLookup = {}
        pathFromVirtualCopy = {}
        
            --[[
            --  @param params (table) elements:
            --      <br>photos (array, default = selectedPhotos) of LrPhoto's.
            --      <br>copyName (string, default = "Virtual Copy" if Lr5, else "Copy N").
            --      <br>call (Call, required) call with context.
            --      <br>assumeGridView (boolean, default = false )
            --      <br>cache (LrMetadataCache, default = nil ) cache for base photo metadata.
            --      <br>verify (boolean, default = true ) set false to subvert copy verification.
            --
            --  @return copies (array of LrPhoto) iff success.
            --  @return errMsg (string) non-empty iff unsuccessful.
            --]]

        local devPreset
        if str:is( exportSettings.relDevPreset ) then
            devPreset = LrApplication.developPresetByUuid( exportSettings.relDevPreset )
            if devPreset then
                self:logV( "Got dev preset: ^1", devPreset:getName() )
            else
                self:logE( "No dev preset" )
                local s, m = self:cancelExport()
                if s then
                    self:log( "Export canceled." )
                else
                    self:logW( m )
                end
                return
            end
        end

        -- unionCache:addRawMetadata probably should finish this thought. ###2

        --Debug.pause( "Creating VC", #photos )
        for i, photo in ipairs( photos ) do
            local copies, errMsg = cat:createVirtualCopies {
                photos = { photo }, -- just one copy, to maintain association with source photo, but need this method to support copy-name.
                copyName = exportSettings.expCopyName,
                call = call,
                assumeGridView = i > 1,
                cache = unionCache, -- ###2 @12/Nov/2013 2:30, this probably does not have what's needed.
                verify = true,
            }
            if copies ~= nil and #copies == 1 then
                local copy = copies[1]
                virtualCopies[#virtualCopies + 1] = copy
                virtualCopyLookup[photo] = copy
            else
                self:logE( errMsg or "?" )
                -- We are not returning here, because the error may only affect one photo, and no reason to kill whole export over it.
            end
        end
        Debug.pauseIf( #virtualCopies < #photos, str:fmtx( "^1/^2 virtual copies created", #virtualCopies, #photos ) )
        if #virtualCopies > 0 then
            if devPreset or exportSettings.metaPreset then
                if devPreset then
                    if exportSettings.devPresetAbs then -- apply absolutely
                        -- note, I could use adj-recs for absolute preset too, but it seems like overkill (shouldn't be necessary).
                        local s, m = cat:update( 30, str:fmtx( "Apply preset '^1' (absolutely)", devPreset:getName() ), function( context, phase )
                            for i, p in ipairs( virtualCopies ) do
                                p:applyDevelopPreset( devPreset )
                            end
                        end )
                        if s then
                            self:log( "Develop preset applied (absolutely): ^1", devPreset:getName() )
                        else -- seems a tad severe, no? ###2 comment added 24/Mar/2014 22:12.
                            self:logE( "Unable to apply develop preset (absolutely): ^1", m )
                            local s, m = self:cancelExport()
                            if s then
                                self:log( "Export canceled." )
                            else
                                self:logW( m )
                            end
                            return
                        end
                    else
                        local adj = {} -- recs
                        local dps = devPreset:getSetting() -- singular.
                        for i, p in ipairs( virtualCopies ) do
                            local ments = {} 
                            local ds = p:getDevelopSettings()
                            for k, v in pairs( dps ) do
                                if type( v ) == 'number' then
                                    local rawValue = ds[k] + v
                                    local newValue = developSettings:constrainSetting( k, rawValue ) -- also returns friendly value.
                                    if newValue ~= ds[k] then
                                        ments[k] = newValue
                                    end
                                else
                                    self:logV( "Not (yet) handling non-numerics: ^1", k )
                                end
                            end
                            adj[#adj + 1] = { photo=p, settings=ments, title="Relative: "..devPreset:getName() }
                        end
                        --[[
                            --  @param params containing:<br>
                            --             adjustmentRecords (array) elements:<br>
                            --                 photo    <br>
                            --                 settings <br>
                            --                 title    <br>
                            --             undoTitle (string, default is computed).
                            --             caption (string, optional) scope caption.
                            --             preConstrained (boolean, default=false) if true, constraints will not be re-evaluated.<br>
                            --             metadataCache (boolean, default=false) if true, constraints will not be re-evaluated.<br>
                            --             call (Call, default=nil) if passed, caption & progress will be updated.<br>
                            --
                            --  @return status (boolean) t or f.
                            --  @return message (string) nil or error.
                        --]]
                        local s, m = developSettings:applyAdjustments { -- auto-wrapped in cat accessor.
                            adjustmentRecords = adj,
                            undoTitle = "Relative preset "..devPreset:getName(),
                            caption = "Applying develop preset...",
                            preConstrained = true,
                            metadataCache = nil, -- ###2 (which items?)
                            call = call,
                        }
                        if s then
                            self:log( "Develop preset applied (relatively): ^1", devPreset:getName() )
                        else -- seems a tad severe, no? ###2 comment added 24/Mar/2014 22:12.
                            self:logE( "Unable to apply develop preset (relatively): ^1", m )
                            local s, m = self:cancelExport()
                            if s then
                                self:log( "Export canceled." )
                            else
                                self:logW( m )
                            end
                            return
                        end
                    end
                -- else - say no mo'
                end
                if str:is( exportSettings.metaPreset ) then
                    local s, m = cat:update( 30, "Applying metadata preset", function( context, phase )
                        for i, p in ipairs( virtualCopies ) do
                            p:applyMetadataPreset( exportSettings.metaPreset ) -- doc doesn't say what happens if problem, or if anything's returned, but it does throw error if problem, e.g. with preset ID.
                        end
                    end )
                    if s then
                        self:log( "Metadata preset applied to all virtual copies (^1)", #virtualCopies )
                    else
                        self:logE( "Unable to apply metadata preset - ^1", m )
                        local s, m = self:cancelExport()
                        if s then
                            self:log( "Export canceled." )
                        else
                            self:logW( m )
                        end
                        return
                    end
                -- else dont.
                end
            end -- dev-preset or meta-preset
            
            for i, p in ipairs( photos ) do -- Only
                virtualCopyLookup[p] = virtualCopies[i] -- I'm not 100% sure @19/Oct/2013 3:11 that virtual copies created are guaranteed to be in same order as base photos.
                    -- thankfully, it won't matter, since lookup is only used to copy rendered virtual copy to destination - even if correspondence is wrong, they'll all get done.
            end
            -- Note: true settings table is at prop-tbl[<contents>], but when indexed, export property table uses meta-method to assure property comes from contents.
            -- So, when making a copy, the correct (true) table must be obtained, otherwise settings are absent (since index metamethod is not included in copied table).
            local _exportSettings = tab:copy( exportSettings['< contents >'] ) -- shallow copy - note: includes scratch pad and stuff (e.g. filter object references) - presumably Lr ignores stuff which ain't pertinent ###3.
            app:assert( str:is( _exportSettings.LR_publish_connectionName ) or ( _exportSettings.LR_collisionHandling == 'overwrite' ), "target must be overwritable" ) -- makes sure '<contents>' is still how it's implemented as well as double-checking for overwrite.
            _exportSettings.LR_exportFiltersFromThisPlugin = nil -- all export settings same except for destination, and no export filters (they're ignored anyway when exports are via on-the-fly session, still..).
            _exportSettings.LR_export_destinationType = 'specificFolder'
            _exportSettings.LR_export_destinationPathPrefix = LrPathUtils.child( LrPathUtils.getStandardFilePath( 'temp' ), self.id ) -- folder
            _exportSettings.LR_export_destinationPathSuffix = "" -- no subfolder.
            local s, m = fso:assureDir( _exportSettings.LR_export_destinationPathPrefix ) -- Lr will not auto-create destination in this situation for some reason.
                -- actually, Lr won't auto-create destination in any situation - it'll prompt for dir if native Lr-hosted export and dest dir not existing.
            if s then
                self:log( "Rendering virtual copies to '^1'", _exportSettings.LR_export_destinationPathPrefix )
            else
                self:logE( m )
                local s, m = self:cancelExport()
                if s then
                    self:log( "Export canceled." )
                else
                    self:logW( m )
                end
                return
            end
            local expSession = LrExportSession {
                photosToExport = virtualCopies,
                exportSettings = _exportSettings
            }
            assert( call.scope, "no scope" )
            for i, rendition in expSession:renditions{ progressScope=call.scope, stopIfCanceled=true } do -- start rendering on separate task implied.
                local s, pom = rendition:waitForRender()
                if s then
                    self:logV( "Virtual copy rendered to: ^1", pom )
                    pathFromVirtualCopy[rendition.photo] = pom
                else
                    self:logE( pom )
                end
            end
            if call:isQuit() then
                self:log( "Canceled" )
                return
            end
            if #virtualCopies > 0 then
                --[[
                    --  @param params<br>
                    --             call (Call, required) call or service...
                    --             photos (array, required) photos to delete
                    --             promptTidbit (string, default="Items") e.g. "Snapshot photos"
                    --             final (boolean, default=false) only applies if mac atm: means dialog box is to be the final box of the service.
                    --  @return status (boolean) true iff photos were deleted; false => not. Note: no qualifying message (check call to see if canceled).
                --]]
                self:log()
                for i, p in ipairs( virtualCopies ) do
                    self:log( "Temporary/extraneous virtual copy: ^1", cat:getPhotoNameDisp( p, false, nil ) ) -- cache? ###2
                end
                -- reminder: this is pre-rendition loop, so no photos have started rendering by Lr yet.
                local worked = cat:deletePhotos {
                    call = call,
                    photos = virtualCopies,
                    promptTidbit = "Temporary/extraneous virtual copies",
                    final = false,
                }
                if worked then
                    self:log( "Temporary/extraneous virtual copies were removed from catalog." )
                else
                    self:logW( "Temporary/extraneous virtual copies were NOT removed from catalog." )
                end
                self:log()
            end
            
        elseif #photos > 0 then
            app:error( "Unable to create virtual copies to export." ) -- errMsg already logged.
        elseif #videos > 0 then
            -- proceed 
        else -- this never happens, since pre-checked above.
            error( "how so?" )
        end
        
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
        
        local renditions
        renditions = candidates
        renditionOptions.renditionsToSatisfy = renditions
        
        -- Reminder: selective abortion beyond this point is hit n' miss, which is way renditions were paired down, if need be - granted Lr will still present the "skipped" ones in a box..

        for sourceRendition, renditionToSatisfy in filterContext:renditions( renditionOptions ) do
            repeat
                assert( exportSettings.expVirtualCopy, "evc ena should be pre-checked" )
                local srcPhoto = sourceRendition.photo
                if sourceRendition.wasSkipped then
                    Debug.pause( "Source rendition was skipped." )
                    self:log( "Source rendition was skipped." )
                    break
                end
                local srcPhotoPath = srcPhoto:getRawMetadata( 'path' )
                if unionCache:getRawMetadata( srcPhoto, 'fileFormat' ) == 'VIDEO' then
                    self:log( "Source video rendition passed through." )
                    renditionToSatisfy:renditionIsDone( true ) -- tested: this works!
                    break
                end
                -- fall-through => photo, not skipped.
                sourceRendition:skipRender() -- keep Lr from rendering (reminder: Exportant will be top of filter heap).
                local vc = virtualCopyLookup[srcPhoto]
                if vc == nil then
                    self:logV( "No virtual copy in lookup." ) -- should have been error logged if problem creating virtual copy, otherwise it'll be there, theoretically.
                    break
                end
                local srcFile = pathFromVirtualCopy[vc]
                if srcFile == nil then
                    self:logV( "No src-file corresponding to virtual copy." ) -- ditto.
                    break
                end
                if str:is( exportSettings.LR_publish_connectionName ) or ( exportSettings.LR_collisionHandling == 'overwrite' ) then
                    local eq = str:isEqualIgnoringCase( renditionToSatisfy.destinationPath, srcPhotoPath )
                    if eq then -- exp dest file is same as source photo file - not ok..
                        renditionToSatisfy:renditionIsDone( false, "This filter does not support overwriting source photo file: "..srcPhotoPath ) -- no need for additional W/E logging here.
                        break
                    end
                    local s, m = fso:moveFile( srcFile, renditionToSatisfy.destinationPath, true, true )
                    if s then
                        self:log( "Rendered virtual copy moved to final destination: ^1", renditionToSatisfy.destinationPath )
                        renditionToSatisfy:renditionIsDone( true )
                    else
                        self:logE( m )
                        break
                    end
                else
                    self:logE( "Collision handling not set to overwrite" )
                    break
                end
                                    
            until true
        end
    end, finale=function( call )
        self:postProcessRenderedPhotosFinale( call )
    end } )
end



function ExportAsVirtualCopy.startDialog( props )
    dialogEnding = false
    local filter = ExtendedExportFilter.assureFilter( ExportAsVirtualCopy, props )
    filter:startDialogMethod()
end



function ExportAsVirtualCopy.sectionForFilterInDialog( vf, props )
    local filter = ExtendedExportFilter.assureFilter( ExportAsVirtualCopy, props )
    return filter:sectionForFilterInDialogMethod()
end



function ExportAsVirtualCopy.endDialog()
    dialogEnding = true    
end



-- reminder: update status filter function need not be implemented, as long as ID passed to listener reg func is this class.
--[[
function ExportAsVirtualCopy.updateFilterStatus( id, props, name, value )
    local filter = ExtendedExportFilter.assureFilter( ExportAsVirtualCopy, props )
    filter:updateFilterStatusMethod( name, value )
end
--]]



function ExportAsVirtualCopy.shouldRenderPhoto( props, photo )
    local filter = ExtendedExportFilter.assureFilter( ExportAsVirtualCopy, props )
    return filter:shouldRenderPhotoMethod( photo )
end



--- Post process rendered photos.
--
function ExportAsVirtualCopy.postProcessRenderedPhotos( functionContext, filterContext )
    local filter = ExtendedExportFilter.assureFilter( ExportAsVirtualCopy, filterContext.propertyTable, { functionContext=functionContext, filterContext=filterContext } )
    filter:postProcessRenderedPhotosMethod()
end



ExportAsVirtualCopy.exportPresetFields = {
	
	{ key = 'expVirtualCopy', default = false },
	{ key = 'expCopyName', default = "Exported Copy" },
	{ key = 'relDevPreset', default = nil },  -- misnomer: may be relative (the default) or absolute (if specified).
	{ key = 'devPresetAbs', default = false },
	{ key = 'metaPreset', default = nil },
	
}



ExportAsVirtualCopy:inherit( ExtendedExportFilter ) -- inherit *non-overridden* members.



return ExportAsVirtualCopy
