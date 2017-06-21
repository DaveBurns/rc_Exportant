-----------------
-- Properties.lua
-----------------


-- declare table of properties:
local _t = {}



--[[
        Current version is housing function properties, which don't support serialization, so: read-only.
        
        All such functions:
        
        * will throw an error if cannot complete their jobs.
        * execute in context of Elare Plugin Framework (most Lr namespaces and all Elare globals are available).
--]]





--[[
        isFinished - determines whether photo meets minimum requirements for locking/publishing, i.e. are all editing pre-requisites met for finalization/export.
        
        Parameters:
        -----------
        * whosAsking
        * photo
        * cache (or metadataCache) - optional.
        
        Return Values:
        --------------
        * status (boolean) true iff photo is finished (has adjustments, has keywords, is rated, ...).
        * message (string) explanation if status is false.
--]]
_t.isFinished = function( params )
    app:callingAssert( params, "no params" )
    local whosAsking = app:callingAssert( params.whosAsking, "need to know who's asking" )
    local photo = app:callingAssert( params.photo, "no photo" )
    local cache = params.metadataCache or params.cache -- synonyms: either, or nil..
    local photoName = cat:getPhotoNameDisp( photo, true, cache ) -- path, including virtual copy name, if applicable.
    
    local unfin = {}

    app:logV( params.whosAsking.." is asking if '^1' is finished.", photoName )
    
    if app:lrVersion() >= 5 then
        local pickStatus = lrMeta:getRaw( photo, 'pickStatus', cache )
        if pickStatus == 0 then
            app:logV( "Unflagged" )
        elseif pickStatus == 1 then
            app:logV( "Picked" )
        elseif pickStatus < 0 then -- photo can't possibly be considered finished, for the purposes this function is intended to be used for (e.g. one should never lock or export rejected photos).
            unfin[#unfin + 1] = "Photo is Rejected!"
        else
            app:error( "Bad pick status" )
        end
    -- else nada
    end
    
    local keywords = lrMeta:getRaw( photo, 'keywords', cache )
    if #keywords > 0 then
        app:logV( "has ^1", str:nItems( #keywords, "keywords" ) )
    else
        unfin[#unfin + 1] = "no keywords"
    end
    
    local creator = lrMeta:getFmt( photo, 'artist', cache )
    if str:is( creator ) then
        app:logV( "Creator: ^1", creator )
    else
        unfin[#unfin + 1] = "no creator"
    end
    
    --[[ copyright fields (all are "formatted" metadata).
    copyright: (string) The copyright text for this image.
    copyrightState: (string) The copyright state for this image. One of 'unknown', 'copyrighted', or 'public domain'.
    rightsUsageTerms: (string) Instructions on how this image can legally be used.
    copyrightInfoUrl
    --]]    
    -- uncomment if you want copyright factor:
    --[[
    local copyright = lrMeta:getFmt( photo, 'copyright', cache )
    if str:is( copyright ) then
        -- you can check other copyright fields in like fashion.
        app:logV( "Image is copyrighted" )
    else
        unfin[#unfin + 1] = "No copyright"
    end
    --]]
    
    local ds = photo:getDevelopSettings()
    local pvNum = tonumber( ds.ProcessVersion )
    local basics = true
    if pvNum > 6 then -- pv12
        repeat
            if ds.Exposure2012 ~= 0 then break end
            if ds.Contrast2012 ~= 0 then break end
            if ds.Highlights2012 ~= 0 then break end
            if ds.Shadows2012 ~= 0 then break end
            if ds.Whites2012 ~= 0 then break end
            if ds.Blacks2012 ~= 0 then break end
            if ds.Clarity2012 ~= 0 then break end
            basics = false -- all 0
        until true
    else -- legacy
        repeat
            if ds.Exposure ~= 0 then break end
            if ds.Contrast ~= 0 then break end
            if ds.FillLight ~= 0 then break end
            if ds.HighlightRecovery ~= 0 then break end
            if ds.Brightness ~= 0 then break end
            if ds.Blacks ~= 0 then break end
            if ds.Clarity ~= 0 then break end
            basics = false -- all 0
        until true
    end
    if basics then
        app:logV( "Basics are adjusted." )
    else
        unfin[#unfin + 1] = "no basic adjustments"
    end

    local m = {}    
    if ds.EnableToneCurve == nil then
        -- m[#m + 1] = "Tone curve is disabled" -- not reliable. ###3
        app:logv( "Tone curve enable indeterminate." )
    elseif not ds.EnableToneCurve then
        m[#m + 1] = "Tone curve is disabled"
    end
    if not ds.EnableColorAdjustments then m[#m + 1] = "Color adjustments are disabled" end
    if not ds.EnableSplitToning then m[#m + 1] = "Split toning is disabled" end
    if not ds.EnableDetail then m[#m + 1] = "Detail is disabled" end
    if not ds.EnableLensCorrections then m[#m + 1] = "Lens corrections are disabled" end
    if not ds.EnableEffects then m[#m + 1] = "Effects are disabled" end
    if not ds.EnableCalibration then m[#m + 1] = "Calibration is disabled" end
    if not ds.EnableRetouch then m[#m + 1] = "Retouch is disabled" end
    if not ds.EnableRedEye then m[#m + 1] = "Red-eye is disabled" end
    if not ds.EnableGradientBasedCorrections then m[#m + 1] = "Gradients are disabled" end
    if not ds.EnableCircularGradientBasedCorrections then m[#m + 1] = "Circular gradients are disabled" end
    if not ds.EnablePaintBasedCorrections then m[#m + 1] = "Paint is disabled" end
    if #m == 0 then
        app:logv( "all develop sections are enabled" )
    else
        unfin[#unfin + 1] = table.concat( m, "; " )
    end
    
    local folderPath = LrPathUtils.parent( photoName )
    if not folderPath:find( "____IMPORT____" ) then
        app:logv( "photo has been moved out of inbox" )
    else
        unfin[#unfin + 1] = str:fmtx( "photo needs to be moved from inbox (^1) to a proper home.", folderPath )
    end
    
    if #unfin == 0 then
        return true -- I guess it's finished..
    else
        return false, table.concat( unfin, "; " )
    end
end



-- return table of properties:
return _t