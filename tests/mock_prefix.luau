-- A minimal simulated Roblox client; exercises the complete standalone file.
local allSignals, allInstances, checks = {}, {}, 0
math.randomseed(145)
local function check(value, message)
	checks += 1
	assert(value, message)
end
local function signal()
	local s = { handlers = {} }; table.insert(allSignals, s)
	function s:Connect(fn)
		local c = { Connected = true, fn = fn, Function = fn }
		function c:Disconnect() self.Connected = false end
		table.insert(self.handlers, c)
		return c
	end
	function s:Fire(...)
		for _, c in ipairs(table.clone(self.handlers)) do if c.Connected then c.fn(...) end end
	end
	return s
end
local function enum()
	return setmetatable({}, { __index = function(t, key) local v = enum(); rawset(t, key, v); return v end })
end
local Enum = enum()
Enum.RenderPriority.Camera.Value = 200
local V2 = {}
V2.__index = function(t, k) if k == "Magnitude" then return math.sqrt(t.X*t.X+t.Y*t.Y) end; return V2[k] end
V2.__add = function(a,b) return setmetatable({ X=a.X+b.X, Y=a.Y+b.Y }, V2) end
V2.__sub = function(a,b) return setmetatable({ X=a.X-b.X, Y=a.Y-b.Y }, V2) end
V2.__eq = function(a,b) return a.X == b.X and a.Y == b.Y end
V2.__mul = function(a,b) return setmetatable({X=a.X*b,Y=a.Y*b},V2) end
local Vector2 = { new = function(x,y) return setmetatable({ X=x or 0, Y=y or 0 }, V2) end }
local V3 = {}
V3.__index = function(t,k)
	if k == "Magnitude" then return math.sqrt(t.X*t.X+t.Y*t.Y+t.Z*t.Z) end
	if k == "Unit" then local m=math.sqrt(t.X*t.X+t.Y*t.Y+t.Z*t.Z); return setmetatable({X=t.X/m,Y=t.Y/m,Z=t.Z/m},V3) end
	return V3[k]
end
V3.__sub = function(a,b) return setmetatable({ X=a.X-b.X,Y=a.Y-b.Y,Z=a.Z-b.Z }, V3) end
V3.__add = function(a,b) return setmetatable({ X=a.X+b.X,Y=a.Y+b.Y,Z=a.Z+b.Z }, V3) end
V3.__mul = function(a,b) if type(a)=="number" then a,b=b,a end; return setmetatable({ X=a.X*b,Y=a.Y*b,Z=a.Z*b }, V3) end
function V3:Dot(b) return self.X*b.X+self.Y*b.Y+self.Z*b.Z end
local Vector3 = { new = function(x,y,z) return setmetatable({ X=x or 0,Y=y or 0,Z=z or 0 }, V3) end }
local RaycastParams={new=function() return {} end}
local UDim = { new = function(scale, offset) return { Scale=scale or 0, Offset=offset or 0 } end }
local UDim2 = {
	new = function(xs,xo,ys,yo) return { X=UDim.new(xs,xo), Y=UDim.new(ys,yo) } end,
	fromOffset = function(x,y) return { X=UDim.new(0,x), Y=UDim.new(0,y) } end,
	fromScale = function(x,y) return { X=UDim.new(x,0), Y=UDim.new(y,0) } end,
}
local Color3 = { new=function(...) return {...} end, fromRGB=function(...) return {...} end, fromHSV=function(...) return {...} end }
local ColorSequence = { new=function(...) return {...} end }
local TweenInfo = { new=function(...) return {...} end }
local pending = {}
local spawned={}
local task = { delay = function(_,fn) table.insert(pending,fn) end,spawn=function(fn) table.insert(spawned,fn) end }
local function flushSpawn() local jobs=spawned; spawned={}; for _,fn in ipairs(jobs) do fn() end end
local function flush() local calls=pending; pending={}; for _,fn in ipairs(calls) do fn() end end
local lookCalls, lastLook, lastAlpha = 0,nil,nil
local CFrame = {}
function CFrame.lookAt(position, point)
	local frame={Position=position,Point=point,LookVector=(point-position).Unit}
	function frame:Lerp(goal) return CFrame.lookAt(goal.Position,goal.Point) end
	return frame
