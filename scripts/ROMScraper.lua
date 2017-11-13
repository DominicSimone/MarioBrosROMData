--ROMScraper.lua

local ROMScraper = {};

local enemyColor = "red";
local groundedColor = "green";

--Increments every time xPosAddrSmall exceeds 256
local xPosAddrLarge = 0x006D;

--X position
local xPosAddrSmall = 0x0086;

--x position on screen, max is 0x0070 usually (around halfway across)
local xPosScreenAddr = 0x0755;

--y position on screen, ranges from ~D0 at bottom to 00 at top
local yPosScreenAddr = 0x00CE;

--0 = standing on solid
--1 = in air by jump
--2 = in air by walking off something
--3 = sliding down pole
local floatStateAddr = 0x001D; 

--5x 4bytes: 5 * [x1][y1][x2][y2]
--actual data starts at the next address(0x04B0),
--but the readbyterange method skips the parameter
local enemyHitBoxesAddr = 0x04AF;
local enemyHitBoxesPos = {};

--Again, the data we care about (0x000F) starts after this address (5 addresses)
local enemyListAddr = 0x000E;
local enemyList = {};

--Data we care about (0x0016) starts after this address (5 addresses)
local enemyTypeListAddr = 0x0015;
local enemyTypeList = {};

--Hardcoding because its only four and I want to try something different
local marioHitBoxAddr = {0x04AC, 0x04AD, 0x04AE, 0x04AF};
local marioHitBox = {};

--First address row to last address row of each layout buffer
local bufferOneLayoutAddresses = {0x0500, 0x05C0};
local bufferTwoLayoutAddresses = {0x05D0, 0x0690};

--readbyterange 13 times for each buffer, read the whole 16 memory locations
--in each row
local aiBufferLayout1 = {{}, {}, {}, {}, {}, {}, {}, {},
                         {}, {}, {}, {}, {}, {}, {}, {}};
local aiBufferLayout2 = {{}, {}, {}, {}, {}, {}, {}, {},
                         {}, {}, {}, {}, {}, {}, {}, {}};

local aiLevelLayout = {aiBufferLayout1, aiBufferLayout2};

--Our input is going ot be a 13x13 table with blocks and enemies
--1 = block
--2 = enemy (?) (may not go well with the NN)
local aiInput = {{},{},{},{},{},{},{},{},{},{},{},{},{}};

local portWidth = 13;
local portHeight = 13;

local portXRangeMin = 0;
local portXRangeMax = portXRangeMin + portWidth;

local startingBlock = 1;

--Calculates fitness, factor of current x position (how far right on the screen)
function ROMScraper.calcFitness()
	fitness = memory.readbyte(xPosAddrLarge) * 256 + memory.readbyte(xPosAddrSmall);
	return fitness;
end


--Finds all the hitboxes of previously found enemies
function ROMScraper.findEnemyHitbox()
	--memory.readbyterange skips the address parameter, so we put the address 
	--right behind where the actual data resides
	local tempTable = memory.readbyterange(enemyHitBoxesAddr, 21); --read hitbox section of hex
	local i = 1;
	for key, value in pairs(tempTable) do 
		enemyHitBoxesPos[i] = value; --assign them to an table with number keys
		i = i+1;
	end
	--For some reason the first address read lands on the end of the table
	--deleting the irrelevant data
	enemyHitBoxesPos[21] = nil
end


--Finding all the enemies that are currently active
function ROMScraper.populateEnemyList()
	local temp = memory.readbyterange(enemyListAddr, 6);
	local i = 1;
	for key,value in pairs(temp) do
		enemyList[i] = value;
		i = i+1;
	end
	--For some reason the first address read lands on the end of the table
	--deleting the irrelevant data
	enemyList[6] = nil;
end


--Making sure the enemies are actually enemies by reading their type address
function ROMScraper.populateEnemyTypeList()
	local temp = memory.readbyterange(enemyTypeListAddr, 6);
	local i=1;
	for key,value in pairs(temp) do
		enemyTypeList[i] = value;
		i = i+1;
	end
	enemyTypeList[6] = nil;
end


--Combines the three functions above
--Finds hitboxes, gets active enemies, and gets their types
function ROMScraper.getEnemyData()
	ROMScraper.findEnemyHitbox();
	ROMScraper.populateEnemyList();
	ROMScraper.populateEnemyTypeList();
end


