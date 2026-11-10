local P = {}
P.__index = P
function P.new(random)
  return setmetatable({balls={}, random=random or math.random, spawn_credit=0},P)
end
function P:drop(c)
  if #self.balls >= 32 then return end
  local r=self.random
  self.balls[#self.balls+1]={x=4+r()*120,y=-3,vx=(r()*2-1)*c.drift,
    vy=0,bounces=0,life=c.lifespan}
end
function P:clear() self.balls={}; self.spawn_credit=0 end
function P:step(dt,c,hit)
  self.spawn_credit=self.spawn_credit+dt*c.density
  while self.spawn_credit>=1 do
    self.spawn_credit=self.spawn_credit-1; self:drop(c)
  end
  for i=#self.balls,1,-1 do
    local b=self.balls[i]
    b.vy=b.vy+c.gravity*dt
    b.x=b.x+b.vx*dt; b.y=b.y+b.vy*dt
    if b.x<3 then b.x=6-b.x;b.vx=math.abs(b.vx) end
    if b.x>124 then b.x=248-b.x;b.vx=-math.abs(b.vx) end
    if b.y>=51 and b.vy>0 then
      b.y=51;b.bounces=b.bounces+1
      hit(b,math.min(1,math.max(.12,b.vy/110)))
      -- Minimum rebound prevents floor chatter while preserving exact lifespan.
      b.vy=-math.max(12,b.vy*c.bounce)
      if b.bounces>=b.life then table.remove(self.balls,i) end
    end
  end
end
return P