end
local cameraFrame = {Position=Vector3.new(),LookVector=Vector3.new(0,0,-1)}
function cameraFrame:Lerp(goal, alpha)
	self.LookVector=(goal.Point-goal.Position).Unit
	lookCalls+=1; lastLook=goal.Point; lastAlpha=alpha
	return self
end
local camera = { FieldOfView=70, ViewportSize=Vector2.new(1280,720), CFrame=cameraFrame }

function camera:WorldToViewportPoint(p) return Vector3.new(640+p.X*10,360-p.Y*10,20),true end
local instanceMethods = {}
local guiClasses = { Frame=true, CanvasGroup=true, TextLabel=true, TextButton=true, TextBox=true, ScrollingFrame=true, ImageLabel=true, ImageButton=true }
local function isA(node, class)
	return node.ClassName == class or class == "Instance" or (class == "GuiObject" and guiClasses[node.ClassName])
		or (class == "GuiButton" and (node.ClassName == "TextButton" or node.ClassName == "ImageButton"))
		or (class == "BasePart" and (node.ClassName == "Part" or node.ClassName == "MeshPart"))
end
local mt = {}
mt.__index = function(t, key)
	if instanceMethods[key] then return instanceMethods[key] end
	local props=rawget(t,"_props")
	if key == "AbsoluteSize" then
		if props.ClassName == "ScreenGui" or props.ClassName == "Workspace" or not props.Parent then return camera.ViewportSize end
		local parentSize = props.Parent.AbsoluteSize
		local size=props.Size or UDim2.fromOffset(100,40)
		local scale=1
		for _, child in ipairs(rawget(t,"_children")) do if child.ClassName == "UIScale" then scale=child.Scale end end
		return Vector2.new((parentSize.X*size.X.Scale+size.X.Offset)*scale,(parentSize.Y*size.Y.Scale+size.Y.Offset)*scale)
	end
	if key == "AbsolutePosition" then
		local pos=props.Position or UDim2.new()
		local ps=props.Parent and props.Parent.AbsoluteSize or camera.ViewportSize
		return Vector2.new(ps.X*pos.X.Scale+pos.X.Offset,ps.Y*pos.Y.Scale+pos.Y.Offset)
	end
	return props[key]
end
mt.__newindex = function(t, key, value)
	local props = rawget(t,"_props")
	if key == "Parent" then
		if props.Parent then
			local children=rawget(props.Parent,"_children")
			local index=table.find(children,t); if index then table.remove(children,index) end
		end
		if value then table.insert(rawget(value,"_children"),t) end
	end
	props[key]=value
	local event = rawget(t,"_changes")[key]; if event then event:Fire() end
end
local Instance = {}
function Instance.new(class)
	local obj=setmetatable({ _props={ClassName=class,Name=class,Visible=true,Enabled=true,Text="",Health=100,MaxHealth=100,AssemblyLinearVelocity=Vector3.new(),
		IgnoreGuiInset=false,DisplayOrder=0,GroupTransparency=0,AbsoluteRotation=0,CanCollide=true},
		_children={},_attributes={},_changes={},_destroyed=false },mt)
	for _,name in ipairs({"Destroying","MouseEnter","MouseLeave","Activated","MouseButton1Click","MouseButton1Down","MouseButton1Up","InputBegan","AnimationPlayed"}) do obj[name]=signal() end
	table.insert(allInstances,obj); return obj
end
function instanceMethods:IsA(class) return isA(self,class) end
function instanceMethods:GetChildren() return table.clone(rawget(self,"_children")) end
function instanceMethods:GetDescendants()
	local result={}
	local function visit(parent)
		for _,child in ipairs(parent:GetChildren()) do table.insert(result,child); visit(child) end
	end
	visit(self); return result
end
function instanceMethods:GetAttributes() return table.clone(rawget(self,"_attributes")) end
function instanceMethods:SetAttribute(key,value) rawget(self,"_attributes")[key]=value end
function instanceMethods:GetAttribute(key) return rawget(self,"_attributes")[key] end
function instanceMethods:FindFirstChild(name)
	for _,child in ipairs(self:GetChildren()) do if child.Name==name then return child end end
end
function instanceMethods:FindFirstChildOfClass(class)
	for _,child in ipairs(self:GetChildren()) do if child:IsA(class) then return child end end
