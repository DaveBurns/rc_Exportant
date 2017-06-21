--[[
        CustomNaming.lua
--]]


local CustomNaming, dbg, dbgf = ExtendedExportFilter:newClass{ className='CustomNaming', register=true }



local dialogEnding
local folderTokenDefineDialogCloseFunction
local fileTokenDefineDialogCloseFunction



--- Constructor for extending class.
--
function CustomNaming:newClass( t )
    return ExtendedExportFilter.newClass( self, t )
end



--- Constructor for new instance.
--
function CustomNaming:new( t )
    local o = ExtendedExportFilter.new( self, t )
    o.enablePropName = 'customNaming'
    return o
end



--- This function will check the status of the Export Dialog to determine 
--  if all required fields have been populated.
--
function CustomNaming:updateFilterStatusMethod( name, value )

    local props = self.exportSettings

    app:call( Call:new{ name=str:fmtx( "^1 - Update Filter Status", self.filterName ), async=true, guard=App.guardSilent, main=function( call )

        -- base class method no longer of concern once overridden in extended class.

        repeat -- once
        
            if not props.customNaming then
                self:allowExport( "^1 is disabled.", self.filterName )
                break
            else
                app:assurePrefSupportFile( props.pluginManagerPreset )
                self:allowExport()
            end
            
            if props.pluginManagerPreset == "Giordano" then
                if not str:is( props.folderSubPath ) then
                    props.folderSubPath = "$C{greatGrandParentFolderName} $C{grandParentFolderName} JPEGS"
                end
            end
            
            local samplePhoto = cat:getAnyPhoto() -- just in case.
            
        	-- Process changes to named properties.
        	
        	if name ~= nil then

                if name == '' then
                end
                
            end

            -- process stuff not tied to change necessarily.
            -- note: export settings are not under same "filter ID" as before, so all previous version settings will be lost.
            
            -- note: custom naming section is enabled.
            if props.customFileNaming then
            
            	if props.LR_renamingTokensOn then
            	    if str:is( props.LR_tokens ) then
            	    
            	        if props.cnMetaEna then -- naming via dedicated metadata item
            	            
            	            if props.LR_tokens:find( "{com.adobe.", 1, true ) then -- usually but not always true, e.g. copy_name (written as 'copyName' ).
            	                if props.LR_tokens:find( props.cnMetaId, 12, true ) then -- ID would be after the com.adobe..
            	                    -- good
            	                else
                            	    app:show{ info="Usually, file naming tokens include chosen metadata item ID - your current file naming template, under the hood, token-wise, is '^1'. Tokens corresponding to the dedicated field you have chosen generally has '^2' in it - your call whether settings are copacetic, but there should be a file naming token which is at least similar to metadata field ID.",
                            	        subs = { props.LR_tokens, props.cnMetaId },
                            	        actionPrefKey = "File naming tokens usually include dedicated metadata item ID",
                            	    }
                                end  
                            else
                        	    app:show{ info="Usually, file naming tokens include '{com.adobe.' in them. Your current file naming template, under the hood, token-wise, is '^1', and the dedicated metadata field ID is '^2'. It's your call whether settings are copacetic, but there should be a file naming token which is at least similar to metadata field ID.",
                          	        subs = { props.LR_tokens, props.cnMetaId },
                        	        actionPrefKey = "File naming tokens usually include com-adobe prefix",
                        	    }
                            end
                                      	    
            	        else -- naming is via custom text.
                	        if props.LR_tokens:find( "{custom_token}", 1, true ) then
                	        
                            	if props.LR_tokenCustomString == "_Exportant_" then -- this was :find for a long time, but since file-base-name supports "custom-text" too, there is no need to add fixed text here too along with '_Exportant_'.
                                    -- note: one can still use a combination of built-in renaming template with custom-naming, since only the custom-text will be replaced.                        	    
                            	else
                            	    local button = app:show{ confirm="Custom text must be '_Exportant_' in order to use custom file naming - ok to change it? (If you answer 'No', custom file naming will be disabled.",
                            	        buttons = dia:buttons( "YesNo" ),
                            	    }
                            	    if button == 'ok' then -- yes
                            	        props.LR_tokenCustomString = "_Exportant_"
                            	    elseif button == 'cancel' then -- no
                            	        props.customFileNaming = false
                            	    else
                            	        error( "bad btn" )
                            	    end
                            	end
                            else
                        	    self:denyExport( "*** Renaming template must include custom text." )
                         	    break
                            end
                        
                        end
                    else
                	    self:denyExport( "*** Renaming template contains no tokens." )
                   	    break
                    end
                else
                    self:denyExport( "*** 'Rename To' must be checked ('File Naming' section above) for custom filenaming support." )
               	    break
                end
            
                local getFileBaseName = app:getPref{ name='getFileBaseName', presetName=props.pluginManagerPreset, expectedType='function' }
                local getCustomTextReplacement = app:getPref{ name='getCustomTextReplacement', presetName=props.pluginManagerPreset, expectedType='function' }

                if not getFileBaseName then
                    self:denyExport( "'getFileBaseName' must be defined in advanced settings, or else disable custom file naming." )
                    break
                end
                if not getCustomTextReplacement then -- not actually used for sample, but will be used for final.
                    self:denyExport( "'getCustomTextReplacement' must be defined in advanced settings, or else disable custom file naming." )
                    break
                end

                if samplePhoto then 
                    local basename = getFileBaseName( samplePhoto, props, 'fileBaseName' )
                    --local export = Export:newDialog()
                    --local ext = export:getDestExt( props, samplePhoto, nil ) -- no cache
                    --props.customFileNameSample = LrPathUtils.addExtension( basename, ext )
                    props.customFileNameSample = basename -- final filename will be determined by get-custom-text-replacement function, which is communicated via tooltip.
                else
                    props.customFileNameSample = "no sample photo"
                end
            else -- custom file-naming is disabled.
                if props.LR_renamingTokensOn and props.LR_tokens:find( "{custom_token}" ) and props.LR_tokenCustomString == "_Exportant_" then
                    props.cnStatus = "You probably don't want '_Exportant_' as custom text unless custom file naming is enabled."
                    -- not a denial, just a note..
                -- else ok
                end
            end
            
            if props.customFileNaming or props.customDirNaming then
                if props.LR_collisionHandling ~= 'overwrite' then
                    if str:is( props.LR_publish_connectionName ) then -- export location overwrite options are not exposed in publish services (I think overwrite is pretty-much implied).
                        props.LR_collisionHandling = 'overwrite' -- to keep the wheel turning sans squeak..
                    else
                        local btn = app:show{ confirm="Custom file and/or directory naming requires \"overwrite without warning\" option - ok if I enable that for you?",
                            buttons = dia:buttons( "YesNo" ),
                            -- actionPrefKey = "OK to enable overwrite", - note: Exportant will keep prompting if overwrite not sticking, but that is presumably an indication of incompatibility..
                        }
                        if btn == 'ok' then
                            props.LR_collisionHandling = 'overwrite'
                        else
                            self:denyExport( "*** Overwrite \"without warning\" must be enabled (can be done manually in 'Export Location' section above - \"Existing Files\", if present)\nfor custom folder/file-naming support." )
                            break
                        end
                    end
                -- else overwrite already set - good..
                end
            elseif props.readdToColl then
                -- ok
            else
                self:denyExport( "Check 'Custom Folder Naming' or 'Custom File Naming', else uncheck 'Custom Naming'." )
                break
            end

            if props.customDirNaming then
        	    if props.LR_export_destinationType == 'chooseLater' then
        	        self:denyExport( "'Choose folder later' is not compatible with custom folder naming feature." ) -- not sure if this is always true, but hey..
        	        break
        	    end
        	    
                local getSubPath = app:getPref{ name='getSubPath', presetName=props.pluginManagerPreset, expectedType='function' }
                if not getSubPath then
                    self:denyExport( "'getSubPath' must be defined in advanced settings, or else disable custom folder naming." )
                    break
                end
        
                if samplePhoto then
                    local subpath = getSubPath( samplePhoto, props, 'folderSubPath' )
                    props.customFolderNameSample = subpath -- could call the whole monty to get full path - ###3: maybe some day.
                else
                    props.customFolderNameSample = "no sample photo"
                end

            -- else std dir
            end
            
            if not dialogEnding and props.customNaming and ( props.customDirNaming or props.customFileNaming ) then
                local status = self:assureBottom( "Leave Custom Naming Enabled", "Disable Custom Naming" )
                if not status then
                    props.customNaming = false
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
function CustomNaming:startDialogMethod()

    local props = self.exportSettings

	view:setObserver( props, 'pluginManagerPreset', CustomNaming, CustomNaming.updateFilterStatus )
	
	view:setObserver( props, 'customNaming', CustomNaming, CustomNaming.updateFilterStatus )
	view:setObserver( props, 'customDirNaming', CustomNaming, CustomNaming.updateFilterStatus )
	view:setObserver( props, 'customFileNaming', CustomNaming, CustomNaming.updateFilterStatus )
	view:setObserver( props, 'readdToColl', CustomNaming, CustomNaming.updateFilterStatus )
	
	view:setObserver( props, 'folderSubPath', CustomNaming, CustomNaming.updateFilterStatus )
	view:setObserver( props, 'fileBaseName', CustomNaming, CustomNaming.updateFilterStatus )

    --view:setObserver( props, 'cnMetaEna', CustomNaming, CustomNaming.updateFilterStatus )
	--view:setObserver( props, 'cnMetaId', CustomNaming, CustomNaming.updateFilterStatus )
	
	view:setObserver( props, 'LR_export_destinationType', CustomNaming, CustomNaming.updateFilterStatus )
	view:setObserver( props, 'LR_collisionHandling', CustomNaming, CustomNaming.updateFilterStatus )
	view:setObserver( props, 'LR_tokens', CustomNaming, CustomNaming.updateFilterStatus )
	view:setObserver( props, 'LR_renamingTokensOn', CustomNaming, CustomNaming.updateFilterStatus )
	view:setObserver( props, 'LR_tokenCustomString', CustomNaming, CustomNaming.updateFilterStatus )
	
    view:setObserver( props, 'LR_exportFiltersFromThisPlugin', CustomNaming, CustomNaming.updateFilterStatus )
    
	
    self:updateFilterStatusMethod() -- async/guarded.

end



--- This function will create the section displayed on the export dialog 
--  when this filter is added to the export session.
--
function CustomNaming:sectionForFilterInDialogMethod()

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
		    title = self.title, -- (requires editing \"advanced settings\")", - note: current date/time can be x-pended sans "advanced settings".
			value = bind 'customNaming',
			width = share 'cn_ena_width',
			tooltip = "If checked, custom directory and/or file naming functions will be invoked to re-locate/re-name exported files.",
		},
    }
	it[#it + 1] = vf:row {
		vf:spacer { width = share( labelWidth ) },
		vf:separator { width = share 'cn_ena_width' },
	}
	space( 7 )

	it[#it + 1] = vf:row {
		vf:checkbox {
		    title = "Custom Folder Naming",
			value = bind 'customDirNaming',
		    width = share( labelWidth ),
			tooltip = "If checked, export directory will be refined according to plugin preset's advanced settings.",
			enabled = bind 'customNaming',
		},
		vf:static_text {
		    title = "If checked, your custom directory naming function (if defined in\n\"advanced settings\") will be called to determine export location.",
			enabled = bind 'customNaming',
		},
	}
	it[#it + 1] = vf:row {
		vf:static_text {
		    title = "Folder Subpath",
		    width = share( labelWidth ),
		    enabled = LrBinding.andAllKeys( 'customNaming', 'customDirNaming' ),
		},
		vf:edit_field {
		    value = bind 'folderSubPath',
		    enabled = LrBinding.andAllKeys( 'customNaming', 'customDirNaming' ),
		    width_in_chars = WIN_ENV and 35 or 31,
		    -- immediate = true, - change is being used to assure define box is to-front, so immediate doesn't work here.
		    tooltip = "This field may be used in export destination computation according to 'getCustomDir' function in advanced settings. By default, if blank, the export destination will not be altered, and if not blank, it will be used as the only element in the subfolder (subpath).",
		},
		vf:push_button {
		    title = "Define",
		    action = function( button )
		        lrMeta:defineTokens {
		            title = "Define tokens for folder subpath",
		            targetProps = props,
		            targetKey = 'folderSubPath',
		            targetName = "Folder Subpath",
		            onShow = function( p )
		                folderTokenDefineDialogCloseFunction = p.close or error( "no folder to-close function" )
		            end,
		            getCustomMetadataItems = app:getPref{ name='getCustomMetadataItems', presetName=props.pluginManagerPreset, expectedType='function' },
		        }
		    end,
		    enabled = LrBinding.andAllKeys( 'customNaming', 'customDirNaming' ),
		    tooltip = "Open token editor...",
		},
	}
	it[#it + 1] = vf:row {
	    vf:static_text {
	        title = "Sample:",
	        width = share( labelWidth ),
	        enabled = LrBinding.andAllKeys( 'customNaming', 'customDirNaming' ),
	        tooltip = "Final export destination will be dictated by 'getCustomDir' function (in advanced settings).",
	    },
	    vf:static_text {
	        title = bind 'customFolderNameSample',
	        width_in_chars = 40,
	        tooltip = bind 'customFolderNameSample',
	        enabled = LrBinding.andAllKeys( 'customNaming', 'customDirNaming' ),
	    },
	}
	
  	space()
	it[#it + 1] = vf:row {
		vf:checkbox {
		    title = "Custom File Naming",
			value = bind 'customFileNaming',
            width = share( labelWidth ),
			tooltip = "If checked, filenames will be refined according to plugin preset's advanced settings.",
			enabled = bind 'customNaming',
		},
		vf:static_text {
		    title = "If checked, your custom file naming function (if defined in\n\"advanced settings\") will be called to determine exported file name.",
			enabled = bind 'customNaming',
		},
	}
	
	space()
	
	it[#it + 1] = vf:row {
		vf:static_text {
		    title = "File Base Name",
		    width = share( labelWidth ),
		    enabled = LrBinding.andAllKeys( 'customNaming', 'customFileNaming' ),
		},
		vf:edit_field {
		    value = bind 'fileBaseName',
		    enabled = LrBinding.andAllKeys( 'customNaming', 'customFileNaming' ),
		    width_in_chars = WIN_ENV and 35 or 31,
		    -- immediate = true, - sample updates immediately, but then interferes with ability to assure define box is to-front.
		    tooltip = "This field may be used in filename computation according to 'getCustomTextReplacement' function in advanced settings. By default, if blank, the filename will not be altered, and if not blank, it will be used as the only element in the filename (with extension added).",
		},
		vf:push_button {
		    title = "Define",
		    action = function( button )
		        lrMeta:defineTokens { -- async
		            title = "Define tokens for file base name",
		            targetProps = props,
		            targetKey = 'fileBaseName',
		            targetName = "File Base Name",
		            onShow = function( p )
		                fileTokenDefineDialogCloseFunction = p.close or error( "no file to-close function" )
		            end,
		            getCustomMetadataItems = app:getPref{ name='getCustomMetadataItems', presetName=props.pluginManagerPreset, expectedType='function' },
		        }
		    end,
		    enabled = LrBinding.andAllKeys( 'customNaming', 'customFileNaming' ),
		    tooltip = "Open token editor...",
		},
	}
	it[#it + 1] = vf:row {
	    vf:static_text {
	        title = "Sample:",
	        width=share( labelWidth ),
	        enabled = LrBinding.andAllKeys( 'customNaming', 'customFileNaming' ),
	        tooltip = "Final filename will be dictated by 'getCustomTextReplacement' function (in advanced settings) and filename extension.",
	    },
	    vf:static_text {
	        title = bind 'customFileNameSample',
	        width_in_chars = 40,
	        tooltip = bind 'customFileNameSample',
	        enabled = LrBinding.andAllKeys( 'customNaming', 'customFileNaming' ),
	    },
	}
	
    --[[ *** save for possible future resurrection:	
	space()
	local setRawMetaPopupItems, cnMetaSpecForId = lrMeta:getRawSetPopupItems{ simpleOnly=true, idOnly=true } -- lookup - keys are ids, values are specs.
	-- note: previously, I've been checking for _Exportant_ since it would be replaced with custom text, but in this case I need to check that specified metadata item is 
	-- in token of filenaming preset. ###1 - the problem with this scheme is that if export/publish service attempts to get filename at any time other than exporting,
	-- it'll give the wrong value, since metadata field not assigned yet.
	it[#it + 1] = vf:row {
	    vf:checkbox {
	        title = "Dedicate metadata field for file naming",
	        value = bind 'cnMetaEna',
	        enabled = bind {
        	    keys = { 'customNaming', 'customFileNaming', 'customDirNaming' },
        	    operation = function()
        	        return props.customNaming and ( props.customFileNaming and not props.customDirNaming )
        	    end,
        	},
        	tooltip = "With this enabled, custom export filenaming is compatible with any export/publish service; if disabled, then compatibility is limited to those not dependent on expected path, like built-in hard drive export service.\n \n*** WARNING: Contents of chosen field will be overwritten for file-naming purposes, so make sure you choose a field that you are NOT using for anything else!",
	    },
	    vf:popup_menu {
	        value = bind 'cnMetaId',
	        items = setRawMetaPopupItems,
	        fill_horizontal = 1,
	        enabled = 	bind {
        	    keys = { 'customNaming', 'customFileNaming', 'customDirNaming', 'cnMetaEna' },
        	    operation = function()
        	        return props.customNaming and ( props.customFileNaming and not props.customDirNaming ) and props.cnMetaEna
        	    end,
        	},
        	tooltip = "*** BEWARE: contents of chosen field will be overwritten for file-naming purposes, so make sure you choose a field that you are NOT using for anything else!",
	    }
	}
	--]]
	
	space()
	
	local cnBinding = bind {
	    keys = { 'customNaming', 'customDirNaming', 'customFileNaming', 'cnMetaEna' },
	    operation = function()
	        return props.customNaming and ( props.customDirNaming or ( props.customFileNaming and not props.cnMetaEna ) )
	    end,
	}

	it[#it + 1] = vf:row {
        -- pre-named files: ( ) keep on disk  ( ) add to catalog  [ ] stack  (above/below).
	    vf:static_text {
	        title = "Keep pre-custom-named file",
			width = share( labelWidth ),
			enabled = cnBinding,
	    },
	    vf:radio_button {
	        title = "On Disk",
	        value = bind 'customNamingKeep',
	        checked_value = 'keepOnDisk',
	        width = share 'cn_keep_col_1',
			enabled = cnBinding,
	    },
	    vf:radio_button {
	        title = "In Catalog",
	        value = bind 'customNamingKeep',
	        checked_value = 'addToCatalog',
	        width = share 'cn_keep_col_2',
			enabled = cnBinding,
	    },
	    vf:checkbox {
	        title = 'Stack',
	        value = bind 'customNamingKeepStack',
	        enabled = bind {
	            keys = { 'customNaming', 'customDirNaming', 'customFileNaming', 'customNamingKeep' },
	            operation = function()
	                if props.customNaming and ( props.customDirNaming or props.customFileNaming ) and props.customNamingKeep == 'addToCatalog' then
	                    return true
	                else
	                    return false
	                end
	            end,
	        },
	    },
	    vf:popup_menu {
	        value = bind 'customNamingKeepStackPos',
	        items = {{ title="Above", value='above' }, { title="Below", value='below' }},
	        enabled = bind {
	            keys = { 'customNaming', 'customDirNaming', 'customFileNaming', 'customNamingKeep', 'customNamingKeepStack' },
	            operation = function()
	                if props.customNaming and ( props.customDirNaming or props.customFileNaming ) and props.customNamingKeep == 'addToCatalog' and props.customNamingKeepStack then
	                    return true
	                else
	                    return false
	                end
	            end,
	        },
	    },
	}
	it[#it + 1] = vf:row {
        -- exported intermediate files: ( ) keep on disk  ( ) add to catalog  ( ) move to trash   ( ) permanently delete.
	    vf:static_text {
	        title = "Discard pre-custom-named file",
			width = share( labelWidth ),
			enabled = cnBinding,
	    },
	    vf:radio_button {
	        title = "Move to trash",
	        value = bind 'customNamingKeep',
	        checked_value = 'trash',
	        width = share 'cn_keep_col_1',
			enabled = cnBinding,
	    },
	    vf:radio_button {
	        title = "Permanently delete",
	        value = bind 'customNamingKeep',
	        checked_value = 'delete',
	        width = share 'cn_keep_col_2',
			enabled = cnBinding,
	    },
	}
    space()
    it[#it + 1] = vf:static_text {
        title = "Note: It is the 'Add To This Catalog' box in 'Export Location' section above that determines whether\ncustom-named file is added to catalog and stacked...",
	    enabled = cnBinding,
    }
    space()
    it[#it + 1] = vf:checkbox {
        title = "Add exported photo to selected collection after adding to catalog (whether renamed or not)",
        value = bind 'readdToColl',
        enabled = LrBinding.andAllKeys( 'LR_reimportExportedPhoto', 'customNaming' )
    }

	space()
	sep()
	space()
	
	it[#it + 1] = self:sectionForFilterInDialogGetStatusView()

	return it
	
end



function CustomNaming.endDialog()
    ending = true
    if folderTokenDefineDialogCloseFunction then
        folderTokenDefineDialogCloseFunction() -- no-op if not open (user already closed it).
        folderTokenDefineDialogCloseFunction = nil -- still, once should to it
    end
    if fileTokenDefineDialogCloseFunction then -- ditto
        fileTokenDefineDialogCloseFunction()
        fileTokenDefineDialogCloseFunction = nil
    end
end



--- This function obtains access to the photos and removes entries that don't match the metadata filter.
--
--  @usage called *before* post-process-rendered-photos function.
--  @usage base class has no say (need not be called).
--
function CustomNaming.shouldRenderPhoto( exportSettings, photo )

    --assert( exportSettings, "no es" )

    --Debug.lognpp( exportSettings )
    --Debug.showLogFile()
    
    --local fileFormat = photo:getRawMetadata( 'fileFormat' )
    
    return true -- it's not up to this export filter to decide not to export, it's up to custom-export-check function, if implemented.

end



function CustomNaming:assureBottom( actionExpr, cancelExpr )
    local filters, first, last, total, names = self:getFilters()
    if filters[last] == self.id then
        self:log( "Of all filters from this plugin, '^1' is at the bottom - good (however it's not possible to determine if filters from other plugins are below), since custom-named exports via *filter* break the rules - downstream filter or export service won't be getting what they expect. I mean, they might be getting the pre-renamed file, if not discarded, but they'll not be receiving the renamed file. If your downstream filter or export service depends on renamed file, then consider using a custom export service instead of an export filter for unconventional naming.", self.filterName )
    else
        local uiTidbit = "Filters from this plugin (mostly):\n-------------------------------------\n"
        local b = {}
        for i, name in ipairs( names ) do
            self:logV( "Filter #^1: ^2", i, filters[i] or name ) -- log id if possible (i.e. from this plugin).
            b[#b + 1] = str:fmtx( "^1: ^2", i, name )
        end
        local lastName = names[last]
        assert( str:is( lastName ), "no last name" )
        uiTidbit = uiTidbit..table.concat( b, "\n" ).."\n \n*** Order may make a difference in result." -- reminder: export service, although present in preset, is not copied to settings.
        local button = app:show{ confirm="Of all filters from this plugin, '^1' is not lowest (but maybe should be at the bottom), '^2' is (however there is no way to tell whether filters from other plugins are below it). This *may* cause problems for down-stream filter or export service (depends which filter/service and what it's expecting)\n \n^3\n \nSo, ^4 regardless, or ^5?",
            subs = { self.filterName, lastName, uiTidbit, LrStringUtils.lower( actionExpr ), LrStringUtils.lower( cancelExpr ) },
            buttons = { dia:btn( actionExpr, 'ok' ), dia:btn( cancelExpr, 'cancel', false ) },
            actionPrefKey = str:fmtx( "^1 - filter position", self.filterName ),
        }
        if button == 'ok' then
            self:log( "'^1' not bottom-most filter - proceeding regardless.", self.filterName )
        else
            self:log( "'^1' is not bottom-most filter - scratch that, reverse it..", self.filterName )
            return -- nil
        end
    end
    return true
end



--- Post process rendered photos (overrides base class).
--
--  @usage reminder: videos are not considered rendered photos (won't be seen by this method).
--
function CustomNaming:postProcessRenderedPhotosMethod()

    local functionContext, filterContext = self.functionContext, self.filterContext
    local exportSettings = filterContext.propertyTable

    -- local renamed = {} - obs
    local addToCatalog = {} -- intermediaries (e.g. initial tif or jpg), and/or converted files.

    app:call( Service:new{ name=str:fmtx( "^1 - Post Process Rendered Photos", self.filterName ), preset=exportSettings.pluginManagerPreset, progress=true, main=function( call )
    
        assert( exportSettings, "no es" )
        assert( exportSettings.customDirNaming ~= nil, "no custom dir spec" )
        assert( exportSettings.customFileNaming ~= nil, "no custom fname spec" )
        
        local customNaming = exportSettings.customNaming
        
        if customNaming then
            self:log( "Filter is enabled." )
        else
            self:log( "Filter is disabled, so it won't do anything." )
            self:passRenditionsThrough()
            return
        end

        local photos, videos, union, candidates, unionCache = self:initPhotos{ rawIds={ 'fileFormat', 'path' }, call=call }
        if not photos then
            return
        end
        
        local status = self:requireMainFilterInPost()
        if not status then
            return
        end
        
        local status = self:assureBottom( "Proceed", "Abort" )
        if status then
            -- nuff said
        else
            local s, m = self:cancelExport()
            if s then
                self:log( "Export canceled (there was probably still an error about how nothing got rendered - that's to be expected..)." )
            else
                self:logW( "Some photo rendering could not be skipped - ^1", m )
            end
            return
        end

        local replacementFunction = app:getPref( 'getCustomTextReplacement', exportSettings.pluginManagerPreset )
        if exportSettings.customFileNaming and replacementFunction == nil then -- this is pre-checked in UI too.
            app:error( "You must define 'getCustomTextReplacement' in advanced settings in order to do custom export file naming." )
        end
        local customDirFunction = app:getPref( 'getCustomDir', exportSettings.pluginManagerPreset )
        if exportSettings.customDirNaming and customDirFunction == nil then -- ditto
            app:error( "You must define 'getCustomDir' in advanced settings in order to do custom folder naming." )
        end
        
        local export = Export:newDialog() -- used for getting export destination.

        assert( gbl:getValue( 'createExifToolSession' ) ~= nil, "gbl ets not init" )
        if createExifToolSession then
            call.ets = exifTool:openSession( self.filterName.."_"..LrUUID.generateUUID() )
            if not call.ets then
                error( "Unable to open exiftool session." )
            end
        end
    
        local currentDateTime = LrDate.currentTime() -- used for naming (e.g. prefix/suffix).
        
        local savedReimportSetting = exportSettings.LR_reimportExportedPhoto
        local reimportExportedPhoto
        local readdCollLookup = {}
        if exportSettings.readdToColl then
            for i, v in ipairs( catalog:getActiveSources() ) do
                if cat:getSourceType( v ):sub( -3 ) == "ion" and not v:isSmartCollection() then -- regular collection
                    local collPhotos = v:getPhotos()
                    for i, photo in ipairs( collPhotos ) do
                        readdCollLookup[photo] = v
                    end
                else
                    Debug.pause()
                end
            end
            if not tab:isEmpty( readdCollLookup ) then
                self:logV( "Readd collection is selected." ) -- ok, no big deal..           
            else
                self:log( "Readd collection is empty." ) -- ok too, but if re-add is checked, it's worth mentioning if it's empty..
            end
        -- else leave readd-coll table empty.
        end

        local keepSecondaryExport = exportSettings.customNamingKeep
        
        local renditionOptions = {
            plugin = _PLUGIN, -- ###3 I have no idea what this does, or if it's better to set it or not (usually it's not set).
            --renditionsToSatisfy = renditions, -- filled in below.
            filterSettings = function( renditionToSatisfy, exportSettings )
                assert( exportSettings, "no es" )
                assert( customNaming, "no custom naming" ) -- pre-checked upon method entry.
                
                -- reminder: you can't change 'LR_tokenCustomString' at this point - I guess export service needs it fixed since renditionToSatisfy filename is fixed.
                local newPath = renditionToSatisfy.destinationPath -- by default return unmodified.
                self:log( "Rendition path: ^1", newPath )
                
                local photo = renditionToSatisfy.photo -- coming back to this, months later, I'm confused: shouldn't this be 'sourceRendition'? - I mean, if
                -- the rendition has not yet been "satisfied", then how can it possibly have a photo associated with it? ###4 somehow this is correct, so...
                
                local newFilename = LrPathUtils.leafName( newPath )
                local newDir = LrPathUtils.parent( newPath )
                
                --newDir = 
                --newFilename = 

                if exportSettings.customDirNaming then                
                    local _newDir = customDirFunction {
                        photo = renditionToSatisfy.photo,
                        rendition=renditionToSatisfy,
                        settings = exportSettings,
                        exifToolSession = call.ets,
                        dir = newDir,
                        filename = newFilename,
                        filePath = newPath,
                        cache = unionCache, -- file-format & path.
                        currentDateTime = currentDateTime,
                    }
                    if _newDir ~= newDir then
                        newDir = _newDir
                        newPath = LrPathUtils.child( newDir, newFilename )
                        --Debug.pause( newPath:sub( 20 ) )
                        self:logV( "Got custom dir: '^1'", newDir )
                    else
                        self:logW( "Custom dir function did not alter dir." )
                    end
                end                
                if exportSettings.customFileNaming then                
                    local newExt = LrPathUtils.extension( newFilename ) -- cant be changed - defined by chosen export format.
                    local replacement = replacementFunction { -- base
                        photo = renditionToSatisfy.photo,
                        rendition=renditionToSatisfy,
                        settings = exportSettings,
                        exifToolSession = call.ets,
                        dir = newDir,
                        filename = newFilename,
                        filePath = newPath,
                        currentDateTime = currentDateTime,
                    }
                    if str:is( replacement ) then
                        self:logV( "Got replacement from custom file naming function: ^1", replacement )
                    else
                        replacement = LrPathUtils.removeExtension( newFilename )
                        self:logV( "No replacement returned from custom file naming function, proceeding with original filename (base): ^1", replacement )
                    end
                    if false and exportSettings.cnMetaEna and str:is( exportSettings.cnMetaId ) then
                        local s, m = cat:update( 30, "Update for export filename metadata", function() -- it would be better to do update en-masse, but dunno how, yet ###1.
                            renditionToSatisfy.photo:setRawMetadata( exportSettings.cnMetaId )
                        end )
                        if s then
                            newFilename = LrPathUtils.addExtension( replacement, newExt ) -- only true if preset has the metadata token only, no other things ###1.
                            newPath = LrPathUtils.child( newDir, newFilename )
                            self:logV( "New filename assumed to be: '^1'", newFilename )
                        else
                            self:logW( "Unable to update catalog for export file-naming metadata." )
                        end
                    else
                        local _newFilename = newFilename:gsub( "_Exportant_", replacement ) -- I guess error if replacement is nil(?)
                        if _newFilename ~= newFilename then
                            newFilename = _newFilename
                            --Debug.pause( exportSettings.LR_renamingTokensOn, exportSettings.LR_tokens, exportSettings.LR_tokenCustomString ) -- seems OK but not taking effect.
                            newPath = LrPathUtils.child( newDir, newFilename )
                            --Debug.pause( newPath:sub( 20 ) )
                            self:logV( "Got new filename after replacement: '^1'", newFilename )
                        else
                            self:logW( "'_Exportant_' not found in custom text - export filename will not be changed. Recommend disabling 'Custom File Naming', or double-check you are using a file naming preset that includes custom text: '_Exportant_'." )
                        end
                    end
                end
                
                if newPath ~= renditionToSatisfy.destinationPath then -- re-destined or renamed.
                    if savedReimportSetting then
                        self:logV( "Path changed - filter to reimport new file, since specified in 'Export Location' section." )
                        exportSettings.LR_reimportExportedPhoto = false -- make sure Lr does not do it.
                        reimportExportedPhoto = true -- make sure this Exportant filter does.
                    else
                        self:logV( "Path changed - filter not reimporting new file, since not specified in 'Export Location' section." )
                        exportSettings.LR_reimportExportedPhoto = false
                        reimportExportedPhoto = false
                        --Debug.pause( "false" )
                    end
                elseif exportSettings.customDirNaming or exportSettings.customFileNaming then -- could have been renamed, but wasn't, still: handle all same if one of these is enabled.
                    -- same as the above clauses, but that's ok.
                    self:logV( "Path unchanged, but custom naming - filter reimporting new file? - ^1 (governed by setting in 'Export Location' section).", savedReimportSetting )
                    exportSettings.LR_reimportExportedPhoto = false
                    reimportExportedPhoto = savedReimportSetting
                elseif exportSettings.readdToColl then
                    self:logV( "Path unchanged, no custom naming, but re-adding to collection - filter reimporting new file? - ^1 (governed by setting in 'Export Location' section).", savedReimportSetting )
                    exportSettings.LR_reimportExportedPhoto = false
                    reimportExportedPhoto = savedReimportSetting
                else -- exportant has no claims on the exported photo, let Lr import it as it would..
                    exportSettings.LR_reimportExportedPhoto = savedReimportSetting -- Let Lr do it, or not.
                    self:logV( "Custom dir naming and custom file naming are disabled (and not re-adding to collection) - Lr will re-import? - ^1 (governed by setting in 'Export Location' section).", savedReimportSetting )
                    reimportExportedPhoto = false -- this filter ain't doing it.
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
                if not success then
                    local errm = pathOrMessage or "?"
                    self:logW( "Unable to export '^1', error message: ^2. This may not cause a problem with this export, but may indicate a problem with this plugin, or with the source photo.", renditionToSatisfy.destinationPath, errm )
                        -- Note: if export is canceled, path-or-message can be nil despite success being false. ###3 - this may have been a flukey glitch - dunno.
                    renditionToSatisfy:renditionIsDone( false, errm.." - see warning in log file for more info." )
                    break
                end
                local renderedPath = pathOrMessage
                if renderedPath == renditionToSatisfy.destinationPath then -- rendered path is destination path - nuthin' to add, just proceed...
                    self:logV( "Source photo '^1' was rendered to '^2'", srcPhotoPath, renderedPath )
                    if reimportExportedPhoto and exportSettings.readdToColl then
                        renditionToSatisfy:renditionIsDone( true ) -- seems a little premature, but hey.. ###2
                        -- need to continue below..
                    else
                        renditionToSatisfy:renditionIsDone( true )
                        break -- next rendition..
                    end
                else
                    self:logV()
                    self:logV( "Destination path was originally to be '^1', but has changed to '^2'", renditionToSatisfy.destinationPath, renderedPath ) -- this will always be the case if a folder subpath is defined.
                    -- Disk:moveFile( sourcePath, destPath, createDestDirsIfNecessary, overwriteDestFileIfNecessary, avoidUnnecessaryUpdate, timeCheckIsEnough )
                    --local s, m = fso:moveFile( pathOrMessage, properPath, false, overwrite, false, true ) -- dir expected, overwrite unconditionally.
                    local overwrite
                    if str:is( exportSettings.LR_publish_connectionName ) or ( exportSettings.LR_collisionHandling == 'overwrite' ) then
                        overwrite = true
                    else
                        self:logE( "Must be allowed to overwrite existing files - check in export dialog box." )
                        break
                    end
                    local eq = str:isEqualIgnoringCase( renditionToSatisfy.destinationPath, srcPhotoPath )
                    if eq then -- exp dest file is same as source photo file - not ok..
                        renditionToSatisfy:renditionIsDone( false, "This filter does not support overwriting source photo file: "..srcPhotoPath ) -- no need for additional W/E logging here.
                        break
                    end
                    local s, m = fso:copyFile( renderedPath, renditionToSatisfy.destinationPath, false, overwrite, false, true ) -- to "satisfy" the rendition.
                    if not s then -- enable to satisfy rendition,
                        m = m or "?" -- ###
                        self:logE( m )
                        renditionToSatisfy:renditionIsDone( false, m ) -- no additional info in corresonding log message.
                        break
                    end
                    --    fall-through => file copy satisfied rendition.
                    --    R E N D I T O N   I S   D O N E
                    --    (deal with copy which satisfied rendition, which is secondary to the custom-named copy)
                    self:logV( "copied '^1' to '^2' to satisfy rendition.", renderedPath, renditionToSatisfy.destinationPath )
                    renditionToSatisfy:renditionIsDone( true )
                    -- LrTasks.yield() - not necessary.
                    --Debug.pause( keepSecondaryExport )
                    
                    -- Note: "initial export" is wrong terminology here, it's really refering to "non-primary" export (that which satisfies rendition, but not necessarily the user,
                    -- who wanted the custom named/located export.
                    if keepSecondaryExport == 'keepOnDisk' then
                        self:logV( "Keeping '^1' on disk, but not adding to catalog.", renditionToSatisfy.destinationPath )
                    elseif keepSecondaryExport == 'addToCatalog' then
                        self:logV( "Keeping '^1' on disk, and adding to catalog.", renditionToSatisfy.destinationPath )
                        addToCatalog[#addToCatalog + 1] = { pathToAdd=renditionToSatisfy.destinationPath, srcPhoto=srcPhoto, srcPhotoPath=srcPhotoPath } -- could add in place here ###3.
                    elseif keepSecondaryExport == 'trash' then
                        local s, m = fso:moveToTrash( renditionToSatisfy.destinationPath ) -- reminder: Lr seems to be happy with export as long as exported file exists when rendition-done is called
                        if s then
                            if m then
                                self:logV( m )
                            end
                            self:logV( "Deleted '^1', or moved to trash.", renditionToSatisfy.destinationPath )
                        else
                            self:logW( "Unable to move pseudo-satisfying rendition to trash after format conversion - ^1.", m or "no reason given" ) -- m should have paths.
                            -- break - png was exported, and export satisfied: user can always manually delete extraneous file.
                        end
                    elseif keepSecondaryExport == 'delete' then
                        local s, m = fso:deleteFile( renditionToSatisfy.destinationPath )
                        if s then
                            -- m always nil.
                            self:logV( "Deleted '^1'.", renditionToSatisfy.destinationPath )
                        else
                            self:logW( "Unable to move pseudo-satisfying rendition to trash after format conversion - ^1.", m or "no reason given" ) -- m should have paths.
                            -- break - png was exported, and export satisfied: user can always manually delete extraneous file.
                        end
                    else
                        app:error( "bad value: ^1", keepSecondaryExport )
                    end
                end

                -- Note: Lr's importer won't touch the custom-named/located file, since it doesn't know about it (i.e. if not the file satisfying the rendition).
                if reimportExportedPhoto then
                
                    local destPhoto = cat:findPhotoByPath( renderedPath )
                    if destPhoto == nil then -- photo not findable, so either it's not there or there has been a path case change, either way - try to add it.
                        --Debug.lognpp ( exportSettings )
                        --Debug.showLogFile()
                        local stackPhoto
                        local stackPos
                        
                        if exportSettings.LR_reimport_stackWithOriginal then
                            stackPhoto = srcPhoto
                            local srcDir = LrPathUtils.parent( srcPhotoPath )
                            local newDir = LrPathUtils.parent( renderedPath )
                            if srcDir == newDir then
                                stackPos = exportSettings.LR_reimport_stackWithOriginal_position
                            else
                                self:logV( "dirs not same - src: '^1', new: '^2' - so not stacking with original", srcDir, newDir )
                                stackPhoto = nil -- changed my mind...
                            end
                        else
                            -- nuthin.
                        end
                        
                        -- makes me nervous doing one at a time, but also hate to defer - hmm... ###3
                        local newPhoto
                        local readdedToColl
                        local s, m = cat:update( 15, "Reimport Exported & Converted Photo", function( context, phase )
                            if phase == 1 then
                                newPhoto = catalog:addPhoto( renderedPath, stackPhoto, stackPos ) -- and return nil
                                if newPhoto then
                                    if readdCollLookup[srcPhoto] then -- source photo is in a re-add collection
                                        return false -- continue
                                    else
                                        return true -- done
                                    end
                                else
                                    error( "Unable to add photo to catalog." )
                                end
                            elseif phase == 2 then
                                assert( readdCollLookup[srcPhoto], "no re-add coll lookup for source photo" )
                                readdCollLookup[srcPhoto]:addPhotos{ newPhoto }
                                readdedToColl = true
                                return true -- done (same as returning nil).
                            else
                                app:error( "bad phase: ^1", phase )
                            end
                        end )
                        Debug.pause( newPhoto, readdedToColl )
                        if s then
                            if stackPhoto then
                                self:log( "Reimported '^1' (stacked ^2 original)", renderedPath, stackPos )
                            else
                                self:log( "Reimported '^1'", renderedPath )
                            end
                        else
                            self:logE( m )
                        end
                    else
                        self:log( "Already in catalog." )
                    end
                else
                    self:logV( "Not reimporting." )
                end
                
            until true
        end
    end, finale=function( call )
        self:log()
        exifTool:closeSession( call.ets )
        if call.status then
            self:logV( "No error thrown." )
            if #addToCatalog > 0 then
                local settings = filterContext.propertyTable
                local s, m = cat:update( 30, "Adding exported files to catalog", function( context, phase )
                    for i, v in ipairs( addToCatalog ) do
                        local stackPhoto
                        local stackPos
                        if settings.customNamingKeepStack then
                            stackPhoto = v.srcPhoto
                            local srcDir = LrPathUtils.parent( v.srcPhotoPath )
                            local newDir = LrPathUtils.parent( v.pathToAdd )
                            if srcDir == newDir then
                                stackPos = settings.customNamingKeepStackPos
                            else
                                self:logV( "dirs not same - src: '^1', new: '^2' - so not stacking with original", srcDir, newDir )
                                stackPhoto = nil -- changed my mind...
                            end
                        else
                            -- nuthin.
                        end
                        local addedPhoto, errm = LrTasks.pcall( catalog.addPhoto, catalog, v.pathToAdd, stackPhoto, stackPos )
                        if addedPhoto then
                            self:log( "Added to catalog: ^1", v.pathToAdd )
                        else
                            self:logW( "Unable to add to catalog: ^1", v.pathToAdd )
                        end
                    end
                end )
                if s then
                    self:log( "Added to catalog" )
                else
                    self:logW( "Not added to catalog - ^1", m )
                end
            end
        else -- call ended prematurely due to error.
            app:show{ error=call.message } -- no finale dialog box?
        end
        self:log()
    end } )
end



function CustomNaming.startDialog( props )
    dialogEnding = false
    local filter = ExtendedExportFilter.assureFilter( CustomNaming, props )
    filter:startDialogMethod()
end



function CustomNaming.sectionForFilterInDialog( vf, props )
    local filter = ExtendedExportFilter.assureFilter( CustomNaming, props )
    return filter:sectionForFilterInDialogMethod()
end



function CustomNaming.endDialog()
    dialogEnding = true
end



-- reminder: update status filter function need not be implemented, as long as ID passed to listener reg func is this class.
--[[
function CustomNaming.updateFilterStatus( id, props, name, value )
    local filter = ExtendedExportFilter.assureFilter( CustomNaming, props )
    filter:updateFilterStatusMethod( name, value )
end
--]]



--- This function obtains access to the photos and removes entries that don't match the metadata filter.
--
--  @usage called *before* post-process-rendered-photos function (no cached metadata).
--  @usage base class has no say (need not be called).
--
function CustomNaming.shouldRenderPhoto( exportSettings, photo )
    local filter = ExtendedExportFilter.assureFilter( CustomNaming, exportSettings )
    return filter:shouldRenderPhotoMethod( photo )
end



--- Post process rendered photos.
--
function CustomNaming.postProcessRenderedPhotos( functionContext, filterContext )
    local filter = ExtendedExportFilter.assureFilter( CustomNaming, filterContext.propertyTable, { functionContext=functionContext, filterContext=filterContext } )
    filter:postProcessRenderedPhotosMethod()
end



CustomNaming.exportPresetFields = {
	{ key = 'customNaming', default = false },
    { key = 'customFileNaming', default = false },
    { key = 'customDirNaming', default = false },
	{ key = 'folderSubPath', default = "" },
	{ key = 'fileBaseName', default = "" },
	{ key = 'customNamingKeep', default = 'trash' },
	{ key = 'customNamingKeepStack', default = false },
	{ key = 'customNamingKeepStackPos', default = 'below' },
	--{ key = 'cnMetaEna', default = false },
	--{ key = 'cnMetaId', default = 'headline' },
	{ key = 'readdToColl', default = false },
}



CustomNaming:inherit( ExtendedExportFilter ) -- inherit *non-overridden* members.


return CustomNaming
