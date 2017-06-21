-- mSave.lua

-- one-func does all menu handler.
app:service{ name="Purge Fast Cache", async=true, main=function( call )

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
    app:initPref( 'purgeTiff', false )
    app:initPref( 'purgeJpeg', false )
    app:initPref( 'ifOlderThan', 0 ) -- days
    
    local cacheDir
    local catDir, catName = cat:getDir()
    cacheDir = LrPathUtils.child( catDir, catName.." RGB Image Cache" )
    if not fso:existsAsDir( cacheDir ) then
        app:show{ info="Cache dir does not exist: '^1' (and so it can't be purged..).", cacheDir }
        call:cancel()
        return
    end
    
    local function getMainViewItems()
        local vi = {} -- binding must be individuated when using app-show method, since items are appended to array before final view created.
        vi[#vi + 1] = vf:row {
            vf:static_text {
                title = "Cache entries to purge",
                --width = share 'lbl_wid',
            },
            vf:checkbox {
                title = "TIFF",
                value = app:getPrefBinding( 'purgeTiff' ),
                --width = share 'item_1_width',
            },
            vf:checkbox {
                title = "JPEG",
                value = app:getPrefBinding( 'purgeJpeg' ),
            },
        }
        vi[#vi + 1] = vf:spacer { height=10 }
        vi[#vi + 1] = vf:row {
            vf:static_text {
                title = "If older than",
                --width = share 'lbl_wid',
            },
            vf:edit_field {
                value = app:getPrefBinding( 'ifOlderThan' ),
                width_in_chars = 8,--share 'item_1_width',
                precision = 2,
                min = 0,
                max = 99999,
                tooltip = 'Enter zero to mean "all ages", or enter a number of days and only those older will be purged (tip: 1 hour is about .04 days).',
            },
            vf:static_text {
                title = "days",
            },
        }
        return vi
    end
    
    local purgeTiff
    local purgeJpeg
    repeat
        local a = app:show{ confirm="Purge cache entries?",
            viewItems = getMainViewItems(),
        }
        if a == 'ok' then
            purgeTiff = app:getPref( 'purgeTiff' )
            purgeJpeg = app:getPref( 'purgeJpeg' )
            if purgeTiff or purgeJpeg then
                break
            else
                app:displayInfo( "Check 'TIFF' or 'JPEG', or click the 'Cancel' button." )
            end
        else
            call:cancel()
            return
        end
    until false

    local timeCutoff
    local days = app:getPref{ name='ifOlderThan', default=0 }
    if days > 0 then
        timeCutoff = LrDate.currentTime() - ( days * 86400 )
    -- else let it remain nill
    end
    --Debug.pause( timeCutoff )
    
    assert( purgeTiff or purgeJpeg, "?" )
    local both = purgeTiff and purgeJpeg
    local targetExt
    if not both then
        targetExt = ( purgeTiff and 'tif' ) or 'jpg'
    -- else target-ext will be nil.
    end
    assert( cacheDir, "no cache dir" )
    local delPhotoLookup = {}
    --local delPhotoNames = {}
    local delFileSet = {}
    for file in LrFileUtils.files( cacheDir ) do
        repeat
            local ext = LrPathUtils.extension( file )
            local subExt = LrPathUtils.extension( LrPathUtils.removeExtension( file ) )
            if ( ext=='tif' and ( both or targetExt=='tif' ) ) or ( ext=='jpg' and ( both or targetExt=='jpg' ) ) then
                if timeCutoff then
                    local fileTime = fso:getFileModificationDate( file )
                    if fileTime > timeCutoff then
                        --Debug.pause( "new", fileTime, timeCutoff )
                        app:logV( "Cache photo entry too new (won't be purged): ^1", file )
                        break
                    else
                        --Debug.pause( "old", fileTime, timeCutoff )
                        app:logV( "Cache photo older than cutoff (will be purged): ^1", file )
                    end
                else
                    app:logV( "No cutoff - cache photo file will be purged: ^1", file )
                end
                -- old or not cutoff - file is cache photo file.
                local photo = catalog:findPhotoByPath( file )
                if photo then
                    delPhotoLookup[photo] = file
                else -- exists as file.
                    delFileSet[file] = true
                end
                -- info-file partner:
                local infoFile = LrPathUtils.addExtension( file, "txt" )
                delFileSet[infoFile] = fso:existsAsFile( infoFile ) or nil
            elseif ext == 'txt' and ( both or subExt == targetExt ) then -- info txt file
                if timeCutoff then
                    local fileTime = fso:getFileModificationDate( file )
                    if fileTime > timeCutoff then
                        app:logV( "Cache info file too new (won't be purged): ^1", file )
                        break
                    else
                        app:logV( "Cache info file older than cutoff (will be purged): ^1", file )
                    end
                else
                    app:logV( "No cutoff - cache info file will be purged: ^1", file )
                end
                -- old or no cutoff, file is info-txt.
                delFileSet[file] = true -- delete info file.
                -- photo/file partner:
                local photoFile = LrPathUtils.removeExtension( file )
                local photo = catalog:findPhotoByPath( photoFile )
                if photo then
                    delPhotoLookup[photo] = photoFile
                else
                    delFileSet[photoFile] = fso:existsAsFile( photoFile ) or nil
                end
            else
                app:logV( "Ignoring file: ^1", file )
            end
        until true
    end
    local delFiles = tab:createArray( delFileSet )
    local delPhotoPaths = {}
    local delPhotos = {}
    for photo, path in pairs( delPhotoLookup ) do
        delPhotos[#delPhotos + 1] = photo or error( "no photo" )
        delPhotoPaths[#delPhotoPaths + 1] = path or error( "no path" )
    end
    if #delPhotos > 0 then
        app:log()
        app:log( "Cache photos to delete:" )
        app:log( "-----------------------" )
        for i, v in ipairs( delPhotos ) do
            app:log( delPhotoPaths[i] or error( "no photo path" ) )                            
        end
        app:log()
        local s, m = cat:deletePhotos {
            photos = delPhotos,
            call = call,
        }
        if s and not call:isQuit() then
            app:log( "^1 cache ^2 deleted.", #delPhotos, str:phrase( #delPhotos, "photo was", "photos were" ) )
        elseif m then
            app:logW( m )
        elseif call:isQuit() then
            return -- don't delete files either if photos not to be deleted.
        else
            app:logV( "*** Not sure what just happened!.." )
            return -- ditto.
        end
    else
        app:log( "No cache photos to delete." )
    end
    if #delFiles > 0 then
        for i, v in ipairs( delFiles ) do
            LrFileUtils.delete( v )
        end
        app:log( "^1 cache info ^2 deleted.", #delFiles, str:phrase( #delFiles, "file was", "files were" ) )
    else
        app:log( "No cache info files to delete." )
    end

        
end, finale=function( call )

end }