--[[
        Info.lua
--]]

return {
    appName = "Exportant",
    author = "Rob Cole",
    authorsWebsite = "www.robcole.com",
    donateUrl = "http://www.robcole.com/Rob/Donate",
    platforms = { 'Windows', 'Mac' },
    pluginId = "com.robcole.lightroom.Exportant",
    xmlRpcUrl = "http://www.robcole.com/Rob/_common/cfpages/XmlRpc.cfm",
    LrPluginName = "rc Exportant",
    LrSdkMinimumVersion = 3.0, -- note: Exportant is using supportsVideo feature, which was introduced in Lr4 - ref in doc.
    LrSdkVersion = 5.0,
    LrPluginInfoUrl = "http://www.robcole.com/Rob/ProductsAndServices/ExportantLrPlugin",
    LrPluginInfoProvider = "ExtendedManager.lua",
    LrToolkitIdentifier = "com.robcole.Exportant",
    LrInitPlugin = "Init.lua",
    LrShutdownPlugin = "Shutdown.lua",
    LrExportServiceProvider = { -- one test exporter.
        title = "Exportant Tester",
        file = "ExtendedExport.lua",
        builtInPresetsDir = "Export Presets",
    },
    -- Reminder: supports-video was introduced in Lr4.
    -- Note: These filters mostly require 'Main' (if they use prefs anyway), I have universally required it using ad-hoc means which still allows moving other filters.
    -- (if you specify requires-filter here, you can no longer move the other filters).
    LrExportFilterProvider = {
        {
            -- *** needs to be top, or export with photos aborted (video-only export will proceed).
            title = "Fast Cache",
            file = "fFastCache.lua",
            id = "com.robcole.Exportant.FastCache",
            supportsVideo = true, -- although you can't export a video as virtual copy, in order to allow export of either photos or videos or both while
            -- this filter is inserted, video is detected and handled appropriately (passed through).
            --requiresFilter = "com.robcole.Exportant.Main",
        },
        {
            -- *** needs to be top, or export with photos aborted (video-only export will proceed).
            title = "Export As Virtual Copy",
            file = "fExportAsVirtualCopy.lua",
            id = "com.robcole.Exportant.ExportAsVirtualCopy",
            supportsVideo = true, -- although you can't export a video as virtual copy, in order to allow export of either photos or videos or both while
            -- this filter is inserted, video is detected and handled appropriately (passed through).
            --requiresFilter = "com.robcole.Exportant.Main",
        },
        {
            -- Not so sure I like the name "Main" - maybe it should be called "Required" *but* 'Required' is already taken by framework module.
            title = "Main",
            file = "fMain.lua",
            id = "com.robcole.Exportant.Main",
            supportsVideo = true, -- although technically, nothing applies to video, in order to allow export of either photos or videos or both while
            -- this filter is inserted, video is detected and handled appropriately (passed through).
        },
        {
            title = "Source Photo Considerations",
            file = "fSourcePhotoConsiderations.lua",
            id = "com.robcole.Exportant.SourcePhotoConsiderations",
            supportsVideo = true, -- although technically, nothing applies to video, in order to allow export of either photos or videos or both while
            -- this filter is inserted, video is detected and handled appropriately (passed through).
            --requiresFilter = "com.robcole.Exportant.Main",
        },
        {
            title = "Exiftool Session",
            file = "fExiftoolSession.lua",
            id = "com.robcole.Exportant.ExiftoolSession",
            supportsVideo = true, -- take care to not do things to videos that aren't supported, e.g. maintain original resolution.
            --requiresFilter = "com.robcole.Exportant.Main",
        },
        {   -- *** includes app/service-compatability option which likes to be bottom-most.
            title = "Miscellaneous",
            file = "fMiscellaneous.lua",
            id = "com.robcole.Exportant.Miscellaneous",
            supportsVideo = true, -- app/service compat applies (although Lr proper may very well have it covered in case of video(?) ), also maintain capture time works..
            --requiresFilter = "com.robcole.Exportant.Main",
        },
        {
            title = "Custom Functions",
            file = "fCustomFunctions.lua",
            id = "com.robcole.Exportant.CustomFunctions",
            supportsVideo = true, -- doc says "true" (with quotes) - my experience: either boolean true or string "true" works.
            --requiresFilter = "com.robcole.Exportant.Main",
        },
        {
            title = "Custom Naming",
            file = "fCustomNaming.lua",
            id = "com.robcole.Exportant.CustomNaming",
            supportsVideo = true, -- doc says "true" (with quotes) - my experience: either boolean true or string "true" works.
            --requiresFilter = "com.robcole.Exportant.Main",
        },
        {
            title = "Image Magick (convert)",
            file = "fImageMagick.lua",
            id = "com.robcole.Exportant.ImageMagick",
            supportsVideo = true, -- although technically, im does not apply to video, in order to allow export of either photos or videos or both while
            -- this filter is inserted, video is detected and handled appropriately (passed through).
            --requiresFilter = "com.robcole.Exportant.Main",
        },
        {
            title = "Export Setting Overrides",
            file = "fExportSettingOverrides.lua",
            id = "com.robcole.Exportant.ExportSettingOverrides",
            supportsVideo = true, -- hard to go wrong here, since photo-only settings will be ignored by Lr if not applicable to video.
            --requiresFilter = "com.robcole.Exportant.Main",
        },
    },
--    LrMetadataTagsetFactory = "Tagsets.lua", - 13/May/2014 19:34
    LrLibraryMenuItems = {
        {
            title = "&Purge Fast Cache",
            file = "mPurge.lua",
        },
        { -- ###1 this should maybe be moved to a script.
            title = "&Re-save (RGB files) destructively",
            file = "mSave.lua",
        },
    },
    LrHelpMenuItems = {
        {
            title = "General Help",
            file = "mHelp.lua",
        },
    },
    VERSION = { display = "6.21    Build: 2015-01-05 22:13:07" },
}
