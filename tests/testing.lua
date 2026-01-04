-- simple testing functionalities

T = {}

T.__index = T

function T.new()
  local self = setmetatable({}, T)
  self.passed = 0
  self.failed = 0

  return self
end

function T:test(name, fn)
  local ok, _ = pcall(fn)
  if ok then
    self.passed = self.passed + 1
    print("Test Passed: " .. name)
  else
    self.failed = self.failed + 1
    print("Test Failed: " .. name)
  end
end

function T.assertsEqual(expected, actual, msg)
  if expected ~= actual then
    error((msg or "Assertion failed") .. ": expected " .. tostring(expected) .. ", got " .. tostring(actual))
  end
end

function T:report()
  print(string.format("Passed: %d", self.passed))
  print(string.format("Failed: %d", self.failed))
  print(string.format("Total:  %d", self.passed + self.failed))
end

function T.assertNotNil(value, msg)
  if value == nil then
    error((msg or "Assertion failed") .. ": expected non-nil value")
  end
end

return T
