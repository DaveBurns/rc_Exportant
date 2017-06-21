-- mSave.lua

-- one-func does all menu handler.
app:service{ name="Re-save (RGB files) destructively", async=true, main=function( call )

    call:initStats{ 'totalTargets', 'ripeTargets', 'processed', 'okAlready', 'videoSkipped', 'missingSkipped', 'virtualCopySkipped', 'notWritableSkipped', 'dngSkipped', 'rawSkipped', 'lockedSkipped' }
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
    app:initPref( 'saveXmpBefore', true )
    app:initPref( 'saveXmpAfter', true )
    
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
    vi[#vi + 1] = vf:row {
        vf:static_text {
            title = "Color Space",
            width = share 'lbl_wid',
        },
        vf:radio_button {
            title = "Adobe RGB",
            bind_to_object = prefs,
            value = app:getPrefBinding( 'saveColorSpace' ),
            checked_value = 'AdobeRGB',
            width = share 'item_1_width',
        },
        vf:radio_button {
            title = "sRGB",
            bind_to_object = prefs,
            value = app:getPrefBinding( 'saveColorSpace' ),
            checked_value = 'sRGB',
        },
    }
    vi[#vi + 1] = vf:row {
        vf:static_text {
            title = "TIFF/PSD Bit Depth",
            width = share 'lbl_wid',
        },
        vf:radio_button {
            title = "16",
            bind_to_object = prefs,
            value = app:getPrefBinding( 'tifBitDepth' ),
            checked_value = 16,
            width = share 'item_1_width',
        },
        vf:radio_button {
            title = "8",
            bind_to_object = prefs,
            value = app:getPrefBinding( 'tifBitDepth' ),
            checked_value = 8,
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
    Debug.pause( call.realMode )
    call:setCaption( "Acquiring metadata..." )
    local cache = lrMeta:createCache{ photos=targetPhotos, rawIds={ 'path', 'isVirtualCopy', 'fileFormat' }, fmtIds={ 'copyName', 'fileName' } }
    call:setCaption( "Scrutinizing selected photos..." )
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
            local locked, lockDate = cat:isLocked( photo, true, cache ) -- check xmp too - I think if jpeg it will check source file. - test this ###1.
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

    local export = Export:new()
    local colorSpace = app:getPref{ name='saveColorSpace', expectedType='string' } or error( "no color-space" )
    local tifBitDepth = app:getPref{ name='tifBitDepth', expectedType='number' } or error( "no bit depth" )
    local recycle = app:getPref{ name='recycle', expectedType='boolean' }
    assert( recycle ~= nil, "nil" )
    local saveXmpBefore = app:getPref( 'saveXmpBefore' )
    local saveXmpAfter = app:getPref( 'saveXmpAfter' )
    
    local function getFormat( ext )
        if str:isEqualIgnoringCase( ext, "jpg" ) then
            return 'JPEG'
        elseif str:isEqualIgnoringCase( ext, "tif" ) then
            return 'TIFF'
        elseif str:isEqualIgnoringCase( ext, "psd" ) then
            return 'PSD'
        else
            error( "Unrecognized extension: ^1", ext ) -- ###1
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
        
        -- consider option to save metadata first, and/or afterward. ###1
        local s, m = export:doExport {
            photo = photo, -- will accept 'photo' or 'photos'.
            constrainSettings = "strict", -- "no", or "strict".
            settings = {
                LR_format = getFormat( ext ),
                LR_export_bitDepth = tifBitDepth,
                LR_jpeg_quality = 1,
                LR_export_colorSpace = colorSpace,
                LR_collisionHandling = 'overwrite',
                LR_export_destinationType = 'specificFolder',    
                LR_size_doConstrain = false,
                LR_export_destinationPathPrefix = dir, 
                LR_export_useSubfolder = false,    
                --LR_export_destinationPathSuffix = '',
            	LR_metadata_keywordOptions = "lightroomHierarchical", -- ###1 hmm - totally unnecessary, since same file? - consider saving metadata after export instead.
            	LR_minimizeEmbeddedMetadata = false, -- Lr3-
                LR_embeddedMetadataOption = 'all', -- Lr4+
            },
            constrainDefaults = "strict", -- constrain default values too.
            defaults = {
                LR_renamingTokensOn = true, 
        	    LR_tokens = "{{custom_token}}",
        	    LR_tokenCustomString = tempBaseName,
        	    --LR_tokensArchivedToString2 = "{{custom_token}}", -- not sure this does anything, but doesn't hurt (it's from saved preset).
            },
        }
        Debug.pause( s, m )
        if s then
            app:assert( fso:existsAsFile( expPath ), "Exported file does not exist." )
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
                        app:logV( "Photo settings were reset - overwritting original." )
                    end
                    if s then
                        local s, m = fso:moveFile( expPath, photoPath, false, not recycle ) -- will most surely need to overwrite original.
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
    
    local s, m
    if recycle and saveXmpBefore then
        if call.realMode then
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
            s = true
        end
    else
        app:log( "Not saving xmp metadata before." )
        s = true
    end
    
    if s then -- this line can be removed if not saving metadata.
    
        call:setCaption( "Processing photos and/or their metadata..." )
        
        --[[ uncomment and edit exif-tool handling, if desired:
        if gbl:getValue( 'exifTool' ) then
            local s, m = exifTool:isUsable()
            if not s then
                app:logErr( m )
                return
            end
            
            call.ets = exifTool:openSession( title )
        -- else - no et
        end
        --]]
        
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
        
    else
        app:logErr( m or "???" )
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