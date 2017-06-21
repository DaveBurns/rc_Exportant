--[[
        Init.lua (plugin initialization module)
--]]


-- Unstrictify _G
local mt = getmetatable( _G ) or {}
mt.__newIndex = function( t, n, v )
    rawset( t, n, v )
end
mt.__index = function( t, n )
    return rawget( t, n )
end
setmetatable( _G, mt )



--   I N I T I A L I Z E   L O A D E R
do
    -- step 0: replace load-file/do-file with versions that will work with non-ascii characters in path.
    local LrPathUtils = import 'LrPathUtils'
    local LrFileUtils = import 'LrFileUtils'
    
    -- this may not be a strict requirement for every plugin, but advanced debug requires it for logging, as does exiftool session, and it's required for 'Preferences', etc..
    if not LrFileUtils.isWritable( _PLUGIN.path ) then -- typically due to being located in Windows "Program Files" dir or Mac's "Applications" folder.
        error( "Plugin directory must be writable, '".._PLUGIN.path.."' is not. Remedy by re-locating to writable user folder like \"Documents\"." ) -- filename/line-no prefix ok.
    end
    
    _G.loadfile = function( file )
        -- Note: file is optional, and if not provided means stdin.
        -- Shouldn't happen in Lr env(?) but just in case...
        if file == nil then
            return nil, "load-file from stdin not supported in Lr env."
        end
        local filename = LrPathUtils.leafName( file )
        local status, contents = pcall( LrFileUtils.readFile, file ) -- lr-doc says nothing about throwing errors, or if contents returned could be nil: best to play safe...
        if status then
            if contents then
                local func, err = loadstring( contents, filename ) -- returns nil, errm if any troubles: no need for pcall (short chunkname required for debug).
                if func then
                    return func
                else
                    --return nil, "loadstring was unable to load contents returned from: " .. tostring( file or 'nil' ) .. ", error message: " .. err -- lua guarantees a non-nil error message string.
                    local x = err:find( filename )
                    if x then
                        err = err:sub( x ) -- strip the funny business at the front: just get the good stuff...
                    elseif err:len() > 77 then -- test on Mac ###2
                        err = err:sub( -77 )
                    end
                    return nil, err -- return *short* error message
                end
            else
                -- return nil, "Unable to obtain contents from file: " .. tostring( file ) -- probably also too long.
                return nil, "No contents in: " .. filename
            end
        else
            -- return nil, "Unable to read file: " .. tostring( file ) .. ", error message: " .. tostring( contents or 'nil' ) -- probably also too long.
            return nil, "Unable to read file: " .. filename
        end
    end
    _G.dofile = function( file )
        local func, err = loadfile( file ) -- returns nil, errm if any problems.
        if func then
            return unpack{ func() } -- throw error, if any.
        else
            error( err ) -- error message guaranteed.
        end
    end
    local LrPathUtils = import 'LrPathUtils'
    local frameworkDir = LrPathUtils.child( _PLUGIN.path, "Framework" )
    local reqFile = frameworkDir .. "/System/Require.lua"
    local status, result1, result2 = pcall( dofile, reqFile ) -- gives good "file-not-found" error - no reason to check first (and is ok with forward slashes).
    if status then
        _G.Require = result1
        _G.Debug = result2
        assert( Require ~= nil, "no require" )
        assert( Debug ~= nil, "no debug" )
        assert( require == Require.require, "'require' is not what's expected" ) -- synonym: helps remind that its not vanilla 'require'.
    else
        error( result1 ) -- we can trust pcall+dofile to return a non-nil error message.
    end
    if _PLUGIN.path:sub( -12 ) == '.lrdevplugin' then
        Require.path( frameworkDir )
    else
        assert( _PLUGIN.path:sub( -9 ) == '.lrplugin', "Invalid plugin extension" )
        Require.path( 'Framework' ) -- relative to lrplugin dir.
    end
end




--   S E T   S T R I C T   G L O B A L   P O L I C Y
_G.Globals = require( 'System/Globals' )
_G.gbl = Globals:new{ strict = true } -- strict from here on out for everything *except* statements in this module.



--   I N I T I A L I Z E   F R A M E W O R K
_G.Object = require( 'System/Object' )                         -- base class of base object factory.
_G.ObjectFactory = require( 'System/ObjectFactory' )           -- base class of special object factory.
_G.InitFramework = require( 'System/InitFramework' )           -- class of object used for initialization.
_G.ExtendedObjectFactory = require( 'ExtendedObjectFactory' )    -- class of object used to create objects of classes not mandated by the framework.
_G.objectFactory = ExtendedObjectFactory:new()               -- object used to create objects of classes not mandated by the framework.
_G.init = InitFramework:new()                               -- create initializer object, of class specified here.
init:framework()                                            -- initialize framwork, relying on object factory to create framework objects of proper class.



--   P L U G I N   S P E C I F I C   I N I T
_G.LrExportSession = import 'LrExportSession'
_G.LrExportSettings = import 'LrExportSettings'
_G.LrXml = import 'LrXml'
_G.Export = require( "ExportAndPublish/Export" )
_G.ExifTool = require( "ExternalApps/ExifTool" )
_G.Convert = require( "ExternalApps/Convert" ) -- used in export-as-png preset, and available for other custom/user presets.
_G.XmlRpc = require( "Communication/XmlRpc" )
_G.Export = require( "ExportAndPublish/Export" )
_G.DevelopSettings = require( "Catalog/DevelopSettings" )
_G.Lightroom = require( "Lightroom/Lightroom" )
_G.Keywords = require( "Catalog/Keywords" )
_G.PublishServices = require( "Catalog/PublishServices" )
_G.JpegTran = require( "ExternalApps/JpegTran" )

_G.ExtendedManager = require( "ExtendedManager" )
_G.ExtendedExport = require( "ExtendedExport" )
_G.ExtendedManager = require( "ExtendedManager" )
_G.ExportFilter = require( "ExportAndPublish/ExportFilter" )
_G.ExtendedExportFilter = require( "ExtendedExportFilter" )
_G.SourcePhotoConsiderations = require( "fSourcePhotoConsiderations" )
_G.Miscellaneous = require( "fMiscellaneous" )
_G.ImageMagick = require( "fImageMagick" )
_G.ExportAsVirtualCopy = require( "fExportAsVirtualCopy" )
_G.ExiftoolSession = require( "fExiftoolSession" )
_G.CustomNaming = require( "fCustomNaming" )
_G.CustomFunctions = require( "fCustomFunctions" )



--   I N I T I A T E   A S Y N C H R O N O U S   I N I T   A N D   B A C K G R O U N D   T A S K
ExtendedManager.initPrefs() -- remember to include all dependent plugin prefs (plugin generator is not helping in this regard, yet)
-- additional global plugin variables
_G.convert = Convert:new{ optional="" } -- setting optional to empty string suppresses prompt if app not configured.
_G.exifTool = ExifTool:new{ optional="Exiftool must be installed and/or configured if you will be using features that require an exif-tool session." } -- exiftool is built-in, so prompt will "never" show.
_G.createExifToolSession = false -- global variable set by ets-session section so all other sections "get the memo".
_G.developSettings = DevelopSettings:new{ cleanup=true } -- relative presets require plugin presets.
_G.lightroom = Lightroom:new()
_G.jpegTran = JpegTran:new{ optional="Jpegtran required for fixing Lr5.5 jpeg compatibility problem." }
app:initDone() -- synchronous init done.
-- Consider async init/background task.
if background then -- not strict in here.
    background:start() -- by default just does init then quits - consider using pref to enable/disable background if optional, else force continuation into background processing...
end



-- the end.