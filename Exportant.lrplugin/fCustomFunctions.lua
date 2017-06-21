--[[
        CustomFunctions.lua
--]]


local CustomFunctions, dbg, dbgf = ExtendedExportFilter:newClass{ className='CustomFunctions', register=true }






--- Constructor for extending class.
--
function CustomFunctions:newClass( t )
    return ExtendedExportFilter.newClass( self, t )
end



--- Constructor for new instance.
--
function CustomFunctions:new( t )
    local o = ExtendedExportFilter.new( self, t )
    o.enablePropName = 'customFuncEna'
    return o
end



--- This function will check the status of the Export Dialog to determine 
--  if all required fields have been populated.
--
function CustomFunctions:updateFilterStatusMethod( name, value )

    local props = self.exportSettings

    app:call( Call:new{ name=str:fmtx( "^1 - Update Filter Status", self.filterName ), async=true, guard=App.guardSilent, main=function( context )

        -- base class method no longer of concern once overridden in extended class.

        repeat -- once

            if not props.customFuncEna then
                self:allowExport( "^1 is disabled.", self.filterName )
                break
            else
                app:assurePrefSupportFile( props.pluginManagerPreset )
                self:allowExport()
            end
            
        	-- Process changes to named properties.
        	
        	if name ~= nil then
        	
        	    -- named property has changed

                if name == '' then
                end
                
            end

            if props.customFuncEna then
                if props.customExportCheck then
                    local func = app:getPref( 'okToExport', props.pluginManagerPreset ) -- dont throw error if bad type.
                    if func then
                        if type( func ) ~= 'function' then
                            self:denyExport( "'okToExport' must be a function (in advanced settings)" )
                            break
                        end
                    else
                        self:denyExport( "You need to define 'okToExport' function in advanced settings." )       
                        break
                    end
                end
                
                if props.customExportFunc then
                    local func = app:getPref( 'customExportFunc', props.pluginManagerPreset ) -- dont throw error if bad type.
                    if func then
                        if type( func ) ~= 'function' then
                            self:denyExport( "'customExportFunc' must be a function (in advanced settings)" )
                            break
                        end
                    else
                        self:denyExport( "You need to define 'customExportFunc' function in advanced settings." )       
                        break
                    end
                end
                
                if props.customPostExportFunc then
                    local func = app:getPref( 'customPostExportFunc', props.pluginManagerPreset ) -- dont throw error if bad type.
                    if func then
                        if type( func ) ~= 'function' then
                            self:denyExport( "'customPostExportFunc' must be a function (in advanced settings)" )
                            break
                        end
                    else
                        self:denyExport( "You need to define 'customPostExportFunc' function in advanced settings." )       
                        break
                    end
                end
                
                if props.customVideoExportFunc then
                    local func = app:getPref( 'customVideoExportFunc', props.pluginManagerPreset ) -- dont throw error if bad type.
                    if func then
                        if type( func ) ~= 'function' then
                            self:denyExport( "'customVideoExportFunc' must be a function (in advanced settings)" )
                            break
                        end
                    else
                        self:denyExport( "You need to define 'customVideoExportFunc' function in advanced settings." )       
                        break
                    end
                end
            -- else X
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
function CustomFunctions:startDialogMethod()

    local props = self.exportSettings

	view:setObserver( props, 'pluginManagerPreset', CustomFunctions, CustomFunctions.updateFilterStatus )
	
	view:setObserver( props, 'customFuncEna', CustomFunctions, CustomFunctions.updateFilterStatus )
	view:setObserver( props, 'customExportCheck', CustomFunctions, CustomFunctions.updateFilterStatus )
	view:setObserver( props, 'customExportFunc', CustomFunctions, CustomFunctions.updateFilterStatus )
	view:setObserver( props, 'customPostExportFunc', CustomFunctions, CustomFunctions.updateFilterStatus )
	view:setObserver( props, 'customVideoExportFunc', CustomFunctions, CustomFunctions.updateFilterStatus )
	
	view:setObserver( props, 'LR_exportFiltersFromThisPlugin', CustomFunctions, CustomFunctions.updateFilterStatus )

	self:updateFilterStatusMethod() -- async/guarded.

end




--- This function will create the section displayed on the export dialog 
--  when this filter is added to the export session.
--
function CustomFunctions:sectionForFilterInDialogMethod()

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
        vf:spacer{ width=share( labelWidth ) },
        vf:checkbox {
            title = str:fmtx( "^1 (requires editing \"advanced settings\")", self.title ),
            value = bind 'customFuncEna',
            width = share 'cf_ena_width',
        },
	}
	it[#it + 1] = vf:row {
		vf:spacer { width = share( labelWidth ) },
		vf:separator { width = share 'cf_ena_width' },
	}
	space( 7 )
	it[#it + 1] = 
		vf:row {
			vf:checkbox {
				title = "Custom Export Check",
				value = bind 'customExportCheck',
				width = share( labelWidth ),
				tooltip = "Check this box if you've implemented a custom export checking function in advanced settings that you want in play (otherwise, leave it unchecked).",
				enabled = bind 'customFuncEna',
			},
			vf:static_text {
				title = "If checked, your custom export pre-checking function will get\ncalled for each item (photo or video) prior to exporting,\nto see if item should be exported.",
				enabled = bind 'customFuncEna',
			},
		}
	it[#it + 1] = 
		vf:row {
			vf:checkbox {
				title = "Custom Export Function",
				value = bind 'customExportFunc',
				width = share( labelWidth ),
				tooltip = "Check this box if you've implemented a custom export function in advanced settings that you want in play (otherwise, leave it unchecked).",
				enabled = bind 'customFuncEna',
			},
			vf:static_text {
				title = "If checked, your custom export function will get called for each\nphoto (not video) *before* it's been exported.",
				enabled = bind 'customFuncEna',
			},
		}
	it[#it + 1] = 
		vf:row {
			vf:checkbox {
				title = "Custom Post-Export Func",
				value = bind 'customPostExportFunc',
				width = share( labelWidth ),
				tooltip = "Check this box if you've implemented a custom post-export function in advanced settings that you want in play (otherwise, leave it unchecked).",
				enabled = bind 'customFuncEna',
			},
			vf:static_text {
				title = "If checked, your custom post-export function will get called for\neach photo (not video) *after* it's been exported.",
				enabled = bind 'customFuncEna',
			},
		}
	it[#it + 1] = 
		vf:row {
			vf:checkbox {
				title = "Custom Video Export",
				value = bind 'customVideoExportFunc',
				width = share( labelWidth ),
				tooltip = "Check this box if you've implemented a custom video export function in advanced settings that you want in play (otherwise, leave it unchecked).",
				enabled = bind 'customFuncEna',
			},
			vf:static_text {
				title = "If checked, your custom video export function will get called for\neach video *after* it's been exported.",
				enabled = bind 'customFuncEna',
			},
		}
	--[[
	space()
    it[#it + 1] = 
		vf:row {
			vf:spacer {
				width = share( labelWidth ),
			},
			vf:push_button {
				title = "Metadata ID's -> Clipboard...",
				enabled = bind 'customFuncEna',
				action = function( button )
				    app:pcall{ name=button.title, async=true, guard=App.guardSilent, main=function( call )
				        local text = lrMeta:getHelpText{ format='idPlusFriendly' }
				        --dialog:putTextOnClipboard{ title="Copy ID help info to Clipboard", contents=contents, dataName = "Lr Metadata ID info" }    
                        local props = LrBinding.makePropertyTable( call.context )
                        --props.copied = false
                        local order = true
                        props.what = 'both'
                        props.text = text
                        local vi = {} -- no bind-to object
                        vi[#vi + 1] = vf:edit_field {
                            bind_to_object = props,
                            value = bind 'text',
                            width_in_chars = 80,
                            height_in_lines = 27,
                        }
                        local s = {}
                        s[#s+1] = "Copy to clipboard if you want to."
                        s = table.concat( s, '\n' )
                        vi[#vi + 1] = vf:static_text {
                            title = s
                        }
                        local ch = function( id, _props, key, value )
                            local text
                            if props.what == 'both' then
                                if order then
                                    text = lrMeta:getHelpText{ format='idPlusFriendly' }
                                else
                                    text = lrMeta:getHelpText{ format='friendlyPlusId' }
                                end
                            else
                                text = lrMeta:getHelpText{ format=props.what }
                            end
                            props.text = text
                        end
                        view:setObserver( props, 'what', CustomFunctions, ch )
                        local ai={}
                        ai[#ai + 1] = vf:row {
                            vf:radio_button {
                                title = "IDs",
                                bind_to_object = props,
                                value = bind 'what',
                                checked_value = 'idOnly',
                            },
                            vf:radio_button {
                                title = "Names",
                                bind_to_object = props,
                                value = bind 'what',
                                checked_value = 'friendlyOnly',
                            },
                            vf:radio_button {
                                title = "Both",
                                bind_to_object = props,
                                value = bind 'what',
                                checked_value = 'both',
                            },
                            vf:push_button {
                                title = "Swap",
                                action = function()
                                    order = not order
                                    ch()
                                end,
                                bind_to_object = props,
                                enabled = LrBinding.keyEquals( 'what', 'both' ),
                            },
                        }
                        button = app:show{ info="Lightroom metadata IDs and/or names.",
                            viewItems = vi,
                            accItems = ai,
                        }
				        
				    end }
				end,
			},
		}
	--]]
	
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
function CustomFunctions:shouldRenderPhotoMethod( photo )

    local exportSettings = self.exportSettings or error( "no es" )
    --assert( exportSettings, "no es" )

    --Debug.lognpp( exportSettings )
    --Debug.showLogFile()

    
    if exportSettings.customFuncEna then
        -- proceed
    else
        return true -- pass-through if disabled.
    end
    
    -- fall-through => custom functions are enabled.
    
    if exportSettings.customExportCheck then
        local okToExport = app:getPref( 'okToExport', exportSettings.pluginManagerPreset ) -- expected type is pre-checked in UI.
        if okToExport then
            local ok, msg = okToExport { -- note: this function may be wired up to shared properties implementation of "is-finished" function.
                exportSettings = exportSettings,
                photo=photo, -- no cache: just wing it, one photo at a time...
            }
            if ok then
                if msg then
                    if exportSettings.stuff == nil then
                        exportSettings.stuff = {}
                    end
                    exportSettings.stuff[#exportSettings.stuff + 1] = { photo=photo, msg=msg, ok=true }
                    self:log( "probably ok to export (prompt first): ^1", msg )
                else
                    self:log( "ok to export - unconditionally" )
                end
                return true
            else
                if msg then
                    if exportSettings.stuff == nil then
                        exportSettings.stuff = {}
                    end
                    exportSettings.stuff[#exportSettings.stuff + 1] = { photo=photo, msg=msg, ok=false }
                    self:log( "maybe not ok to export (prompt first): ^1", msg )
                    return true
                else
                    self:log( "not ok to export - non-negotiable" )
                    return false
                end
            end
        else
            app:displayError( "No custom ok-to-export function defined in advanced settings." ) -- bezel, scope, and log.
            return false
        end
    end
    
    return true
    
end



--- Post process rendered photos (overrides base class).
--
--  @usage reminder: videos are not considered rendered photos (won't be seen by this method).
--
function CustomFunctions:postProcessRenderedPhotosMethod()

    local functionContext, filterContext = self.functionContext, self.filterContext
    local exportSettings = filterContext.propertyTable
    assert( exportSettings == self.exportSettings, "?" )
    
    local qExpCollOk
    local expColl
    local notExpColl

    app:call( Service:new{ name=str:fmtx( "^1 - Post Process Rendered Photos", self.filterName ), preset=exportSettings.pluginManagerPreset, progress=true, main=function( call )
    
        assert( exportSettings, "no es" )
        
        if exportSettings.customFuncEna then
            self:log( "Filter is enabled." )
        else
            self:log( "Filter is disabled, so it won't do anything." )
            self:passRenditionsThrough()
            return -- no-op if custom functions not enabled.
        end

        local omit = {}

        local photos, videos, union, candidates, unionCache = self:initPhotos{ rawIds={ 'path', 'fileFormat' }, fmtIds={ 'fileName' }, call=call }
        if not photos then
            return
        end        
           
        local status = self:requireMainFilterInPost()
        if not status then
            return
        end
        
        if exportSettings.stuff then
            -- note: set of stuff could be bigger than union set (since all prelimanary stuff went through ok-to-export, but was not necessarily passed-through for rendering due to other filter..).
            -- pair down stuff based on union set.
            
            local useColls = app:getPref{ name='useCollections', presetName=exportSettings.pluginManagerPreset, default=true }
            app:initPref( 'preClearColls', false )
            if useColls then
                expColl, notExpColl = cat:assurePluginCollections{ "Questionable Items Exported", "Questionable Items - NOT Exported" } -- or error.
            end
            -- "secondary" cache to support questionable item confirmation.
            --local cache = lrMeta:createCache{ photos=photos, rawIds={ 'path', 'smartPreviewInfo', 'isVirtualCopy', 'dimensions', 'croppedDimensions' }, fmtIds={ 'copyName' } } -- path is replicated, but facilitates get-photo-name-disp.
            
            local unionSet = tab:createSet( union )
            local stuff = {}
            for i, v in ipairs( exportSettings.stuff ) do
                if unionSet[v.photo] then
                    stuff[#stuff + 1] = v
                end
            end
            app:assert( exportSettings.customExportCheck, "how stuff sans custom-export-check" )
            local thumbSize = app:getPref{ name='thumbSize', default=64 }
            local props = LrBinding.makePropertyTable( functionContext )
            --Debug.pause( )
            local vi = {}
            local si = { width = 800, height = 600 }
            for i, rec in ipairs( stuff ) do
                props['export_'..i] = rec.ok
                si[#si + 1] = vf:row {
                    vf:catalog_photo {
                        photo = rec.photo or error( "no photo" ),
                        width = thumbSize,
                        height = thumbSize,
                        tooltip = unionCache:getFormattedMetadata( rec.photo, 'fileName' ),
                    },
                    vf:checkbox {
                        title = rec.msg or error( "no msg" ),
                        bind_to_object = props,
                        value = bind( 'export_'..i ),
                        width = share 'msg_width',
                        tooltip = unionCache:getRawMetadata( rec.photo, 'path' ),
                    },
                }
            end
            if #si > 0 then -- this happens if all questionable photos were pre-denied by other filters (e.g. due to smart preview prompt).
                props.masterEnaTogl = true
                vi[#vi + 1] = vf:scrolled_view( si )
                local ai = {}
                ai[#ai + 1] = vf:row {
                    vf:checkbox {
                        bind_to_object = props,
                        value = bind 'masterEnaTogl',
                        title = "Check/Uncheck",
                        tooltip = "Enable/Disable all items.",
                    },
                    vf:push_button {
                        title = "Restore Initial Checkmarks",
                        action = function()
                            for i, v in ipairs( stuff ) do
                                props['export_'..i] = v.ok
                            end
                        end,
                        tooltip = "Restore check-marks to initial state, that is: as was returned by 'okToExport' function.",
                    },
                }
                ai[#ai + 1] = vf:spacer{ fill_horizontal=1 }
                ai[#ai + 1] = vf:row {
                    vf:checkbox {
                        title = "Pre-clear collections",
                        bind_to_object = prefs,
                        value = app:getPrefBinding( 'preClearColls' ),
                        enabled = useColls,
                    },
                }
                view:setObserver( props, 'masterEnaTogl', CustomFunctions, function( id, props, key, value )
                    for i, v in ipairs( stuff ) do
                        props['export_'..i] = value
                    end
                end )
                Debug.pauseIf( #si ~= #stuff, "?" )
                local uiTidbit = ( #videos > 0 ) and "/videos" or ""
                local button = app:show{ info="Export checked photos^1? (^2 of ^3 are subject to consideration)",
                    subs = { uiTidbit, #stuff, #union },
                    buttons = { dia:btn( "Export Checked Photos", 'ok' ), dia:btn( "Cancel Export", 'cancel' ) },
                    viewItems = vi,
                    accItems = ai,
                }
                if button == 'ok' then

                    if useColls and app:getPref( 'preClearColls', exportSettings.pluginManagerPreset ) then
                        assert( expColl and notExpColl, "no coll" )
                        local s, m = cat:update( 30, "Clear Questionable Export Collections", function( context, phase )
                            expColl:removeAllPhotos()
                            notExpColl:removeAllPhotos()
                        end )
                        if s then
                            self:log( "Questionable export collections pre-cleared." )
                        else
                            self:logE( "Unable to pre-clear collections - ^1", m )
                        end
                    else
                        self:log( "Questionable export collections not pre-cleared - photos will be added \"cumulatively\", if added." )
                    end

                    -- photos for collections:
                    local expPhotos = {}
                    local notExpPhotos = {}
                    for i, rec in ipairs( stuff ) do
                        if props['export_'..i] then -- export
                            --self:log( "ena ^1", i )
                            expPhotos[#expPhotos + 1] = rec.photo
                        elseif props['export_'..i] == false then -- disabled
                            --self:log( "dis ^1", i )
                            notExpPhotos[#notExpPhotos + 1] = rec.photo
                        else
                            -- ?
                        end
                    end
                    --Debug.pause( #stuff, #expPhotos, #notExpPhotos )
                    if useColls then
                        if #expPhotos > 0 or #notExpPhotos > 0  then
                            local s, m = cat:update( 30, "Add Photos to Questionable Export Collections", function( context, phase )
                                if #expPhotos > 0 then
                                    expColl:addPhotos( expPhotos )
                                end
                                if #notExpPhotos > 0 then
                                    notExpColl:addPhotos( notExpPhotos )
                                end
                            end )
                            if s then
                                self:log( "Photos added to questionable export collections." )
                                qExpCollOk = true -- used to prompt to go to qe collections upon completion.
                            else
                                self:logE( "Unable to add photos to questionable export collections - ^1", m )
                            end
                        else
                            Debug.pause() -- this shouldn't ever happen.
                            self:log( "No photos for collections." )
                        end
                    -- else don't
                    end

                    for i, rec in ipairs( stuff ) do
                        if props['export_'..i] then
                            -- dont omit.
                        else
                            omit[rec.photo] = true
                        end
                    end
                else -- cancel button clicked.
                    local s, m = self:cancelExport()
                    if s then
                        self:log( "Export canceled." )
                    else
                        self:logW( m )
                    end
                    return
                end
            else
                self:logV( "Nothing to present prompt-wise." )
            end
        else
            self:logV( "No stuff." )
        end
        
        -- @v5, custom initialization function is serving custom (export) functions only.
        local initFunction = app:getPref{ name='initExport', presetName=exportSettings.pluginManagerPreset, expectedType='function' } -- no default.
        if initFunction then
            call.cache = lrMeta:createCache() -- create empty cache.
            local s, m = initFunction { -- may add everything it needs to cache.
                exportFilter = self,
                call = call,
                photos = photos,
                cache = call.cache,
                functionContext = functionContext,
                filterContext = filterContext,
                --exportSession = session,
                exportSettings = exportSettings,
            }
            if s then
                self:logV( "init ok" )
            elseif str:is( m ) then
                self:logW( m )
                local s, m = self:cancelExport()
                if s then
                    self:log( "Aborted (you may still get an error logged, since photos were not rendered as expected)." )
                else
                    self:logW( "Some renditions could not be skipped." )
                end
                return
            else
                self:logW( "init ok? - proceeding regardless..." )
            end
        end
        
        assert( gbl:getValue( 'createExifToolSession' ) ~= nil, "ets not init properly" )
        if createExifToolSession then -- global variable.
            call.ets = exifTool:openSession( self.filterName.."_"..LrUUID.generateUUID() ) -- deterministic session name not required unless "re-use existing session" is passed too.
            if not call.ets then
                error( "Unable to open exiftool session." )
            end
        end
    
        local renditionOptions = {
            plugin = _PLUGIN, -- ###3 I have no idea what this does, or if it's better to set it or not (usually it's not set).
            --renditionsToSatisfy = renditions, -- filled in below.
            filterSettings = function( renditionToSatisfy, exportSettings )
                assert( exportSettings, "no es" )
                assert( exportSettings.customFuncEna, "enable should be pre-checked" ) -- must be true
                
                -- fall-through => Custom functions are enabled.
                
                -- reminder: you can't change 'LR_tokenCustomString' at this point - I guess export service needs it fixed since renditionToSatisfy filename is fixed.
                local newPath = renditionToSatisfy.destinationPath -- by default return unmodified.
                self:log( "Rendition path: ^1", newPath )
                
                local photo = renditionToSatisfy.photo
                
                if exportSettings.customExportFunc then -- pre-export custom function is checked in UI.
                    local func = app:getPref{ name='customExportFunc', presetName=exportSettings.pluginManagerPreset, expectedType='function' } -- default is nil.
                    if func then -- pre-export custom function exists in advanced settings preferences.
                        local s, m = func {
                            renditionToSatisfy = renditionToSatisfy,
                            newPath = newPath, -- this is the rendition-to-satisfy destination path.
                            exportSettings = exportSettings,
                            exportFilter = self,
                            photo = photo,
                            -- cache = call.cache, - cache only present if init-function option specified - get from call object directly if you know it's there.
                            functionContext = functionContext,
                            filterContext = filterContext,
                            call = call,
                        }
                        if s then
                            self:logV( "Custom export function executed OK." )
                        else
                            self:logE( "Custom export function did not return successful status, error message - ^1", m or "none" )
                        end
                    else
                        self:logW( "Custom export function is missing - remedy by choosing different preset, or editing advanced settings of current preset." )
                    end
                end
                
                return nil -- newPath (this function won't change new-path - probably more efficient to return nothing than same thing: maybe saves a string-compare in Lr proper.
                -- ###3 consider this tiny optimization in the other filters.
                
            end, -- end of rendition filter function
        } -- closing rendition options
        
        local customPostExportFunc
        if exportSettings.customPostExportFunc then
            customPostExportFunc = app:getPref{ name='customPostExportFunc', presetName=exportSettings.pluginManagerPreset, expectedType='function' } -- default is nil.   
            assert( customPostExportFunc ~= nil, "setting but no custom post-export func" )
        -- else nada
        end
        
        local customVideoExportFunc
        if exportSettings.customVideoExportFunc then
            customVideoExportFunc = app:getPref{ name='customVideoExportFunc', presetName=exportSettings.pluginManagerPreset, expectedType='function' } -- dflt nil.
            assert( customVideoExportFunc ~= nil, "setting but no custom video export func" )
        -- else n.
        end        

        local renditions = {}
        for i, rend in ipairs( candidates ) do
            if not omit[rend.photo] then
                renditions[#renditions + 1] = rend
            -- else not much one can do: either omit from rendering, and take a generic error message, or wait for rendering and assign a better message.
            end
        end
        renditionOptions.renditionsToSatisfy = renditions
        
        -- Reminder: selective abortion beyond this point is hit n' miss, which is why renditions were paired down, if need be - granted Lr will still present the "skipped" ones in a box..

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
                
                if success then -- upstream filter or Lr delivered a rendered file.
                    self:logV()
                    self:logV( "Source photo '^1' was rendered to '^2'", srcPhotoPath, pathOrMessage )
                else -- problem exporting original, which in my case is due to something in metadata blocks that Lightroom does not like.
                    local errm = pathOrMessage or "?"
                    self:logW( "Unable to export '^1', error message: ^2. This may not cause a problem with this export, but may indicate a problem with this plugin, or with the source photo.", renditionToSatisfy.destinationPath, errm )
                        -- Note: if export is canceled, path-or-message can be nil despite success being false. ###3 - this may have been a flukey glitch - dunno.
                    renditionToSatisfy:renditionIsDone( false, errm.." - see warning in log file for more info." )
                    break
                end

                local fmt = unionCache:getRawMetadata( srcPhoto, 'fileFormat' )
                if fmt == 'VIDEO' then
                    if customVideoExportFunc then
                        app:call( Call:new{ name="Custom Video Export Function", main=function( context )
                            customVideoExportFunc { -- document change from previous version.
                                sourceRendition = sourceRendition,
                                renditionToSatisfy = renditionToSatisfy, 
                                exportedFilePath = pathOrMessage,
                                exportSettings = exportSettings,
                                photo = renditionToSatisfy.photo, -- photo is video.
                                -- cache = call.cache, - cache only present if init-function option specified - get from call object directly if you know it's there.
                                functionContext = functionContext,
                                filterContext = filterContext,
                                exportFilter = self,
                                call = call,
                            }
                        end, finale=function( call, status, message )
                            if status then
                                --
                            else
                                self:logE( message ) -- errors are not automatically logged for base calls, just services.
                                renditionToSatisfy:renditionIsDone( false, message )
                            end
                        end } )
                    -- else nuthin'
                    end
                else -- photo
                    if customPostExportFunc then
                        app:call( Call:new{ name="Custom Post-Export Function", main=function( context )
    
                            customPostExportFunc { -- no return.
                                sourceRendition = sourceRendition,
                                renditionToSatisfy = renditionToSatisfy,
                                -- source-rendition is absent, but dunno why @this.
                                exportedFilePath = pathOrMessage,
                                exportSettings = exportSettings,
                                photo = renditionToSatisfy.photo,
                                -- cache = call.cache, - cache only present if init-function option specified - get from call object directly if you know it's there.
                                functionContext = functionContext,
                                filterContext = filterContext,
                                exportFilter = self,
                                call = call,
                            }
                    
                        end, finale=function( call, status, message )
                            if status then
                                --
                            else
                                self:logE( message ) -- errors are not automatically logged for base calls, just services.
                                renditionToSatisfy:renditionIsDone( false, message )
                            end
                        end } )
                    -- else nuthin'
                    end
                end -- end of photo clause
                
            until true
        end
    end, finale=function( call )
        self:log()
        exifTool:closeSession( call.ets )
        if call.status then
            self:logV( "No error thrown." )
            -- Confirm Smart Previews:
            if qExpCollOk then -- photos added to sp collections (won't be set unless all other pre-reqs were met).
                local sources = catalog:getActiveSources()
                local srcSet = tab:createSet( sources )
                if not srcSet[expColl] or not srcSet[notExpColl] then
                    local button = app:show{ confirm="Photos were added to questionable export collections - wanna go there now?",
                        buttons = dia:buttons( 'YesNo' ), -- "no" is memorable too.
                        actionPrefKey = "Go to questionable export collections",
                    }
                    if button == 'ok' then
                        assert( expColl and notExpColl, "no qe coll" )
                        catalog:setActiveSources{ expColl, notExpColl }
                        self:logV( "Questionable export collections should be active photo sources." )
                    else
                        self:logV( "User chose not to visit questionable export collections." ) -- nothing got "canceled".
                    end
                else
                    self:log( "Questionable export collections are already selected." )
                end
            -- else nuthin'.
            end
            
        else -- call ended prematurely due to error.
            app:show{ error=call.message } -- no finale dialog box?
        end
        self:log()
        
    end } )
end



function CustomFunctions.startDialog( props )
    local filter = ExtendedExportFilter.assureFilter( CustomFunctions, props )
    filter:startDialogMethod()
end



function CustomFunctions.sectionForFilterInDialog( vf, props ) -- vf is being ignored in favor of global version - I sure hope that's OK. ###3
    local filter = ExtendedExportFilter.assureFilter( CustomFunctions, props )
    return filter:sectionForFilterInDialogMethod()
end



-- reminder: update status filter function need not be implemented, as long as ID passed to listener reg func is this class.
--[[
function CustomFunctions.updateFilterStatus( id, props, name, value )
    local filter = ExtendedExportFilter.assureFilter( CustomFunctions, props )
    filter:updateFilterStatusMethod( name, value )
end
--]]



function CustomFunctions.endDialog()
end


function CustomFunctions.shouldRenderPhoto( exportSettings, photo )
    local filter = ExtendedExportFilter.assureFilter( CustomFunctions, exportSettings )
    return filter:shouldRenderPhotoMethod( photo )
end

--- Post process rendered photos.
--
function CustomFunctions.postProcessRenderedPhotos( functionContext, filterContext )
    local filter = ExtendedExportFilter.assureFilter( CustomFunctions, filterContext.propertyTable, { functionContext=functionContext, filterContext=filterContext } )
    filter:postProcessRenderedPhotosMethod()
end



CustomFunctions.exportPresetFields = {
	{ key = 'customFuncEna', default = false },
	{ key = 'customExportCheck', default = false },
	{ key = 'customExportFunc', default = false },
	{ key = 'customPostExportFunc', default = false },
	{ key = 'customVideoExportFunc', default = false },
}



CustomFunctions:inherit( ExtendedExportFilter ) -- inherit *non-overridden* members.


return CustomFunctions
