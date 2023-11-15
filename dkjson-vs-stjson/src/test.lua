local dk = require "dkjson"
local st = require "st.json"
local utils = require "st.utils"

local function table_eq(exp, other)
	return utils.stringify_table(exp) == utils.stringify_table(other)
end

--This might be not working, but it could be due to ordering 
-- in dkjson that it is failing. I dont think iteration should matter
-- since we recurse to lowest level table before modifying anything in place
local function recursive_sort(tbl)
	for k, v in pairs(tbl) do
		if type(v) == "table" then
			recursive_sort(v)
		end
	end
	table.sort(tbl)
end

--handles two levels of nesting, which is all we need for test data
local function nested_sort(tbl)
	table.sort(tbl)
	for k, v in pairs(tbl) do
		if type(v) == "table" then
			table.sort(v)
			for k, v in pairs(tbl) do
				if type(v) == "table" then
					table.sort(v)
				end
			end
		end
	end
end

local function key_order(tbl)
	local res = {}
	for k, v in pairs(tbl) do
		table.insert(res, k)
	end
	table.sort(res)
	return res
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

--TODO store results on testcase itself?
function TestCase:run_comparison_test()
	local dk_res
	local st_res
	local test_result
	if self.type == "encode" then
		--[[ These seem to all pass when they shouldn't
		local dk_enc = dk.encode(self.test_data)
		local st_enc = st.encode(self.test_data)
		dk_res = dk.decode(st_enc)
		st_res = st.decode(dk_enc)
		test_result = table_eq(dk_res, st_res)
		--]]
		--[[ Some of these fail because ordering is not deteminant in dkjson
		nested_sort(self.test_data)
		dk_res = dk.encode(self.test_data)
		st_res = st.encode(self.test_data)
		test_result = dk_res == st_res
		--]]
		--[[ Key order isn't always respected by dkjson and definitely not for nested objects]]
		-- Note sorting is modifying test data as it runs, but it doesn't affect the roundtrip tests
		recursive_sort(self.test_data)
		local keyorder = key_order(self.test_data)
		dk_res = dk.encode(self.test_data, {keyorder = keyorder})
		st_res = st.encode(self.test_data)
		test_result = dk_res == st_res
		--]]
	elseif self.type == "decode" then
		dk_res = dk.decode(self.test_data)
		st_res = st.decode(self.test_data)
		test_result = table_eq(dk_res, st_res)
	end

	return test_result, dk_res, st_res
end

function TestCase:run_st_roundtrip_test(nullval)
	local test_result, actual
	if self.type == "encode" then
		local enc = st.encode(self.test_data)
		actual = st.decode(enc, nil, nullval)
		test_result = table_eq(self.test_data, actual)
	elseif self.type == "decode" then
		local dec = st.decode(self.test_data, nil, nullval)
		actual = st.encode(dec)
		test_result = self.test_data == actual
	end

	return test_result, self.test_data, actual
end


function TestCase:run_dk_roundtrip_test()
	local test_result, actual
	if self.type == "encode" then
		local enc = dk.encode(self.test_data)
		actual = dk.decode(enc)
		test_result = table_eq(self.test_data, actual)
	elseif self.type == "decode" then
		local dec = dk.decode(self.test_data)
		actual = dk.encode(dec)
		test_result = self.test_data == actual
	end

	return test_result, self.test_data, actual
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
	--[[
	local num_pass = 0
	print(string.format("Running %d comparison tests...", #self.test_cases))
	for i, test_case in ipairs(self.test_cases) do
		local res, dk_res, st_res = test_case:run_comparison_test()
		print(string.format("\t%s(%s):%s", test_case.type, test_case.test_name, res))
		if not res then
			print(string.format("\t\ttest data: %s", utils.stringify_table(test_case.test_data)))
			print(string.format("\t\tdkjson: %s", utils.stringify_table(dk_res)))
			print(string.format("\t\tstjson: %s", utils.stringify_table(st_res)))
		else
		  num_pass = num_pass + 1
		end
	end
	print(string.format("Passed %d/%d comparison tests. Note hand check the encode tests", num_pass, #self.test_cases))
	--]]
	--[[]]
	num_pass = 0
	print(string.format("Running %d st roundtrip tests...", #self.test_cases))
	for i, test_case in ipairs(self.test_cases) do
		local res, expected, actual = test_case:run_st_roundtrip_test()
		print(string.format("\t%s(%s):%s", test_case.type, test_case.test_name, res))
		if not res then
			print(string.format("\t\tStarted with: %s", utils.stringify_table(expected)))
			print(string.format("\t\tGot back: %s", utils.stringify_table(actual)))
		else
		  num_pass = num_pass + 1
		end
	end
	print(string.format("Passed %d/%d tests", num_pass, #self.test_cases))
	--]]
	--[[]]
	num_pass = 0
	print(string.format("Running %d st roundtrip tests with nullval...", #self.test_cases))
	for i, test_case in ipairs(self.test_cases) do
		local res, expected, actual = test_case:run_st_roundtrip_test(st.null)
		print(string.format("\t%s(%s):%s", test_case.type, test_case.test_name, res))
		if not res then
			print(string.format("\t\tStarted with: %s", utils.stringify_table(expected)))
			print(string.format("\t\tGot back: %s", utils.stringify_table(actual)))
		else
		  num_pass = num_pass + 1
		end
	end
	print(string.format("Passed %d/%d tests", num_pass, #self.test_cases))
	--]]
	--[[
	num_pass = 0
	print(string.format("Running %d dk roundtrip tests...", #self.test_cases))
	for i, test_case in ipairs(self.test_cases) do
		local res, expected, actual = test_case:run_st_roundtrip_test()
		print(string.format("\t%s(%s):%s", test_case.type, test_case.test_name, res))
		if not res then
			print(string.format("\t\tStarted with: %s", utils.stringify_table(expected)))
			print(string.format("\t\tGot back: %s", utils.stringify_table(actual)))
		else
		  num_pass = num_pass + 1
		end
	end
	print(string.format("Passed %d/%d tests", num_pass, #self.test_cases))
	--]]
end

local test = {
	RunnerConfig = RunnerConfig,
	TestRunner = TestRunner,
	TestCase = TestCase,
}

return test