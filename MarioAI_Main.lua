--Most of this is just reading and formatting data from the ROM to 
--then simplify down and feed into an AI via 13x13 table of blocks

local ROMScraper = require("scripts/ROMScraper");

local JoyPadRight = {Right=1};
local JoyPadLeft = {Left=1};
local JoyPadUp = {Up=1};
local JoyPadDown = {Down=1};
local JoyPadB = {B=1}; --fireball/run
local JoyPadA = {A=1}; --jump

local fitness = 0;

local cpuSaver9000 = 0;

local portWidth = 13;
local portHeight = 13;

local neuralInput;

local function pressRight()
	joypad.set(JoyPadRight,1)
end

local function pressLeft()
	joypad.set(JoyPadLeft,1)
end

local function pressUp()
	joypad.set(JoyPadUp,1)
end

local function pressDown()
	joypad.set(JoyPadDown,1)
end

local function pressA()
	joypad.set(JoyPadA,1)
end

local function pressB()
	joypad.set(JoyPadB,1)
end

--displays fitness
local function displayInfo()
	gui.text(5, 10, "script running", "white");

	--Fitness will be used to train the neural network
	gui.text(170, 10, "Fitness: " .. ROMScraper.calcFitness(), "white");
end

--Draws the 13x13 map of blocks with Mario in the middle (mario not shown)
--param: x the x location of the top left corner of the block map onscreen
--param: y the y location of the top left corner of the block map onscreen
local function displayPort(port, x, y)
	gui.drawRectangle(x + 5, y + 5, 5*portWidth, 5*portHeight, "red");
	for row=1,portWidth do
		for col=1,portHeight do
			if port[row][col] == 1 then
				gui.drawRectangle(x + 5*col, y + 5*row, 4, 4, "white");
			end
			if port[row][col] == -1 then
				gui.drawRectangle(x + 5*col, y + 5*row, 4, 4, "red");
			end
		end
	end
end


--This is the main loop
while true do

	--Current fitness
	displayInfo();

	neuralInput = ROMScraper.getPort();
	displayPort(neuralInput, 50, 50);

	--Next frame
	emu.frameadvance();
end
