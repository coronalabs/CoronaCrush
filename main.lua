-- =============================================================
-- main.lua - A simple connect-3 style game.
-- =============================================================
-- Last Updated: 22 AUG 2013
-- =============================================================

----------------------------------------------------------------------
--	1. Requires
----------------------------------------------------------------------
local physics = require "physics"

----------------------------------------------------------------------
--	2. Initialization
----------------------------------------------------------------------
io.output():setvbuf("no") -- Don't use buffer for console messages
display.setStatusBar(display.HiddenStatusBar)  -- Hide that pesky bar
Runtime:hideErrorAlerts( )

audio.setVolume( 0.5, { channel = 1 } ) -- Sound Effects Channel Volume
audio.setVolume( 0.8, { channel = 2 } ) -- Sound Track Channel Volume

physics.start()
physics.setGravity( 0, 0 )

----------------------------------------------------------------------
--	3. Locals
----------------------------------------------------------------------
-- Helper Variables (Useful for many games and apps)
local w = display.contentWidth
local h = display.contentHeight
local centerX = display.contentCenterX
local centerY = display.contentCenterY

local shaderEffect = 0 -- 0 for no shader; 1..8 for various effects (see code below)

local gameFont = "Comic Book Commando"

local maxImageNum = 4 -- Adjust up to 7 to get between 1 and 7 random images (per set)
local lastImageNumber 

local sounds = {}
for i = 1, 5 do
	sounds[i] =  audio.loadSound("sounds/sound" .. i .. ".wav")
end

local soundTrack = audio.loadStream("sounds/Itty Bitty 8 Bit.mp3")
audio.play( soundTrack, { channel = 2, loops=-1, fadein=1000 }  )

local pointsPerGem = 25

local layers
local theBases
local gemGrid
local theBoard
local scoreLabel
local scoreHUD
local touchesAllowed = false
local lastTouchedGem
local consecutiveMatches = 0

-- Provide some parameters so that we can automatically calculate the size and position of gems
--
local playWidth  = w - 30 -- Maximum width of gem area
local playHeight = h - 60 -- maximum height of gem area
local numCols = 6 -- How many columns of gems?
local numRows = 7 -- How many row of gems?

-- Calculate the best size for gems so that we can fit the specified number of rows and columns
-- in the play area.
--
local gemSize = playWidth/numCols
if(gemSize > playHeight/numRows) then
	gemSize = playHeight/numRows
end

-- Calulate the position of the lower-left gem.
--
-- This will be used to lay out the board and to drop replacement gems.
--
local x0 = (w - (numCols * gemSize))/2 + gemSize/2
local y0 = h - (h - (numRows * gemSize))/2 - gemSize/2  + 4

----------------------------------------------------------------------
--	4. Forward Declarations
----------------------------------------------------------------------
local createGem
local calculateIndex
local testForMatches
local handleMatches
local achievementPopup
local swapBack
local settleGems
local replaceGems
local onGemTouch

local createBadges
local onTouch_Badge