end
function instanceMethods:FindFirstAncestorWhichIsA(class)
	local parent=self.Parent
	while parent do if parent:IsA(class) then return parent end; parent=parent.Parent end
end
function instanceMethods:GetFullName() return self.Parent and self.Parent:GetFullName().."."..self.Name or self.Name end
function instanceMethods:GetPropertyChangedSignal(name)
	local changes=rawget(self,"_changes"); if not changes[name] then changes[name]=signal() end; return changes[name]
end
function instanceMethods:WaitForChild(name) return assert(self:FindFirstChild(name)) end
function instanceMethods:IsDescendantOf(parent)
	local ancestor=self.Parent
	while ancestor do if ancestor==parent then return true end; ancestor=ancestor.Parent end
	return false
end
local guiHits={}
function instanceMethods:GetGuiObjectsAtPosition() return guiHits[self] or {} end
function instanceMethods:ReleaseFocus() end
function instanceMethods:Move(direction) self.LastMove=direction end
function instanceMethods:MoveTo(position) self.LastMoveTo=position; self.Moves=(self.Moves or 0)+1 end
function instanceMethods:ChangeState(state) self.LastState=state end
function instanceMethods:Activate() self.Activations=(self.Activations or 0)+1 end
function instanceMethods:GetBoundingBox()
	return { PointToWorldSpace=function(_,p) return p end },Vector3.new(4,6,2)
end
local loadedTracks={}
function instanceMethods:LoadAnimation(animation)
	local track=Instance.new("AnimationTrack"); track.Animation=animation; track.Name=animation.Name
	track.Length=0.24; track.IsPlaying=false; track.Animator=self
	table.insert(loadedTracks,track); return track
end
function instanceMethods:Play() self.IsPlaying=true; if self.Animator then self.Animator.AnimationPlayed:Fire(self) end end
function instanceMethods:Stop() self.IsPlaying=false end
function instanceMethods:Destroy()
	if rawget(self,"_destroyed") then return end
	rawset(self,"_destroyed",true); self.Destroying:Fire()
	for _,child in ipairs(self:GetChildren()) do child:Destroy() end
	for _,v in pairs(rawget(self,"_props")) do if type(v)=="table" and v.handlers then for _,c in ipairs(v.handlers) do c:Disconnect() end end end
	for _,v in pairs(rawget(self,"_changes")) do for _,c in ipairs(v.handlers) do c:Disconnect() end end
	self.Parent=nil
end
local function node(class,name,parent,value)
	local obj=Instance.new(class); obj.Name=name; obj.Parent=parent
	if value~=nil then obj.Value=value end
	return obj
end
local workspace = node("Workspace","Workspace"); workspace.Gravity=196.2; workspace.CurrentCamera=camera
local wall=false
local forcedHit
local ground=true
function workspace:Raycast(origin,direction) if direction and direction.Y < -2 then return ground and {Instance=workspace} or nil end; return forcedHit and {Instance=forcedHit} or wall and {Instance=workspace} or nil end
local blockcasts=0
function workspace:Blockcast() blockcasts+=1; return wall and {Instance=workspace} or nil end
local replicated=node("Folder","ReplicatedStorage")
local players = node("Players","Players"); players.PlayerRemoving=signal()
local people={}
function players:GetPlayers() return table.clone(people) end
local function player(name,id)
	local p=node("Player",name,players); p.UserId=id; p.DisplayName=name.." Display"
	table.insert(people,p); return p
end
local localPlayer=player("Owner",1); players.LocalPlayer=localPlayer
local other=player("Other",2)
local function character(plr)
	local model=node("Model",plr.Name,workspace)
	local head=node("Part","Head",model); head.Position=Vector3.new(0,4,0)
	local root=node("Part","HumanoidRootPart",model); root.Position=Vector3.new()
	root.AssemblyLinearVelocity=Vector3.new(); root.Anchored=false
	root.Size=Vector3.new(2,2,1)
	root.CFrame=CFrame.lookAt(root.Position,root.Position+Vector3.new(0,0,-1))
	model.PrimaryPart=root
	local h=node("Humanoid","Humanoid",model); h.JumpPower=50; h.JumpHeight=7.2; h.UseJumpPower=true; h.MoveDirection=Vector3.new(); h.WalkSpeed=16; h.AutoRotate=true; h.PlatformStand=false; h.FloorMaterial=Enum.Material.Concrete
	node("Animator","Animator",h); plr.Character=model
	return model
