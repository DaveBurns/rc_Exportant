--[[
        Miscellaneous.lua
--]]


local Miscellaneous, dbg, dbgf = ExtendedExportFilter:newClass{ className='Miscellaneous', register=true }



local dialogEnding -- end of export dialog box.



--- Constructor for extending class.
--
function Miscellaneous:newClass( t )
    return ExtendedExportFilter.newClass( self, t )
end



--- Constructor for new instance.
--
function Miscellaneous:new( t )
    local o = ExtendedExportFilter.new( self, t )
    o.enablePropName = 'miscEna'
    return o
end



function Miscellaneous:assureBottom( actionExpr, cancelExpr )
    local filters, first, last, total, names = self:getFilters()
    local lastId = filters[last]
    if lastId == self.id then -- reminder: no guarantee bottom-most absolutely, since filters from other plugins may be below.
        self:log( "This filter is lowest of all those from this plugin - no telling whether there are filters from other plugins below it. Anyway it's a good sign, since it probably should be lowest, since app/service-compat is enabled.." )
    else
        -- reminder: main filter dumps whole list to log file, always.
        local lastName = names[last]
        assert( str:is( lastName ), "no last name" )
        
        -- note: although filter order was already logged, by main, it's being done again here, albeit verbosely, since there is a possible anomaly which is having attention called to.
        local uiTidbit = str:fmtx( "\n \nFilters from this plugin (mostly):\n-------------------------------------\n" )
        local b = {}
        for i, name in ipairs( names ) do
            self:logV( "Filter #^1: ^2", i, filters[i] or name )
            b[#b + 1] = str:fmtx( "^1: ^2", i, name )
        end
        uiTidbit = uiTidbit..table.concat( b, "\n" ).."\n \n*** Order may make a difference in result." -- reminder: export service, although present in preset, is not copied to settings.
        local button = app:show{ confirm="'^1' is not bottom filter, '^2' or a filter from some other plugin is lowest. This configuration *may* not be optimal, since app/service-compatability is enabled (downstream export filter may write final rendition non-atomically, causing the problem the app/service-compat option is designed to thwart).^3\n \nSo, ^4 regardless, or ^5?",
            subs = { self.filterName, lastName, uiTidbit, LrStringUtils.lower( actionExpr ), LrStringUtils.lower( cancelExpr ) },
            buttons = { dia:btn( actionExpr, 'ok' ), dia:btn( cancelExpr, 'cancel', false ) },
            actionPrefKey = str:fmtx( "^1 - filter position", self.filterName ),
        }
        if button == 'ok' then
            self:log( "Not bottom - ok I guess.." )
        else
            self:log( "Not bottom - not going with it.." )
            return -- nil - no go..
        end
    end 
    return true -- proceed
end



function Miscellaneous:updatePluginPresetDependentItems()
    local props = self.exportSettings
    props.enableDeleteOriginals = app:getPref{ name='enableDeleteOriginalsAfterExport', presetName=props.pluginManagerPreset, default=false } -- seems there was a prop togl thing I invented for convenience, but don't remember details now. ###2
    -- property actually controls visibility, not enable/disable.
end



--- This function will check the status of the Export Dialog to determine 
--  if all required fields have been populated.
--
function Miscellaneous:updateFilterStatusMethod( name, value )

    local props = self.exportSettings

    app:call( Call:new{ name=str:fmtx( "^1 - Update Filter Status", self.filterName ), async=true, guard=App.guardSilent, main=function( context )

        -- base class method no longer of concern once overridden in extended class.

        repeat -- once
        
            if not props.miscEna then
                self:allowExport( "^1 is disabled.", self.filterName )
                break
            else
                app:assurePrefSupportFile( props.pluginManagerPreset )
                self:allowExport()
            end
            
        	-- Process changes to named properties.
        	
        	if name ~= nil then
        	
        	    -- named property has changed
                if name == 'deleteOriginalsAfterExport' then
                    if value then
                        if WIN_ENV then
                            local button = app:show{ confirm="Are you sure you want to delete the original after exported copy has been created? - if unsure: click 'No'",
                                buttons = { dia:btn( "Yes", 'ok' ), dia:btn( "No", 'cancel' ) },
                                -- NO ACTION PREF KEY
                            }
                            if button ~= 'ok' then
                                props.deleteOriginalsAfterExport = false
                            end
                        else -- this never happens, since option is disable on mac, but cheap insurance...
                            app:show{ warning="Not yet implemented on Mac" }
                            props.deleteOriginalsAfterExport = false
                        end
                    -- else ok
                    end
                elseif name == 'pluginManagerPreset' then
                    self:updatePluginPresetDependentItems()
                end
                
            end

            if props.dropboxCompat or ( props.LR_format == 'JPEG' and ( props.jpegOptimize or props.jpegProgressive ) ) then
                if props.LR_collisionHandling == 'overwrite' then
                    -- all-systems go for dbcompat, except maybe filter order.
                    if not dialogEnding then -- this check is required to prevent double-prompting - once when this is called upon closing (not sure why it is, but it is), and again in post-process-photos method.
                        local status = self:assureBottom( "Leave App/Service Compatibility Enabled", "Disable App/Service Compatibility" )
                        if not status then
                            props.dropboxCompat = false
                            props.jpegOptimize = false
                            props.jpegProgressive = false
                        -- else ok..
                        end                    
                    end
                else
                    if str:is( props.LR_publish_connectionName ) then
                        props.LR_collisionHandling = 'overwrite'
                    elseif dia:isOk( "Collision handling must be set to 'Overwrite WITHOUT WARNING' in 'Export Location' section. Want me to go ahead and set that for you, if so, then click 'OK', (or would you prefer to do it yourself? - if so, then click 'Cancel'). Note: if 'Export Location' section is not accessible, you'll have to let this plugin do it, if that's OK. If not OK, then you'll have to uncheck ^1.", 'App/service Compatibility' ) then
                        props.LR_collisionHandling = 'overwrite'
                    else
                        self:denyExport( "Collision handling must be set to 'Overwrite WITHOUT WARNING' in 'Export Location' section, or uncheck 'App/service Compatibility'." )
                        break
                    end
                end
            -- else ..
            end
            
            if props.resizePercentEnabled then
            	if props.resizePercent == nil then
            	    self:denyExport( "*** Enter 'Resize by' percent (or disable percent resizing)." )
            	    break
            	end
        	    if props.LR_size_doConstrain then
        	        -- good
        	    else
        	        self:denyExport( "'Resize to Fit' must be checked  (or disable percent resizing)." )
        	        break
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
function Miscellaneous:startDialogMethod()

    local props = self.exportSettings
        
	view:setObserver( props, 'pluginManagerPreset', Miscellaneous, Miscellaneous.updateFilterStatus )
	
	view:setObserver( props, 'miscEna', Miscellaneous, Miscellaneous.updateFilterStatus )
	view:setObserver( props, 'matchModifiedTime', Miscellaneous, Miscellaneous.updateFilterStatus )
	view:setObserver( props, 'matchCreatedTime', Miscellaneous, Miscellaneous.updateFilterStatus )
	view:setObserver( props, 'deleteOriginalsAfterExport', Miscellaneous, Miscellaneous.updateFilterStatus )
	view:setObserver( props, 'dropboxCompat', Miscellaneous, Miscellaneous.updateFilterStatus )
	view:setObserver( props, 'jpegOptimize', Miscellaneous, Miscellaneous.updateFilterStatus )
	view:setObserver( props, 'jpegProgressive', Miscellaneous, Miscellaneous.updateFilterStatus )
	
	view:setObserver( props, 'resizePercent', Miscellaneous, Miscellaneous.updateFilterStatus )
	view:setObserver( props, 'resizePercentEnabled', Miscellaneous, Miscellaneous.updateFilterStatus )
	
	-- not needed so far:
	--view:setObserver( props, 'longAsShortEdge', Miscellaneous, Miscellaneous.updateFilterStatus )
	--view:setObserver( props, 'LR_format', Miscellaneous, Miscellaneous.updateFilterStatus )
	
	view:setObserver( props, 'LR_size_resizeType', Miscellaneous, Miscellaneous.updateFilterStatus )
	view:setObserver( props, 'LR_size_megapixels', Miscellaneous, Miscellaneous.updateFilterStatus )
	view:setObserver( props, 'LR_size_maxWidth', Miscellaneous, Miscellaneous.updateFilterStatus )
	view:setObserver( props, 'LR_size_maxHeight', Miscellaneous, Miscellaneous.updateFilterStatus )
	view:setObserver( props, 'LR_size_doNotEnlarge', Miscellaneous, Miscellaneous.updateFilterStatus )
	
	view:setObserver( props, 'LR_collisionHandling', Miscellaneous, Miscellaneous.updateFilterStatus )
	view:setObserver( props, 'LR_exportFiltersFromThisPlugin', Miscellaneous, Miscellaneous.updateFilterStatus )
	
	self:updateFilterStatusMethod() -- async/guarded.

end




--- This function will create the section displayed on the export dialog 
--  when this filter is added to the export session.
--
function Miscellaneous:sectionForFilterInDialogMethod()

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
		vf:spacer { width = share( labelWidth ) },
		vf:checkbox {
		    title = self.title,
		    value = bind 'miscEna',
		    width = share 'misc_width',
		},
	}
	it[#it + 1] = vf:row {
		vf:spacer { width = share( labelWidth ) },
		vf:separator { width = share 'misc_width' },
	}
	space( 7 )
	
	-- reminder if things depend on other disabled things, then there's a deadlock.
    local resizeByEnabled = bind {
        keys = { 'miscEna', 'LR_size_doConstrain' },
        operation = function()
            if props.miscEna and props.LR_size_doConstrain then
                return true
            else
                return false
            end
        end,
    }
    local resizePercentEnabled = bind {
        keys = { 'miscEna', 'resizePercentEnabled', 'LR_size_doConstrain', 'megapixelsDivisor'  },
        operation = function()
            if props.miscEna and props.resizePercentEnabled and props.LR_size_doConstrain and not props.megapixelsDivisor then
                return true
            else
                return false
            end
        end,
    }
	it[#it + 1] = 
		vf:row {
			vf:checkbox {
				title = "Resize by",
				value = bind 'resizePercentEnabled',
				width = share( labelWidth ),
				enabled = resizeByEnabled,
			},
			vf:edit_field {
				value = bind 'resizePercent',
				tooltip = "Scale cropped width and height by this percent.",
				width_in_digits = 4,
				width = share 'data_num_width',
				min = -1000,
				max = 1000,
				precision = 0,
				enabled = resizePercentEnabled,
			},
			vf:static_text {
				title = "%   Width and height entered in 'Image Sizing'\nsection above will be ignored. Megapixels is also\nbased on actual image dimensions...",
				enabled = resizePercentEnabled,
			},
		}
		
	it[#it + 1] = vf:row {
		vf:checkbox {
		    title = "Progressive JPEG format",
		    value = bind 'jpegProgressive',
			width = share( labelWidth ),
		    enabled = bind {
        	    keys = { 'miscEna', 'LR_format' },
        	    operation = function()
        	        if props.LR_format == "JPEG" then
        	            return props.miscEna
        	        else
        	            return false
        	        end
        	    end,
        	},
		    tooltip = "Losslessly transform your jpeg into progressively displayable format - supported by most but not all jpeg display software.\n \n*** Progressive jpegs are *always* optimized.",
		},
		vf:checkbox {
		    title = "Optimize Jpegs",
			value = bind 'jpegOptimize',
		    enabled = bind {
        	    keys = { 'miscEna', 'LR_format', 'jpegProgressive' },
        	    operation = function()
        	        if props.LR_format == "JPEG" then
        	            return props.miscEna and not props.jpegProgressive
        	        else
        	            return false
        	        end
        	    end,
        	},
			tooltip = [[
Check this option if you want jpegs *losslessly* optimized. Optimized means "image data cleverly made smaller" - there will be NO metadata loss nor image quality degradation and decompression will be just as fast if not faster. The downside is just the time it takes to do the optimization when exporting: a fraction of a second per image.

This feature has the side effect that jpegs exported in Lr5.5 will be readable by DPP4 and other apps that aren't happy with Lr5.5 jpegs. It might help in other cases too - dunno..]],
		},
	}
	it[#it + 1] = 
	    vf:row {
    		vf:static_text {
    		    title = "Maintain Capture Time",
    		    width = share( labelWidth ),
    		    enabled = bind 'miscEna',
    		},
    		vf:checkbox {
    		    title = "Last Modified Date",
    			value = bind 'matchModifiedTime',
    			tooltip = "if checked, last-modified time (of exported files) will be set to match date-time/original of source photo.",
    		    enabled = bind 'miscEna',
    		},
    		vf:checkbox {
    		    title = "File Created Date",
    			value = bind 'matchCreatedTime',
    			tooltip = "if checked, creation time (of exported files) will be set to match date-time/original of source photo.",
    		    enabled = bind 'miscEna',
    		}
    	}
	local megaPixDivEna = bind {
	    keys = { 'miscEna', 'LR_size_doConstrain', 'LR_size_resizeType', 'megapixelDivisorEnabled', 'resizePercentEnabled' },
	    operation=function( binder, value, toUi )
	        return props.miscEna and props.LR_size_doConstrain and props.LR_size_resizeType == 'megapixels' and props.megapixelDivisorEnabled and not props.resizePercentEnabled
	    end,
	}
	it[#it + 1] = 
		vf:row {
			vf:checkbox {
				title = "Enable Megapixels Divisor",
				value = bind 'megapixelDivisorEnabled',
				width = share( labelWidth ),
				enabled = bind {
				    keys = { 'miscEna', 'LR_size_doConstrain', 'LR_size_resizeType', 'resizePercentEnabled' },
				    operation=function( binder, value, toUi )
				        return props.miscEna and props.LR_size_resizeType == 'megapixels' and props.LR_size_doConstrain and not props.resizePercentEnabled and not props.megapixelsDivisor
				    end,
				}
			},
			vf:edit_field {
				value = bind 'megapixelDivisor',
				tooltip = "'Image Sizing' megapixels will be divided by this number. For example, if divisor is 1000 and you enter 300 megapixels, it will be interpreted as 300 kilopixels. To enter 750 kilopixels, set divisor to 100 and enter 75 megapixels, etc...",
				width_in_digits = 6,
				width = share 'data_num_width',
				min = 1,
				max = 999999,
				precision = 0,
				enabled = megaPixDivEna,
			},
			vf:static_text {
				title = "Divide megapixels by this number.",
				enabled = megaPixDivEna,
			},
		}
	local longShortEnaBinding = bind {
        keys = { 'miscEna', 'LR_format', 'LR_size_doConstrain', 'LR_size_resizeType', 'resizePercentEnabled' },
        operation = function()
            return props.miscEna and props.LR_format == 'DNG' and  props.LR_size_doConstrain and props.LR_size_resizeType == 'longEdge' and not props.resizePercentEnabled
        end,
	}
	it[#it + 1] = 
		vf:row {
			vf:checkbox {
				title = "Interpret long as short edge",
				value = bind 'longAsShortEdge',
				width = share( labelWidth ),
				tooltip = "Interprets value entered for long edge, as specifying dimension for short edge.",
				enabled = longShortEnaBinding,
			},
			vf:static_text {
				title = "Use when exporting lossy DNGs if you'd rather specify short edge.",
				enabled = longShortEnaBinding,
			},
		}
	it[#it + 1] = 
		vf:row {
			vf:checkbox {
				title = "App/service compatibility",
				value = bind 'dropboxCompat',
				width = share( labelWidth ),
				tooltip = "Check this box if there are any problems with exported files experienced in conjunction with other apps/processes/services. Originally developed to solve Lr/dropbox incompatibility introduced in February 2013 (not an issue anymore), but still useful to avoid other similar problems.",
				enabled = bind 'miscEna',
			},
			vf:static_text {
				title = "Eliminates the potential for corrupt or zero-byte export files\nwhich can occur if an asynchronous process attempts to access\nexporting file before it's finished being exported.",
				enabled = bind 'miscEna',
			},
		}
		
	self:updatePluginPresetDependentItems() -- sets ena-del-orig prop

    space()
	it[#it + 1] = 
		vf:row {
			vf:checkbox {
				title = "Delete Originals After Export",
				value = bind 'deleteOriginalsAfterExport',
				width = share( labelWidth ),
				visible = bind 'enableDeleteOriginals',
				enabled = bind 'miscEna',
			},
			vf:static_text {
				title = "If you are unsure about this setting, leave it unchecked!",
				visible = bind 'enableDeleteOriginals',
				enabled = bind 'miscEna',
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
function Miscellaneous:shouldRenderPhotoMethod( photo )

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
function Miscellaneous:postProcessRenderedPhotosMethod()

    local functionContext, filterContext = self.functionContext, self.filterContext -- convenience vars, available in finale method too.
    local exportSettings = filterContext.propertyTable

    local originalsToDelete = {} -- originals are deleted in finale method, if approved by user...
        
    app:call( Service:new{ name=str:fmtx( "^1 - Post Process Rendered Photos", self.filterName ), preset=exportSettings.pluginManagerPreset, progress=true, main=function( call )
    
        assert( exportSettings, "no es" )
        
        if exportSettings.miscEna then
            self:log( "Filter is enabled." )
        else
            self:log( "Filter is disabled, so it won't do anything." )
            self:passRenditionsThrough()
            return
        end

        local destToSatisfy = {}        -- to support app/service compatability: photo key, file-path (which needs to be satisfied) value.
        
        local photos, videos, union, candidates, unionCache = self:initPhotos{ rawIds={ 'fileFormat' }, call=call }
        if not photos then
            return
        end
        
        local status = self:requireMainFilterInPost()
        if not status then
            return
        end
        
        if exportSettings.dropboxCompat or ( exportSettings.LR_format == 'JPEG' and ( exportSettings.jpegOptimize or exportSettings.jpegProgressive ) ) then
            local status = self:assureBottom( "Proceed", "Abort" )
            if not status then
                local s, m = self:cancelExport()
                if s then
                    self:log( "Aborted (you may still get an error logged, since photos were not rendered as expected)." )
                else
                    self:logW( "Some renditions could not be skipped." )
                end
                return -- nil - canceled..
            end
        -- else x
        end

        -- save initial values for settings that will be overwritten (and need to be referred to of course).
        local initialResizeType = exportSettings.LR_size_resizeType
        local initialMaxWidth = exportSettings.LR_size_maxWidth
        local initialMaxHeight = exportSettings.LR_size_maxHeight -- or max-single-dim
        local initialMegapixels = exportSettings.LR_size_megapixels
        local initialDoNotEnlarge = exportSettings.LR_size_doNotEnlarge
        
        -- load static prefs..
        local dimFixOffset = app:getPref{ name='dimFixOffset', presetName=exportSettings.pluginManagerPreset, default=.4 }
        
        local renditionOptions = {
            plugin = _PLUGIN, -- ###3 I have no idea what this does, or if it's better to set it or not (usually it's not set).
            --renditionsToSatisfy = renditions, -- filled in below.
            filterSettings = function( renditionToSatisfy, exportSettings )
                -- note: these export settings are a parameter which supercedes initial export settings initially in filter context (they represent the current, possibly modified, values)
                -- to assure the right thing is done, a shallow copy of initial settings was made under a different name.
                
                local photo = renditionToSatisfy.photo or error( "no photo" )
                
                -- reminder: you can't change 'LR_tokenCustomString' at this point - I guess export service needs it fixed since renditionToSatisfy filename is fixed.
                local newPath = renditionToSatisfy.destinationPath -- by default return unmodified.
                self:log( "Rendition path: ^1", newPath )
                
                if exportSettings.resizePercentEnabled then
                    app:assert( exportSettings.resizePercent, "Resize percent must not be blank." )
                    if exportSettings.LR_size_doConstrain then
                        local dims = photo:getRawMetadata( 'croppedDimensions' )
                        if exportSettings.LR_size_resizeType == 'megapixels' then
                            local megapixels = ( dims.width * dims.height * exportSettings.resizePercent ) / 100000000 
                            exportSettings.LR_size_megapixels =  megapixels
                        else            
                            local w = math.ceil( dims.width * exportSettings.resizePercent / 100 )
                            local h = math.ceil( dims.height * exportSettings.resizePercent / 100 )
                            exportSettings.LR_size_maxWidth = w
                            exportSettings.LR_size_maxHeight = h
                  	    --else
                        --    app:error( "Unexpected resize type: ^1", exportSettings.LR_size_resizeType )
                  	    end
                  	else
                  	    self:logW( "No point in checking \"Resize by Percent\" without constraining size, and choosing dimensions vs. megapixels..." ) -- this usually does not happen, since UI checks.
                  	end
                end
                
                -- may have some catch-22 here ###1
                if exportSettings.megapixelDivisorEnabled and exportSettings.LR_size_resizeType == 'megapixels' and not exportSettings.resizePercentEnabled then
                    local megapixels = initialMegapixels / ( exportSettings.megapixelDivisor or 1 )
                    if exportSettings.LR_size_megapixels ~= megapixels then
                        app:logV( "Changing megapixels from ^1 to ^2", exportSettings.LR_size_megapixels, megapixels )
                        exportSettings.LR_size_megapixels = megapixels -- note: another approach is to pre-compute the value and re-use, it need not be dynamic ###3
                    else
                        -- already been done..
                    end
                end
                
                -- note: dropbox compat is redundent when exporting as virtual copy or doing image magick conversion.
                if ( exportSettings.dropboxCompat or ( exportSettings.LR_format == 'JPEG' and ( exportSettings.jpegOptimize or exportSettings.jpegProgressive ) ) ) and newPath then
                    assert( newPath == renditionToSatisfy.destinationPath, "path skew" ) -- this filter no longer skewing.
                    -- export to temp dir and move atomically, to solve problem with dropbox compatibility that began in February 2013.
                    destToSatisfy[renditionToSatisfy.photo] = newPath
                    local fn = LrPathUtils.leafName( newPath )
                    local dir = LrPathUtils.parent( newPath )
                    local newDir = LrPathUtils.getStandardFilePath( 'temp' )
                    newPath = LrPathUtils.child( newDir, fn )
                    if newDir then
                        newPath = LrFileUtils.chooseUniqueFileName( newPath )
                    else
                        self:logE( "No temp dir" )
                        destToSatisfy[renditionToSatisfy.photo] = nil
                        newPath = renditionToSatisfy.destinationPath
                    end
                end

                if exportSettings.longAsShortEdge and exportSettings.LR_format=='DNG' and exportSettings.LR_size_doConstrain and initialResizeType=='longEdge' and not exportSettings.resizePercentEnabled then
                    local dims = photo:getRawMetadata( 'dimensions' ) -- note: lossy DNGs are sorta like a hybrid export - image will be resized according to non-cropped dimensions, then relative crop is carried over as an adjustment.
                    local longEdgeSizeSpecified = initialMaxHeight
                    local edgeRatio
                    if dims.width > dims.height then -- width is the long edge, height is the short edge
                        edgeRatio = dims.width / dims.height
                    else -- height is the long edge, width is the short edge
                        edgeRatio = dims.height / dims.width
                    end
                    exportSettings.LR_size_maxHeight = longEdgeSizeSpecified * edgeRatio
                    --Debug.pause( initialMaxWidth, initialMaxHeight, exportSettings.LR_size_maxHeight )
                else
                    --Debug.pause( exportSettings.longAsShortEdge )
                end
                    
                return newPath
                
            end, -- end of rendition filter function
        } -- closing rendition options
        

        local renditions
        renditions = candidates
        renditionOptions.renditionsToSatisfy = renditions
        
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
                if success then -- exported virtual copy or waited for upstream to render..
                    self:logV()
                    self:logV( "Source photo '^1' was rendered to '^2'", srcPhotoPath, pathOrMessage )
                    if exportSettings.dropboxCompat or ( exportSettings.LR_format == 'JPEG' and ( exportSettings.jpegOptimize or exportSettings.jpegProgressive ) ) then
                        if destToSatisfy[srcPhoto] then -- a pre-requisite..
                            assert( pathOrMessage ~= destToSatisfy[srcPhoto], "oops - move to self?" )
                            if ( exportSettings.LR_format == 'JPEG' and ( exportSettings.jpegOptimize or exportSettings.jpegProgressive ) ) then -- jpeg-tran'ing satisfies dropbox-compat purpose too.
                                local p = "-copy all"
                                if exportSettings.jpegProgressive then
                                    p = p.." -progressive" -- progressive + optimize (implied).
                                elseif exportSettings.jpegOptimize then -- only
                                    p = p.." -optimize" -- optimize
                                end
                                -- *** will overwrite if dest file already exists:
                                local s, m
                                if WIN_ENV then
                                    s, m = jpegTran:executeCommand( p, { pathOrMessage, destToSatisfy[srcPhoto] } )
                                else
                                    s, m = jpegTran:executeCommand( p, pathOrMessage, destToSatisfy[srcPhoto] )
                                end
                                if s then
                                    self:logV( "Exported file jpeg-tran'd (atomically) to final destination - optimized and/or progressive, for dpp4/other-picky-app compatibility etc.." )
                                    pathOrMessage = renditionToSatisfy.destinationPath -- pretend that's where Lr put it in the first place...
                                else
                                    self:logE( "Unable to jpeg-tran exported file to final destination - ^1", m )
                                    break
                                end
                            else
                                local overwrite
                                if str:is( exportSettings.LR_publish_connectionName ) or ( exportSettings.LR_collisionHandling == 'overwrite' ) then -- better make this a "dropbox compatibility" option (? ###2).
                                    overwrite = true
                                else
                                    self:logE( "Must be allowed to overwrite existing files - check in export dialog box." )
                                    break
                                end
                                self:logV( "Moving '^1' to '^2'", pathOrMessage, destToSatisfy[srcPhoto] )
                                -- Disk:moveFile( sourcePath, destPath, createDestDirsIfNecessary, overwriteDestFileIfNecessary, avoidUnnecessaryUpdate, timeCheckIsEnough )
                                local eq = str:isEqualIgnoringCase( destToSatisfy[srcPhoto], srcPhotoPath )
                                if eq then -- exp dest file is same as source photo file - not ok..
                                    renditionToSatisfy:renditionIsDone( false, "This filter does not support overwriting source photo file: "..srcPhotoPath ) -- no need for additional W/E logging here.
                                    break
                                end
                                local s, m = fso:moveFile( pathOrMessage, destToSatisfy[srcPhoto], true, overwrite ) -- this is the "end of the line" for dest-to-satisfy.
                                if s then
                                    self:logV( "Exported file moved (atomically) to final destination - for external app/service compatibility." )
                                    pathOrMessage = renditionToSatisfy.destinationPath -- pretend that's where Lr put it in the first place...
                                else
                                    self:logE( "Unable to move exported file to final destination (for external app/service compatibility) - ^1", m )
                                    break
                                end
                            end
                        else
                            Debug.pause( "No dest to satisfy." )
                            self:logV( "No dest to satisfy, so dropbox or dpp4 compatibility setting ignored." ) -- nor expected if one of the other options like custom folder/filenaming usurpted.
                        end
                    end
                    if exportSettings.matchModifiedTime or exportSettings.matchCreatedTime then
                        local time = srcPhoto:getRawMetadata( 'dateTimeOriginal' )
                        if not time then
                            self:logW( "Unable to obtain date-time original metadata for source photo - using modification date of source file instead." )
                            time = fso:getFileModificationDate( srcPhotoPath )
                        end
                        if time then
                            local args = { file=pathOrMessage }
                            if exportSettings.matchModifiedTime then
                                args.modifiedTime = time
                            end
                            if exportSettings.matchCreatedTime then
                                args.createdTime = time
                            end
                            local s, cm, c = app:changeFileDates( args )
                            if s then
                                self:logV( "Changed file dates via command: ^1", cm )
                            else
                                self:logW( "unabled to change file dates - ^1", cm )
                                renditionToSatisfy:renditionIsDone( false, "unable to change file dates - see log file for more info." ) 
                                break
                            end
                        else
                            self:logE( "No modifictaion date of source file." )                            
                        end
                    end
                    
                    renditionToSatisfy:renditionIsDone( true ) -- control error message: keeps it from blaming the export filter for "failed" export.
                    if exportSettings.deleteOriginalsAfterExport then -- applies to virtual copies too.
                        if app:getPref( 'enableDeleteOriginalsAfterExport', exportSettings.pluginManagerPreset ) then
                            originalsToDelete[#originalsToDelete + 1] = srcPhoto -- { srcPhoto=srcPhoto, srcPhotoPath=srcPhotoPath, exportedFile=pathOrMessage } -- delete the satisfied rendition in honor of the renamed rendition.
                        else
                            -- this doesn't normally happen, since prop not presented if not pref, but there's presets which may bypass UI..
                            self:logV( "not recording original to delete since \"enable delete originals after export\" pref is not set." )
                        end
                    -- else keep quiet.                    
                    end                    
                    
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
            if #originalsToDelete > 0 then
                -- @4/Nov/2013 4:50 - not sure why I'm not just using the cat:deletePhotos method (I think it may have even been born from this code here!?:).
                app:call( Call:new{ name="Delete Originals after Export", async=true, main=function( _call )
                    -- I *think* the reason they are not deleted when rendition is done is because there is no guarantee *all* processing (downstream) has been successfully completed.
                    app:show{ info="*After* export is complete (as indicated by progress bar in upper left area of Lightroom), dismiss this dialog box." }
                    self:log()
                    self:log( "Deleting originals after export:" )
                    local s, m = cat:selectPhotos( nil, originalsToDelete, true, nil ) -- nil => keep current selection if possible, but if not...; true => assure-folders; nil => no metadata cache.
                    if s then
                        if app:getPref( 'splatDeleteOk', exportSettings.pluginManagerPreset ) then
                            if WIN_ENV then
                                app:initGlobalPref( 'fiddleTime', 3 ) -- I want this short as default, so user knows what's happening fairly quickly the first time - he/she can always increase.
                                self:log()
                                local button
                                repeat
                                    --call:setCaption( "Dialog box needs your attention..." )
                                    button = app:show{ confirm="*** Splat-delete is enabled. If you click 'Yes...', then after dismissing this dialog box, all selected photos will be permanently deleted, or moved to recycle bin.\n \n*** If you are not 100% sure you want to do this, then click 'No...'.\n \n*** Note: If there are other dialog boxes under this one (you'll have to move it around to check), or any other impediments (see documentation on plugin web page), automatic deletion of selected photos will not work. If that is the case, you must dismiss this dialog box for a few seconds in order to close those other dialog boxes (preferably permanently, so you don't have problems in the future), or eliminate other impediments before clicking 'Yes...', or click 'No...' to abort.\n \n*** Reminder: virtual copies will disappear along with their masters, even if not selected.",
                                        accItems = {
                                            vf:push_button {
                                                title = "Dismiss for",
                                                action = function( button )
                                                    LrDialogs.stopModalWithResult( button, 'fiddle' )
                                                end,
                                                tooltip = "Click this button to dismiss this dialog box temporarily, so you can dismiss dialog boxes underneath it, and/or eliminate any other potential impediments...",
                                            },
                                            vf:edit_field {
                                                bind_to_object = prefs,
                                                value = app:getGlobalPrefBinding( 'fiddleTime' ),
                                                width_in_digits = 2,
                                                precision = 0,
                                                min = 1,
                                                max = 99,
                                                tooltip = "Enter estimated time you will need to fiddle...",
                                            },
                                            vf:static_text {
                                                title = "seconds",
                                            },
                                            vf:spacer {
                                                width = 5,
                                            },
                                        },
                                        --buttons = { dia:btn( str:fmtx( "Yes - delete selected photos", app:getAppName() ), 'ok' ), dia:btn( "Show Log File", 'other'), dia:btn( "No - do not delete", 'cancel', false ) },
                                        buttons = { dia:btn( str:fmtx( "Yes - delete selected photos", app:getAppName() ), 'ok' ), dia:btn( "No - do not delete", 'cancel', false ) },
                                        actionPrefKey = "SPLAT DELETE OK - CONFIRM DELETION OF ORIGINAL PHOTOS",
                                    }
                                    if button == 'ok' then
                                        break
                                    --elseif button == 'other' then
                                    --    app:showLogFile()
                                    elseif button == 'cancel' then
                                        self:log( "Splat delete option rejected - nothing deleted - consider disabling splat-delete in advanced settings." )
                                        return
                                    elseif button == 'fiddle' then
                                        local remaining = app:getGlobalPref( 'fiddleTime' ) or 3
                                        app:sleep( remaining, 1, function()
                                            remaining = remaining - 1
                                            --call:setCaption( "Dialog will reappear in ^1", str:nItems( remaining, "seconds" ) )
                                        end )
                                        if shutdown then return end
                                    else
                                        app:error( "pgm fail" )
                                    end
                                until false
                                assert( button=='ok', "button not ok" )
                                local s, m = app:sendWinAhkKeys( "{Ctrl Down}{Shift Down}{Alt Down}{Delete}{Alt Up}{Shift Up}{Ctrl Up}" ) -- yield after.
                                if s then
                                    self:log( "*** Originals were deleted using splat-delete." )
                                else
                                    self:logE( m )
                                end
                            else
                                app:show{ info="Splat delete not yet implemented on Mac. Original photos to be deleted should be selected now - after dismissing this dialog box, go ahead and delete manually.",
                                    actionPrefKey = "No splat delete on Mac yet",
                                }
                            end
                        else
                            if WIN_ENV then
                                app:show{ info="Original photos to be deleted should be selected now - after dismissing this dialog box, go ahead and delete manually. To have original photos deleted automatically after export, edit advanced settings file and set 'splatDeleteOk' to true.",
                                    actionPrefKey = "No splat delete on Mac yet",
                                }
                            else
                                app:show{ info="Original photos to be deleted should be selected now - after dismissing this dialog box, go ahead and delete manually.",
                                    actionPrefKey = "No splat delete on Mac yet",
                                }
                            end
                        end
                    else
                        self:logE( m )
                    end
                    self:log()
                end } )
            else
                self:logV( "no originals to delete" )
            end
            
        else -- call ended prematurely due to error.
            app:show{ error=call.message } -- no finale dialog box?
        end
        self:log()
        
    end } )
end



function Miscellaneous.startDialog( props )
    dialogEnding = false
    local filter = ExtendedExportFilter.assureFilter( Miscellaneous, props )
    filter:startDialogMethod()
end



function Miscellaneous.sectionForFilterInDialog( vf, props )
    local filter = ExtendedExportFilter.assureFilter( Miscellaneous, props )
    return filter:sectionForFilterInDialogMethod()
end



-- No need for a method, just set upvalue flag.
function Miscellaneous.endDialog()
    dialogEnding = true
end



-- reminder: update status filter function need not be implemented, as long as ID passed to listener reg func is this class.
--[[
function Miscellaneous.updateFilterStatus( id, props, name, value )
    local filter = ExtendedExportFilter.assureFilter( Miscellaneous, props )
    filter:updateFilterStatusMethod( name, value )
end
--]]



function Miscellaneous.shouldRenderPhoto( props, photo )
    local filter = ExtendedExportFilter.assureFilter( Miscellaneous, props )
    return filter:shouldRenderPhotoMethod( photo )
end



--- Post process rendered photos.
--
function Miscellaneous.postProcessRenderedPhotos( functionContext, filterContext )
    local filter = ExtendedExportFilter.assureFilter( Miscellaneous, filterContext.propertyTable, { functionContext=functionContext, filterContext=filterContext } )
    filter:postProcessRenderedPhotosMethod()
end



Miscellaneous.exportPresetFields = {
	{ key = 'miscEna', default = false }, -- makes sense to have default be enabled, upon initial insertion: user can disable if such becomes desirable.
	{ key = 'matchModifiedTime', default = false },
	{ key = 'matchCreatedTime', default = false },
	{ key = 'resizePercent', default = 50 },
	{ key = 'resizePercentEnabled', default = false },
	{ key = 'megapixelDivisorEnabled', default = false },
	{ key = 'megapixelDivisor', default = 1000 },
	{ key = 'longAsShortEdge', default = false },
	{ key = 'currentTime', default = 'dateOmit' },
	{ key = 'dateFormat', default = "%Y-%m-%d_%H-%M-%S" },
	{ key = 'dropboxCompat', default = false },
	{ key = 'jpegOptimize', default = false },
	{ key = 'jpegProgressive', default = false },
	{ key = 'deleteOriginalsAfterExport', default = false },
}



Miscellaneous:inherit( ExtendedExportFilter ) -- inherit *non-overridden* members.



return Miscellaneous