----------------------------------------------------------------------
--	5. Definitions
----------------------------------------------------------------------
-- =======================
-- create() - This is the primary function for the whole game.  It has the job of creating the following:
--
--            * Layers - This game uses display groups to organize screen elements in layers.
--            * Interface Objects - These include the background a frame to overlay the play area, the score HUD, some 'credit' badges/buttons,
--                                  and an overlay image that makes sure any excess space (on devices with different aspect ratios from the design ratio) looks good.
--            * The board/grid - This is the actual gem grid and includes a hidden base (bottom) layer of gems and the actual play pieces which 'stack' on top of them.
--
-- =======================
function create( )

	-- 1. Create rendering layers (group)
	--
	layers = display.newGroup()
	layers.back = display.newGroup()
	layers.content = display.newGroup()
	layers.frame = display.newGroup()
	layers.interface = display.newGroup()
	layers.overlay = display.newGroup()
	layers:insert(layers.back)
	layers:insert(layers.content)
	layers:insert(layers.frame)
	layers:insert(layers.interface)
	layers:insert(layers.overlay)


	-- 2. Add Interface Objects
	--	
	-- Background image
	local tmp = display.newImage( layers.back, "images/back3.png" )
	tmp.x = centerX
	tmp.y = centerY
	
	-- Overlay image (covers unused space regardless of screen shape/size)
	local tmp = display.newImage( layers.overlay, "images/overlay.png" )
	tmp.x = centerX
	tmp.y = centerY

	-- Play Area Frame
	local tmp = display.newImage( layers.frame, "images/frame.png" )
	tmp.x = centerX
	tmp.y = centerY

	-- Score Background
	local tmp = display.newRoundedRect( layers.interface, 0, 0, 300, 50, 6 )
	tmp.x = centerX
	tmp.y = 37
	tmp:setFillColor( 254/255, 191/255, 199/255 )
	tmp.strokeWidth = 3
	tmp:setStrokeColor( 243/255, 95/255, 179/255 )

	-- Score Label	
	scoreLabel = display.newText( layers.interface, "SCORE:", 0, 0, gameFont, 42 )
	scoreLabel.x = centerX - scoreLabel.contentWidth/2 + 10
	scoreLabel.y = 36
	scoreLabel:setFillColor( 51/255, 16/255, 95/255 )

	-- Score HUD
	scoreHUD = display.newText( layers.interface, 0, 0, 0, gameFont, 42 )
	scoreHUD.x = scoreLabel.x + scoreLabel.contentWidth/2 + scoreHUD.contentWidth/2 + 10
	scoreHUD.y = scoreLabel.y
	scoreHUD:setFillColor( 51/255, 16/255 , 95/255 )
	
	-- Game Title Background
	local tmp = display.newRoundedRect( layers.interface, 0, 0, 200, 30, 6 )
	tmp.x = centerX
	tmp.y = h - 30
	tmp:setFillColor( 254/255, 191/255, 199/255 )
	tmp.strokeWidth = 3
	tmp:setStrokeColor( 243/255 ,95/255, 179/255 )

	-- Game Title
	local tmp = display.newText( layers.interface, "Corona Candy", 0, 0, gameFont, 24 )
	tmp.x = centerX
	tmp.y = h - 30
	tmp:setFillColor( 51/255, 16/255, 95/255 )
	

	-- 3. Build the game board
	--
	gemGrid = {}	
	theBases = {}
	theBoard = display.newGroup()	

	-- create a base row to 'hold up' the other gems
	for i = 1, numCols do
		local tmp = createGem( layers.content, "static" )
		tmp.x = x0 + (i - 1) * gemSize
		tmp.y = y0 + gemSize
		tmp.isBase = true
		tmp.alpha = 0
		tmp:setFillColor( 255/255, 255/255, 255/255 )
	end

	replaceGems()
	timer.performWithDelay( numRows * numCols * 15 * 2, function() touchesAllowed = true end )	
	layers.content:insert( theBoard )	


	-- 4. Add badges (Hey, everyone needs a little credit!)
	--
	createBadges()
end

-- =======================
-- destroy() - This function is designed to destroy all of the game contents.  It is not used in this implementation, but
--             has been provided for users who want to modify the code to work in a framework or as a module.
-- =======================
function destroy()
	-- 1. Destroy the layers and everything in them.  Easy!
	layers:removeSelf()

	-- 2. Clear all local variables referencing objects (so Lua can garbage collect)
	layers = nil
	gemGrid = nil
	theBases = nil
	theBoard = nil
	scoreLabel = nil
	scoreHUD = nil
	lastTouchedGem = nil
end