end
character(localPlayer); character(other)
node("PlayerGui","PlayerGui",localPlayer)
local coreGui=node("CoreGui","CoreGui")
local run={ Heartbeat=signal(), RenderStepped=signal(),PreSimulation=signal() }
local renderBindings={}
function run:BindToRenderStep(name, priority, fn) renderBindings[name]={priority=priority,fn=fn} end
function run:UnbindFromRenderStep(name) renderBindings[name]=nil end
local function renderAim(dt) for _,binding in pairs(renderBindings) do binding.fn(dt or 1/60) end end
local focusedBox
local input={ InputBegan=signal(),InputChanged=signal(),InputEnded=signal(),WindowFocusReleased=signal(),WindowFocused=signal(),JumpRequest=signal(),GetFocusedTextBox=function() return focusedBox end }
local tweens={ Create=function(_,item,_,props)
	return { Cancel=function() end, Play=function() for k,v in pairs(props) do item[k]=v end end }
end }
local sentKeys, sentMouse, sentTouches, rejectKeys = {},{},{},false
local vim={SendKeyEvent=function(_,down,key)
	if rejectKeys then error("virtual input unavailable") end
	table.insert(sentKeys,{down=down,key=key})
end,SendMouseButtonEvent=function(_,x,y,button,down) table.insert(sentMouse,{down=down,x=x,y=y}) end,
SendTouchEvent=function(_,id,state,x,y) table.insert(sentTouches,{id=id,state=state,x=x,y=y}) end}
local lighting=node("Lighting","Lighting")
lighting.Brightness=1; lighting.Ambient="Ambient"; lighting.OutdoorAmbient="Outdoor"; lighting.GlobalShadows=true; lighting.FogStart=15; lighting.FogEnd=400
local atmosphere=node("Atmosphere","Atmosphere",lighting); atmosphere.Density=0.4; atmosphere.Haze=2
local teleports,lastTeleport=0,nil
local teleportService={TeleportToPlaceInstance=function(_,place,job,plr) teleports+=1; lastTeleport=job end,Teleport=function() teleports+=1 end}
local pathSuccess=true
local pathPoints={}
local pathfinder={CreatePath=function()
	return {ComputeAsync=function(self,origin,goal) self.Origin=origin; self.Goal=goal; self.Status=pathSuccess and Enum.PathStatus.Success or Enum.PathStatus.NoPath end,GetWaypoints=function(self) if #pathPoints>0 then return pathPoints end; return {{Position=self.Origin},{Position=self.Goal}} end}
end}
local nativeActions={}
local services={ContextActionService={GetAllBoundActionInfo=function() return nativeActions end},GuiService={GetGuiInset=function() return Vector2.new(0,36) end},PathfindingService=pathfinder,TeleportService=teleportService,Lighting=lighting,Players=players,RunService=run,UserInputService=input,TweenService=tweens,CoreGui=coreGui,VirtualInputManager=vim,ReplicatedStorage=replicated}
local game={PlaceId=123456,JobId="current-server",GetService=function(_,name) return assert(services[name],name) end}
local env={}
local warnings={}
local warn=function(value) table.insert(warnings,value) end
local getgenv=function() return env end
local clipboard
local setclipboard=function(value) clipboard=value end
local firesignal=function(s,...) s:Fire(...) end
local getconnections=function(s)
	local connected={}; for _,c in ipairs(s.handlers) do if c.Connected then table.insert(connected,c) end end
	return connected
end

workspace.DescendantAdded=signal()
localPlayer.CharacterAdded=signal()
localPlayer.Idled=signal()
localPlayer.CameraMaxZoomDistance=24; localPlayer.CameraMinZoomDistance=0.5
input.TouchEnabled=true
local idleClicks=0
services.VirtualUser={CaptureController=function() end,ClickButton2=function() idleClicks+=1 end}
local originalInstanceNew=Instance.new
Instance.new=function(class)
 local item=originalInstanceNew(class)
 item.FocusLost=signal()
 return item
end
