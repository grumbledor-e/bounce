-- A global note-on rate cap. Drop excess events; never queue them.
local Cap={}
Cap.__index=Cap
function Cap.new(rate)
  assert(rate>0)
  return setmetatable({interval=1/rate,last=-math.huge},Cap)
end
function Cap:allow(now)
  if now-self.last+1e-9<self.interval then return false end
  self.last=now
  return true
end
return Cap
