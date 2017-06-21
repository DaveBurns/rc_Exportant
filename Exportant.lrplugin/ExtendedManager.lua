--[[
        ExtendedManager.lua
--]]


local ExtendedManager, dbg, dbgf = Manager:newClass{ className='ExtendedManager' }



--[[
        Constructor for extending class.
--]]
function ExtendedManager:newClass( t )
    return Manager.newClass( self, t )
end



--[[
        Constructor for new instance object.
--]]
function ExtendedManager:new( t )
    return Manager.new( self, t )
end



--- Initialize global preferences.
--
function ExtendedManager:_initGlobalPrefs()

    -- init presets without special field values:
    app:registerPreset( "RC Standard", 2 ) -- There is also a _Rob preset that I use which is very close.
    app:registerPreset( "Giordano", 3 ) -- Even though tokens to support Giordano are now standard, he still needs the custom post export function.
    app:registerPreset( "Export Videos in FLV Format", 4 ) -- ###3 could make ffmpeg video export like Image Magick (separate section), then eliminate this.
    app:registerPreset( "Metadata Check Example", 5 )
    app:registerPreset( "No Republish", 6 )
    --app:registerPreset( "Jim Reekes", 6 ) -- obsolete - supported by 'Exporder' now.
    
    -- base class init:
    Manager._initGlobalPrefs( self )
end



--- Initialize local preferences for preset.
--
function ExtendedManager:_initPrefs( presetName )
    -- Instructions: uncomment to support these external apps in global prefs, otherwise delete:
    -- app:initPref( 'exifToolApp', "", presetName )
    -- app:initPref( 'convertApp', "", presetName )
    -- app:initPref( 'sqliteApp', "", presetName )
    -- *** Instructions: delete this line if no async init or continued background processing:
    --app:initPref( 'background', false, presetName ) -- true to support on-going background processing, after async init (auto-update most-sel photo).
    -- *** Instructions: delete these 3 if not using them:
    --app:initPref( 'processTargetPhotosInBackground', false, presetName )
    --app:initPref( 'processFilmstripPhotosInBackground', false, presetName )
    --app:initPref( 'processAllPhotosInBackground', false, presetName )
    Manager._initPrefs( self, presetName )
end



--- Start of plugin manager dialog.
-- 
function ExtendedManager:startDialogMethod( props )
    -- *** Instructions: uncomment if you use these apps and their exe is bound to ordinary property table (not prefs).
    Manager.startDialogMethod( self, props ) -- adds observer to all props.
end



--- Preference change handler.
--
--  @usage      Handles preference changes.
--              <br>Preferences not handled are forwarded to base class handler.
--  @usage      Handles changes that occur for any reason, one of which is user entered value when property bound to preference,
--              <br>another is preference set programmatically - recursion guarding is essential.
--
function ExtendedManager:prefChangeHandlerMethod( _id, _prefs, key, value )
    Manager.prefChangeHandlerMethod( self, _id, _prefs, key, value )
end



--- Property change handler.
--
--  @usage      Properties handled by this method, are either temporary, or
--              should be tied to named setting preferences.
--
function ExtendedManager:propChangeHandlerMethod( props, name, value, call )
    if app.prefMgr and (app:getPref( name ) == value) then -- eliminate redundent calls.
        -- Note: in managed cased, raw-pref-key is always different than name.
        -- Note: if preferences are not managed, then depending on binding,
        -- app-get-pref may equal value immediately even before calling this method, in which case
        -- we must fall through to process changes.
        return
    end
    -- *** Instructions: strip this if not using background processing:
    if name == 'background' then
        app:setPref( 'background', value )
        if value then
            local started = background:start()
            if started then
                app:show( "Auto-check started." )
            else
                app:show( "Auto-check already started." )
            end
        elseif value ~= nil then
            app:call( Call:new{ name = 'Stop Background Task', async=true, guard=App.guardVocal, main=function( call )
                local stopped
                repeat
                    stopped = background:stop( 10 ) -- give it some seconds.
                    if stopped then
                        app:logVerbose( "Auto-check was stopped by user." )
                        app:show( "Auto-check is stopped." ) -- visible status wshould be sufficient.
                    else
                        if dialog:isOk( "Auto-check stoppage not confirmed - try again? (auto-check should have stopped - please report problem; if you cant get it to stop, try reloading plugin)" ) then
                            -- ok
                        else
                            break
                        end
                    end
                until stopped
            end } )
        end
    else
        -- Note: preference key is different than name.
        Manager.propChangeHandlerMethod( self, props, name, value, call )
    end
end



