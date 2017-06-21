--[[
        ImageMagick.lua
--]]


local ImageMagick, dbg, dbgf = ExtendedExportFilter:newClass{ className='ImageMagick', register=true }



local dialogEnding



--- Constructor for extending class.
--
function ImageMagick:newClass( t )
    return ExtendedExportFilter.newClass( self, t )
end



--- Constructor for new instance.
--
function ImageMagick:new( t )
    local o = ExtendedExportFilter.new( self, t )
    o.enablePropName = 'imageMagickEna'
    return o
end



--- This function will check the status of the Export Dialog to determine 
--  if all required fields have been populated.
--
function ImageMagick:updateFilterStatusMethod( name, value )

    local props = self.exportSettings

    app:call( Call:new{ name=str:fmtx( "^1 - Update Filter Status", self.filterName ), async=true, guard=App.guardSilent, main=function( context )

        -- base class method no longer of concern once overridden in extended class.

        repeat -- once
        
            if not props.imageMagickEna then
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

            if props.imageMagickEna then
                if props.LR_collisionHandling == 'overwrite' then
                    if not dialogEnding then
        	            local status = self:assureBottom( "If conversion will have same folder/filename/extension as original, then this filter may not need to be last. If on the other hand, you'll be converting to png or something, it may need to be bottom-most (last).", "Leave Image Magick Enabled", "Disable Image Magick" )
        	            if not status then
        	                props.imageMagickEna = false
        	            end
        	        -- else too late - time to get on with it..
        	        end
                else
                    if props.LR_publish_connectionName then
                        props.LR_collisionHandling = 'overwrite'
                    elseif dia:isOk( "Collision handling must be set to 'Overwrite WITHOUT WARNING' in 'Export Location' section. Want me to go ahead and set that for you, if so, then click 'OK', (or would you prefer to do it yourself? - if so, then click 'Cancel'). Note: if 'Export Location' section is not accessible, you'll have to let this plugin do it, if that's OK. If not OK, then you'll have to uncheck ^1.", self.filterName ) then
                        props.LR_collisionHandling = 'overwrite'
                    else
                        self:denyExport( "Collision handling must be set to 'Overwrite WITHOUT WARNING' in 'Export Location' section, or uncheck ^1.", self.filterName )
                        break
                    end
                end
            -- else ..
            end
            
            if props.imageMagickEna then
                if str:is( props.imageMagickBin, "imageMagickBin" ) then
                    local existsAsDir, existsAsFile = fso:existsAs( props.imageMagickBin, "directory" )
                    if existsAsDir then
                        local convertPath
                        if WIN_ENV then
                            convertPath = LrPathUtils.child( props.imageMagickBin, 'convert.exe' )
                        else
                            convertPath = LrPathUtils.child( props.imageMagickBin, 'convert' )
                        end
                        convert:processExeChange( convertPath )
                        app:setPref( 'convertApp', convertPath ) -- could build into exe-change processor, but some apps use global pref ###3.
                        local usable, qual = convert:isUsable()
                        if usable then
                            -- good
                        else
                            self:denyExport( "^1 - executable is not usable as configured - ^2", self.filterName, qual )
                            break
                        end
                    elseif existsAsFile then
                        self:denyExport( "Must be directory, '^1' is a file.", props.imageMagickBin )
                        break
                    else
                        self:denyExport( "'^1' does not exist - must be a directory.", props.imageMagickBin )
                        break
                    end
                else
                    self:denyExport( "'Image Magick Directory' can not be blank (or disable Image Magick)." )
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
function ImageMagick:startDialogMethod()

    local props = self.exportSettings
       
	view:setObserver( props, 'pluginManagerPreset', ImageMagick, ImageMagick.updateFilterStatus )
	
	view:setObserver( props, 'imageMagickEna', ImageMagick, ImageMagick.updateFilterStatus )
	view:setObserver( props, 'imageMagickBin', ImageMagick, ImageMagick.updateFilterStatus )
	view:setObserver( props, 'imageMagickParams', ImageMagick, ImageMagick.updateFilterStatus )
	view:setObserver( props, 'imageMagickKeep', ImageMagick, ImageMagick.updateFilterStatus )
	view:setObserver( props, 'imageMagickKeepStack', ImageMagick, ImageMagick.updateFilterStatus )
	view:setObserver( props, 'imageMagickKeepStackPos', ImageMagick, ImageMagick.updateFilterStatus )

	view:setObserver( props, 'LR_exportFiltersFromThisPlugin', ImageMagick, ImageMagick.updateFilterStatus )
	
	self:updateFilterStatusMethod() -- async/guarded.

end




--- This function will create the section displayed on the export dialog 
--  when this filter is added to the export session.
--
function ImageMagick:sectionForFilterInDialogMethod()

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
	        value = bind 'imageMagickEna',
			width = share 'im_ena_width',
			tooltip = "Check box to enable Image Magick functionality, e.g. export as png.",
	    },
	}
	it[#it + 1] = vf:row {
		vf:spacer { width = share( labelWidth ) },
	    vf:separator { width = share 'im_ena_width' },
	}
	space( 7 )
	it[#it + 1] = vf:row {
	    vf:static_text {
	        title = "Image Magick Directory",
			width = share( labelWidth ),
			enabled = bind 'imageMagickEna',
	    },
		vf:edit_field {
			value = bind 'imageMagickBin',
			enabled = bind 'imageMagickEna',
			width_in_chars = WIN_ENV and 35 or 33,
			tooltip = "Directory where convert and mogrify executables reside.",
		},
		vf:push_button {
		    title = 'Browse',
		    action = function( button )
		        dia:selectFolder({
		            title = "Choose Image Magick program/application folder",
		        }, props, 'imageMagickBin' )
		    end,
		},
	}
	it[#it + 1] = vf:row {
	    vf:static_text {
	        title = "Conversion Parameters",
			width = share( labelWidth ),
			enabled = bind 'imageMagickEna',
	    },
		vf:combo_box {
			value = bind 'imageMagickParams',
			width_in_chars = 35,
			items = { "-format png -define png:bit-depth=8" },--, "-format jp2 -define jp2:rate=.5" },
			tooltip = "Choose options as delivered from factory, and/or edit to taste...",
			enabled = bind 'imageMagickEna',
			immediate=true, -- dunno if necessary, but comforting.
		},
		vf:static_text {
		    title = 'Help',
		    text_color = LrColor( 'blue' ),
		    mouse_down = function()
		        app:call( Call:new{ name="Image Magick Help", async=true, guard=App.guardVocal, main=function( call )
		            LrHttp.openUrlInBrowser( "http://www.imagemagick.org/script/command-line-options.php" )
		        end } )
		    end,
			enabled = bind 'imageMagickEna',
		},
	}
	it[#it + 1] = vf:row {
        -- exported intermediate files: ( ) keep on disk  ( ) add to catalog  [ ] stack  (above/below).
	    vf:static_text {
	        title = "Keep pre-converted file",
			width = share( labelWidth ),
			enabled = bind 'imageMagickEna',
	    },
	    vf:radio_button {
	        title = "On Disk",
	        value = bind 'imageMagickKeep',
	        checked_value = 'keepOnDisk',
	        width = share 'im_keep_col_1',
			enabled = bind 'imageMagickEna',
	    },
	    vf:radio_button {
	        title = "In Catalog",
	        value = bind 'imageMagickKeep',
	        checked_value = 'addToCatalog',
	        width = share 'im_keep_col_2',
			enabled = bind 'imageMagickEna',
	    },
	    vf:checkbox {
	        title = 'Stack',
	        value = bind 'imageMagickKeepStack',
	        enabled = bind {
	            keys = { 'imageMagickEna', 'imageMagickKeep' },
	            operation = function()
	                if props.imageMagickEna and props.imageMagickKeep == 'addToCatalog' then
	                    return true
	                else
	                    return false
	                end
	            end,
	        },
	    },
	    vf:popup_menu {
	        value = bind 'imageMagickKeepStackPos',
	        items = {{ title="Above", value='above' }, { title="Below", value='below' }},
	        enabled = bind {
	            keys = { 'imageMagickEna', 'imageMagickKeep', 'imageMagickKeepStack' },
	            operation = function()
	                if props.imageMagickEna and props.imageMagickKeep == 'addToCatalog' and props.imageMagickKeepStack then
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
	        title = "Discard pre-converted file",
			width = share( labelWidth ),
			enabled = bind 'imageMagickEna',
	    },
	    vf:radio_button {
	        title = "Move to trash",
	        value = bind 'imageMagickKeep',
	        checked_value = 'trash',
	        width = share 'im_keep_col_1',
			enabled = bind 'imageMagickEna',
	    },
	    vf:radio_button {
	        title = "Permanently delete",
	        value = bind 'imageMagickKeep',
	        checked_value = 'delete',
	        width = share 'im_keep_col_2',
			enabled = bind 'imageMagickEna',
	    },
	}
    space()
    it[#it + 1] = vf:static_text {
        title = "Note: It is the 'Add To This Catalog' box in 'Export Location' section above that determines whether\n*converted* file is added to catalog and stacked...",
        enabled = bind 'imageMagickEna',
    }

    space()
    sep()
    space()
	
	it[#it + 1] = self:sectionForFilterInDialogGetStatusView()

	return it
	
end



local _imDflt
if WIN_ENV then 
    _imDflt = "C:\\Program Files\\ImageMagick-6.7.3-Q16"
else
    _imDflt = "/Applications/ImageMagick"
end



--- This function obtains access to the photos and removes entries that don't match the metadata filter.
--
--  @usage called *before* post-process-rendered-photos function.
--  @usage base class has no say (need not be called).
--
function ImageMagick:shouldRenderPhotoMethod( photo )

    local exportSettings = self.exportSettings
    --assert( exportSettings, "no es" )

    --Debug.lognpp( exportSettings )
    --Debug.showLogFile()
    
    --local fileFormat = photo:getRawMetadata( 'fileFormat' )
    
    return true -- it's not up to this export filter to decide not to export, it's up to custom-export-check function, if implemented.

end



function ImageMagick:assureBottom( uiTidbit, actionExpr, cancelExpr )
    local filters, first, last, total, names = self:getFilters()
    if filters[last] == self.id then
        self:log( "This filter is bottom-most of filters from *this* plugin - good (but there is no way to tell if there are filters from other plugins below it), since converted files with different extensions exported via *filter* break the rules - downstream filter or export service won't be getting what they expect. I mean, they might be getting the pre-converted file, if not discarded, but they'll not be receiving the converted file. If your downstream filter or export service depends on converted file, then consider using a custom export service instead of an export filter for exporting unconventional formats.", self.filterName )
    else
        local lastName = names[last]
        assert( str:is( lastName ), "no last name" )
        
        uiTidbit = uiTidbit.."\n \nFilters from this plugin (mostly):\n-------------------------------------\n"
        local b = {}
        for i, name in ipairs( names ) do
            self:logV( "Filter #^1: ^2", i, filters[i] or name ) -- log ID from this plugin, or "name" of filter from some other plugin.
            b[#b + 1] = str:fmtx( "^1: ^2", i, name ) -- display names only.
        end
        uiTidbit = uiTidbit..table.concat( b, "\n" ).."\n \n*** Order may make a difference in result." -- reminder: export service, although present in preset, is not copied to settings.
        local button = app:show{ confirm="Of all filters in this plugin, '^1' is not the lowest (but maybe should be at the bottom), '^2' is (but there is no way to tell if filters from other plugins are below it). This *may* cause problems for down-stream filter or export service (depends which filter/service and what it's expectations are).\n \n^3\n \nSo, ^4 regardless, or ^5?",
            subs = { self.filterName, lastName, uiTidbit, LrStringUtils.lower( actionExpr ), LrStringUtils.lower( cancelExpr ) },
            buttons = { dia:btn( actionExpr, 'ok' ), dia:btn( cancelExpr, 'cancel', false ) },
            actionPrefKey = str:fmtx( "^1 - filter position", self.filterName ),
        }
        if button == 'ok' then
            self:logV( "'^1' is not bottom-most filter - ok I guess..", self.filterName )
        else
            self:logV( "'^1' is not bottom-most filter - not being considered ok..", self.filterName )
            return nil
        end
    end
    return true
end



--- Post process rendered photos (overrides base class).
--
--  @usage reminder: videos are not considered rendered photos (won't be seen by this method).
--
function ImageMagick:postProcessRenderedPhotosMethod()

    local functionContext, filterContext = self.functionContext, self.filterContext
    local exportSettings = filterContext.propertyTable

    local addToCatalog = {} -- intermediaries (e.g. initial tif or jpg), and/or converted files.

    app:call( Service:new{ name=str:fmtx( "^1 - Post Process Rendered Photos", self.filterName ), preset=exportSettings.pluginManagerPreset, progress=true, main=function( call )
    
        assert( exportSettings, "no es" )
        
        if exportSettings.imageMagickEna then
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
        
        -- Note: whether this filter needs to be bottom or not depends on extension (actually filename too, since that could conceivably be changed via conversion parameters too)
        -- If same extension (and filename), then converted file will satisfy rendition.
        local convExt = exportSettings.imageMagickParams:match( "%-format%s+(%w-)%s+" )
        if not str:is( convExt ) then
            convExt = exportSettings.imageMagickParams:match( "%-format%s+(%w-)$" )
        end
        local uiTidbit
        if str:is( convExt ) then
            self:logV( "converting to extension: ^1", convExt )
            if #photos > 0 then
                local export = Export:newDialog() -- dummy export object to get dest ext (of export service)
                local expSrvExt = export:getDestExt( exportSettings, photos[1], unionCache )
                if str:is( expSrvExt ) then
                    if str:isEqualIgnoringCase( convExt, expSrvExt ) then
                        uiTidbit = str:fmtx( "Note: conversion extension is same as that expected by export service, namely '^1', so probably this filter does not need to be last. However the downstream filter may request a different extension, or even filename, so it's not definitive - your call (try reordering filters if you're having problems).", expSrvExt )
                    else
                        uiTidbit = str:fmtx( "Note: conversion extension is '^1' and export service is expecting '^2', so probably this filter *does* need to be last. However it's not definitive - your call (try reordering filters if you're having problems).", convExt, expSrvExt )
                    end
                else
                    uiTidbit = str:fmtx( "Note: it's uncertain if conversion extension (^1) is same as that expected by export service, so all bets are off whether this filter needs to be last or not. Try reordering filters if you're having problems.", convExt )
                end
            -- else ui-tidbit stays nil, as flag.
            end
        else
            -- Debug.pause( "no match in", exportSettings.imageMagickParams )
            self:logV( "converting to same filename/extension" )
            uiTidbit = str:fmtx( "Note: conversion extension is same as that expected by export service, so probably this filter does not need to be last. However the downstream filter may request a different extension, or even filename, so it's not definitive - your call (try reordering filters if you're having problems)." )
        end

        if uiTidbit then -- there are photos, and qualifying tidbit.        
        
            local status = self:assureBottom( uiTidbit, "Proceed", "Abort" )
            if status then
                -- proceed ('nuff logged).
            else
                local s, m = self:cancelExport()
                if s then
                    self:log( "Export canceled (there was probably still an error about how nothing got rendered - that's to be expected..)." )
                else
                    self:logW( "Some photo rendering could not be skipped - ^1", m )
                end
                return
            end
        else
            self:logV( "Videos only (no photos being exported), which should pass through unhampered." )
        end
        
        local savedReimportSetting = exportSettings.LR_reimportExportedPhoto
        local reimportExportedPhoto
        
        local renditionOptions = {
            plugin = _PLUGIN, -- ###3 I have no idea what this does, or if it's better to set it or not (usually it's not set).
            --renditionsToSatisfy = renditions, -- filled in below.
            filterSettings = function( renditionToSatisfy, exportSettings )
                assert( exportSettings, "no es" )
                
                local newPath = renditionToSatisfy.destinationPath -- by default return unmodified.
                self:log( "Rendition path to satisfy: ^1", newPath )
                
                local photo = renditionToSatisfy.photo -- coming back to this, months later, I'm confused: shouldn't this be 'sourceRendition'? - I mean, if
                -- the rendition has not yet been "satisfied", then how can it possibly have a photo associated with it? ###4 somehow this is correct, so...
                
                -- note: dropbox compat is redundent when exporting as virtual copy or doing image magick conversion.
                assert( exportSettings.imageMagickEna, "imageMagickEna should be pre-checked" )
                -- export to temp dir and move atomically - keeps windows from screwing up the thumbnail, and generally keeps other apps from accessing until whole file is ready.
                local fn = LrPathUtils.leafName( newPath )
                local dir = LrPathUtils.parent( newPath )
                local newDir = LrPathUtils.getStandardFilePath( 'temp' )
                newPath = LrPathUtils.child( newDir, fn )
                if newDir then
                    newPath = LrFileUtils.chooseUniqueFileName( newPath )
                    self:logV( "Diverting upstream rendition to: ^1", newPath )
                else
                    self:logE( "No temp dir" )
                    newPath = renditionToSatisfy.destinationPath
                end
                
                if newPath ~= renditionToSatisfy.destinationPath then -- re-destined or renamed.
                    if savedReimportSetting then
                        exportSettings.LR_reimportExportedPhoto = false -- make sure Lr does not do it.
                        reimportExportedPhoto = true -- make sure this Exportant filter does.
                    else
                        exportSettings.LR_reimportExportedPhoto = false
                        reimportExportedPhoto = false -- make sure this Exportant filter does.
                        --Debug.pause( "false" )
                    end
                else -- not renamed
                    exportSettings.LR_reimportExportedPhoto = savedReimportSetting -- Let Lr do it.
                    reimportExportedPhoto = false
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
                if unionCache:getRawMetadata( srcPhoto, 'fileFormat' ) == 'VIDEO' then
                    self:log( "Source video rendition passed through." )
                    renditionToSatisfy:renditionIsDone( true ) -- tested: this works!
                    break
                end
                -- fall-through => photo, not skipped.
                local success, pathOrMessage = sourceRendition:waitForRender()
                if not success then
                    local errm = pathOrMessage or "?"
                    self:logW( "Unable to export '^1', error message: ^2. This may not cause a problem with this export, but may indicate a problem with this plugin, or with the source photo.", renditionToSatisfy.destinationPath, errm )
                        -- Note: if export is canceled, path-or-message can be nil despite success being false. ###3 - this may have been a flukey glitch - dunno.
                    renditionToSatisfy:renditionIsDone( false, errm.." - see warning in log file for more info." )
                    break
                end
                local renderedPath = pathOrMessage
                assert( exportSettings.imageMagickEna, "?" )
                if renderedPath == renditionToSatisfy.destinationPath then
                    self:logW( "path was not diverted - it should be for image magick conversion." )
                    break
                end
                self:logV( "Destination path was originally to be '^1', but has changed to '^2'", renditionToSatisfy.destinationPath, renderedPath ) -- this will always be the case if a sibling folder is defined.
                local usable, qual = convert:isUsable()
                if not usable then
                    self:logW( qual )
                    renditionToSatisfy:renditionIsDone( false, "Image Magick convert executable is not usable - "..qual )
                    break -- no export
                end
                if not str:is( exportSettings.imageMagickParams, "imageMagickParams" ) then
                    self:logW( "Unable to convert via ImageMagick - there are no params." )
                    renditionToSatisfy:renditionIsDone( false, "Unable to convert via ImageMagick - there are no params." )
                    break
                end
                local keepInitialExport = exportSettings.imageMagickKeep
                assert( keepInitialExport ~= nil, "== nil" )
                -- convert type of property, since some folks will be migrating from legacy version - probably never happen, since setting is member of different filter ID, still... (cheap insurance).
                if type( keepInitialExport ) == 'boolean' then -- Exportant v3.0
                    if keepInitialExport then
                        keepInitialExport = 'keepOnDisk'
                    else
                        keepInitialExport = 'trash'
                    end
                end
                assert( renderedPath ~= renditionToSatisfy.destinationPath, "path match shouldn't" )
                -- Debug.pause( renderedPath, destToSatisfy[srcPhoto], renditionToSatisfy.destinationPath )
                if not fso:existsAsFile( renderedPath ) then
                    self:logW( "No existe: ^1", renderedPath )
                    renditionToSatisfy:renditionIsDone( false, str:fmtx( "No existe: ^1", renderedPath ) ) -- info in warning is same.
                    break
                end
                
                local output -- path of converted file
                
                local destExt                        
                if str:is( convExt ) then
                    destExt = convExt
                    output = LrPathUtils.replaceExtension( renderedPath, convExt )
                    self:logV( "converting to ^1", output )
                else
                    -- Debug.pause( "no match in", exportSettings.imageMagickParams )
                    destExt = LrPathUtils.extension( renderedPath )
                    output = renderedPath -- I guess (?)
                    self:logV( "converting to same filename/extension: '^1'", destExt )
                end

                -- dest-path will be converted file in destination location - note: it may or may not satisfy the rendition, depending on extension.
                local destPath = LrPathUtils.replaceExtension( renditionToSatisfy.destinationPath, destExt ) -- user-desired (primary) export file which may or may not satisfy the rendition.
                
                -- http://www.imagemagick.org/script/command-line-options.php
                local params = str:fmtx( '"^1" ^2', renderedPath, exportSettings.imageMagickParams ) -- e.g. '-format png -define png:bit-depth=8'.
                local sts, cmdOrMsg, resp = convert:executeCommand( params, { output } ) -- could mogrify instead of convert if not keeping initial export, but why have special handling..
                if not sts then
                    self:logW( "Unable to convert '^1' to '^2' due to error: ^3. Command-line app response: ^4", renderedPath, output, cmdOrMsg or "?", resp or "" )
                    renditionToSatisfy:renditionIsDone( false, str:fmtx( "Unable to convert file due to command error - see warning in log file for more info." ) )
                    break
                end
                if fso:existsAsFile( output ) then
                    self:logV( "Converted exported file (^1) to ^2 (^3) using command: ^4", renderedPath, destExt, output, cmdOrMsg )
                else
                    self:logW( "Unable to convert '^1' (e.g. to png) - file not found: ^2", renderedPath, output )
                    renditionToSatisfy:renditionIsDone( false, str:fmtx( "Convert file not in expected location - see warning in log file for more info." ) )
                    break
                end
                local eq = str:isEqualIgnoringCase( destPath, srcPhotoPath )
                if eq then -- exp dest file is same as source photo file - not ok..
                    renditionToSatisfy:renditionIsDone( false, "This filter does not support overwriting source photo file: "..srcPhotoPath ) -- no need for additional W/E logging here.
                    break
                end
                local s, m = fso:moveFile( output, destPath, true, true ) -- move converted file to same folder where export is destined - may or may not be a different extension.
                if s then
                    if m then
                        self:logV( m )
                    end
                    self:log( "Moved '^1' into place: ^2", output, destPath ) -- may or may not satusfy rendition
                else
                    self:logW( "Unable to move converted file into place - ^1", m or "no reason given" ) -- m includes paths.
                    break
                end
                -- satisfy rendition and optionally keep.
                -- beware: it's possible dest-path will be same as that to satisfy, in which case file was already moved.
                if destPath ~= renditionToSatisfy.destinationPath then -- ext was different, so dest-path (moved above) will not have satisfied rendition.
                    local eq = str:isEqualIgnoringCase( renditionToSatisfy.destinationPath, srcPhotoPath )
                    if eq then -- exp dest file is same as source photo file - not ok..
                        renditionToSatisfy:renditionIsDone( false, "This filter does not support overwriting source photo file: "..srcPhotoPath ) -- no need for additional W/E logging here.
                        break
                    end
                    local s, m = fso:moveFile( renderedPath, renditionToSatisfy.destinationPath, true, true ) -- this is the line that makes Lr happy when rendition-is-done is called (avoids error message that expected file not present in export destination).
                    if s then
                        self:log( "Moved '^1' to '^2' to satisfy rendition.", renderedPath, renditionToSatisfy.destinationPath )
                        renditionToSatisfy:renditionIsDone( true )
                        -- LrTasks.yield() - let Lr see it's been done (not necessary - keep comment as reminder).
                        if keepInitialExport == 'keepOnDisk' then
                            self:logV( "Keeping '^1' on disk, but not adding to catalog.", renditionToSatisfy.destinationPath )
                        elseif keepInitialExport == 'addToCatalog' then
                            self:logV( "Keeping '^1' on disk, and adding to catalog.", renditionToSatisfy.destinationPath )
                            local already = catalog:findPhotoByPath( renditionToSatisfy.destinationPath )
                            if already then
                                self:logV( "Already in catalog: ^1", renditionToSatisfy.destinationPath )
                            else
                                addToCatalog[#addToCatalog + 1] = { pathToAdd=renditionToSatisfy.destinationPath, srcPhoto=srcPhoto, srcPhotoPath=srcPhotoPath } -- ###3 could add in place.
                            end
                        -- note: in this and the other place, if one moves to trash immediately after satisfying the rendition, there is a good chance
                        -- the next import filter down will fail. ###3
                        elseif keepInitialExport == 'trash' then
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
                        elseif keepInitialExport == 'delete' then
                            local s, m = fso:deleteFile( renditionToSatisfy.destinationPath )
                            if s then
                                -- m always nil.
                                self:logV( "Deleted '^1'.", renditionToSatisfy.destinationPath )
                            else
                                self:logW( "Unable to move pseudo-satisfying rendition to trash after format conversion - ^1.", m or "no reason given" ) -- m should have paths.
                                -- break - png was exported, and export satisfied: user can always manually delete extraneous file.
                            end
                        else
                            app:error( "bad value: ^1", keepInitialExport )
                        end
                    else
                        m = m or "?" -- probably not needed(?) (somehows I've been getting nil error message from somewheres - not sure how/where..)
                        self:logW( "Unable to move file to satisfy rendition - ^1", m )
                        renditionToSatisfy:renditionIsDone( false, m.." - see warning in log file for more info." )
                        break
                    end
                else
                    self:logV( "Dest paths match: ^1", destPath )
                    renditionToSatisfy:renditionIsDone( true )
                end
                LrTasks.yield() -- give Lr a chance to see file exists in destination as expected (@31/Oct/2013 20:17 - dunno if this is needed).
                
                -- Reminder: at this point, rendition has been affirmatively satisfied.
                
                -- Note: Lr's importer won't touch the converted file, if extension is different, since it doesn't know about it (i.e. if not the file satisfying the rendition).
                if reimportExportedPhoto then
                
                    local destPhoto = cat:findPhotoByPath( destPath )
                    if destPhoto == nil then -- photo not findable, so either it's not there or there has been a path case change, either way - try to add it.
                        --Debug.lognpp ( exportSettings )
                        --Debug.showLogFile()
                        local stackPhoto
                        local stackPos
                        
                        if exportSettings.LR_reimport_stackWithOriginal then
                            stackPhoto = srcPhoto
                            local srcDir = LrPathUtils.parent( srcPhotoPath )
                            local newDir = LrPathUtils.parent( destPath )
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
                        local s, m = cat:update( 15, "Reimport Exported & Converted Photo", function( context, phase )
                        
                            catalog:addPhoto( destPath, stackPhoto, stackPos )
                            
                        end )
                        if s then
                            if stackPhoto then
                                self:log( "Reimported '^1' (stacked ^2 original)", destPath, stackPos )
                            else
                                self:log( "Reimported '^1'", destPath )
                            end
                        else
                            self:logE( m )
                        end
                    else
                        self:log( "Already in catalog." )
                    end
                
                end
                
            until true
        end
    end, finale=function( call )
        -- incorporates things common to "all" finale methods (e.g. base filter class).
        self:log()
        exifTool:closeSession( call.ets )
        if call.status then
            local settings = filterContext.propertyTable
            self:logV( "No error thrown." )
            if #addToCatalog > 0 then -- theoretically not already in catalog.
                local s, m = cat:update( 30, "Adding exported files to catalog", function( context, phase )
                    for i, v in ipairs( addToCatalog ) do
                        local stackPhoto
                        local stackPos
                        if settings.imageMagickKeepStack then
                            stackPhoto = v.srcPhoto
                            local srcDir = LrPathUtils.parent( v.srcPhotoPath )
                            local newDir = LrPathUtils.parent( v.pathToAdd )
                            if srcDir == newDir then
                                stackPos = settings.imageMagickKeepStackPos
                            else
                                self:logV( "dirs not same - src: '^1', new: '^2' - so not stacking with original", srcDir, newDir )
                                stackPhoto = nil -- changed my mind...
                            end
                        else
                            -- nuthin.
                        end
                        local addedPhoto, errm = LrTasks.pcall( catalog.addPhoto, catalog, v.pathToAdd, stackPhoto, stackPos)
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



function ImageMagick.startDialog( props )
    dialogEnding = false
    local filter = ExtendedExportFilter.assureFilter( ImageMagick, props )
    filter:startDialogMethod()
end



function ImageMagick.sectionForFilterInDialog( vf, props )
    local filter = ExtendedExportFilter.assureFilter( ImageMagick, props )
    return filter:sectionForFilterInDialogMethod()
end



function ImageMagick.endDialog()
    dialogEnding = true
end



-- reminder: update status filter function need not be implemented, as long as ID passed to listener reg func is this class.
--[[
function ImageMagick.updateFilterStatus( id, props, name, value )
    local filter = ExtendedExportFilter.assureFilter( ImageMagick, props )
    filter:updateFilterStatusMethod( name, value )
end
--]]



function ImageMagick.shouldRenderPhoto( props, photo )
    local filter = ExtendedExportFilter.assureFilter( ImageMagick, props )
    return filter:shouldRenderPhotoMethod( photo )
end



--- Post process rendered photos.
--
function ImageMagick.postProcessRenderedPhotos( functionContext, filterContext )
    local filter = ExtendedExportFilter.assureFilter( ImageMagick, filterContext.propertyTable, { functionContext=functionContext, filterContext=filterContext } )
    filter:postProcessRenderedPhotosMethod()
end



ImageMagick.exportPresetFields = {
	{ key = 'imageMagickEna', default = false },
	{ key = 'imageMagickBin', default = _imDflt },
	{ key = 'imageMagickParams', default = "" },
	-- reminder: refers to pre-converted output
	{ key = 'imageMagickKeep', default = 'keepOnDisk' },
	{ key = 'imageMagickKeepStack', default = false }, -- reminder: n/a if 'keep-on-disk'.
	{ key = 'imageMagickKeepStackPos', default = 'below' },
}



ImageMagick:inherit( ExtendedExportFilter ) -- inherit *non-overridden* members.



return ImageMagick
