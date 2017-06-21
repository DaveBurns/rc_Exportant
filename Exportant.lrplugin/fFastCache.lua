--[[
        FastCache.lua
--]]


local FastCache, dbg, dbgf = ExtendedExportFilter:newClass{ className='FastCache', register=true }



local dialogEnding



--- Constructor for extending class.
--
function FastCache:newClass( t )
    return ExtendedExportFilter.newClass( self, t )
end



--- Constructor for new instance.
--
function FastCache:new( t )
    local o = ExtendedExportFilter.new( self, t )
    o.enablePropName = 'fastCacheEna'
    return o
end



--- This function will check the status of the Export Dialog to determine 
--  if all required fields have been populated.
--
function FastCache:updateFilterStatusMethod( name, value )

    local props = self.exportSettings

    app:call( Call:new{ name=str:fmtx( "^1 - Update Filter Status", self.filterName ), async=true, guard=App.guardSilent, main=function( call )

        -- base class method no longer of concern once overridden in extended class.

        repeat -- once
        
            if not props.fastCacheEna then
                self:allowExport( "^1 is disabled.", self.filterName )
                break
            else
                app:assurePrefSupportFile( props.pluginManagerPreset )
                self:allowExport()
            end
            
        	-- Process changes to named properties.
        	
        	if name ~= nil then
        	
                if name == 'cacheFormat' then
                    assert( value == 'jpg' or value == 'tif', "bad value" )
                    local otherExt = ( value=='tif' and "jpg" or "tif" )
                    app:show{ info="Cache files will be written/read in the new format (^1) from here on out - entries in '^2' format will no longer be used (consider deleting them using Library Menu -> Plugin Extras..).",
                        subs = { value=='tif' and "TIFF" or "JPEG", value=='tif' and "JPEG" or "TIFF" },
                        actionPrefKey="Cache file regeneration",
                    }
                elseif name == 'pluginManagerPreset' then
                    self:updatePluginPresetDependentItems()
                end
        	    
            end

            -- process stuff not tied to change necessarily.

            if props.fastCacheEna then
                if props.LR_collisionHandling == 'overwrite' then
                    if not dialogEnding then
                        local filters, first, last, total, names = self:getFilters()
                        if filters[1] == self.id then -- document limitation: it could be re-programmed to populate cache from enhanced virtual (or any other) copy.. ###1
                            self:log( "'^1' is top filter - good (it must be above *all* others).", self.filterName )
                        --elseif filters[1] == 'com.robcole.Exportant.ExportAsVirtualCopy' then
                        --    self:log( "*** 'ExportAsVirtualCopy' is above '^1', - that's OK *if* your objective is to fill the cache with an edited (via applied preset) version of source photo.", self.filterName )
                        else
                            self:logV( "This filter must be at top, but '^1' is (it must be above *all* others). Either disable it, or raise it up.", names[1] )
                            self:denyExport( "'^1' must be top filter (it must be above *all* others).\nEither disable it, or raise it up.", self.filterName, names[1] )
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




--- This optional function adds the observers for our required fields metachoice and metavalue so we can change the dialog depending if they have been populated.
--
--  @usage reminder: change handler can be triggered by changes to any other filter property too.
--
function FastCache:startDialogMethod()

    local props = self.exportSettings
       
	view:setObserver( props, 'pluginManagerPreset', FastCache, FastCache.updateFilterStatus )

    -- these were left over by "export as virtual copy" filter - probably a mistake, so taking
    -- them out here - dunno if it was intentional to leave them in for EAVC filter (?)
	--view:setObserver( props, 'saveXmp', FastCache, FastCache.updateFilterStatus )
	--view:setObserver( props, 'snapEna', FastCache, FastCache.updateFilterStatus )
	--view:setObserver( props, 'snapFmt', FastCache, FastCache.updateFilterStatus )

	view:setObserver( props, 'fastCacheEna', FastCache, FastCache.updateFilterStatus )
	view:setObserver( props, 'cacheFormat', FastCache, FastCache.updateFilterStatus )

	view:setObserver( props, 'LR_exportFiltersFromThisPlugin', FastCache, FastCache.updateFilterStatus )
	
	self:updateFilterStatusMethod() -- async/guarded.

end



function FastCache:updatePluginPresetDependentItems()
    -- nuthin' to do no mo'.
    --local props = self.exportSettings
	--local devPresetItems = lightroom:getDevPresetItems( app:getPref( 'devPresetFolderSubstring', props.pluginManagerPreset ) )
	--devPresetItems[#devPresetItems + 1] = { separator=true }
	--devPresetItems[#devPresetItems + 1] = { title="None", value=nil }
	--props.devPresetItems = devPresetItems
	--local metaPresetItems = lightroom:getMetaPresetItems( app:getPref( 'metaPresetSubstring', props.pluginManagerPreset ) )
	--metaPresetItems[#metaPresetItems + 1] = { separator=true }
	--metaPresetItems[#metaPresetItems + 1] = { title="None", value=nil }
	--props.metaPresetItems = metaPresetItems
end



--- This function will create the section displayed on the export dialog 
--  when this filter is added to the export session.
--
function FastCache:sectionForFilterInDialogMethod()

    local props = self.exportSettings
    
    local it = { title = self:getSectionTitle(), spacing=5, synopsis=bind( self.synopsisPropName ) } -- minimal spacing, add more where needed.
    
    local catDir, catName = cat:getDir()
    self.cacheDir = LrPathUtils.child( catDir, catName.." RGB Image Cache" )
    --fso:assureDir( self.cacheDir ) - does not need to exist unless will be used (post-process-rendered-photos).
    
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
	        value = bind 'fastCacheEna',
			width = share 'fc_ena_width',
			tooltip = "Check box to use existing cached copy if available (and create cached copy for next time, if unavailable), instead of re-rendering - for faster performance without sacrificing quality.",
	    },
	}
	it[#it + 1] = vf:row {
		vf:spacer { width = share( labelWidth ) },
		vf:separator { width = share 'fc_ena_width' },
	}
	space( 7 )
	it[#it + 1] = vf:row {
	    vf:static_text {
	        title = str:fmtx( "Cache directory: ^1\n(not configurable)", str:squeezeToFit( self.cacheDir, WIN_ENV and 60 or 50 ) ), -- long paths don't fit along with label (or maybe even without label).
	        --font = "<system/>",
			enabled = bind 'fastCacheEna',
	    },
	}
	space( 3 )
	it[#it + 1] = vf:row {
	    vf:static_text {
	        title = "Cache format",
	        width = share( labelWidth ),
			enabled = bind 'fastCacheEna',
	    },
	    vf:popup_menu {
	        value = bind 'cacheFormat',
	        items = { { title="TIFF", value='tif' }, { title="JPEG", value='jpg' } },
	        tooltip = [[
If you don't know any better, choose TIFF; if you run out of space, consider purging the fast cache (see library menu -> plugin extras), or switch to JPEG cache format.

Note: cache entries will persist in both formats if you don't purge them, so you could have some export presets which uses tiff cache format, and other presets which use jpeg - not a problem..

Also, consider trying both cache formats and see if you can see a difference!]],
			enabled = bind 'fastCacheEna',
	    },
	    vf:static_text {
	        title = "TIFF: 16-bit zip compression, ProPhotoRGB; JPEG: 100% quality, AdobeRGB.",
			enabled = bind 'fastCacheEna',
	    },
	}
	space( 2 )
	it[#it + 1] = vf:row {
	    vf:static_text {
	        title = [[
Theoretically, tiff gives the best quality (e.g. cache entries are losslessly compressed), but
Lr's 100% quality jpegs are so good that it might take a microscope to see the difference, and
the jpegs are MUCH smaller. If the cache entries will only persist temporarily, or you want to
assure quality is top for printing.., then use tiff, but if you plan to keep cache entries around
for a while, and your cache-based exports are for screen viewing, you will probably be more
than satisfied with jpeg.]],
	    enabled = bind 'fastCacheEna',
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
function FastCache:shouldRenderPhotoMethod( photo )

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
function FastCache:postProcessRenderedPhotosMethod()

    local functionContext, filterContext = self.functionContext, self.filterContext
    local exportSettings = filterContext.propertyTable
   
    app:call( Service:new{ name=str:fmtx( "^1 - Post Process Rendered Photos", self.filterName ), preset=exportSettings.pluginManagerPreset, progress=true, main=function( call )

        assert( exportSettings, "no es" )
        
        if exportSettings.fastCacheEna then
            self:log( "Filter is enabled." )
        else
            self:log( "Filter is disabled, so it won't do anything." )
            self:passRenditionsThrough() -- photos and/or video.
            return
        end
        
        local cacheCopies
        local cacheCopyLookup
        local pathFromCacheCopy

        local photos, videos, union, candidates, unionCache = self:initPhotos{ rawIds={ 'fileFormat', 'path', 'lastEditTime', 'editCount', 'uuid' }, call=call }
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
        --elseif filters[1] == 'com.robcole.Exportant.ExportAsVirtualCopy' then
        --    self:log( "*** 'ExportAsVirtualCopy' is above '^1', - that's OK *if* your objective is to fill the cache with an edited (via applied preset) version of source photo.", self.filterName )
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
        
        cacheCopies = {}
        cacheCopyLookup = {}
        pathFromCacheCopy = {}
        
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

        -- info is lua table containing develop settings and formatted metadata (and edit-date..).
        local function writeTxtFile( txtFile, info )
            return fso:writeFile( txtFile, "return "..luaText:serialize( info ) ) -- s, m
        end

        local catDir, catName = cat:getDir()
        self.cacheDir = LrPathUtils.child( catDir, catName.." RGB Image Cache" )
        fso:assureDir( self.cacheDir ) -- if unsucessful, there will be plenty of errors logged when attempting to use..
        
        -- note: files in cache folder: {path}.tif; {path}.txt
        local cacheInfo = {}
        local exporter = Export:newDialog()
        local dfltSettings = {
            LR_export_destinationType = 'specificFolder',
            LR_export_destinationPathPrefix = self.cacheDir, -- image dir
            LR_export_destinationPathSuffix = "", -- no subdir
            LR_renamingTokensOn = true,
    		LR_tokens = "{{custom_token}}",
    		LR_tokensArchivedToString2 = "{{custom_token}}",
    		LR_tokenCustomString = nil, -- filename (base) filled in below.
    		LR_embeddedMetadataOption = 'all',
    		LR_size_doConstrain = false, -- full size.
    		LR_collisionHandling = 'overwrite', -- shouldn't happen, right?
    		LR_export_useSubfolder = false,
    		LR_export_videoFileHandling = "exclude",
    		--export_videoFormat = "4e49434b-4832-3634-fbfb-fbfbfbfbfbfb",
    		--export_videoPreset = "original",
    		LR_extensionCase = "lowercase",
    		--includeFaceTagsAsKeywords = true,
    		LR_includeVideoFiles = false,
    		--initialSequenceNumber = 1,
    		--jpeg_limitSize = 100,
    		--jpeg_useLimitSize = false,
    		LR_metadata_keywordOptions = "lightroomHierarchical",
    		--outputSharpeningLevel = 2,
    		--outputSharpeningMedia = "screen",
    		LR_outputSharpeningOn = false,
    		LR_reimportExportedPhoto = false,
    		--reimport_stackWithOriginal = false,
    		--reimport_stackWithOriginal_position = "below",
    		--removeFaceMetadata = true,
    		LR_removeLocationMetadata = false,
    		LR_selectedTextFontFamily = "Myriad Web Pro",
    		LR_selectedTextFontSize = 12,
    		--LR_size_doNotEnlarge = true, - not resizing.
    		--size_maxHeight = 1000,
    		--size_maxWidth = 1000,
    		--size_resizeType = "wh",
    		--size_resolution = 240,
    		--size_resolutionUnits = "inch",
    		--LR_size_units = "pixels", - not required.
    		--LR_size_userWantsConstrain = true, ###1 not registered - dunno what it does/means.
    		LR_useWatermark = false,
    		--watermarking_id = "<simpleCopyrightWatermark>",
        }
        local addlSettings = {}
        if exportSettings.cacheFormat == 'tif' then
            addlSettings.LR_format = 'TIFF'
    		addlSettings.LR_export_bitDepth = 16
    		addlSettings.LR_tiff_compressionMethod = "compressionMethod_ZIP"
    		addlSettings.LR_tiff_preserveTransparency = false
    		addlSettings.LR_export_colorSpace = "ProPhotoRGB"
        elseif exportSettings.cacheFormat == 'jpg' then
            addlSettings.LR_format = 'JPEG'
    		--jpeg_limitSize = 100
    		addlSettings.LR_jpeg_quality = 1
    		addlSettings.LR_jpeg_useLimitSize = false
       		addlSettings.LR_export_colorSpace = "AdobeRGB"
        else
            error( exportSettings.cacheFormat or "oops" )
        end
        local filesToAdd = {}
        for i, photo in ipairs( photos ) do
            repeat
                -- may be init for txt file:
                local devSettings
                local fmtMetadata
                local editDate -- @5/Nov/2014, this is write-only. but in the future it may be used, so better to have it there.
                local editCount
                --------------
                local path = unionCache:getRaw( photo, 'path' )
                local uuid = unionCache:getRaw( photo, 'uuid' )
                local imgName = LrPathUtils.addExtension( uuid, exportSettings.cacheFormat )
                local txtName = LrPathUtils.addExtension( uuid, exportSettings.cacheFormat..".txt" ) -- must match image type, else values are not applicable.
                local imgFile = LrPathUtils.child( self.cacheDir, imgName )
                local txtFile = LrPathUtils.child( self.cacheDir, txtName )
                if fso:existsAsFile( imgFile ) then
                    if fso:existsAsFile( txtFile ) then
                        local s, d = pcall( dofile, txtFile )
                        if s then
                            if d then
                                --assert( imgFile, "no cache image file" )
                                local good -- cache entry status.
                                editCount = unionCache:getRaw( photo, 'editCount' )
                                editDate = unionCache:getRaw( photo, 'lastEditTime' )
                                if type( d.editCount ) ~= 'number' then -- nil or wonked
                                    self:logV( "*** edit-count missing from info txt file (or invalid data type)." )
                                    d.editCount = -1 -- don't kill the deal, just re-create.
                                end
                                if type( d.editDate ) ~= 'number' then -- nil or wonked
                                    self:logV( "*** edit-date missing from info txt file (or invalid data type)." )
                                    d.editDate = editDate -- edit-count now used for decisions, but this is comforting, albeit may get overwritten..
                                end
                                if editCount > d.editCount then -- photo has been "edited" (whatever that means..).
                                    Debug.pause( editCount, d.editCount ) -- reminder: arithmetic round-off can make unedited photo seem edited - maybe should be using edit-count "integer" instead (?).
                                    devSettings = photo:getDevelopSettings()
                                    if type( d.devAdj ) ~= 'table' then -- nil or wonked
                                        self:logV( "*** dev-adj missing from info txt file (or invalid data type)." )
                                        d.devAdj = {} -- ditto
                                    end
                                    if tab:isEquivalent( d.devAdj, devSettings ) then
                                        fmtMetadata = photo:getFormattedMetadata() -- includes ratings, keyword text, IPTC metadata (incl. extns), copyright.. - hopefully no raw data need be gotten ###.
                                        if tab:isEquivalent( d.fmtMeta, fmtMetadata ) then
                                            self:logV( "Develop settings and metadata are equivalent, so not re-rendering." ) -- this happens when custom metadata is reason for "edit", or user backed out a change..
                                            good = true
                                            d.editCount = editCount
                                            d.editDate = editDate
                                            local s, m = writeTxtFile( txtFile, d )
                                            if s then
                                                self:logV( "info txt file updated to avoid settings/metadata comparison next time." )
                                            else
                                                self:log( "*** Unable to update info txt file to avoid settings/metadata comparison next time - ^1", m ) -- won't affect result, just minor perforance thing.
                                            end
                                        else
                                            self:logV( "Develop settings are equivalent, but metadata is not, so re-rendering." ) -- ###2 could sync instead.
                                        end
                                    else
                                        self:logV( "Develop settings have changed, so cache entry is stale - to be discarded." )
                                    end
                                else
                                    self:logV( "Edit count hasn't advanced, so develop settings and metadata are presumed to still be valid, and hence cache entry is acceptable." )
                                    good = true
                                end
                                if good then
                                    local p = catalog:findPhotoByPath( imgFile )
                                    if p then
                                        self:log( "Cache hit: ^1", imgFile )
                                        cacheCopies[#cacheCopies + 1] = p
                                    else
                                        self:log( "Hmm - cache photo on disk but not in catalog: ^1 (will be re-added)", imgFile )
                                        filesToAdd[#filesToAdd + 1] = d.imgFile
                                    end
                                    cacheInfo[uuid] = tab:addItems( { imgFile=imgFile }, d )
                                    break -- do not fall through and recreate cache entry. instead, maybe just add to catalog (if adding unsuccessful, cache entry ignored).
                                -- else fall-through and recreate tif + assoc. txt file(s).
                                end
                            else
                                self:logW( "Bad image cache file: ^1 (cache files to be deleted)", txtFile )
                                LrFileUtils.delete( imgFile )
                                LrFileUtils.delete( txtFile )
                            end
                        else
                            self:logW( d )
                            LrFileUtils.delete( imgFile )
                            LrFileUtils.delete( txtFile )
                        end
                    else
                        self:log( "*** missing control file - deleting image file from cache: ^1", imgFile )
                        LrFileUtils.delete( imgFile )
                    end
                else
                    self:logV( "image file not in cache dir: ^1", imgFile )
                    if fso:existsAsFile( txtFile ) then
                        self:log( "*** missing image file - deleting control file from cache: ^1", txtFile )
                        LrFileUtils.delete( txtFile )
                    end
                end
                
                -- set (base) filename
                addlSettings.LR_tokenCustomString = uuid -- base filename.
                -- export cache entry: full-rez, no sharpening, all metadata etc., i.e. master conversion..
                local s, m = exporter:doExport {
                    photos = { photo },
                    defaults = dfltSettings,
                    settings = addlSettings,
                    constrainSettings = app:isAdvDbgEna() and 'strict' or 'no', -- or 'yes'
                    constrainDefaults = app:isAdvDbgEna() and 'strict' or 'no', -- ditto.
                }
                if s then
                    devSettings = devSettings or photo:getDevelopSettings() -- may or may not have already been gotten above.
                    fmtMetadata = fmtMetadata or photo:getFormattedMetadata() -- ditto
                    editCount = editCount or unionCache:getRaw( photo, 'editCount' ) -- maybe overkill, but consistent..
                    editDate = editDate or unionCache:getRaw( photo, 'lastEditTime' ) -- maybe overkill, but consistent..
                    app:assert( fso:existsAsFile( imgFile ), "cant find exported image file: ^1", imgFile )
                    local info = { devAdj=devSettings, fmtMeta=fmtMetadata, editCount=editCount, editDate=editDate }
                    local s2, m2 = writeTxtFile( txtFile, info )
                    if s2 then
                        --Debug.pause( editCount, info.editCount ) -- reminder: arithmetic round-off can make unedited photo seem edited - maybe should be using edit-count "integer" instead (?).
                        local photo = catalog:findPhotoByPath( imgFile )
                        if photo then
                            cacheCopies[#cacheCopies + 1] = photo
                        else
                            filesToAdd[#filesToAdd + 1] = imgFile
                        end
                        self:log( "New cache entry created: ^1", imgFile )
                        cacheInfo[uuid] = tab:addItems( { imgFile=imgFile }, info )
                    else
                        self:logE( m2 )
                    end
                else
                    Debug.pause( m )
                    self:logE( m )
                end
            until true
        end
        
        if #filesToAdd > 0 then
            local newPhotos = {}
            local s, m = cat:update( 30, "Adding cache photos", function()
                for i, v in ipairs( filesToAdd ) do
                    local p = catalog:addPhoto( v )
                    if p then
                        newPhotos[#newPhotos + 1] = p
                    else
                        self:logW( "Cant add photo." )
                    end
                end
            end )
            if s and #newPhotos > 0 then
                self:log( "Added ^1 to catalog.", #newPhotos )
                tab:appendArray( cacheCopies, newPhotos ) -- reminder: without presence in cacheCopies array, cache entry is "write only".
            elseif m then
                self:logE( m )
            else
                self:logE( "Unable to add requisite photos." )
            end
        end

        --Debug.lognpp( cacheInfo )
        --Debug.showLogFile()
        --Debug.pause( "See debug log file." )
        
        if #cacheCopies > 0 then
            
            for i, photo in ipairs( photos ) do
                cacheCopyLookup[photo] = cacheCopies[i]
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
                self:log( "Initial destination for rendering cache copy sources with user settings: ^1", _exportSettings.LR_export_destinationPathPrefix )
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
                photosToExport = cacheCopies,
                exportSettings = _exportSettings
            }
            assert( call.scope, "no scope" )
            for i, rendition in expSession:renditions{ progressScope=call.scope, stopIfCanceled=true } do -- start rendering on separate task implied.
                local s, pom = rendition:waitForRender()
                if s then
                    self:logV( "Cached copy source rendered to: ^1", pom )
                    pathFromCacheCopy[rendition.photo] = pom
                else
                    self:logE( pom )
                end
            end
            if call:isQuit() then
                self:log( "Canceled" )
                return
            end
            
        elseif #photos > 0 then
            app:error( "Unable to create cache copies to export." ) -- errMsg already logged.
        elseif #videos > 0 then
            -- proceed 
        else -- this never happens, since pre-checked above.
            error( "how so?" )
        end
        
        local renditionOptions = {
            plugin = _PLUGIN, -- ###3 I have no idea what this does, or if it's better to set it or not (usually it's not set).
            renditionsToSatisfy = candidates, -- try to satisfy all candidates.
            filterSettings = function( renditionToSatisfy, exportSettings )
                --assert( exportSettings, "no es" )
                -- reminder: you can't change 'LR_tokenCustomString' at this point - I guess export service needs it fixed since renditionToSatisfy filename is fixed.
                --local newPath = renditionToSatisfy.destinationPath -- by default return unmodified.
                self:logV( "Rendition (to satisfy) path: ^1", renditionToSatisfy.destinationPath ) -- shortcut - path will not be changed by this export filter.
                --local photo = renditionToSatisfy.photo
                return nil -- newPath
                
            end, -- end of rendition filter function
        } -- closing rendition options
        
        -- Reminder: selective abortion beyond this point is hit n' miss, which is way renditions were paired down, if need be - granted Lr will still present the "skipped" ones in a box..
        -- Note: all actual rendering has already been completed. So we're banking on the ability to skip all renditions before they've really gotten started - so far, it's working 100%,
        -- but I suppose it's possible if exporting thousands that it will fail (rendering will start and can't be skipped) - cross that bridge when come to I guess..

        for sourceRendition, renditionToSatisfy in filterContext:renditions( renditionOptions ) do
            repeat
                assert( exportSettings.fastCacheEna, "evc ena should be pre-checked" )
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
                local ent = cacheInfo[unionCache:getRaw( srcPhoto, 'uuid' )] -- get entry from cache for uuid.
                if ent then
                    -- *** SKIP UPSTREAM (LR) RENDERING
                    sourceRendition:skipRender() -- keep Lr from rendering (reminder: Exportant will be top of filter heap).
                    local cacheCopy = cacheCopyLookup[srcPhoto]
                    if cacheCopy == nil then
                        Debug.pause( "no cache-copy" )
                        self:logV( "*** No cache copy in lookup." ) -- should have been error logged if problem creating cache copy, otherwise it'll be there, theoretically.
                        break
                    end
                    local srcFile = pathFromCacheCopy[cacheCopy]
                    if srcFile == nil then
                        Debug.pause( "no src-file" )
                        self:logV( "*** No src-file corresponding to cache copy." ) -- ditto.
                        break
                    end
                    if str:is( exportSettings.LR_publish_connectionName ) or ( exportSettings.LR_collisionHandling == 'overwrite' ) then
                        local eq = str:isEqualIgnoringCase( renditionToSatisfy.destinationPath, srcPhotoPath )
                        if eq then -- exp dest file is same as source photo file - not ok..
                            renditionToSatisfy:renditionIsDone( false, "This filter does not support overwriting source photo file: "..srcPhotoPath ) -- no need for additional W/E logging here.
                            break -- not necessary, but comforting..
                        end
                        --Debug.pause( "Overwrite?", renditionToSatisfy.destinationPath, "source photo path:", srcPhotoPath )
                        local s, m = fso:moveFile( srcFile, renditionToSatisfy.destinationPath, true, true )
                        if s then
                            self:log( "Rendered cache copy moved to final destination: ^1", renditionToSatisfy.destinationPath )
                            renditionToSatisfy:renditionIsDone( true )
                        else
                            self:logE( m )
                            break
                        end
                    else
                        self:logE( "Collision handling not set to overwrite" )
                        break
                    end
                else
                    self:logW( "No cache entry - exporting normally." )
                    break
                end
            until true
        end
    end, finale=function( call )
        self:postProcessRenderedPhotosFinale( call )
    end } )
end



function FastCache.startDialog( props )
    dialogEnding = false
    local filter = ExtendedExportFilter.assureFilter( FastCache, props )
    filter:startDialogMethod()
end



function FastCache.sectionForFilterInDialog( vf, props )
    local filter = ExtendedExportFilter.assureFilter( FastCache, props )
    return filter:sectionForFilterInDialogMethod()
end



function FastCache.endDialog()
    dialogEnding = true    
end



-- reminder: update status filter function need not be implemented, as long as ID passed to listener reg func is this class.
--[[
function FastCache.updateFilterStatus( id, props, name, value )
    local filter = ExtendedExportFilter.assureFilter( FastCache, props )
    filter:updateFilterStatusMethod( name, value )
end
--]]



function FastCache.shouldRenderPhoto( props, photo )
    local filter = ExtendedExportFilter.assureFilter( FastCache, props )
    return filter:shouldRenderPhotoMethod( photo )
end



--- Post process rendered photos.
--
function FastCache.postProcessRenderedPhotos( functionContext, filterContext )
    local filter = ExtendedExportFilter.assureFilter( FastCache, filterContext.propertyTable, { functionContext=functionContext, filterContext=filterContext } )
    filter:postProcessRenderedPhotosMethod()
end



-- reminder: fast-cache is tied to catalog, since entry is no good if develop settings in catalog have changed since cached.
FastCache.exportPresetFields = {
	
	{ key = 'fastCacheEna', default = false },
	{ key = 'cacheFormat', default = 'tif' }, -- or 'jpg'
	
}



FastCache:inherit( ExtendedExportFilter ) -- inherit *non-overridden* members.



return FastCache
