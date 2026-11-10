-- bounce v0.3.2 | a physics sequencer for nb voices
local nb=include('bounce/lib/nb/lib/nb')
local Physics=include('bounce/lib/physics')
local TriggerCap=include('bounce/lib/trigger_cap')
local trigger_cap=TriggerCap.new(16)
local music=require 'musicutil'
local cs=require 'controlspec'
local world=Physics.new()
local running=false
local ready=false
local elapsed=0
local flashes={}
local active={}
local timer,boot
local overlay,overlay_until='',0
local held=false
local shapes={'sine','triangle','square','random','saw'}
local targets={'off','density','gravity','bounce','drift','length','velocity','voice mod'}
local phases,random_values={0,.25,.5,.75},{0,0,0,0}
local notes={}
local player
local progression, harmony_scale, chord, chord_time, root_shift = {}, {}, 1, 0, 0
local function generate_progression()
  harmony_scale=music.generate_scale(48,params:string('scale'),1)
  local degrees=#harmony_scale-1
  progression = {1}
  for i=2,4 do
    local degree = math.random(math.max(1,degrees-1))
    if degree >= progression[i-1] then degree=degree+1 end
    progression[i]=math.min(degree,degrees)
  end
  chord, chord_time = 1, 0
end

local function chord_interval(degree, step)
  local degrees=#harmony_scale-1
  return harmony_scale[(degree-1+step)%degrees+1]
    -harmony_scale[degree]+12*math.floor((degree-1+step)/degrees)
end

local chord_qualities={
  [3]={[6]='dim',[7]='m'},
  [4]={[7]='',[8]='aug'},
  [2]={[7]='sus2'},
  [5]={[7]='sus4'},
}

local function harmony_label()
  local root=params:get('root')
  if params:get('progression')==2 and progression[chord] then
    local degree=progression[chord]
    local third,fifth=chord_interval(degree,2),chord_interval(degree,4)
    local quality=chord_qualities[third] and chord_qualities[third][fifth]
    local name=music.note_num_to_name(root+harmony_scale[degree]-48):lower()
    return name..(quality or (' +'..third..' +'..fifth))
  end
  return music.note_num_to_name(root):lower()..' '..params:string('scale'):lower():sub(1,13)
end

local function harmony(dt)
  local enabled = params:get('progression') == 2
  if enabled then
    chord_time=chord_time+dt
    local duration=params:get('chord_beats')*clock.get_beat_sec()
    if chord_time>=duration then
      chord_time=chord_time%duration
      chord=chord%4+1
    end
  end
  local target=0
  if enabled then
    target=harmony_scale[progression[chord]]-48
  end
  root_shift=target
end

local function release_note(note)
  active[note].player:note_off(note)
  active[note]=nil
