--[[
        SourcePhotoConsiderations.lua
--]]


local SourcePhotoConsiderations, dbg, dbgf = ExtendedExportFilter:newClass{ className='SourcePhotoConsiderations', register=true }



--- Constructor for extending class.
--
function SourcePhotoConsiderations:newClass( t )
    return ExtendedExportFilter.newClass( self, t )
end



--- Constructor for new instance.
--
function SourcePhotoConsiderations:new( t ) -- have base class ###3
    local o = ExtendedExportFilter.new( self, t )
    o.enablePropName = 'spcEna'
    return o
end



--- This function will check the status of the Export Dialog to determine 
--  if all required fields have been populated.
--
function SourcePhotoConsiderations:updateFilterStatusMethod( name, value )

    local props = self.exportSettings

    app:call( Call:new{ name=str:fmtx( "^1 - Update Filter Status", self.filterName ), async=true, guard=App.guardSilent, main=function( context )

        -- base class method no longer of concern once overridden in extended class.

        repeat -- once
        
            if not props.spcEna then
                self:allowExport( "^1 is disabled.", self.filterName )
                break
            else
                app:assurePrefSupportFile( props.pluginManagerPreset )
                self:allowExport()
            end
            
        	-- Process changes to named properties.
        	
        	if name ~= nil then
        	
        	    -- named property has changed

                if name == 'postMetaSetPick' then
        	        if value then
        	            props.postMetaClearPick = false
        	        end
        	    elseif name == 'postMetaClearPick' then
        	        if value then
        	            props.postMetaSetPick = false
        	        end
        	    -- else nada.
                end
            	
            end

            -- process stuff not tied to change necessarily.
            
            if props.postMetaSetPick and props.postMetaClearPick then
                props.postMetaSetPick = false
                props.postMetaClearPick = false
            end
            
            if props.postMetaEna and str:is( props.postMetaClearKeywords ) then
                local kwStrings = str:split( props.postMetaClearKeywords, "," )
                if #kwStrings > 0 then
                    for i, kstr in ipairs( kwStrings ) do
                        if str:is( kstr ) then
                            local kws = self.keywords:getKeywordsForName( kstr ) -- maybe empty but never nil.
                            if #kws == 1 then
                                -- ok
                            elseif #kws > 1 then
                                self:denyExport( "Keyword is ambiguous: ^1 (there are ^2 of them).", kstr, #kws )
                                break
                            else -- zero
                                self:denyExport( "Keyword (to clear) is missing: ^1", kstr )
                                break
                            end     
                        end
                    end
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
function SourcePhotoConsiderations:startDialogMethod()

    self.keywords = Keywords:new() -- continuous init - default interval is OK (stopped in end-dialog function).

    local props = self.exportSettings
    
	view:setObserver( props, 'pluginManagerPreset', SourcePhotoConsiderations, SourcePhotoConsiderations.updateFilterStatus )
	
	view:setObserver( props, 'spcEna', SourcePhotoConsiderations, SourcePhotoConsiderations.updateFilterStatus )
	view:setObserver( props, 'confirmSmartPreviews', SourcePhotoConsiderations, SourcePhotoConsiderations.updateFilterStatus )
	
	view:setObserver( props, 'saveXmp', SourcePhotoConsiderations, SourcePhotoConsiderations.updateFilterStatus )
	
	view:setObserver( props, 'snapEna', SourcePhotoConsiderations, SourcePhotoConsiderations.updateFilterStatus )
	view:setObserver( props, 'snapFmt', SourcePhotoConsiderations, SourcePhotoConsiderations.updateFilterStatus )

	view:setObserver( props, 'postMetaEna', SourcePhotoConsiderations, SourcePhotoConsiderations.updateFilterStatus )
	view:setObserver( props, 'postMetaPreset', SourcePhotoConsiderations, SourcePhotoConsiderations.updateFilterStatus )
	view:setObserver( props, 'postMetaSetPick', SourcePhotoConsiderations, SourcePhotoConsiderations.updateFilterStatus )
	view:setObserver( props, 'postMetaCollect', SourcePhotoConsiderations, SourcePhotoConsiderations.updateFilterStatus ) -- no dependency yet, but heck..
	view:setObserver( props, 'postMetaClearKeywords', SourcePhotoConsiderations, SourcePhotoConsiderations.updateFilterStatus )
	view:setObserver( props, 'postMetaClearPick', SourcePhotoConsiderations, SourcePhotoConsiderations.updateFilterStatus )

	view:setObserver( props, 'LR_exportFiltersFromThisPlugin', SourcePhotoConsiderations, SourcePhotoConsiderations.updateFilterStatus )

	self:updateFilterStatusMethod() -- async/guarded.

end



--- This function will create the section displayed on the export dialog 
--  when this filter is added to the export session.
--
function SourcePhotoConsiderations:sectionForFilterInDialogMethod()

    local props = self.exportSettings

    local it = { title = self:getSectionTitle(), spacing=5, synopsis=bind( self.synopsisPropName ) } -- minimal spacing, add more where needed.
    
    -- Get's sample snapshot name, not the real thing.
    local function getSnapshotName()
        local time = LrDate.currentTime()
        local name = props.snapFmt
        if not str:is( name ) then
            return "" -- not exactly correct, since there is a default, but seems right..
        end
        name = name:gsub( "%%V", "Master" )
        name = name:gsub( "%%v", "Copy 1" )
        return LrDate.timeToUserFormat( time, name )
    end
    
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

    space()
    local labelWidth = LrUUID.generateUUID() -- tired of widths tied to unrelated sections..

	it[#it + 1] = vf:row {
		vf:spacer{ width = share( labelWidth ) },
		vf:checkbox {
		    title = self.title,
		    value = bind 'spcEna',
		    width = share 'src_width',
		},
	}
	it[#it + 1] = vf:row {
		vf:spacer { width = share( labelWidth ) },
		vf:separator { width = share 'src_width' },
	}
	space( 7 )

    local cspEna = bind {
	    key = 'spcEna',
        transform = function()
            if props.spcEna and app:lrVersion() >= 5 then
                return true
            else
                return false
            end
        end
    }
	it[#it + 1] = 
		vf:row {
		    vf:checkbox {
		        title = "Confirm Smart Previews",
		        value = bind 'confirmSmartPreviews',
				width = share( labelWidth ),
				enabled = cspEna,   
				tooltip = "Check box to show prompt before exporting smart previews (when originals are offline).",
		    },
			vf:static_text {
			    title = "Protect from inadvertent exporting of sub-quality smart previews.",
				enabled = cspEna,   
			},
		}
	it[#it + 1] = 
		vf:row {
		    vf:checkbox {
		        title = "Save XMP upon export",
		        value = bind 'saveXmp',
				width = share( labelWidth ),
				tooltip = "Check this box to assure xmp is saved upon export. Note: this settings may be useless if auto-write XMP option is enabled, but if not, it is highly recommended, unless you've got it covered some other way, but even then, it may be cheap insurance...",
			    enabled = bind 'spcEna',
		    },
			vf:static_text {
			    title = "Assure saved settings/metadata represent photo at time of export.",
			    enabled = bind 'spcEna',
			},
		}
	it[#it + 1] = vf:row { 
		    vf:checkbox {
		        title = "Pre-export Snapshot",
		        value = bind 'snapEna',
				width = share( labelWidth ),
				tooltip = "Check box to take snapshop *prior to* export rendering.",
			    enabled = bind 'spcEna',
		    },
		    vf:column { spacing=2,
    		    vf:edit_field {
    		        value = bind 'snapFmt',
    		        enabled = LrBinding.andAllKeys( 'spcEna', 'snapEna' ),
    		        width_in_chars = WIN_ENV and 35 or 31,
    		        width = share 'field_width',
    		        immediate = true,
    		    },
    		    vf:static_text {
    		        --bind_to_object = scratchProps,
    		        title = bind {
    		            key = 'snapFmt',
    		            transform = function( value, toUi )
    		                if str:is( props['snapFmt'] ) then
    		                    return getSnapshotName()
    		                else
    		                    return ""
    		                end
    		            end,
    		        },
    		        --width_in_chars = 35,
    		        width = share 'field_width',
    		        enabled = LrBinding.andAllKeys( 'spcEna', 'snapEna' ),
		        },
		    },
	        vf:column { spacing=2,
    			vf:push_button {
    			    title = "Help",
    			    action = function()
    			        local m = [[
    Use the following special strings for date elements:
    
        %B: Full name of month
        %b: 3-letter name of month
        %m: 2-digit month number
        %d: Day number with leading zero
        %e: Day number without leading zero
        %j: Julian day of the year with leading zero
        %y: 2-digit year number
        %Y: 4-digit year number
        %H: Hour with leading zero (24-hour clock)
        %1H: Hour without leading zero (24-hour clock)
        %I: Hour with leading zero (12-hour clock)
        %1I: Hour without leading zero (12-hour clock)
        %M: Minute with leading zero
        %S: Second with leading zero
        %p: AM/PM designation
    
        %V: Virtual copy name, "Master" if not virtual copy.
        %v: Virtual copy name, blank if not virtual copy.
    ]]
    
    			        dia:quickTips( m )
    			        
    			    end,
    				tooltip = "Snapshot name format help...",
    		        enabled = LrBinding.andAllKeys( 'spcEna', 'snapEna' ),
    			},
    		    vf:static_text {
    		        title = "(example)",
    		        enabled = LrBinding.andAllKeys( 'spcEna', 'snapEna' )
    		    },
            },
		}
	it[#it + 1] = vf:row {
		    vf:checkbox {
		        title = "Post-export Metadata",
		        value = bind 'postMetaEna',
				width = share( labelWidth ),
				tooltip = "Check box to have metadata set and/or cleared (source photo I mean) after successful export.",
				enabled = bind 'spcEna',
		    },
		    vf:column { spacing=1,
		        vf:row {
        		    vf:static_text {
        		        title = "Apply:",
        		        width = share 'inner_label',
        		        enabled = LrBinding.andAllKeys( 'spcEna', 'postMetaEna' ),
        		    },
        		    vf:popup_menu {
        		        value = bind 'postMetaPreset',
        		        items = metaPresetItems,
        				tooltip = "Preset to be applied post-export, to set/clear selected metadata (won't clear keywords, and excludes pick flag).",
        				width_in_chars = WIN_ENV and 27 or 23,
        				width = share 'pem_popup_width',
        		        enabled = LrBinding.andAllKeys( 'spcEna', 'postMetaEna' ),
        		    },
        		    vf:checkbox {
        		        title = "Set Pick",
        		        value = bind 'postMetaSetPick',
        		        tooltip = "If checked, pick flag will be set upon successful export.",
        		        enabled = LrBinding.andAllKeys( 'spcEna', 'postMetaEna' ),
        		    },
        		},
		        vf:row {
        		    vf:static_text {
        		        title = "Clear:",
        		        width = share 'inner_label',
        		        enabled = LrBinding.andAllKeys( 'spcEna', 'postMetaEna' ),
        		    },
        		    vf:edit_field {
        		        value = bind 'postMetaClearKeywords',
         				width = share 'pem_popup_width',
         				tooltip = "Enter keywords to clear - must be simple (hierarchical syntax not supported) and unambiguous (only one matching keyword). Separate keywords using a ',' (comma) or whatever you've got configured as separator.",
        		        enabled = LrBinding.andAllKeys( 'spcEna', 'postMetaEna' ),
        		    },
        		    vf:checkbox {
        		        title = "Un-flag",
        		        value = bind 'postMetaClearPick',
        		        tooltip = "If checked, pick flag will be cleared upon successful export.",
        		        enabled = LrBinding.andAllKeys( 'spcEna', 'postMetaEna' ),
        		    },
        		},
        		vf:spacer{ height=5 },
		        vf:row {
        		    vf:static_text {
        		        title = "Collect:",
        		        width = share 'inner_label',
        		        enabled = LrBinding.andAllKeys( 'spcEna', 'postMetaEna' ),
        		    },
        		    vf:edit_field {
        		        value = bind 'postMetaCollect',
         				fill_horizontal = 1,
         				tooltip = str:fmtx( "Enter collection names (separated by '^1' without the apostrophes) and photos will be added to regular collections with specified name(s) - by default: in '^2' collection set.", app:getPref{ name='collNameSep', default=",", presetName=props.pluginManagerPreset }, app:getPluginName() ),
        		        enabled = LrBinding.andAllKeys( 'spcEna', 'postMetaEna' ),
        		    },
        		},
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
--  @usage called *before* post-process-rendered-photos function (no cached metadata).
--  @usage base class has no say (need not be called).
--
function SourcePhotoConsiderations:shouldRenderPhotoMethod( photo )

    local exportSettings = self.exportSettings
    assert( exportSettings, "no es" )

    --Debug.lognpp( exportSettings )
    --Debug.showLogFile()
    
    if exportSettings.spcEna then
        -- dictated below
    else
        return true -- no-op if disabled.
    end
    
    -- reminder: there is no metadata cache at this stage.
    local fileFormat = photo:getRawMetadata( 'fileFormat' )
    
    if fileFormat ~= 'VIDEO' then -- real or virtual photo
        if exportSettings.saveXmp then
            local isVirt = photo:getRawMetadata( 'isVirtualCopy' ) -- note: since virtual copies are not represented in xmp, no sense saving xmp for virtual copies sake, and this check avoids repeat saving in case multiple virtual copies are being exported.
            if not isVirt then -- reminder: new way will fail if virtual copy.
                -- Catalo g : s avePhotoMetadata( photo, photoPath, targ, call, noVal, oldWay )
                local photoPath = photo:getRawMetadata( 'path' )
                if fso:existsAsFile( photoPath ) then
                    local s, m = cat:savePhotoMetadata(
                        photo,
                        photoPath,
                        nil, -- let method compute target xmp file path, based on file type.
                        nil, -- no call => no scope/caption...
                        false, -- do validation
                        app:getPref{ name='saveXmpTheOldWay', presetName=exportSettings.pluginManagerPreset, default=false } -- ###3: not entirely sure what the default should be.
                    )
                    if s then
                        self:log( "XMP of '^1' has been successfully saved and validated.", photoPath )
                        return true
                    else
                        app:displayError( "Unable to save xmp prior to export - ^1. Therefore, not exporting photo...", m ) -- bezel, scope, and log.
                        return false
                    end
                else
                    local sp = cat:isSmartPreview( photo )
                    if sp then
                        self:log( "*** photo file does not exist - smart preview does, but xmp can not be saved when original photo file is not accessible." )
                    else
                        self:logW( "*** photo file does not exist, nor does smart preview, so xmp can not be saved - you will (probably) have an export error because of this." )
                        --return false - ###3 not sure if this is the right course of action, it could be that a preview could still be exported (although not sure as presently coded).
                        -- let it error out naturally instead.
                    end
                end
            else
                self:logV( "photo is virtual copy - not saving xmp" )
            end
        end
    -- else - @4/Nov/2013 19:15, includes video, so take care..
    end

    return true -- it's not up to this export filter to decide not to export, it's up to custom-export-check function, if implemented.

end



--- Post process rendered photos (overrides base class).
--
--  @usage reminder: videos are not considered rendered photos (won't be seen by this method).
--
function SourcePhotoConsiderations:postProcessRenderedPhotosMethod()

    local functionContext, filterContext = self.functionContext, self.filterContext
    local exportSettings = filterContext.propertyTable
    
    local postMetaPhotos = {} -- exported photos - only populated if metadata to apply.
    local postMetaSetPick
    local postMetaClearPick
    local postMetaClearKeywords
    local postMetaCollect
    local postMetaColls
    local postMetaPresetId
    local spCollOk -- flag indicating photos added to sp collections successfully.
    local spFullColl -- sp exported at full quality.
    local spSubColl -- exported at sub-quality.
    local spDisColl -- disabled/skipped.
        
    app:call( Service:new{ name=str:fmtx( "^1 - Post Process Rendered Photos", self.filterName ), preset=exportSettings.pluginManagerPreset, progress=true, main=function( call )
    
        assert( exportSettings, "no es" )

        if exportSettings.spcEna then
            self:log( "Filter is enabled." )
        else
            self:log( "Filter is disabled, so it won't do anything." )
            self:passRenditionsThrough()
            return
        end

        local smartPreviewSet = {}
        local skipRender = {}
        
        local photos, videos, union, candidates, unionCache = self:initPhotos{ rawIds={ 'fileFormat', 'path' }, call=call }
        if not photos then
            return
        end
        
        local status = self:requireMainFilterInPost()
        if not status then
            return
        end
        
        if exportSettings.postMetaEna then
            assert( postMetaPhotos ~= nil and #postMetaPhotos == 0, "bad init" )
            postMetaSetPick = exportSettings.postMetaSetPick
            postMetaClearPick = exportSettings.postMetaClearPick
            postMetaCollect = exportSettings.postMetaCollect
            if str:is( postMetaCollect ) then
                local collNames = str:split( postMetaCollect, app:getPref{ name='collNameSep', default=",", presetName=exportSettings.pluginManagerPreset } )
                local collSetName = app:getPref{ name='collSet', expectedType='string', presetName=exportSettings.pluginManagerPreset } -- default is nil (defaults to plugin name in called context)
                -- ( names, tries, doNotRemoveDevSuffixFromPluginName, pluginName )
                postMetaColls = { cat:assurePluginCollections( collNames, 25, nil, collSetName ) } -- returns collections unpacked.
            end
            -- Note: good to check keywords upon export, but shouldn't they also be checked upon entry? ###1
            if str:is( exportSettings.postMetaClearKeywords ) then
                -- not much point in using keywords object since default is lax checking, which makes fair sense, since rigorous checking was added to UI.
                -- (I don't want to hold up exports for several seconds or more on account of a keyword or two to clear)
                postMetaClearKeywords = {}
                local kwStrings = str:split( exportSettings.postMetaClearKeywords, app:getPref{ name='keywordSep', presetName=exportSettings.pluginManagerPreset, default="," } )
                Debug.pause( #kwStrings, kwStrings )
                if #kwStrings > 0 then
                    local kwSet
                    local keywords = {}
                    local dups = {}
                    local nK = 0
                    local function doKeywordsRig( kws )
                        -- breadth first
                        for i, k in ipairs( kws ) do
                            local name = k:getName()
                            if keywords[name] then
                                dups[name] = true
                            else
                                keywords[name] = k
                            end
                        end
                        -- then depth
                        for i, k in ipairs( kws ) do
                            doKeywordsRig( k:getChildren() )
                        end
                    end
                    local function doKeywordsLax( kws )
                        -- breadth first
                        for i, k in ipairs( kws ) do
                            local name = k:getName()
                            if keywords[name] then
                                dups[name] = true
                            else
                                keywords[name] = k
                                if kwSet[name] then
                                    nK = nK + 1
                                    if nK == #kwStrings then
                                        return -- avoiding further dup checking
                                    end
                                end
                            end
                        end
                        -- then depth
                        for i, k in ipairs( kws ) do
                            doKeywordsLax( k:getChildren() )
                            if nK == #kwStrings then
                                return
                            end
                        end
                    end
                    if app:getPref{ name='keywordDupCheckRigorous', presetName=exportSettings.pluginManagerPreset, default=false } then
                        doKeywordsRig( catalog:getKeywords() ) -- consider using keywords object with async init. ###1
                    else
                        kwSet = tab:createSet( kwStrings )
                        doKeywordsLax( catalog:getKeywords() )
                    end
                    --Debug.pause( nK, #kwStrings )
                    local ok = true
                    for j, kwString in ipairs( kwStrings ) do
                        if keywords[kwString] then
                            if not dups[kwString] then
                                -- exists not dup
                                postMetaClearKeywords[#postMetaClearKeywords + 1] = keywords[kwString]
                            else
                                self:logE( "Redundent keyword: ^1", kwString )
                                ok = false
                            end
                        else
                            self:logE( "Missing keyword: ^1", kwString )
                            ok = false
                        end
                    end
                    if ok then
                        assert( #postMetaClearKeywords > 0, "ok sans keywords?" )
                        self:log( "^1 to clear.", str:nItems( #postMetaClearKeywords, "keywords" ) )
                        --Debug.pause( #postMetaClearKeywords )
                    else
                        local s, m = self:cancelExport()
                        if s then
                            self:log( "Export canceled." )
                        else
                            self:logW( m )
                        end
                        return
                    end
                else
                    app:error( "str sans split - hmm..." )
                end
            else
                assert( postMetaClearKeywords == nil, "not nil" )
            end
            postMetaPresetId = exportSettings.postMetaPreset
        end

        -- confirm smart previews:        
        local thumbSize = app:getPref{ name='thumbSize', presetName=exportSettings.pluginManagerPreset, default=64 }
        -- Note: it's hard to selectively filter exports at this point, since rendering may have begun already (depending on export filter order) on a separate task.
        local useColls = app:getPref{ name='useCollections', presetName=exportSettings.pluginManagerPreset, default=true }
        app:initPref( 'preClearColls', false )
        if exportSettings.confirmSmartPreviews then
            if app:lrVersion() >= 5 then
                if useColls then
                    spFullColl, spSubColl, spDisColl = cat:assurePluginCollections{ "Smart Previews Exported @100%+", "Smart Previews Exported @<100%", "Smart Previews - NOT Exported" } -- or error.
                end
                -- "secondary" cache to support smart preview confirmation.
                local cache = lrMeta:createCache{ photos=photos, rawIds={ 'path', 'smartPreviewInfo', 'isVirtualCopy', 'dimensions', 'croppedDimensions' }, fmtIds={ 'copyName' } } -- path is replicated, but facilitates get-photo-name-disp.
                local si = {}
                local ok = true
                local props = LrBinding.makePropertyTable( functionContext )
                props.masterEnaTogl = true
                props.redsEnaTogl = true
                local smarts = {} -- union of smart preview photos (array)
                local reds = {} -- reds array of indexes.
                local redSet = {} -- reds - set of photos.
                local blacks = {}
                local blackSet = {} -- blacks - set of photos.
                assert( props, "no props" )
                local spMax = app:getPref{ name='smartPreviewSize', presetName=exportSettings.pluginManagerPreset, default=2560 }
                for i, photo in ipairs( photos ) do
                    local photoName = cat:getPhotoNameDisp( photo, true, cache ) -- full name, rely on cache for metadata.
                    self:logV()
                    self:logV( "Considering whether ok to export (smart-preview-wise) '^1'", photoName )
                    local file = unionCache:getRawMetadata( photo, 'path' ) -- pick your cache...
                    if not fso:existsAsFile( file ) then
                        local sp = cat:isSmartPreview( photo, cache )
                        if sp then -- smart preview to be exported.
                            -- path & size (in bytes).
                            smartPreviewSet[photo] = true
                            smarts[#smarts + 1] = photo
                            local origDim = cache:getRawMetadata( photo, 'dimensions' ) -- original file (image) dimensions.
                            local origLong = math.max( origDim.width, origDim.height )
                            local cropDim = cache:getRawMetadata( photo, 'croppedDimensions' )
                            local cropLong = math.max( cropDim.width, cropDim.height )
                            local expLong
                            
                            -- ###2 long dim may be wrong dim.
                            
                            -- ideally, it'd be nice to know if quality will be lost due to size of smart preview.
                            local color
                            
                            if exportSettings.LR_size_doConstrain then
                                if exportSettings.LR_size_resizeType == 'longEdge' then
                                    if cropDim.width > cropDim.height then
                                        expLong = exportSettings.LR_size_maxWidth
                                    else
                                        expLong = exportSettings.LR_size_maxHeight
                                    end
                                elseif exportSettings.LR_size_resizeType == 'shortEdge' then
                                    if cropDim.width > cropDim.height then
                                        expLong = exportSettings.LR_size_maxWidth
                                    else
                                        expLong = exportSettings.LR_size_maxHeight
                                    end
                                elseif exportSettings.LR_size_resizeType == 'dimensions' then
                                    if cropDim.width > cropDim.height then
                                        expLong = exportSettings.LR_size_maxWidth
                                    else
                                        expLong = exportSettings.LR_size_maxHeight
                                    end
                                elseif exportSettings.LR_size_resizeType == 'wh' then
                                    if cropDim.width > cropDim.height then
                                        expLong = exportSettings.LR_size_maxWidth
                                    else
                                        expLong = exportSettings.LR_size_maxHeight
                                    end
                                elseif exportSettings.LR_size_resizeType == 'megapixels' then
                                    local spPixels
                                    local origPixels = origDim.width * origDim.height
                                    if origDim.width > origDim.height then
                                        spPixels = spMax * ( spMax * origDim.height / origDim.width )
                                    else
                                        spPixels = spMax * ( spMax * origDim.width / origDim.height )
                                    end
                                    local expPixels = exportSettings.LR_size_megapixels * 1000000
                                    expLong = cropLong * expPixels / origPixels
                                else -- should never happen
                                    Debug.pause()
                                    self:logW( "Unexpected resize-type: ^1", exportSettings.LR_size_resizeType )
                                    expLong = origLong -- for lack of something better to set it to.
                                end
                            else -- no resizing. ###3 LR_size_userWantsConstrain ???
                                expLong = cropLong
                            end

                            props['ena_'..i] = true

                            local spLong
                            local diffFactor
                            if origLong <= spMax then
                                spLong = origLong
                            else
                                spLong = spMax
                            end
                            
                            --[[                                        
                                        srcPixelSf = orig/sp -- source pixel scale factor.
                                        outPixelSf = crop/exp
                                        
                                        spPixels = cropDim / srcPixelSf = crop/orig * sp
                                        
                                        orig = 5000:
                                        ============
                                        crop = 2500, sp = 2500 => spPixels = 1250
                                        ------------
                                        exp = 625:
                                        o: downsample x 8.
                                        c: downsample x 2.
                                        
                                        exp = 1250:
                                        o: downsample x 4.
                                        c: samesample x 1.
                                        
                                        exp = 2500:
                                        o: downsample x 2.
                                        c: upsample x 2.
                                        
                                        exp = 5000:
                                        o: samesample x 1.
                                        c: upsample x 4.
                                        
                                        exp = 10000
                                        o: upsample x 2.
                                        c: upsample x 8.                                        
                                        
                                        o = orig / exp-size
                                        c = spPixels / exp-size
                                        
                                        
                                --]]
                                
                            local spPixels = (cropLong/origLong) * spLong
                            diffFactor = spPixels / expLong
                            
                            if diffFactor >=1 then
                                color = LrColor( 'black' ) -- only calling attention to upsizers
                                --Debug.pause( "down", expLong, spLong, origLong, cropLong, diffFactor )
                                blacks[#blacks + 1] = i
                                blackSet[photo] = true
                            else
                                --Debug.pause( "up", expLong, spLong, origLong, cropLong, diffFactor )
                                local red
                                if diffFactor > .8 then
                                    red = .2 -- barely noticeable as red, but noticebly different than black.
                                elseif diffFactor > .6 then
                                    red = .4 -- easily noticeable, but not obnoxiously red
                                elseif diffFactor > .4 then
                                    red = .6 -- pretty dang red but not blaring
                                elseif diffFactor > .2 then
                                    red = .8 -- very red, but not fully red.
                                else -- >= 3
                                    red = 1 -- full-on red.
                                end                                
                                color = LrColor( red, 0, 0 )
                                reds[#reds + 1] = i
                                redSet[photo] = true
                            end
                            
                            local diffFactor2 = spLong / expLong
                            local percent_1, cropTitle
                            if cropLong == origLong then -- uncropped.
                                assert( diffFactor == diffFactor2, "bad diffactor" )
                                percent_1 = str:fmtx( "^1%", math.floor( diffFactor * 100 ) )
                                cropTitle = "(uncropped)"
                            else -- cropped
                                percent_1 = str:fmtx( "^1%", math.floor( diffFactor * 100 ) )
                                cropTitle = str:fmtx( "(^1 x ^2)", cropDim.width, cropDim.height )
                            end
                            
                            si[#si + 1] = vf:row {
                                LrView.conditionalItem( thumbSize > 0,
                                    vf:catalog_photo {
                                        photo = photo,
                                        width = thumbSize, -- ###3 might be a nice touch to down-throttle thumb size based on total number to present (return to double-loop..).
                                        height = thumbSize,
                                }),
                                vf:checkbox {
                                    bind_to_object = props,
                                    value = bind( 'ena_'..i ),
                                    text_color = color,
                                    title = cache:getRawMetadata( photo, 'path' ),
                                    width = share "col_1",                                
                                },
                                vf:static_text {
                                    text_color = color,
                                    title = percent_1,
                                    width = share "col_2",  
                                },
                                vf:static_text {
                                    text_color = color,
                                    title = cropTitle,
                                    width = share "col_3",  
                                },
                            }
                            
                        else -- no smart preview
                            app:displayError{ disp="File does not exist and no smart preview - not OK to export.", log="Missing photo file: '^1' - no smart preview, so can't export.", file }
                            ok = false
                        end
                    -- else file exists, ignoring smart preview info.
                    end
                end
                if not ok then
                    self:log( "Export aborted since one or more photos was offline with no smart preview available." )
                    return
                end
                
                if #si > 0 then
                    si.width = 800
                    si.height = 500
                    local masterEnaToglView = vf:row {
                        vf:checkbox {
                            bind_to_object = props,
                            value = bind 'masterEnaTogl',
                            title = "Master Enable/Disable",
                            tooltip = str:fmtx( "Enable/Disable all ^1 (enable means export smart preview, disable means don't export it).", #si ),                            
                        },
                        vf:spacer{ fill_horizontal=1 },
                        vf:checkbox {
                            bind_to_object = props,
                            value = bind 'redsEnaTogl',
                            title = "Enable/Disable reds",
                            tooltip = str:fmtx( "Enable/Disable all ^1 (those having less than full quality, size-wise)", str:nItems( #reds, "reds" ) ),                            
                        },
                    }
                    view:setObserver( props, 'masterEnaTogl', SourcePhotoConsiderations, function( id, p, k, v )
                        for i, photo in ipairs( photos ) do
                            props['ena_'..i] = v
                        end
                    end )
                    view:setObserver( props, 'redsEnaTogl', SourcePhotoConsiderations, function( id, p, k, v )
                        for j = 1, #reds do
                            props['ena_'..reds[j]] = v
                        end
                    end )
                    local ai = {}
                    ai[#ai + 1] = vf:row {
                        vf:push_button {
                            title = "Help",
                            action = function( button )
                                local p = {} -- paragraphs
                                p[#p + 1] = "By \"export smart preview\" I mean \"export offline photo, using smart preview as the source of original image data\"."
                                p[#p + 1] = "100% means exporting smart preview is same as exporting original, pixel-size-wise.\n>100% means there is headroom - smart previews are being downsized to satisfy export dimensions.\n<100% (red) means pixel interpolation (upsizing) must be performed when exporting smart previews, thus quality is being lost.\n(crop dimensions are presented if photos is cropped)."
                                p[#p + 1] = "See \"web help\" for details."
                                dia:quickTips( p ) -- if array, default is double-linefeed (paragraph) separator.
                            end,
                        },
                        vf:spacer { fill_horizontal = 1 },
                        vf:checkbox {
                            title = "Pre-clear collections",
                            bind_to_object = prefs,
                            value = app:getPrefBinding( 'preClearColls' ), -- default preset
                            enabled = useColls,
                            tooltip = "If checked, before commencing with export, smart preview collections will be emptied, so what's in 'em will be fresh. If unchecked, smart previews exported or skipped will be added to existing contents.",
                        },
                    }
                    local vi = { vf:scrolled_view( si ), masterEnaToglView  }
                    
                    --   P R E S E N T   P R O M P T
                    local button = app:show{ confirm="You are about to export ^1 (of ^2 being exported) - go for it? (sans unchecked photos), or abort the export?",
                        subs = { str:nItems( #si, "smart previews" ), str:nItems( #photos, "total photos" ) },
                        viewItems = vi,
                        accItems = ai,
                        buttons = { dia:btn( "Go For It", 'ok' ), dia:btn( "Abort The Export", 'cancel' ) },
                    }
                    if button == 'ok' then
                        local c = 0
                        self:log( "Exporting smart previews - approved..." )

                        if useColls and app:getPref( 'preClearColls' ) then -- default preset
                            assert( spFullColl and spSubColl and spDisColl, "no coll" )
                            local s, m = cat:update( 30, "Clear Smart Preview Collections", function( context, phase )
                                spFullColl:removeAllPhotos()
                                spSubColl:removeAllPhotos()
                                spDisColl:removeAllPhotos()
                            end )
                            if s then
                                self:log( "Smart preview export collections pre-cleared." )
                            else
                                self:logE( "Unable to pre-clear collections - ^1", m )
                            end
                        else
                            self:log( "Smart preview collections not pre-cleared - photos will be added \"cumulatively\", if added." )
                        end

                        -- photos for collections:
                        local spFull = {}
                        local spSub = {}
                        local spDis = {}   
                        for i, photo in ipairs( photos ) do
                            if props['ena_'..i] then -- export
                                --self:log( "ena ^1", i )
                                if blackSet[photo] then
                                    spFull[#spFull + 1] = photo
                                elseif redSet[photo] then
                                    spSub[#spSub + 1] = photo
                                else
                                    --Debug.pause()
                                end
                            elseif props['ena_'..i] == false then -- disabled
                                --self:log( "dis ^1", i )
                                skipRender[photo] = true
                                if redSet[photo] or blackSet[photo] then
                                    spDis[#spDis + 1] = photo
                                else
                                    --Debug.pause()
                                end
                                c = c + 1
                            else
                                -- not sp-only
                            end
                        end
                        if useColls then
                            if #spFull > 0 or #spSub > 0 or #spDis > 0 then
                                local s, m = cat:update( 30, "Add Photos to Smart Preview Export Collections", function( context, phase )
                                    if #spFull > 0 then
                                        spFullColl:addPhotos( spFull )
                                    end
                                    if #spSub > 0 then
                                        spSubColl:addPhotos( spSub )
                                    end
                                    if #spDis > 0 then
                                        spDisColl:addPhotos( spDis )
                                    end
                                end )
                                if s then
                                    self:log( "Photos added to smart preview collections." )
                                    spCollOk = true -- used to prompt to go to sp collections upon completion.
                                else
                                    self:logE( "Unable to add photos to smart preview collections - ^1", m )
                                end
                            else
                                Debug.pause() -- this shouldn't ever happen.
                                self:log( "No photos for collections." )
                            end
                        -- else don't
                        end
                        
                        if c == #photos then -- skipping all                                  
                            self:logW( "Skipping all smart previews." )
                            -- reminder: we're skipping all smart-previews, NOT all photos - export must be allowed to continue
                            -- the normal error message box will show which smart previews weren't exported due to "error" (skipped).
                            -- see below for explanation of why it's best not to try and skip rendering after s.p. prompt has been dismissed.
                        end
                        
                    elseif button =='cancel' then
                        local s, m = self:cancelExport()
                        if s then
                            self:log( "Export canceled since photos are offline and smart previews not acceptable - note: you may still get an error logged, since photos were not rendered as expected." )
                        else
                            self:logW( "Export canceled since photos are offline and smart previews not acceptable, however some renditions could not be skipped - photos went \"downstream\" - unstoppable..." )
                        end
                        return
                    else
                        error( "bad button" )
                    end
                else
                    self:log( "No exporting files are smart-preview only." )
                end
            else
                self:logW( "Smart previews are not supported in Lr^1", app:lrVersion() ) -- disabled in UI if not lr5+, but still possible to be present in export preset..
                -- proceed
            end
        -- else nada
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
        if exportSettings.confirmSmartPreviews then
            renditions = {}
            for i, rend in ipairs( candidates ) do
                if not smartPreviewSet[rend.photo] or not skipRender[rend.photo] then -- not smart preview, or maybe smart preview but not skipping.
                    renditions[#renditions + 1] = rend
                    -- else there will be an error: not rendered... - dunno how jf get's around such error: seems down-stream export service is hell-bent on having photos
                    -- exported and will complain if filename not present in final expected destination - hmm...
                --[[ This clause removed (10/Nov/2013 21:08) - because of the smart preview prompt, some renditions will have already started (despite not having entered the main renditions loop),
                --  thus it's better to skip none than hit n' miss.
                    elseif smartPreviewSet[rend.photo] and skipRender[rend.photo] then -- smart preview, and skipping
                        local s, m = LrTasks.pcall( rend.skipRender, rend )
                        if s then
                            self:logW( "*** Smart preview rendition skipped." )
                        else
                            self:logW( m )
                        end
                    else
                        Debug.pause( '?' )
                    --]]
                -- else there will no doubt be an error box - containing "skipped" smart preview photos.
                end
            end
            --Debug.pause( #renditions )--, renditions[1].photo:getFormattedMetadata( 'fileName' ) ) --, renditions[2].photo:getFormattedMetadata( 'fileName' ) )
        else
            renditions = candidates
        end
        renditionOptions.renditionsToSatisfy = renditions
        
        if exportSettings.snapEna then
            local masterCopyName
            local time = LrDate.currentTime()
            local snapName
            local snapFmt = exportSettings.snapFmt or "%V - %Y-%m-%d %H:%M:%S as exported." -- same as default, just in case user nil'd it somehow, but still has snap-ena set.
            local updInPlace = true -- document.
            local dyn
            if snapFmt:find( "%%V" ) then
                masterCopyName = app:getPref{ name='masterCopyName', presetName=exportSettings.pluginManagerPreset, default="Master" }
                dyn = true
            elseif snapFmt:find( "%%v" ) then
                masterCopyName = nil
                dyn = true
            else
                if str:is( exportSettings.snapFmt ) then
                    snapName = LrDate.timeToUserFormat( time, snapFmt )
                else
                    snapName = "Prior to Export"
                end
            end
            local nSnaps = 0
            local s, m = cat:update( 30, "Pre-export snapshots", function( context, phase )
                for i, rend in ipairs( renditions ) do
                    repeat
                        local photo = unionCache:getRawMetadata( rend.photo, 'fileFormat' ) ~= 'VIDEO' and rend.photo or nil
                        if not photo then
                            break
                        end
                        if dyn then -- snap-name is dynamic
                            local isVirt = photo:getRawMetadata( 'isVirtualCopy' ) -- batch? - ###3, but reminder: there is not yet an array of photos at the ready, just an array of renditions.
                            local copyName
                            if isVirt then
                                copyName = photo:getFormattedMetadata( 'copyName' )
                            else
                                copyName = masterCopyName
                            end
                            if masterCopyName then
                                snapName = snapFmt:gsub( "%%V", copyName )
                            else
                                snapName = snapFmt:gsub( "%%v", copyName or "" )
                            end
                            snapName = LrDate.timeToUserFormat( time, snapName ) -- does fine even if no time formatters - just passes text through.
                        -- else - snap-name is fixed.
                        end
                        local ok = photo:createDevelopSnapshot( snapName, updInPlace ) -- should never return false if upd-in-place is true
                        if ok then
                            nSnaps = nSnaps + 1
                        else
                            error( "snaphot creation failed" )
                        end
                    until true
                end
            end )
            if s then
                self:log( "^1 created.", str:nItems( nSnaps, "pre-export snapshots" ) )
                --LrTasks.sleep( 30 ) -- definitely happening prior to render - dunno how jf is doin' it..
            else
                self:logE( "Unable to create pre-export snapshots - ^1", m )
                -- too far along to try and abort? ###3
                return
            end
        else
            self:log( "^1 to be rendered (no pre-export snapshots taken).", str:nItems( #renditions, "photos" ) )
        end
        
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
                local success, pathOrMessage
                -- reminder: skip-render when export in progress is problematic.
                local srcPhotoPath = unionCache:getRawMetadata( srcPhoto, 'path' )
                -- note: nothing special to do for videos here.
                success, pathOrMessage = sourceRendition:waitForRender()
                if success then -- exported virtual copy or waited for upstream to render..
                    if exportSettings.postMetaEna then
                        postMetaPhotos[#postMetaPhotos + 1] = srcPhoto or error( "no src photo" )
                    -- else no comment..
                    end
                    
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
        self:log()
        exifTool:closeSession( call.ets )
        if call.status then
            self:logV( "No error thrown." )
            
            -- Post-export Metadata:
            if tab:isNotEmpty( postMetaPhotos ) then
                local s, m = cat:update( 30, "Apply post-export settings to source photos", function( context, phase )
                    local i1 = ( phase - 1 ) * 1000 + 1 -- do 1000 at a time.
                    local i2 = math.min( phase * 1000, #postMetaPhotos )
                    for i = i1, i2 do
                        local srcPhoto = postMetaPhotos[i]
                        if postMetaPresetId then
                            srcPhoto:applyMetadataPreset( postMetaPresetId ) -- doc doesn't say what happens if problem, or if anything's returned, but it does throw error if problem, e.g. with preset ID.
                        end
                        if postMetaSetPick then
                            srcPhoto:setRawMetadata( 'pickStatus', 1 )
                        end
                        if postMetaClearPick then
                            srcPhoto:setRawMetadata( 'pickStatus', 0 )
                        end
                        if tab:isNotEmpty( postMetaClearKeywords ) then
                            for i, k in ipairs( postMetaClearKeywords ) do
                                srcPhoto:removeKeyword( k )
                            end
                        end
                    end
                    if i2 < #postMetaPhotos then
                        return false -- continue to next phase.
                    else -- last phase
                        if str:is( postMetaCollect ) then
                            if postMetaColls then
                                for i, coll in ipairs( postMetaColls ) do
                                    coll:addPhotos( postMetaPhotos )
                                end
                                self:log( "^1 added to collections: ^2", str:nItems( #postMetaPhotos, "photos" ), postMetaCollect )
                            else
                                self:logE( "Post-export metadata collections have not been initialized." )
                            end
                        end
                    end
                end )
                if s then
                    self:log( "Applied post-export settings to source photos." )
                else
                    self:logE( "Unable to apply post-export settings to source photos - ^1", m )
                end
            -- else no such photos.
            end
            
            -- Confirm Smart Previews:
            if spCollOk then -- photos added to sp collections (won't be set unless all other pre-reqs were met).
                local sources = catalog:getActiveSources()
                local srcSet = tab:createSet( sources )
                if not srcSet[spFullColl] or not srcSet[spSubColl] or not srcSet[spDisColl] then
                    local button = app:show{ confirm="Photos were added to smart preview export collections - wanna go there now?",
                        buttons = dia:buttons( 'YesNo' ), -- "no" is memorable too.
                        actionPrefKey = "Go to smart preview collections",
                    }
                    if button == 'ok' then
                        assert( spFullColl and spSubColl and spDisColl, "no sp coll" )
                        catalog:setActiveSources{ spFullColl, spSubColl, spDisColl }
                        self:logV( "Smart preview collections should be active photo sources." )
                    else
                        self:logV( "User chose not to visit smart preview collections." ) -- nothing got "canceled".
                    end
                else
                    self:log( "Smart preview collections are already selected." )
                end
            -- else nuthin'.
            end
        else -- call ended prematurely due to error.
            app:show{ error=call.message } -- no finale dialog box?
        end
        self:log()
        
    end } )
end



function SourcePhotoConsiderations.startDialog( props )
    local filter = ExtendedExportFilter.assureFilter( SourcePhotoConsiderations, props )
    filter:startDialogMethod()
end


function SourcePhotoConsiderations.endDialog( props )
    local filter = ExtendedExportFilter.assureFilter( SourcePhotoConsiderations, props )
    if filter.keywords then
        filter.keywords:stopInit()
    else
        Debug.pause( "no keywords object to stop initing" )
    end
end



function SourcePhotoConsiderations.sectionForFilterInDialog( vf, props )
    local filter = ExtendedExportFilter.assureFilter( SourcePhotoConsiderations, props )
    return filter:sectionForFilterInDialogMethod()
end



-- reminder: update status filter function need not be implemented, as long as ID passed to listener reg func is this class.
--[[
function SourcePhotoConsiderations.updateFilterStatus( id, props, name, value )
    local filter = ExtendedExportFilter.assureFilter( SourcePhotoConsiderations, props )
    filter:updateFilterStatusMethod( name, value )
end
--]]



function SourcePhotoConsiderations.shouldRenderPhoto( props, photo )
    local filter = ExtendedExportFilter.assureFilter( SourcePhotoConsiderations, props )
    return filter:shouldRenderPhotoMethod( photo )
end



--- Post process rendered photos.
--
function SourcePhotoConsiderations.postProcessRenderedPhotos( functionContext, filterContext )
    local filter = ExtendedExportFilter.assureFilter( SourcePhotoConsiderations, filterContext.propertyTable, { functionContext=functionContext, filterContext=filterContext } )
    filter:postProcessRenderedPhotosMethod()
end



SourcePhotoConsiderations.exportPresetFields = {
	{ key = 'spcEna', default = false },
	{ key = 'confirmSmartPreviews', default = false },
	{ key = 'postMetaEna', default = false },
	{ key = 'postMetaPreset', default = nil },
	{ key = 'postMetaSetPick', default = false },
	{ key = 'postMetaClearKeywords', default = "" },
	{ key = 'postMetaClearPick', default = false },
	{ key = 'postMetaCollect', default = "" },
	{ key = 'saveXmp', default = false }, -- upon export, implied.
	{ key = 'snapEna', default = false }, -- snapshot enable.
	{ key = 'snapFmt', default = "%V - %Y-%m-%d %H:%M:%S as exported." }, -- snapshot format.
}



SourcePhotoConsiderations:inherit( ExtendedExportFilter ) -- inherit *non-overridden* members.



return SourcePhotoConsiderations
