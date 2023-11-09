local dk = require "dkjson"
local st = require "st.json"
local utils = require "st.utils"

local function table_eq(exp, other)
	return utils.stringify_table(exp) == utils.stringify_table(other)
end

--TODO handle test cases with expected errors
--- Each test case is its own lua file that returns a table with
--- the fields `description` and `data`
local TestCase = {}
function TestCase:new(require_str, type)
	assert(require_str ~= nil)
	assert(type == "encode" or type == "decode")
	local case = assert(require(require_str))
	assert(case.description)
	assert(case.data)
	o = {
		test_name = case.description,
		test_data = case.data,
		type = type,
	}
  setmetatable(o, self)
  self.__index = self
  return o
end

function TestCase:run()
	local dk_res
	local st_res
	local test_result
	if self.type == "encode" then
		dk_res = dk.encode(self.test_data)
		st_res = st.encode(self.test_data)
		test_result = dk_res == st_res
	elseif self.type == "decode" then
		-- dk_res = utils.stringify_table(dk.decode(self.test_data))
		-- st_res = utils.stringify_table(st.decode(self.test_data))
		dk_res = dk.decode(self.test_data)
		st_res = st.decode(self.test_data)
		test_result = table_eq(dk_res, st_res)
	end

	return test_result, dk_res, st_res
end

local RunnerConfig = {
	num_encode_tests = 0,
	num_decode_tests = 0,
}
function RunnerConfig:new(o)
	o = o or {}
  setmetatable(o, self)
  self.__index = self
  return o
end

function RunnerConfig:num_encode_tests(num)
	self.num_encode_tests = num
	return self
end

function RunnerConfig:num_decode_tests(num)
	self.num_decode_tests = num
	return self
end


local TestRunner = {}
function TestRunner:new(o)
	o = o or {
		test_cases = {}
	}
	assert(o.test_cases)
  setmetatable(o, self)
  self.__index = self
  return o
end

function TestRunner:register_tests(config)
	if config == nil then
		config = RunnerConfig:new()
	end
	self.config = config
	--require in test strings
	for i = 1, config.num_decode_tests do
		table.insert(self.test_cases, TestCase:new(string.format("test_cases.decode-%d", i), "decode")) 
	end
	--require in test tables
	for i = 1,  config.num_encode_tests do
		table.insert(self.test_cases, TestCase:new(string.format("test_cases.encode-%d", i), "encode")) 
	end
end

function TestRunner:run_tests()
	local num_pass = 0
	print(string.format("Running %d tests...", #self.test_cases))
	for i, test_case in ipairs(self.test_cases) do
		local res, dk_res, st_res = test_case:run()
		print(string.format("TestCase(%s):\t\t%s", test_case.test_name, res))
		if not res then
			print(string.format("\tdkjson: %s", utils.stringify_table(dk_res)))
			print(string.format("\tstjson: %s", utils.stringify_table(st_res)))
		else
		  num_pass = num_pass + 1
		end
	end
	print(string.format("Passed %d/%d tests", num_pass, #self.test_cases))
end

local test = {
	RunnerConfig = RunnerConfig,
	TestRunner = TestRunner,
	TestCase = TestCase,
}

return test