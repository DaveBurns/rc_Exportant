--[[
        ExiftoolSession.lua
--]]


local ExiftoolSession, dbg, dbgf = ExtendedExportFilter:newClass{ className='ExiftoolSession', register=true }



--- Constructor for extending class.
--
function ExiftoolSession:newClass( t )
    return ExtendedExportFilter.newClass( self, t )
end



--- Constructor for new instance.
--
function ExiftoolSession:new( t )
    local o = ExtendedExportFilter.new( self, t )
    o.enablePropName = 'exifSession'
    return o
end



--- This function will check the status of the Export Dialog to determine 
--  if all required fields have been populated.
--
function ExiftoolSession:updateFilterStatusMethod( name, value )

    local props = self.exportSettings

    app:call( Call:new{ name=str:fmtx( "^1 - Update Filter Status", self.filterName ), async=true, guard=App.guardSilent, main=function( context )

        -- base class method no longer of concern once overridden in extended class.
        
        repeat -- once
        
            if not props.exifSession then
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
            
            if props.exifSession then
                local usable, qual = exifTool:isUsable()
                if usable then
                    -- great
                else
                    self:denyExport( "*** Exiftool unusable (^1) - consider fixing configuration via advanced settings, or disable exif-tool session.", qual )
                end
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
function ExiftoolSession:startDialogMethod()

    local props = self.exportSettings
    
	view:setObserver( props, 'pluginManagerPreset', ExiftoolSession, ExiftoolSession.updateFilterStatus )
	
	view:setObserver( props, 'exifSession', ExiftoolSession, ExiftoolSession.updateFilterStatus )
	view:setObserver( props, 'originalRez', ExiftoolSession, ExiftoolSession.updateFilterStatus )
	view:setObserver( props, 'copySrcMeta', ExiftoolSession, ExiftoolSession.updateFilterStatus )
	view:setObserver( props, 'minTagDup', ExiftoolSession, ExiftoolSession.updateFilterStatus )
	view:setObserver( props, 'inclMakerNotes', ExiftoolSession, ExiftoolSession.updateFilterStatus )
	view:setObserver( props, 'inclOrient', ExiftoolSession, ExiftoolSession.updateFilterStatus )
	view:setObserver( props, 'omitThumbs', ExiftoolSession, ExiftoolSession.updateFilterStatus )
	view:setObserver( props, 'addlParams', ExiftoolSession, ExiftoolSession.updateFilterStatus )
	
	view:setObserver( props, 'LR_exportFiltersFromThisPlugin', ExiftoolSession, ExiftoolSession.updateFilterStatus )

	self:updateFilterStatusMethod() -- async/guarded.

end




--- This function will create the section displayed on the export dialog 
--  when this filter is added to the export session.
--
function ExiftoolSession:sectionForFilterInDialogMethod()

    -- there are no sections defined in base class.
    
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
			value = bind 'exifSession',
			width = share 'ets_ena_width',
			tooltip = "if checked, exiftool session will be available for custom folder/file-naming, and other custom functions. Of course it is also needed by the other (built-in standard) functions in this section."
		},
	}
	it[#it + 1] = vf:row {
		vf:spacer { width = share( labelWidth ) },
		vf:separator { width = share 'ets_ena_width' },
	}
	space( 7 )
	it[#it + 1] = vf:row {
		vf:checkbox {
		    title = "Maintain Original Resolution",
			value = bind 'originalRez',
			enabled = bind 'exifSession',
			width = share( labelWidth ),
			tooltip = "if checked, 'Resolution' from exif metadata will prevail over 'Resolution' set in 'Image Sizing' section above. - note: 'Resolution' is 'pixels per inch/cm', for printing...",
		},
		vf:static_text {
		    title = "Export (print) resolution to be same as original source photo.",
			enabled = bind 'exifSession',
		}
	}

	space( 5 )
	
	it[#it + 1] = vf:row {
		vf:checkbox {
			title = "Copy Source Metadata",
			value = bind 'copySrcMeta',
			width = share( labelWidth ),
			enabled = bind 'exifSession',
			tooltip = "Check this box to have maker notes and other metadata transferred from source photo to exported file. Initial motivation was for applying DxO's profile-based lens corrections (typically to a tiff), processing in DxO to a file (typically jpeg) which is imported in Lightroom, but the DxOh plugin will probably be a better bet if such is your aim..",
		},
		vf:static_text {
			title = "e.g. for applying DxO lens corrections (be sure not to double-\napply the same corrections in Lr && DxO.",
			enabled = bind 'exifSession',
		},
	}

	it[#it + 1] = vf:row {
		vf:checkbox {
			title = "Minimize Tag Duplication",
			value = bind 'minTagDup',
			width = share( labelWidth ),
			enabled = LrBinding.andAllKeys( 'exifSession', 'copySrcMeta' ),
			tooltip = "If unchecked, there will be some tag duplication, e.g. original exif tags will be replicated in xmp (this usually doesn't hurt anything, and occasionally helps, but may make the exported files bigger than they need to be); if checked, tags are only copied to their \"preferred\" location, and not all possible locations.",
		},
		vf:static_text {
			title = "Copy source metadata, without duplicating tags to all possible\nlocations..",
			enabled = LrBinding.andAllKeys( 'exifSession', 'copySrcMeta' ),
		},
	}

	it[#it + 1] = vf:row {
		vf:checkbox {
			title = "Include Maker Notes",
			value = bind 'inclMakerNotes',
			width = share( labelWidth ),
			enabled = LrBinding.andAllKeys( 'exifSession', 'copySrcMeta' ),
			tooltip = "Sometimes it helps if maker-notes are explicitly copied too.",
		},
		vf:static_text {
			title = "Copy source metadata, explicitly including maker notes.",
			enabled = LrBinding.andAllKeys( 'exifSession', 'copySrcMeta' ),
		},
	}

	it[#it + 1] = vf:row {
		vf:checkbox {
			title = "Include Orientation",
			value = bind 'inclOrient',
			width = share( labelWidth ),
			enabled = LrBinding.andAllKeys( 'exifSession', 'copySrcMeta' ),
			tooltip = "Most often, image data itself will be oriented upon export, and so inclusion of orientation metadata from source photo would \"over-orient\", thus I anticipate this being \"disabled\" (unchecked) in most cases.\n \n*** If not oriented correctly, try toggling this..",
		},
		vf:static_text {
			title = "Include source photo orientation metadata too.",
			enabled = LrBinding.andAllKeys( 'exifSession', 'copySrcMeta' ),
		},
	}

    space( 2 )
    
	it[#it + 1] = vf:row {
		vf:checkbox {
			title = "Omit Thumbnails",
			value = bind 'omitThumbs',
			width = share( labelWidth ),
			enabled = LrBinding.andAllKeys( 'exifSession' ),
			tooltip = "Sometimes it helps if maker-notes are explicitly copied too.",
		},
		vf:static_text {
			title = "Delete all embedded thumbnail jpegs, to make file smaller.",
			enabled = LrBinding.andAllKeys( 'exifSession' ),
		},
	}

    space( 2 )
    
    local delim = app:getPref( 'exifToolParamSep' ) or "|"
	it[#it + 1] = vf:row {
		vf:static_text {
			title = "Additional Parameters",
			width = share( labelWidth ),
			enabled = LrBinding.andAllKeys( 'exifSession' ),
		},
		vf:edit_field {
			value = bind 'addlParams',
			width_in_chars = WIN_ENV and 40 or 35,
			enabled = LrBinding.andAllKeys( 'exifSession' ),
			tooltip = str:fmtx( "*** Important: these parameters are for an exiftool *session*, NOT exiftool proper (see web doc for more info).\n \nFormat: '-param1=Value One ^1 -param2=Value2 ^1 -param3= ^1 -param4' (omit the single-quotes).\n \n*** To be clear:\n1. Do NOT include double-quotes to delimit values with spaces.\n2. DO separate parameters with the '^1' character (spaces around it are optional, and will be ignored).\n3. If parameter has an extra part, it must be an extra parameter, e.g. '-tagsFromFile ^1 /path/to/file' NOT '-tagsFromFile /path/to/file'\n \nTo specifiy a custom separator, edit advanced settings.", delim ),
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
function ExiftoolSession:shouldRenderPhotoMethod( photo )

    --assert( exportSettings, "no es" )

    --Debug.lognpp( exportSettings )
    --Debug.showLogFile()
    
    --local fileFormat = photo:getRawMetadata( 'fileFormat' )
    
    _G.createExifToolSession = self.exportSettings.exifSession -- make sure ets "memo" is in the "inbox" of all other filters when their
    -- post-process-rendered-photos method is first called, regardless of filter order.

    return true -- it's not up to this export filter to decide not to export, it's up to custom-export-check function, if implemented.

end



--- Post process rendered photos (overrides base class).
--
--  @usage reminder: videos are not considered rendered photos (won't be seen by this method).
--
function ExiftoolSession:postProcessRenderedPhotosMethod()

    local functionContext, filterContext = self.functionContext, self.filterContext
    local exportSettings = filterContext.propertyTable
    assert( exportSettings == self.exportSettings, "?" )

    app:call( Service:new{ name=str:fmtx( "^1 - Post Process Rendered Photos", self.filterName ), preset=exportSettings.pluginManagerPreset, progress=true, main=function( call ) -- note: synchronous.
    
        assert( exportSettings, "no es" )
        
        if exportSettings.exifSession then
            self:log( "Filter is enabled." )
        else
            self:log( "Filter is disabled, so it won't do anything." )
            self:passRenditionsThrough()
            return
        end

        local photos, videos, union, candidates, unionCache = self:initPhotos{ rawIds={ 'fileFormat', 'isVirtualCopy' }, call=call }
        if not photos then
            return
        end
        
        local status = self:requireMainFilterInPost()
        if not status then
            return
        end
        
        assert( exportSettings.exifSession, "ets ena should be pre-checked" )
        
        assert( gbl:getValue( 'createExifToolSession' ) ~= nil and createExifToolSession == exportSettings.exifSession, "ets not init or mismatch" )
        call.ets = exifTool:openSession( self.filterName.."_"..LrUUID.generateUUID() ) -- tosses error or returns nil?
        if not call.ets then
            error( "Unable to open exiftool session." ) -- to be safe.
        end
    
        local renditionOptions = {
            plugin = _PLUGIN, -- ###3 I have no idea what this does, or if it's better to set it or not (usually it's not set).
            --renditionsToSatisfy = renditions, -- filled in below.
            filterSettings = function( renditionToSatisfy, exportSettings )
                assert( exportSettings, "no es" )
                
                -- reminder: you can't change 'LR_tokenCustomString' at this point - I guess export service needs it fixed since renditionToSatisfy filename is fixed.
                local photo = renditionToSatisfy.photo
                
                local newPath = renditionToSatisfy.destinationPath -- by default return unmodified.
                self:log( "Rendition path: ^1", newPath )
                
                local isVideo = ( unionCache:getRawMetadata( photo, 'fileFormat' ) == 'VIDEO' )
                -- local isVirtualCopy = unionCache:getRawMetadata( photo, 'isVirtualCopy' )
                
                if exportSettings.originalRez and not isVideo then -- and not isVirtualCopy then - should take rez from master if virtual.
                    assert( call.ets, "no ets" )
                    local rez
                    local path = renditionToSatisfy.photo:getRawMetadata( 'path' )
                    if fso:existsAsFile( path ) then
                        call.ets:addArg( "-xresolution" )
                        call.ets:addTarget( path )
                        local rslt, qual = call.ets:execute()
                        local x, y
                        if not str:is( qual) then
                            if str:is( rslt ) then
                                x = exifTool:getValueFromPairS( rslt )
                            else
                                self:logW( "No x-rez" )
                            end
                        else
                            self:logW( "Error getting x-rez - ^1", qual )
                        end
                        call.ets:addArg( "-yresolution" )
                        call.ets:addTarget( path )
                        local rslt, qual = call.ets:execute()
                        --s, m, c = exifTool:executeCommand( "-xresolution", { path }, nil, 'del' )
                        if not str:is( qual ) then
                            if str:is( rslt ) then
                                y = exifTool:getValueFromPairS( rslt )
                            else
                                self:logW( "No y-rez" )
                            end
                        else
                            self:logW( "Error getting y-rez - ^1", m )
                        end
                        local xrez = num:numberFromString( x ) -- handles nil OK.
                        local yrez = num:numberFromString( y )
                        if xrez and yrez then
                            if xrez == yrez then
                                rez = xrez
                                self:logV( "Got x-rez and y-rez (same): ^1", rez )
                            elseif xrez > yrez then
                                rez = xrez
                                self:logV( "x-rez bigger than y-rez (^1), using x: ^1", yrez, rez )
                            else
                                rez = yrez
                                self:logV( "y-rez bigger than x-rez (^1), using y: ^1", xrez, rez )
                            end
                        elseif xrez then
                            rez = xrez
                            self:logV( "Using x-rez: ^1", rez )
                        elseif yrez then
                            rez = yrez
                            self:logV( "Using y-rez: ^1", rez )
                        else
                            self:logW( "No rez in exif - so not changing export setting, which is: ^1", exportSettings.LR_size_resolution )
                        end
                        if rez then
                            if exportSettings.LR_size_resolution ~= rez then
                                self:log( "Changing size resolution from ^1 to ^2", exportSettings.LR_size_resolution, rez )
                                exportSettings.LR_size_resolution = rez
                            else
                                self:log( "Original size resolution is same - no change: ^1", rez )
                            end
                        else
                            -- already logged.                
                        end
                    else
                        self:logW( "Photo is missing." )
                    end
                end
                
                return newPath
                
            end, -- end of rendition filter function
        } -- closing rendition options
        

        local renditions
        renditions = candidates
        renditionOptions.renditionsToSatisfy = renditions
        
        -- Reminder: selective abortion beyond this point is hit n' miss, which is way renditions were paired down, if need be - granted Lr will still present the "skipped" ones in a box..
        
        local delim = app:getPref( 'exifToolParamSep' ) or "|"

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
                if unionCache:getRawMetadata( srcPhoto, 'fileFormat' ) == 'VIDEO' then
                    self:log( "Source video rendition passed through." )
                    renditionToSatisfy:renditionIsDone( true ) -- tested: this works! ###2 - hmm... - before waiting for render even.
                    break
                end
                -- fall-through => photo - not video, rendition not skipped.
                local isVirtualCopy = unionCache:getRawMetadata( srcPhoto, 'isVirtualCopy' )
                local success, pathOrMessage = sourceRendition:waitForRender()
                if success then -- exported virtual copy or waited for upstream to render..
                    self:logV()
                    self:logV( "Source photo '^1' was rendered to '^2'", srcPhotoPath, pathOrMessage ) -- reminder: could be misnomer - "source photo" could have been extracted preview..
                    if not call.ets then
                        self:logV( "No exiftool session - just gonna forward the rendition to downstream entity.." )
                        renditionToSatisfy:renditionIsDone( true )
                        break
                    end
                    -- reminder: original rez is handled as rendition option (above), not exiftooling of exported file (here).
                    local etsFlag = exportSettings.copySrcMeta or exportSettings.omitThumbs or str:is( exportSettings.addlParams )
                    if not etsFlag then
                        self:logV( "No options require exiftooling exported file - just gonna forward the rendition to downstream entity.." )
                        renditionToSatisfy:renditionIsDone( true )
                        break
                    end
                    call.ets:addArg( "-overwrite_original" )
                    if exportSettings.copySrcMeta then
                        if fso:existsAsFile( srcPhotoPath ) then -- there is really a source photo file from which to get original metadata.
                            self:logV( "Metadata from source file is being transferred to exported file." )
                            call.ets:addArg( "-tagsFromFile" )
                            call.ets:addArg( str:fmtx( '^1', srcPhotoPath ) )
                            if exportSettings.inclMakerNotes then
                                self:logV( "Metadata are being explicitly included." )
                                call.ets:addArg( "-makernotes" )
                            end
                            if exportSettings.minTagDup then
                                self:logV( "Tag duplication is being minimized." )
                                call.ets:addArg( "-all:all" )
                            else
                                self:logV( "Tag duplication as exiftool sees fit.." )
                                call.ets:addArg( "-all:all>all:all" )
                            end
                        else
                            local sp = cat:isSmartPreview( srcPhoto ) -- not in cache.
                            if sp then
                                app:logW( "Source photo file is missing, but smart preview is not, anyway - no way to transfer exif metadata from source file." )
                            else
                                app:logW( "Source photo file is missing, and there is no smart preview is not, anyway - no way to transfer exif metadata from source file." )
                            end
                            renditionToSatisfy:renditionIsDone( false, "Unable to copy metadata from source file.. - see warning in log file for more info." )
                            break
                        end
                    end
                    if exportSettings.omitThumbs then
                        self:logV( "Thumbnails are being eliminated." )
                        call.ets:addArg( "-IFD1:all=" ) -- jpeg-tran app could also be used for this, but not wired up..
                        call.ets:addArg( "-Photoshop:PhotoshopThumbnail=" ) -- ditto
                    end
                    if not exportSettings.inclOrient then
                        self:logV( "Orientation metadata is being explicitly excluded." )
                        call.ets:addArg( "-Orientation=" ) -- this was working as addl-param, which is why it's being put here instead of above (I think it needs to follow the all-this's and all-thats..).
                    else
                        app:logV( "Orientation metadata is being included too - if not oriented correctly, try disabling orientation inclusion." )
                    end
                    if str:is( exportSettings.addlParams ) then
                        local comps = str:split( exportSettings.addlParams, delim )
                        for i, comp in ipairs( comps ) do
                            self:logV( "Adding parameter to exiftool *session*: ^1", comp )
                            call.ets:addArg( comp )
                        end
                    end
                    call.ets:addTarget( pathOrMessage )
                    local s, m = call.ets:execWrite() -- checks rslt for strings which get output by exiftool, indicating success / failure.
                    if s then
                        self:log( "Updated metadata of exported file using exiftool (session)." )
                        renditionToSatisfy:renditionIsDone( true )
                        break
                    else -- assumption is: if user had this option selected, then he/she was depending on it - so if not happening, export is considered failed.
                        self:logW( "Unable to execute exiftool session - ^1", m )
                        renditionToSatisfy:renditionIsDone( false, m.." - see warning in log file for more info." )
                        break
                    end
                    
                    error( "never comes here" )
                    
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



function ExiftoolSession.startDialog( props )
    local filter = ExtendedExportFilter.assureFilter( ExiftoolSession, props )
    filter:startDialogMethod()
end



function ExiftoolSession.sectionForFilterInDialog( vf, props )
    local filter = ExtendedExportFilter.assureFilter( ExiftoolSession, props )
    return filter:sectionForFilterInDialogMethod()
end



-- reminder: update status filter function need not be implemented, as long as ID passed to listener reg func is this class.
--[[
function ExiftoolSession.updateFilterStatus( id, props, name, value )
    local filter = ExtendedExportFilter.assureFilter( ExiftoolSession, props )
    filter:updateFilterStatusMethod( name, value )
end
--]]



function ExiftoolSession.shouldRenderPhoto( exportSettings, photo )
    local filter = ExtendedExportFilter.assureFilter( ExiftoolSession, exportSettings )
    return filter:shouldRenderPhotoMethod( photo )
end



--- Post process rendered photos.
--
function ExiftoolSession.postProcessRenderedPhotos( functionContext, filterContext )
    local filter = ExtendedExportFilter.assureFilter( ExiftoolSession, filterContext.propertyTable, { functionContext=functionContext, filterContext=filterContext } )
    filter:postProcessRenderedPhotosMethod()
end



ExiftoolSession.exportPresetFields = {
    { key = 'exifSession', default = false }, -- so we know whether to check for _Exportant_ as filenaming token.
	{ key = 'originalRez', default = false }, -- maintain exif resolution.
	{ key = 'copySrcMeta', default = false },
	{ key = 'inclOrient', default = false }, -- copy over source orientation metadata too? (usually better not to, since orientation is typically baked into the image data, including in metadata too over-orients. Exception would be if format is "original" - probably could hard-code, but I may have mis-evaluated).
	{ key = 'minTagDup', default=false },
	{ key = 'inclMakerNotes', default=false },
	{ key = 'addlParams', default="" },
	{ key = 'omitThumbs', default=false },
}



ExiftoolSession:inherit( ExtendedExportFilter ) -- inherit *non-overridden* members.


return ExiftoolSession
