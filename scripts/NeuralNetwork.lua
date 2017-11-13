--NeuralNode.lua

local NeuralNetwork = {
	input = {},
	output = {},
	connections = {},
	numOfConnections = 0
};

function NeuralNetwork:setInputLayer(inputTable, ...)
	self.input = inputTable;
	self.inputLength = arg[1];
	self.inputWidth = arg[2] or 1;
end

function NeuralNetwork:updateInput(inputTable)
	self.input = inputTable;
end

function NeuralNetwork:setOutputLayer(outputTable, length)
	self.output = outputTable;
	self.outputLength = length;
end

function NeuralNetwork.processInput()
	--2d array as input
	if self.inputWidth > 1 then

	--normal array as input
	else 

	end
end

function NeuralNetwork:addRandomConnection()
	--Choose random input node and output node to establish connection
	local randomInputNode = math.random(1, self.inputLength * self.inputWidth);
	local randomOutputNode = math.random(1, self.outputLength);

	self.numOfConnections = self.numOfConnections + 1;
	self.connections[self.numOfConnections] = {randomInputNode, randomOutputNode};
end

return NeuralNetwork;