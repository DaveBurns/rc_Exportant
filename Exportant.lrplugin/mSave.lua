-- mSave.lua

-- one-func does all menu handler.
app:service{ name="Re-save (RGB files) destructively", async=true, main=function( call )

    call:initStats{ 'totalTargets', 'ripeTargets', 'processed', 'okAlready', 'videoSkipped', 'missingSkipped', 'virtualCopySkipped', 'notWritableSkipped', 'dngSkipped', 'psdSkipped', 'rawSkipped', 'lockedSkipped' }
    if gbl:getValue( 'background' ) then
        local s, m = background:pause()
        if not s then
            app:show{ error=m }
            return
        end
    end
    call.selPhotosEtc = cat:saveSelPhotos() -- comment out if restoring original photos etc. upon completion is not required.
    -- local props = LrBinding.makePropertyTable( call.context ) -- uncomment if you need local (temporary) properties.
    app:initPref( 'realMode', false )
    app:initPref( 'saveColorSpace', "AdobeRGB" )
    app:initPref( 'tifBitDepth', 16 )
    app:initPref( 'recycle', true )
    app:initPref( 'jpegPreset', "" )
    app:initPref( 'tiffPreset', "" )
    app:initPref( 'saveXmpBefore', true )
    app:initPref( 'saveXmpAfter', true )
    local export = Export:new()

    local function chg( id, p, k, v )
        app:pcall{ name="chg", async=not LrTasks.canYield(), guard=App.guardSilent, main=function( call )
            local status, sOrM = LrTasks.pcall( export.getSettingsFromPreset, export, { file=v } )
            local name = app:getPrefName( k )
            if not status then
                app:show{ warning="Bogus export preset file: '^1' - ^2", v, sOrM }
            else
                local settings = sOrM
                if name == 'jpegPreset' then
                    if settings.LR_format == 'JPEG' then
                        -- good
                    else
                        app:show{ warning="JPEG export preset must be for jpegs (not ^1).", settings.LR_format }
                    end
                elseif name == 'tiffPreset' then
                    if settings.LR_format == 'TIFF' then
                        -- good
                    else
                        app:show{ warning="TIFF export preset must be for tiffs (not ^1).", settings.LR_format }
                    end
                else
                    Debug.pause( name )
                end
            end
        end }
    end
    chg( nil, nil, app:getPrefKey( 'jpegPreset' ), app:getPref( 'jpegPreset' ) )
    chg( nil, nil, app:getPrefKey( 'tiffPreset' ), app:getPref( 'tiffPreset' ) )
    view:setObserver( prefs, app:getPrefKey( 'jpegPreset' ), ExtendedManager, chg )
    view:setObserver( prefs, app:getPrefKey( 'tiffPreset' ), ExtendedManager, chg )
    
    local vi = {} -- binding must be individuated when using app-show method, since items are appended to array before final view created.
    vi[#vi + 1] = vf:row {
        vf:static_text {
            title = "Recycle original",
            width = share 'lbl_wid',
        },
        vf:radio_button {
            title = "Yes (if possible)",
            bind_to_object = prefs,
            value = app:getPrefBinding( 'recycle' ),
            checked_value = true,
            width = share 'item_1_width',
        },
        vf:radio_button {
            title = "No (delete permanently)",
            bind_to_object = prefs,
            value = app:getPrefBinding( 'recycle' ),
            checked_value = false,
        },
    }
    vi[#vi + 1] = vf:spacer{ height=5 }
    vi[#vi + 1] = vf:row {
        vf:static_text {
            title = "Save XMP",
            width = share 'lbl_wid',
        },
        vf:checkbox {
            title = "Before",
            bind_to_object = prefs,
            value = app:getPrefBinding( 'saveXmpBefore' ),
            width = share 'item_1_width',
            enabled = LrBinding.keyEquals( app:getPrefKey( 'recycle' ), true )
        },
        vf:checkbox {
            title = "After",
            bind_to_object = prefs,
            value = app:getPrefBinding( 'saveXmpAfter' ),
        },
    }
    vi[#vi + 1] = vf:spacer{ height=5 }
    vi[#vi + 1] = vf:row {
        vf:static_text {
            title = "JPEG Export Preset",
            width = share 'lbl_wid',
        },
        vf:edit_field {
            bind_to_object = prefs,
            value = app:getPrefBinding( 'jpegPreset' ),
            width_in_chars = 40,
        },
        vf:push_button {
            title = 'Browse',
            action = function()
            
                -- pre 13/Apr/2014 3:03
                --local dir = LrPathUtils.getStandardFilePath( 'appData' )
                --dir = LrPathUtils.child( dir or "", 'Export Presets' )
                -- post 13/Apr/2014 3:04 ###1 not yet released
                local dir = lightroom:getPresetDir( 'Export Presets' )
                
                dia:selectFile( {
                    title = app:getAppName().." - JPEG Export Preset",
                    subtitle = "Select preset to be used for saving jpg files.",
                    initialDirectory = dir,
                }, prefs, app:getPrefKey( 'jpegPreset' ) )     -- change handler to take it from here.. 
            end,
        }
    }
    vi[#vi + 1] = vf:row {
        vf:static_text {
            title = "TIFF Export Preset",
            width = share 'lbl_wid',
        },
        vf:edit_field {
            bind_to_object = prefs,
            value = app:getPrefBinding( 'tiffPreset' ),
            width_in_chars = 40,
        },
        vf:push_button {
            title = 'Browse',
            action = function()
                --local dir = LrPathUtils.getStandardFilePath( 'appData' )
                --dir = LrPathUtils.child( dir or "", 'Export Presets' )
                local dir = lightroom:getPresetDir( 'Export Presets' ) -- ditto ###1
                
                dia:selectFile( {
                    title = app:getAppName().." - TIFF Export Preset",
                    subtitle = "Select preset to be used for saving tif files.",
                    initialDirectory = dir,
                }, prefs, app:getPrefKey( 'tiffPreset' ) )     -- change handler to take it from here.. 
            end,
        }
    }
    vi[#vi + 1] = vf:spacer{ height=20 }
    vi[#vi + 1] = vf:row {
        vf:static_text {
            title="Run Mode",
            width = share 'lbl_wid',
        },
        vf:radio_button {
            --title = "Make changes, for real (if unchecked, then it's just a test run)",
            title = "Real",
            bind_to_object = prefs,
            value = app:getPrefBinding( 'realMode' ),
            checked_value = true,
            tooltip = "if checked, you will be running in \"Real\" mode, and source photo files or xmp sidecars will be modified, and catalog will be processed (subject to final prompt approval).",
        },
        vf:radio_button {
            --title = "Make changes, for real (if unchecked, then it's just a test run)",
            title = "Test",
            bind_to_object = prefs,
            value = app:getPrefBinding( 'realMode' ),
            checked_value = false,
            tooltip = "if checked, you will be running in \"Test\" mode - nothing will be changed, but you can see what would have been changed if running in real mode.",
        },
        vf:static_text {
            title=" (note: you need to run in real mode, once satisfied with test mode)",
        },
    }
    local targetPhotos = dia:promptForTargetPhotos { -- target photos may be those selected, visible in filmstrip, whole catalog, or most-selected only.
        prefix = "Re-save",
        viewItems = vi,
        accItems = nil,
        returnComponents = nil,
        call = call,
    }
    if call:isQuit() then -- user canceled or program aborted.
        return
    end
    --Debug.pause( app:getPref( 'saveColorSpace' ) )
    -- fall-through => there is at least one photo to process.
    assert( #targetPhotos > 0, "no sel photos" )
    call:setStat( 'totalTargets', #targetPhotos )
    call.selSet = tab:createSet( targetPhotos )
    call.realMode = app:getPref( 'realMode' )
    assert( call.realMode ~= nil, "real mode needs to be initialized" )
    --Debug.pause( call.realMode )
    call:setCaption( "Acquiring metadata..." )
    local cache = lrMeta:createCache{ photos=targetPhotos, rawIds={ 'path', 'isVirtualCopy', 'fileFormat' }, fmtIds={ 'copyName', 'fileName' } }
    call:setCaption( "Scrutinizing target photos..." )
    local photos = {} -- for saving metadata and then processing.
    local resavePhotos = {} -- processed: re-save metadata.
    local yc = 0
    for i, photo in ipairs( targetPhotos ) do
        call:setPortionComplete( i-1, #targetPhotos )
        yc = app:yield( yc )
        repeat
            local fmt = cache:getRawMetadata( photo, 'fileFormat' )
            if fmt == 'RAW' then
                call:incrStat( 'rawSkipped' )
                call.selSet[photo] = false
                break
            end
            if fmt == 'DNG' then
                call:incrStat( 'dngSkipped' )
                call.selSet[photo] = false
                break
            end
            if fmt == 'PSD' then
                call:incrStat( 'psdSkipped' )
                call.selSet[photo] = false
                break
            end
            if fmt == 'VIDEO' then -- ###3 could support videos somehow too.
                call:incrStat( 'videoSkipped' )
                call.selSet[photo] = false
                break
            end
            local virt = cache:getRawMetadata( photo, 'isVirtualCopy' )
            if virt then
                call:incrStat( 'virtualCopySkipped' )
                call.selSet[photo] = false
                break
            end
            local path = cache:getRawMetadata( photo, 'path' )
            if not fso:existsAsFile( path ) then
                call:incrStat( 'missingSkipped' )
                call.selSet[photo] = false
                break
            end
            local locked, lockDate = cat:isLocked( photo, true, cache ) -- check xmp too (rgb source file) -- make sure it's read/write.
            if locked then
                app:logV( "Locked: ^1", lockDate ) -- lock-date may be descriptive text if locked due to xmp but not CM.
                call:incrStat( 'lockedSkipped' )
                call.selSet[photo] = false
                break
            end
            photos[#photos + 1] = photo
        until true
        if call:isQuit() then
            return
        end
    end
    call:setPortionComplete( 1 )
    if #photos == 0 then
        app:show{ info="No photos ripe for re-saving." }
        call:cancel()
        return
    end
    call:setStat( 'ripeTargets', #photos )

    local jpegPreset = app:getPref( 'jpegPreset' )
    local tiffPreset = app:getPref( 'tiffPreset' )
    local recycle = app:getPref{ name='recycle', expectedType='boolean' }
    assert( recycle ~= nil, "nil" )
    local saveXmpBefore = app:getPref( 'saveXmpBefore' )
    local saveXmpAfter = app:getPref( 'saveXmpAfter' )
    
    local jpegSettings = export:getSettingsFromPreset{ file=jpegPreset }
    jpegSettings.LR_export_postProcessing = nil
    local tiffSettings = export:getSettingsFromPreset{ file=tiffPreset }
    tiffSettings.LR_export_postProcessing = nil
    
    -- note: we already know that ext is from rgb image file (not raw).
    local function getFormat( ext )
        local e2 = ext:sub( 1, 2 )
        if str:isEqualIgnoringCase( e2, "jp" ) then -- jpg or jpeg
            return 'JPEG', jpegSettings
        elseif str:isEqualIgnoringCase( e2, "ti" ) then -- tif or tiff.
            return 'TIFF', tiffSettings
        else
            error( "Unrecognized extension: '^1'", ext )
        end
    end

    -- photo processing function - errors will be caught and logged (and so are NOT fatal).
    local function processPhotoOrVideo( photo )
        assert( call.realMode ~= nil, "bad mode" )
        local photoPath = cache:getRawMetadata( photo, 'path' )
        app:log( photoPath )
        
        local dir = LrPathUtils.parent( photoPath )
        local filename = cache:getFormattedMetadata( photo, 'fileName' )
        local ext = LrPathUtils.extension( filename )
        local baseName = LrPathUtils.removeExtension( filename )
        local tempBaseName = LrPathUtils.addExtension( baseName, '_re-save_' )
        local tempFilename = LrPathUtils.addExtension( tempBaseName, ext )
        local expPath = LrPathUtils.child( dir, tempFilename )
        local format, baseline = getFormat( ext )
        local strictOrNo
        if app:isAdvDbgEna() then
            strictOrNo = 'strict'
        else
            strictOrNo = 'no'
        end
        
        local s, m = export:doExport {
            photo = photo, -- will accept 'photo' or 'photos'.
            constrainSettings = strictOrNo, -- "no", or "strict".
            settings = {
                LR_format = format,
                LR_collisionHandling = 'overwrite',
                -- location:
                LR_export_destinationType = 'specificFolder',    
                LR_export_destinationPathPrefix = dir, 
                LR_export_useSubfolder = false,    
                -- filename:                
                LR_renamingTokensOn = true, 
        	    LR_tokens = "{{custom_token}}",
        	    LR_tokenCustomString = tempBaseName,
        	    -- metadata
            	LR_metadata_keywordOptions = "lightroomHierarchical", -- probably not necessary, but hopefully doesn't hurt.
            	LR_minimizeEmbeddedMetadata = false, -- Lr3-
                LR_embeddedMetadataOption = 'all', -- Lr4+
            },
            constrainDefaults = strictOrNo, -- constrain default values too.
            defaults = baseline,
        }
        --Debug.pause( s, m )
        if s then
            app:assert( fso:existsAsFile( expPath ), "Exported file does not exist: ^1", expPath )
            app:logV( "Exported to temp file: ^1", expPath )
            local ds = developSettings:getAdobeDefaultSettings( 'rgb', photo:getDevelopSettings() ) -- same pv.
            if call.realMode then
                local s, m = developSettings:adjustPhotos( { photo }, "Reset Dev \"in the name\" of Re-save", ds ) -- 10 second default timeout should be OK (?)
                if s then
                    if recycle then
                        app:logV( "Photo settings were reset - recycling original." )
                        local s, m = fso:moveToTrash( photoPath )
                        if s then
                            if m then
                                app:logV( m )
                            end
                        else
                            app:error( m )
                        end
                    else
                        app:logV( "Photo settings were reset - overwriting original." )
                    end
                    if s then
                        local s, m = fso:moveFile( expPath, photoPath, false, not recycle ) -- should only need to overwrite original if not recycled.
                        if s then
                            app:log( "Re-saved photo by replacing with exported version and resetting settings." )
                            call:incrStat( 'processed' )
                            resavePhotos[#resavePhotos + 1] = photo
                        else
                            app:logE( m )
                        end
                    else
                        app:logE( m )
                    end
                else
                    app:logE( m )
                end
            else
                app:log( "*** IF NOT TEST RUN, WOULD reset original photo, then move '^1' to '^2'.", expPath, photoPath )
                local s, m = fso:deleteFile( expPath )
                if s then
                    app:log( "(instead, just deleted '^1'.", expPath )
                    call:incrStat( 'processed' )
                    resavePhotos[#resavePhotos + 1] = photo
                else
                    app:logE( m )
                end
            end
        else
            app:logE( m )
        end
        
        call.selSet[photo] = false
        return true
    end

    local vi = {}
    vi[#vi + 1] = vf:row {
        vf:static_text {
            title="If uncertain, answer \"No\"!!!",
            font = "<system/bold>",
        },
    }
    local button = app:show{ confirm="*** WARNING: Re-saving (destructively) will overwrite your original photo with an exported copy - is that really what you want?",
        buttons = { dia:btn( "Yes - I understand, proceed...", 'ok' ), dia:btn( "No - cancel the operation.", 'cancel', false ) },
        viewItems = vi,
        actionPrefKey = 're-saving (destructively) overwrites original',
    }
    if button == 'ok' then -- yes
        app:log()
        app:log( "*** User has acknowledged that re-saving (destructively) overwrites original." )
        app:log()
    elseif button == 'cancel' then -- no/cancel.
        call:cancel()
        return
    else
        app:error( "bad button: ^1", button )
    end
    
    -- reminder: export preset loader throws error if export filters are present.
    local prob = {}
    local crit = {}
    if jpegSettings.LR_size_doConstrain then -- resize
        prob[#prob + 1] = "Jpeg settings include resizing"
    end
    if tiffSettings.LR_size_doConstrain then
        prob[#prob + 1] = "Tiff settings include resizing"
    end
    if tiffSettings.LR_export_bitDepth < 16 then
        prob[#prob + 1] = "Tiff settings include bit-depth of "..str:to( tiffSettings.LR_export_bitDepth )
    end
    if jpegSettings.LR_jpeg_useLimitSize then -- resize
        prob[#prob + 1] = "Jpeg settings include size limiting"
    end
    if jpegSettings.LR_jpeg_quality < .7 then
        crit[#crit + 1] = "Jpeg settings are not high quality"
    elseif jpegSettings.LR_jpeg_quality < 1 then
        prob[#prob + 1] = "Jpeg settings include reduced quality"
    end
    local button
    if tab:isArray( crit ) then
        button = app:show{ confirm="There are some potentially critical issues: ^1\n \nProceed anyway?",
            subs = { table.concat( crit, "; " ) },
            actionPrefKey = "Potentially critical issues",
        }
        if button == 'cancel' then
            call:cancel()
            return
        end
    end
    if tab:isArray( prob ) then
        button = app:show{ confirm="There are some potential issues: ^1\n \nProceed anyway?",
            subs = { table.concat( prob, "; " ) },
            actionPrefKey = "Potential issues",
        }
        if button == 'cancel' then
            call:cancel()
            return
        end
    end
    -- no issues or all are ok'd

    
    --  H E R E   W E   G O . . .
    
    if recycle and saveXmpBefore then
        if call.realMode then
            local s, m
            if #photos == 1 then
                -- Catalo g : s avePhotoMetadata( photo, photoPath, targ, call, noVal )
                s, m = cat:savePhotoMetadata( photos[1], cache:getRawMetadata( photos[1], 'path' ), nil, call )
            else
                -- Catalo g : s aveMetadata( photos, preSelect, restoreSelect, alreadyInGridMode, service )
                s, m = cat:saveMetadata( photos, true, false, false, call )
                -- s = true -- ###
            end
            if s then
                app:log( "(xmp) metadata saved - ^1", str:nItems( #photos, "photos" ) )
            else
                app:logE( m or "?" )
                return
            end
        else
            app:log( "*** IF NOT TEST RUN, would have saved xmp metadata: ^1", str:nItems( #photos, "photos" ) )
        end
    else
        app:log( "Not saving xmp metadata before." )
    end
    
    call:setCaption( "Processing photos and/or their metadata..." )
    
    app:log()
    for i, photo in ipairs( photos ) do
        call:setPortionComplete( i-1, #photos )
        yc = app:yield( yc )
        repeat
            local s, m = LrTasks.pcall( processPhotoOrVideo, photo )
            if not s then
                app:logE( m or "??" )
            -- else presumably all the normal logging and such was already done.
            end
        until true
        if call:isQuit() then
            return
        end
    end
    call:setPortionComplete( 1 )
    app:log()
    
    if saveXmpAfter then
        if #resavePhotos > 0 then
            if call.realMode then
                local s, m
                if #resavePhotos == 1 then
                    -- Catalo g : s avePhotoMetadata( photo, photoPath, targ, call, noVal )
                    s, m = cat:savePhotoMetadata( resavePhotos[1], cache:getRawMetadata( resavePhotos[1], 'path' ), nil, call )
                else
                    -- Catalo g : s aveMetadata( photos, preSelect, restoreSelect, alreadyInGridMode, service )
                    s, m = cat:saveMetadata( resavePhotos, true, false, false, call )
                    -- s = true -- ###
                end
                if s then
                    app:log( "(xmp) metadata saved again - ^1.", str:nItems( #resavePhotos, "photos" ) )
                else
                    app:logE( m or "?" )
                end
            else
                app:log( "*** IF NOT TEST RUN, would have saved xmp metadata again: ^1", str:nItems( #resavePhotos, "photos" ) )
            end
        else
            app:log( "No photos to save xmp after." )
        end
    else
        app:logV( "Not saving xmp after." )
    end
        
end, finale=function( call )
    if gbl:getValue( 'exifTool' ) then
        exifTool:closeSession( call.ets ) -- handles nil appropriately.
    end
    if call.status then
        if not call.realMode then
            call:setMandatoryMessage( "*** THIS WAS JUST A TEST RUN..." )
        end
        app:log()
        local ripe = call:getStat( 'ripeTargets' )
        local total = call:getStat( 'totalTargets' )
        if ripe == total then
            app:log( "^1 ripe for processing", str:nItems( ripe, "photos" ) )
        else
            app:log( "^1 of ^2 ripe for processing.", ripe, str:nItems( total, "photos" ) )
        end
        if call.realMode then
            app:log( "^1 processed", call:getStat( 'processed' ) )
        else
            app:log( "*** ^1 would have been processed", call:getStat( 'processed' ) )
        end
        app:logStat( "^1 already OK", call:getStat( 'okAlready' ), "photos" )
        app:logStat( "^1 not writable - skipped", call:getStat( 'notWritableSkipped' ), "photos" )
        app:logStat( "^1 skipped", call:getStat( 'rawSkipped' ), "RAWs" )
        app:logStat( "^1 skipped", call:getStat( 'dngSkipped' ), "DNGs" )
        app:logStat( "^1 skipped", call:getStat( 'psdSkipped' ), "PSDs" )
        app:logStat( "^1 skipped", call:getStat( 'videoSkipped' ), "videos" )
        app:logStat( "^1 skipped", call:getStat( 'missingSkipped' ), "missing files" )
        app:logStat( "^1 skipped", call:getStat( 'virtualCopySkipped' ), "virtual copies" )
        app:logStat( "^1 skipped", call:getStat( 'lockedSkipped' ), "locked photos" )
        if app:isAdvDbgEna() then
            local set = call.selSet or {}
            local count = tab:countItems( set, false ) -- exclude false items.
            if count > 0 then
                app:log( "^1 unaccounted for.", str:nItems( count, "selected items" ) )
                for photo, still in pairs( set ) do
                    if still then
                        app:logWarning( "Unaccounted for (presumably error'd out): ^1", photo:getRawMetadata( 'path' ) )
                    end
                end
            end
        end
    else
        app:logv( "error caught, should have been logged - ^1", call.message )
    end
    cat:restoreSelPhotos( call.selPhotosEtc ) -- no-op if sel-photos-etc is nil. all logs are verbose.
    if gbl:getValue( 'background' ) then
        background:continue() -- no s, m.
    end    

end }