-- =======================
-- onGemTouch() - This is the event listener for all gems.  It has the job or swapping gems and starting the 'matching' check.
-- =======================
local function onGemTouch(self, event)
	local target  = event.target
	local phase   = event.phase
	local touchID = event.id
	local parent  = target.parent

	if( not touchesAllowed ) then return true end
	if( target.isBase ) then return true end

	if( phase == "began" ) then
		display.getCurrentStage():setFocus( target, touchID )
		target.isFocus = true
	
	elseif( target.isFocus ) then
		if(phase == "ended" or phase == "cancelled") then
			display.getCurrentStage():setFocus( target, nil )
			target.isFocus = false

			if( not lastTouchedGem ) then
				lastTouchedGem = target
				lastTouchedGem.xScale = 0.8
				lastTouchedGem.yScale = 0.8

			elseif( target == lastTouchedGem ) then
				lastTouchedGem.xScale = 1
				lastTouchedGem.yScale = 1
				lastTouchedGem = nil
			
			else
				local hits = physics.rayCast( target.x, target.y, lastTouchedGem.x, lastTouchedGem.y, "sorted" )

				if(#hits == 1) then
					-- Don't allow diagonal swaps
					local dx = math.abs(target.x - lastTouchedGem.x) > 1 -- Give a little leeway for inexact positions (because of physics)
					local dy = math.abs(target.y - lastTouchedGem.y) > 1 -- Give a little leeway for inexact positions (because of physics)
					if(dx and dy) then
						-- Both being off by more than 1 means they are diagonal
					else						
						transition.to( target, { x = lastTouchedGem.x, y = lastTouchedGem.y, time = 200 } )
						transition.to( lastTouchedGem, { x = target.x, y = target.y, time = 200 } )						
					
						target.swapped = true
						lastTouchedGem.swapped = true

						timer.performWithDelay( 300, function() testForMatches( 0 ) end )
					end
				end

				lastTouchedGem.xScale = 1
				lastTouchedGem.yScale = 1
				lastTouchedGem = nil
			end
		end		
	end
	return true
end

-- =======================
-- createGem() - This function creates a single gem using a randomly selected image (from our set of image).  The 'type' argument is used to tell this function whether
--               a gem is a 'base game' or a 'normal' gem.  Base gems are placeholder gems that go at the bottom of each column.
--               They are not placed in the 'gemGrid' and are later used by other functions to do maintenance tasks such as:
--
--               * Settling gems - see settleGems()
--               * Replacing gems - see replaceGems()
--               
-- =======================
createGem = function( group, type )
	local type = type or "dynamic"

	-- Randomly choose a new image number (not the same as last selected)
	local imageNumber = math.random(1,maxImageNum)
	while( imageNumber == lastImageNumber ) do
		imageNumber = math.random(1,maxImageNum)
	end
	lastImageNumber = imageNumber

	local theGem = display.newImageRect(group, "images/candy/" .. imageNumber .. ".png", gemSize, gemSize ) 

	-- Graphics 2.0: Filter effects
	-- 
	if( shaderEffect > 0 ) then

		display.setDrawMode( "forceRender", true )

		local effects = {
			"filter.polkaDots",		-- 1
			"filter.levels",		-- 2
			"filter.pixelate",		-- 3
			"filter.sobel",			-- 4
			"filter.zoomBlur",		-- 5
			"filter.scatter",		-- 6
			"filter.woodCut",		-- 7
			"filter.wobble",		-- 8
		}

		theGem.fill.effect = effects[shaderEffect]

		-- Reduce wobble size
		if ( effects[i] == "filter.wobble" ) then
			local effect = theGem.fill.effect
			effect.amplitude = 4
		end
	end

	-- Keep reference to image number for later comparison
	theGem.myImageNumber = imageNumber 

	theGem.touch = onGemTouch
	theGem:addEventListener( "touch", theGem )	
	local halfSize = gemSize/2
	local halfSizeMinus = halfSize - 2
	local bodyShape = { -halfSizeMinus,-halfSize, halfSizeMinus,-halfSize, halfSizeMinus,halfSize, -halfSizeMinus,halfSize }

	physics.addBody( theGem, type, { radius = gemSize/4 } )

	if( type == "dynamic" ) then
		gemGrid[theGem] = theGem
	else
		theBases[theGem] = theGem
	end

	return theGem
end

-- =======================
-- testForMatches() - This function iterates over all of the current gems, and for each gem casts a ray up, down, right, and left.
--                    After each set of casts, the function counts how many consecutive hits are found where the 'hit gems' have the
--                    same image number ('myImageNumber') as the matching gem.  Furthermore, if 3 or more gems (including the current gem) in a row (left,right) or
--                    column (up,down) are found to have the same image number , the current gem is marked as 'matched'.  This means the current gem
--                    is adjacent to 2 or more same colored gems in a row or column respectively.
--
--                    Note: You may wonder why so many ray casts are used and whether there is a better way to do this.  In fact, there are
--                    many ways to do this, chief among the alternatives is to keep gems in a table and to use an algorithm to determine rows and 
--                    columns.  This way is faster, but significantly more complex than ray casting.  Whereas, ray casting is simple, and only costs about 4ms
--                    for 48 * 4 == 192 ray casts.  So, even if you budget is only 16 ms (i.e. 60 FPS), you've got plenty of time to do this every frame.
--
--                    In closing, I chose this method because it is short to code and easy to understand and to explain.
-- =======================
testForMatches = function( lastMatches )
	local left  = -2000
	local right =  2000
	local up    = -2000
	local down  =  2000

	touchesAllowed = false

	local foundMatch = false

	for k,v in pairs( gemGrid ) do
		local horizontalHits = 0
		local verticalHits = 0
		local leftHits = physics.rayCast( v.x, v.y, v.x + left, v.y, "sorted" ) or {}
		local rightHits = physics.rayCast( v.x, v.y, v.x + right, v.y, "sorted" ) or {}
		local upHits = physics.rayCast( v.x, v.y, v.x, v.y + up, "sorted" ) or {}
		local downHits = physics.rayCast( v.x, v.y, v.x, v.y + down, "sorted" ) or {}


		-- Count the horizontal hits
		for i = 1, #leftHits do
			if(leftHits[i].object.myImageNumber ~= v.myImageNumber) then
				break
			end
			horizontalHits = horizontalHits + 1
		end
		for i = 1, #rightHits do
			if(rightHits[i].object.myImageNumber ~= v.myImageNumber) then
				break
			end
			horizontalHits = horizontalHits + 1
		end

		-- Count the vertical hits
		for i = 1, #upHits do
			if(upHits[i].object.myImageNumber ~= v.myImageNumber) then
				break
			end
			verticalHits = verticalHits + 1
		end
		for i = 1, #downHits do
			if(downHits[i].object.myImageNumber ~= v.myImageNumber) then
				break
			end
			verticalHits = verticalHits + 1
		end

		if( horizontalHits >  1 or verticalHits > 1 ) then
			v.matched = true
			foundMatch = true			
		end
	end
	
	if( foundMatch ) then
		lastMatches = lastMatches + 1
		audio.play( sounds[math.random(1,5)], { channel = 1 } )
		handleMatches()
		timer.performWithDelay( 150, function() settleGems() end )
		timer.performWithDelay( 250, function() replaceGems() end )
		timer.performWithDelay( 750, function() testForMatches( lastMatches ) end )
	else
		if( lastMatches >= 2 ) then
			achievementPopup()
		end
		swapBack()
		timer.performWithDelay( 250, function() touchesAllowed = true end )
	end
end

-- =======================
-- handleMatches() - This function iterates over all of the current gems and checks to see if they were marked as 'matched'.
--                   Each gem that is found to have been marked this way is removed from the board and in its place, a temporary
--                   floating points award is shown.
-- =======================
handleMatches = function()
	for k,v in pairs( gemGrid ) do		
		if(v.matched) then
			local tmp = display.newText( layers.frame, pointsPerGem, 0, 0, gameFont, 36 )
			
			tmp.x = v.x
			tmp.y = v.y
			transition.to( tmp, { y = tmp.y - 75, alpha = 0, time = 1000 } )
			timer.performWithDelay( 1100, function() tmp:removeSelf() end )

			v:removeSelf()
			gemGrid[k] = nil

			local tmpScore = tonumber( scoreHUD.text )
			tmpScore = tmpScore + pointsPerGem
			scoreHUD.text = tmpScore
			scoreHUD.x = scoreLabel.x + scoreLabel.contentWidth/2 + scoreHUD.contentWidth/2 + 10
		end
	end
end

-- =======================
-- swapBack() - This function looks for two gems that were just 'swapped' and then swaps them back.
--              The assumption here is, if we don't find any marked gems, the swap isn't needed.
-- =======================
swapBack = function()
	local swapGems = {}
	for k,v in pairs( gemGrid ) do		
		if(v.swapped) then
			swapGems[#swapGems+1] = v
			v.swapped = false
		end
	end

	if(#swapGems == 2) then
		local gem1 = swapGems[1]
		local gem2 = swapGems[2]		
		transition.to( gem1, { x = gem2.x, y = gem2.y, time = 200 } )
		transition.to( gem2, { x = gem1.x, y = gem1.y, time = 200 } )		
	end
end


-- =======================
-- settleGems() - Iterates over 'base gems' and casts ray upward to see how many gems are in the column.
--                 If fewer than 'numRows' gems are found, the existing gems are 'dropped' to fill empty spaces.
--                 Note: To make dropping nice, we use the transition library.  We could have used physics
--                 gravity, but Box2D tends to have a little flex when objects collide and we don't want 
--                 that affect.  Instead, we want a nice solid stop.  
-- =======================
settleGems = function()
	local up    = -2000
	local nextX 
	local nextY
	for k,v in pairs( theBases ) do
		nextX = v.x
		nextY = v.y - gemSize
		missingGemCount = 0
		local hits = physics.rayCast( v.x, v.y, v.x, v.y + up, "closest" ) or {}

		local moveCount = 0
			
		while(#hits == 1) do
			local object = hits[1].object
			if(object.y < nextY) then
				transition.to( object, { y = nextY, time = 100 + moveCount * 50 } )
				moveCount = moveCount + 1
			end
			nextY = nextY - gemSize
			hits = physics.rayCast( object.x, object.y, object.x, object.y + up, "closest" ) or {}
		end
	end
end

-- =======================
-- replaceGems() - Iterates over 'base gems' and casts ray upward to see how many gems are in the column.
--                 If fewer than 'numRows' gems are found, new gems are 'dropped' to fill the column.
--                 Note: To make dropping nice, we use the transition library.  We could have used physics
--                 gravity, but Box2D tends to have a little flex when objects collide and we don't want 
--                 that affect.  Instead, we want a nice solid stop.  
-- =======================
replaceGems = function()
	local up    = -500
	for k,v in pairs( theBases ) do
		missingGemCount = 0
		local hits = physics.rayCast( v.x, v.y, v.x, v.y + up, "sorted" ) or {}

		local missingGems = numRows - #hits 
		
		for i = 1, missingGems do
			local tmp  = createGem( layers.content )
			tmp.x = v.x
			tmp.y = 0 - (i * gemSize)
			
			local toY = v.y - (#hits + i) * gemSize
			transition.to( tmp, { y = toY, time  = 250 + 50 * i} )
		end
	end
end

-- =======================
-- achievementPopup() - This function produces a random 'achievement' popup.  It is used for sequential connections >= 3
-- =======================
achievementPopup = function()

	local group = display.newGroup()
	
	local back = display.newRoundedRect( group, 0, 0, 200, 60, 12 )
	back.strokeWidth = 3
	back:setFillColor( 243/255, 95/255, 179/255 )
	back:setStrokeColor( 254/255, 191/255, 199/255 ) 
	back.x = centerX
	back.y = centerY

	local messages = {}
	messages[#messages+1] = "Awesome!"
	messages[#messages+1] = "Keep Going!"
	messages[#messages+1] = "Rockin' It!"
	messages[#messages+1] = "Woah!"
	messages[#messages+1] = "Super Cool!"

	local tmp = display.newText( group, messages[ math.random( 1, #messages )], 0, 0, gameFont, 32 )
	tmp.x = back.x
	tmp.y = back.y

	transition.to( group, { alpha = 0, time = 1000, delay = 500 } )
	timer.performWithDelay( 1600, function() group:removeSelf() end )
end

-- =======================
-- createExample() - Adds badges to screen.  Also starts listeners.
-- =======================
createBadges = function()
	local tmp = display.newImageRect( layers.frame, "images/Built_with_Corona_SM.png", 43, 60 )
	tmp.x = 30
	tmp.y = h - 30
	tmp.touch = onTouch_Badge
	tmp.url = "http://www.coronalabs.com/"
	tmp:addEventListener( "touch", tmp )

	local tmp = display.newImageRect( layers.frame, "images/rg.png", 43, 60 )
	tmp.x = w - 30
	tmp.y = h - 30
	tmp.touch = onTouch_Badge
	tmp.url = "http://roaminggamer.com/makegames/"
	tmp:addEventListener( "touch", tmp )
end

-- =======================
-- onTouch_Badge() - Event listener for 'badge touches'.  Opens web pages.
-- =======================
onTouch_Badge = function( self, event )
	local phase = event.phase
	local target = event.target
	local url = target.url
	if( phase == "ended" ) then
		system.openURL( url ) 
	end
	return true
end

----------------------------------------------------------------------
-- 6. Create and Start Game
----------------------------------------------------------------------
create( display.currentStage ) 