end
local stealing_modes={'oldest (first)','newest (last)','random','lowest pitch','highest pitch','quietest','loudest'}
local function held_notes()
  local held={}
  for note in pairs(active) do held[#held+1]=note end
  table.sort(held)
  return held
end

local function steal_note(held)
  local mode=params:get('voice_stealing')
  if mode==3 then return held[math.random(#held)] end
  if mode==4 then return held[1] end
  if mode==5 then return held[#held] end
  local selected=held[1]
  for _,note in ipairs(held) do
    local candidate,current=active[note],active[selected]
    if (mode==1 and candidate.started<current.started)
      or (mode==2 and candidate.started>current.started)
      or (mode==6 and candidate.velocity<current.velocity)
      or (mode==7 and candidate.velocity>current.velocity) then
      selected=note
    end
  end
  return selected
end

local function trim_voices()
  local held=held_notes()
  while #held>params:get('max_voices') do
    release_note(steal_note(held))
    held=held_notes()
  end
end

local function rebuild_scale()
  notes=music.generate_scale(params:get('root'),params:string('scale'),params:get('octaves'))
  local legal={}
  for _,n in ipairs(notes) do if n<=127 then legal[#legal+1]=n end end
  notes=legal
end
local function stop_notes()
  for n,v in pairs(active) do v.player:note_off(n) end
  active={}
  if player then player:stop_all() end
end
local function message(s) overlay=s;overlay_until=elapsed+1.2 end
local function control(id,name,lo,hi,default,warp,units)
  params:add_control(id,name,cs.new(lo,hi,warp or 'lin',0,default,units or ''))
end
local function config(dt)
  local c={density=params:get('density'),gravity=params:get('gravity'),bounce=params:get('bounce'),
    drift=params:get('drift'),lifespan=params:get('lifespan'),length=params:get('length'),velocity=1,mod=0}
  local amounts={density=4,gravity=100,bounce=.25,drift=25,length=1,velocity=.75,mod=1}
  for i=1,4 do
    local prefix='lfo_'..i..'_'
    local old=phases[i]
    local advance=dt*params:get(prefix..'rate')
    phases[i]=(old+advance)%1
    if old+advance>=1 then random_values[i]=math.random()*2-1 end
    local p=phases[i]
    local shape=params:get(prefix..'shape')
    local val=shape==1 and math.sin(2*math.pi*p) or shape==2 and (1-4*math.abs(p-.5)) or shape==3 and (p<.5 and 1 or -1) or shape==5 and (2*p-1) or random_values[i]
    local target=targets[params:get(prefix..'target')]
    if target=='voice mod' then target='mod' end
    if c[target] then c[target]=c[target]+val*params:get(prefix..'depth')*amounts[target] end
  end
  c.density=util.clamp(c.density,0,8);c.gravity=util.clamp(c.gravity,10,200)
  c.bounce=util.clamp(c.bounce,.2,.98);c.drift=util.clamp(c.drift,0,40)
  c.length=util.clamp(c.length,.02,4);c.velocity=util.clamp(c.velocity,.05,1)
  c.mod=util.clamp(c.mod,0,1)
  return c
end
local function impact(b,velocity,c)
  if #notes==0 or not player then return end
  local progressing=params:get('progression')==2
  local steps=progressing and params:get('octaves')*3+1 or #notes
  local index=util.clamp(math.floor((b.x-3)/121*steps)+1,1,steps)
  local pitch=notes[index]
  if progressing then
    local degree=progression[chord]
    local chord_step=(index-1)%3*2
    pitch=notes[1]+12*math.floor((index-1)/3)+chord_interval(degree,chord_step)
  end
  local note=util.clamp(pitch+math.floor(root_shift+.5),0,127)
  if not trigger_cap:allow(util.time()) then return end

  if active[note] then release_note(note) end
  local held=held_notes()
  if #held>=params:get('max_voices') then release_note(steal_note(held)) end

  local capabilities=player:describe()
  local pan
  for _,target in ipairs(capabilities.note_mod_targets or {}) do
    if target=='pan' then
      pan=util.clamp((b.x-3)/121*2-1,-1,1)*params:get('pan_width')
      break
    end
  end
  local strength=util.clamp(velocity*c.velocity,.03,1)
  player:note_on(note,strength,pan and {pan=pan} or nil)
  active[note]={player=player,until_time=elapsed+c.length,started=elapsed,velocity=strength}
  flashes[#flashes+1]={x=b.x,time=elapsed}
end
local function tick()
  local dt=1/120
  elapsed=elapsed+dt
  if not ready then return end
  local chosen=params:lookup_param('voice'):get_player()
  if chosen~=player then
    stop_notes()
    if player then player:modulate(0) end
    player=chosen
  end
  for n,v in pairs(active) do
    if elapsed>=v.until_time then
      release_note(n)
    end
  end
  if running then
    harmony(dt)
    local c=config(dt)
    player:modulate(c.mod)
    world:step(dt,c,function(b,v) impact(b,v,c) end)
  end
  for i=#flashes,1,-1 do if elapsed-flashes[i].time>.3 then table.remove(flashes,i) end end
end
function init()
  nb:init()
  params:add_separator('bounce_main','bounce')
  nb:add_param('voice','nb voice')
  params:add_number('max_voices','voices',1,16,8,function(p)
    return p:get()==1 and '1 (mono)' or tostring(p:get())
  end)
  params:add_option('voice_stealing','voice stealing',stealing_modes,1)
  params:set_action('max_voices',trim_voices)
  control('density','density',0,8,1.5,'lin','balls/s')
  control('gravity','gravity',10,200,48)
  params:add_number('lifespan','lifespan (bounces)',1,32,6)
  control('bounce','bounce elasticity',.2,.98,.78)
  control('drift','sideways drift',0,40,13)
  control('length','note length',.02,4,.25,'exp','s')
  params:add_number('root','lowest note',0,96,48,function(p) return music.note_num_to_name(p:get(),true) end)
  local scales={};local minor=1
  for i,v in ipairs(music.SCALES) do scales[i]=v.name;if v.name:lower()=='natural minor' then minor=i end end
  params:add_option('scale','scale',scales,minor)
  params:add_number('octaves','octaves',1,5,3)
  for _,id in ipairs({'root','scale','octaves'}) do params:set_action(id,rebuild_scale) end
  params:set_action('scale',function() rebuild_scale();generate_progression() end)
  params:add_separator('bounce_harmony','harmony')
  params:add_option('progression','random progression',{'off','on'},1)
  params:set_action('progression',function(value)
    if value==2 then generate_progression() else root_shift=0 end
  end)
  params:add_number('chord_beats','beats per chord',1,32,4)
  params:add_trigger('reroll_progression','reroll progression')
  params:set_action('reroll_progression',generate_progression)
  params:add_separator('bounce_motion','note motion')
  control('pan_width','pan width',0,1,0)
  for i=1,4 do
    local p='lfo_'..i..'_'
    params:add_group('lfo_'..i,'lfo '..i,4)
    params:add_option(p..'target','target',targets,1)
    params:add_option(p..'shape','shape',shapes,1)
    control(p..'rate','rate',.01,10,.1,'exp','Hz')
    control(p..'depth','depth',0,1,0)
  end
  nb:add_player_params()
  -- Targeted initial state only: don't bang every installed voice's trigger/gate.
  params:set('voice_hidden_string',note_players['emplait 1'] and 'emplait 1' or 'none')
  if note_players['emplait 1'] then
    params:set('plaits_model_1',12) -- string
    params:set('plaits_style_1',1) -- percussive
    params:set('plaits_decay_1',.45)
    params:set('plaits_amp_1',.18)
  end
  rebuild_scale()
  generate_progression()
  timer=metro.init(function() for _=1,4 do tick() end;redraw() end,1/30,-1)
  timer:start()
  boot=clock.run(function()
    clock.sleep(1.2) -- nb initializes its selector after one second.
    ready=true;running=true
    player=params:lookup_param('voice'):get_player()
    world:drop(config(0))
    if params:string('voice')=='none' then message('select an nb voice') end
  end)
  params.action_read=function()
    stop_notes();world:clear();rebuild_scale();generate_progression()
  end
end
function enc(n,d)
  local id=n==1 and (held and 'length' or 'lifespan') or n==2 and 'density' or 'gravity'
  params:delta(id,d)
  message((id=='lifespan' and 'life ' or id..' ')..params:string(id))
end
function key(n,z)
  if n==1 then held=z==1;return end
  if z==0 or not ready then return end
  if n==2 then
    running=not running
    if not running then stop_notes();if player then player:modulate(0) end end
  elseif n==3 then
    if held then world:clear();stop_notes();message('clear') else world:drop(config(0)) end
  end
end
function redraw()
  screen.clear()
  for _,b in ipairs(world.balls) do
    screen.level(12);screen.circle(b.x,b.y,2);screen.stroke()
    screen.level(15);screen.pixel(b.x,b.y);screen.fill()
  end
  screen.level(3);screen.move(2,54);screen.line(125,54);screen.stroke()
  for _,f in ipairs(flashes) do
    local a=1-(elapsed-f.time)/.3;local r=2+10*(1-a)
    screen.level(math.floor(a*15));screen.move(math.max(2,f.x-r),54);screen.line(math.min(125,f.x+r),54);screen.stroke()
  end
  screen.font_face(1);screen.font_size(8);screen.level(7)
  screen.move(2,63);screen.text(harmony_label())
  screen.level(12)
  if running then screen.move(121,58);screen.line(121,63);screen.line(125,60);screen.close();screen.fill()
  else screen.rect(120,58,2,5);screen.fill();screen.rect(124,58,2,5);screen.fill() end
  if elapsed<overlay_until then
    screen.level(0);screen.rect(0,0,128,12);screen.fill()
    screen.level(15);screen.move(64,9);screen.text_center(overlay)
  end
  screen.update()
end
function cleanup()
  if timer then timer:stop() end
  if boot then clock.cancel(boot) end
  stop_notes()
  if player then player:modulate(0) end
  if nb then nb:stop_all() end
end