--Taking the enemy list and enemytype list we draw and color code the hitboxes
--Also puts enemies into our formatted port (as -1 values)
function ROMScraper.recordEnemyHitbox()
	ROMScraper.getEnemyData();

	-- '1' for non enemy
	-- '-1' for enemy
	local entityID = 0;

	--Find mario's on screen position so we can get the distance from mario (center of the 13x13 port)
	local marioX = memory.readbyte(xPosScreenAddr);
	local marioY = memory.readbyte(yPosScreenAddr);

	local x1;
	local y1;
	local x2;
	local y2;
	local xBlocksFromMario;
	local xBlock;
	local yBlock;
	local startAddr;

	for i=1,5 do --All five possible enemies
		--For each set of addresses, draw a box
		startAddr = (4*i) - 3;

		x1 = enemyHitBoxesPos[startAddr];
		y1 = enemyHitBoxesPos[startAddr + 1];
		x2 = enemyHitBoxesPos[startAddr + 2];
		y2 = enemyHitBoxesPos[startAddr + 3];

		xBlocksFromMario = math.floor((marioX - x1) / 16);
		xBlock = 7 --[[middle of table]] - xBlocksFromMario; 
		yBlock = math.floor( (y1-8) / 16);


		--If the enemy does not exist anymore, skip
		if enemyList[i] ~= 0 then 
			--Check to see if the enemy is actually an enemy or safe to walk on
			--data from a Super Mario Bros RAM map
			if enemyTypeList[i] < 33 or enemyTypeList[i] > 55 or enemyTypeList[i] == 45 then
				color = enemyColor;
				entityID = -1;
			else
				color = groundedColor;
				entityID = 1;
			end
			--I had an overflow issue where the y1 pos would flow from 00 -> FF
			--causing the drawn hitbox to stretch across the screen vertically.
			--This test fixes that issue
			if y1 - y2 > 120 then
				y1 = 0;
			end
			if y2 - y1 > 120 then
				y2 = 0;
			end

			--insert enemy into formatted table of inputs (13x13)
			if yBlock > 0 and yBlock < 14 and xBlock ~= 0 and xBlock < 14 then
				aiInput[yBlock][xBlock] = entityID;
			end

			--Replace draw box with something to alert ai of enemy location
			--gui.drawBox(x1, y1, x2, y2, color, color);
		end
	end
end

--This method reads the ROM's memory where the current rendered level blocks 
--(stored in two blocks/buffers) and loads in the proper values into two
--seperate table buffers. 
--Note: The NES swaps these buffers when rendering tiles so it can load one
--while another is already loaded and ready to render 
function ROMScraper.populateBufferLayouts()

    local startingFirstAddr = bufferOneLayoutAddresses[1];
    local startingSecondAddr = bufferTwoLayoutAddresses[1];
    local currentStartAddr;


    --Could be more efficient
    --populating first table buffer
    for row=1,13 do
    	currentStartAddr = startingFirstAddr + (16*(row-1));
    	aiBufferLayout1[row] = memory.readbyterange(currentStartAddr-1, 17);
    end

    --Populating second table buffer
    for row=1,13 do
    	currentStartAddr = startingSecondAddr + (16*(row-1));
   	    aiBufferLayout2[row] = memory.readbyterange(currentStartAddr-1, 17);
    end
end


--Reads the two memory buffer blocks that store the level layout
--and formats the data to fit into a 13x13 map with Mario in the center
function ROMScraper.formatPort()

	--Finding the absolute level coordinate for the center of the display port
	--as well as the first coord and the last coord of the screen
	local Xlarge = memory.readbyte(xPosAddrLarge);
	local Xsmall = memory.readbyte(xPosAddrSmall);

    --We want the 6 blocks on either side of mario
    --six blocks left of mario
    portXRangeMin = ((Xlarge * 256) + Xsmall) - (6 * 16);
    --thirteen blocks right from there
    portXRangeMax = portXRangeMin + (portWidth * 16);

    --determining which buffer to draw from
    local firstBuffer = aiLevelLayout[1 + (Xlarge % 2)];
    --we may have to read from both buffers at each transition
    local secondBuffer = aiLevelLayout[1 + ((Xlarge+1) % 2)];

    if(portXRangeMin < 0) then
    	portXRangeMin = 0;
    	portXRangeMax = portWidth * 16;
    end

    --determining which block within the buffer to start drawing from
    local startingBlock = 1 + (math.floor(portXRangeMin/16) % 16);
    local endingBlock = startingBlock + portWidth - 1;

    --print(startingBlock .. " : " .. endingBlock);

    local currentBlock = startingBlock;
    local currentBuffer = firstBuffer;
    local otherBuffer = secondBuffer;

    --CURRENT ISSUE: Vertical lines near buffer ends
    
    --Current buffer needs to be the buffer on the left side
    --[[ __________  __________
		|          ||          |
		| current  ||  other   |
		| buffer   ||  buffer  |
		|__________||__________|
    --]]

    if Xlarge == 0 then
    	currentBuffer = firstBuffer;
    	otherBuffer = secondBuffer;
    elseif startingBlock > 16 - math.floor(portWidth/2) then
    	currentBuffer = secondBuffer;
    	otherBuffer = firstBuffer;
    else
    	currentBuffer = firstBuffer;
    	otherBuffer = secondBuffer;
    end

    
    --Filling the port layout
    for row=1,portHeight do
    	local aiCol = 1
    	for col=startingBlock,endingBlock do
    		--Use the correct buffer and put the end-game input blocks in the table
    		if col <= 16 then
    			if currentBuffer[row][col] ~= nil and currentBuffer[row][col] ~= 0 then
    				aiInput[row][aiCol] = 1;
    			else 
    				aiInput[row][aiCol] = 0;
    			end
    		else
    			if otherBuffer[row][col - 16] ~= nil and otherBuffer[row][col-16] ~= 0 then
    				aiInput[row][aiCol] = 1;
    			else 
    				aiInput[row][aiCol] = 0;
    			end
    		end
    		aiCol = aiCol + 1;
    	end
    end
end

--Reads all the memory data, formats the environment, adds the enemies, then returns the 13x13 table with this info
function ROMScraper.getPort()
	ROMScraper.populateBufferLayouts();
	ROMScraper.formatPort();
	ROMScraper.recordEnemyHitbox();
	return aiInput;
end


return ROMScraper;