--- Sections for bottom of plugin manager dialog.
-- 
function ExtendedManager:sectionsForBottomOfDialogMethod( vf, props)

    local appSection = {}
    if app.prefMgr then
        appSection.bind_to_object = props
    else
        appSection.bind_to_object = prefs
    end
    
	appSection.title = app:getAppName() .. " Settings"
	appSection.synopsis = bind{ key='presetName', object=prefs }

	appSection.spacing = vf:label_spacing()
	
	--[=[ *** on hold - maybe in future:
	appSection[#appSection + 1] = vf:row {
	    vf:static_text {
	        title = "Convert Executable\n(Image Magick)"
	    },
	    vf:edit_field {
	        value = bind 'convertApp',
	        width_in_chars = 40,
	        tooltip = "convert executable file",
	        
	    },
	    vf:push_button {
	        title = "Browse",
	        action = function( button )
	            dia:selectFile( {
	                title = "Select convert executable file",
	            }, props, 'convertApp' )
	        end,
	    },
	}
	appSection[#appSection + 1] = vf:spacer{ height=20 }
	appSection[#appSection + 1] = vf:row {
	    vf:static_text {
	        title = "In addition to the things configured here, consider perusing the \"advanced settings\" in 'Preset Manager' section."
	    }
	}
	--]=]
	appSection[#appSection + 1] = vf:row {
	    vf:static_text {
	        title = "There is nothing to configure here, but consider perusing the \"advanced settings\" in 'Preset Manager' section."
	    }
	}
	
	if gbl:getValue( 'background' ) then
	
	    -- *** Instructions: tweak labels and titles and spacing and provide tooltips, delete unsupported background items,
	    --                   or delete this whole clause if never to support background processing...
	    -- PS - One day, this may be handled as a conditional option in plugin generator.
  	    local labelWidth = LrUUID.generateUUID() -- tired of widths tied to unrelated sections..
  	    local dataWidth = LrUUID.generateUUID() -- tired of widths tied to unrelated sections..
	    
        appSection[#appSection + 1] =
            vf:row {
                bind_to_object = props,
                vf:static_text {
                    title = "Auto-check control",
                    width = share( labelWidth ),
                },
                vf:checkbox {
                    title = "Automatically check most selected photo.",
                    value = bind( 'background' ),
    				--tooltip = "",
                    width = share( dataWidth ),
                },
            }
        appSection[#appSection + 1] =
            vf:row {
                bind_to_object = props,
                vf:static_text {
                    title = "Auto-check selected photos",
                    width = share( labelWidth ),
                },
                vf:checkbox {
                    title = "Automatically check selected photos.",
                    value = bind( 'processTargetPhotosInBackground' ),
                    enabled = bind( 'background' ),
    				-- tooltip = "",
                    width = share( dataWidth ),
                },
            }
        appSection[#appSection + 1] =
            vf:row {
                bind_to_object = props,
                vf:static_text {
                    title = "Auto-check whole catalog",
                    width = share( labelWidth ),
                },
                vf:checkbox {
                    title = "Automatically check all photos in catalog.",
                    value = bind( 'processAllPhotosInBackground' ),
                    enabled = bind( 'background' ),
    				-- tooltip = "",
                    width = share( dataWidth ),
                },
            }
        appSection[#appSection + 1] =
            vf:row {
                vf:static_text {
                    title = "Auto-check status",
                    width = share( labelWidth ),
                },
                vf:edit_field {
                    bind_to_object = prefs,
                    value = app:getGlobalPrefBinding( 'backgroundState' ),
                    width = share( dataWidth ),
                    tooltip = 'auto-check status',
                    enabled = false, -- disabled fields can't have tooltips.
                },
            }
    end

    if not app:isRelease() then
    	appSection[#appSection + 1] = vf:spacer{ height = 20 }
    	appSection[#appSection + 1] = vf:static_text{ title = 'For plugin author only below this line:' }
    	appSection[#appSection + 1] = vf:separator{ fill_horizontal = 1 }
    	appSection[#appSection + 1] = 
    		vf:row {
    			vf:edit_field {
    				value = bind( "testData" ),
    			},
    			vf:static_text {
    				title = str:format( "Test data" ),
    			},
    		}
    	appSection[#appSection + 1] = 
    		vf:row {
    			vf:push_button {
    				title = "Test",
    				action = function( button )
    				    app:call( Call:new{ name='Test', async=true, main=function( call )
                            --app:show( { info="^1: ^2" }, str:to( app:getGlobalPref( 'presetName' ) or 'Default' ), app:getPref( 'testData' ) )
                            
                            
                            --Debug.pause( vf:label_spacing(), vf:control_spacing(), vf:dialog_spacing() ) -- 5, 10, 15 (win7).
           
                            local s1 = catalog:getActiveSources()
                            local s2 = cat:getActiveSources()
                            Debug.lognpp( s1, s2 )
                            Debug.showLogFile()
                            Debug.pause()
                            catalog:setActiveSources( s1 )
                            
                            
                            --Debug.pause( LrDate.timeToUserFormat( LrDate.currentTime(), "asdf %Y qwerty" ) )
                            
                            --[[
                            local props = LrBinding.makePropertyTable( call.context )
                            local vi = view:getCollectionBrowser{
                                bindTo = props,
                                bindKey = 'coll',
                            }
                            app:show{
                                info = "Test",       
                                viewItems = { vi },
                            }
                            if props['coll'] then
                                Debug.pause( props['coll']:getName() )
                            else
                                Debug.pause( "no coll" )
                            end
                            --]]                            
                            
                        end } )
    				end
    			},
    			vf:static_text {
    				title = str:format( "Perform tests." ),
    			},
    		}
    end
		
    local sections = Manager.sectionsForBottomOfDialogMethod ( self, vf, props ) -- fetch base manager sections.
    if #appSection > 0 then
        tab:appendArray( sections, { appSection } ) -- put app-specific prefs after.
    end
    return sections
end



return ExtendedManager
-- the end.