-- Rift Hub / Survive The Hulk / v1.1 / standalone Luau.
-- No external UI library. All effects, movement overrides and connections unload cleanly.
local Players=game:GetService("Players")
local Run=game:GetService("RunService")
local Input=game:GetService("UserInputService")
local Tween=game:GetService("TweenService")
local Lighting=game:GetService("Lighting")
local LocalPlayer=Players.LocalPlayer
local env=type(getgenv)=="function" and getgenv() or _G
if type(env.RiftHulkHub)=="table" and type(env.RiftHulkHub.Unload)=="function" then pcall(env.RiftHulkHub.Unload) end
local API={Game="Survive The Hulk",Version="1.1",PlaceId=109166720609444,UniverseId=10742937135}
local C={Base=Color3.fromRGB(13,17,15),Panel=Color3.fromRGB(21,27,23),Hover=Color3.fromRGB(29,39,31),
	Line=Color3.fromRGB(48,65,51),Green=Color3.fromRGB(120,230,76),DarkGreen=Color3.fromRGB(40,65,36),
	Text=Color3.fromRGB(232,240,228),Sub=Color3.fromRGB(144,163,145),Black=Color3.fromRGB(4,5,6),White=Color3.fromRGB(209,218,208),
	Red=Color3.fromRGB(246,109,84)}
local Config={ESP=true,Hulk=true,Players=true,Chams=true,Names=true,ThroughWalls=true,
	Opacity=0.48,Range=1500,Warnings=true,HulkOverride="",Noclip=false,Speed=false,WalkSpeed=28,
	JumpBoost=false,JumpPower=70,InfiniteJump=false,Fullbright=false,WideView=false,FOV=85,ReduceMotion=false,
	Fly=false,FlySpeed=40,Sprint=false,SprintSpeed=38,AutoHop=false,AntiIdle=false,NoFog=false,
	ExtendedZoom=false,ZoomDistance=128,LowHealthAlert=true}
API.Config=Config
local alive=true
local connections,rows,candidates,collisions={}, {}, {}, {}
local uiOrders=setmetatable({},{__mode="k"})
local movement,lightSnapshot,cameraSnapshot=nil,nil,nil
local flight,zoomSnapshot=nil,nil
local atmosphereSnapshots={}
local held,keys={},{}
local windowFocused=true
local flightControls,controlsAttempted=nil,false
local syncTouch=function() end
local function clearHeld() table.clear(held); table.clear(keys) end
local function holding(action)
	for _,value in pairs(held) do if value==action then return true end end
	return false
end
local function canControl() return windowFocused and not Input:GetFocusedTextBox() end
local gui,panel,bubble,fitScale,warning,healthStat,hulkStat,playerStat,statusLabel,headerStatus,sidebarFrame,contentFrame
local toggles,sliders={},{}
local lastMessage,lastMessageAt="Ready",0
local selectedTab="overview"
local minimized=false
local function connect(event,fn)
	local connection=event:Connect(fn); table.insert(connections,connection); return connection
end
local function make(class,props,parent)
	local node=Instance.new(class)
	for name,value in pairs(props) do node[name]=value end
	if parent and node:IsA("GuiObject") and props.LayoutOrder==nil then uiOrders[parent]=(uiOrders[parent] or 0)+1; node.LayoutOrder=uiOrders[parent] end
	node.Parent=parent; return node
end
local function round(node,radius) return make("UICorner",{CornerRadius=UDim.new(0,radius or 10)},node) end
local function animate(node,props,duration)
	if Config.ReduceMotion then for key,value in pairs(props) do node[key]=value end; return end
	local tween=Tween:Create(node,TweenInfo.new(duration or 0.16,Enum.EasingStyle.Quad,Enum.EasingDirection.Out),props)
	tween:Play()
end
local function message(text)
	lastMessage=text; lastMessageAt=os.clock()
	if statusLabel then statusLabel.Text=text end
end
local Brand=(function()
-- Exact user-supplied Rift logo. ImageRect selects the R emblem for compact controls.
-- One asynchronous download per script; failed image loading leaves the text fallback usable.
return function(url)
	local M={}
	local asset,started=nil,false
	local targets=setmetatable({},{__mode="k"})
	local function paint(image,fallback)
		if not image.Parent or not asset then return end
		image.Image=asset; image.Visible=true
		if fallback and fallback.Parent then fallback.Text="" end
	end
	function M.Apply(image,fallback)
		image.Name="RiftLogo"; image.ImageRectOffset=Vector2.new(380,295); image.ImageRectSize=Vector2.new(510,525)
		image.ImageColor3=Color3.new(1,1,1); image.ScaleType=Enum.ScaleType.Fit; image.Visible=false
		targets[image]=fallback or false
		if asset then paint(image,fallback); return end
		if started then return end; started=true
		task.spawn(function()
			local ok,result=pcall(function()
				local customAsset=type(getcustomasset)=="function" and getcustomasset or type(getsynasset)=="function" and getsynasset
				assert(customAsset and type(writefile)=="function" and type(isfile)=="function","Custom images unavailable")
				local path="RiftHub/rift-logo-92145dc6000c.jpg"
				if type(isfolder)=="function" and type(makefolder)=="function" and not isfolder("RiftHub") then makefolder("RiftHub") end
				if not isfile(path) then
					local bytes=game:HttpGet(url)
					assert(type(bytes)=="string" and bytes:sub(1,3)==string.char(255,216,255),"Invalid Rift logo")
					writefile(path,bytes)
				end
				local content=customAsset(path)
				assert(type(content)=="string" and content~="","Image registration failed")
				return content
			end)
			if not ok then return end
			asset=result
			for image,fallback in pairs(targets) do paint(image,fallback) end
			table.clear(targets)
		end)
	end
	return M
end
end)()("https://raw.githubusercontent.com/copperpoppercms-sys/Rift-Hub-Survive-The-Hulk/main/assets/rift_logo.jpg")
local function normalize(value) return type(value)=="string" and value:lower():gsub("[^%w]","") or "" end
local function hulkWord(value)
	if type(value)~="string" then return false end
	local word=normalize(value)
	return word=="hulk" or word=="thehulk" or word=="hulkrig" or word=="hulknpc" or word=="npchulk" or word=="incrediblehulk" or
		value:lower():match("%f[%a]hulk%f[%A]")~=nil
end
local function body(plr)
	local model=plr and plr.Character
	local entities=workspace:FindFirstChild("Entities")
	if (not model or not model.Parent) and entities and plr then model=entities:FindFirstChild(plr.Name) end
	local hum=model and model:FindFirstChildOfClass("Humanoid")
	local root=model and (model:FindFirstChild("HumanoidRootPart") or model.PrimaryPart)
	if model and model.Parent and hum and hum.Health>0 and root and root:IsA("BasePart") then return model,hum,root end
end
local function ownerOf(model)
	for _,plr in ipairs(Players:GetPlayers()) do
		if plr.Character==model then return plr end
		if model.Parent and model.Parent.Name=="Entities" and plr.Name==model.Name then return plr end
	end
end
local roleFields={"Role","Team","Character","CharacterType","MorphCurrent","SelectedCharacter","MonsterType"}
local function isHulk(model,plr)
	if plr and Config.HulkOverride~="" and plr.Name:lower()==Config.HulkOverride:lower() then return true,"Username override" end
	if plr and plr.Team and hulkWord(plr.Team.Name) then return true,"Player.Team" end
	for _,node in ipairs({model,plr or false}) do
		if node then
			if node:GetAttribute("IsHulk")==true then return true,node.Name..".@IsHulk" end
			for _,field in ipairs(roleFields) do
				if hulkWord(node:GetAttribute(field)) then return true,node.Name..".@"..field end
				local value=node:FindFirstChild(field)
				if value and value:IsA("StringValue") and hulkWord(value.Value) then return true,value:GetFullName() end
			end
		end
	end
	-- Player usernames and green cosmetics are never treated as proof of a Hulk role.
	if not plr and hulkWord(model.Name) then return true,"NPC model name" end
	return false,"No Hulk role exposed"
end
API.IsHulk=isHulk
local function destroyRow(row)
	for _,node in ipairs({row.Highlight,row.Tag}) do pcall(function() node:Destroy() end) end
end
local function newRow(model)
	local highlight=make("Highlight",{Name="RiftHulk_Chams",Enabled=false,OutlineTransparency=0.12},model)
	highlight.Adornee=model
	local tag=make("BillboardGui",{Name="RiftHulk_Tag",Size=UDim2.fromOffset(220,22),AlwaysOnTop=true,Enabled=false,
		StudsOffsetWorldSpace=Vector3.new(0,1.7,0),MaxDistance=Config.Range},model)
	local name=make("TextLabel",{Name="Username",Size=UDim2.fromScale(1,1),BackgroundTransparency=1,Font=Enum.Font.GothamBold,
		TextSize=13,TextColor3=C.Text,TextStrokeTransparency=0.3,Text=""},tag)
	return {Highlight=highlight,Tag=tag,Name=name}
end
local function restoreFlight()
	if not flight then return end
	local old=flight; flight=nil
	for _,key in ipairs({"Velocity","Orientation","Attachment"}) do
		if old[key] then pcall(function() old[key]:Destroy() end) end
	end
	pcall(function()
		old.Root.AssemblyLinearVelocity=Vector3.new()
		old.Hum.AutoRotate=old.AutoRotate; old.Hum.PlatformStand=old.PlatformStand
		if old.Hum.Health>0 and not old.PlatformStand then old.Hum:ChangeState(Enum.HumanoidStateType.GettingUp) end
	end)
end
local function applyFlight(dt)
	local _,hum,root=body(LocalPlayer)
	if not Config.Fly or not root or root.Anchored or not workspace.CurrentCamera then restoreFlight(); return end
	if flight and (flight.Hum~=hum or flight.Root~=root) then restoreFlight() end
	if not flight then
		-- Store ownership before creating constraints so startup failures can be cleaned up.
		flight={Hum=hum,Root=root,AutoRotate=hum.AutoRotate,PlatformStand=hum.PlatformStand,Current=Vector3.new()}
		flight.Attachment=make("Attachment",{Name="RiftHulk_FlightAttachment"},root)
		flight.Velocity=make("LinearVelocity",{Name="RiftHulk_FlightVelocity",Attachment0=flight.Attachment,
			VelocityConstraintMode=Enum.VelocityConstraintMode.Vector,RelativeTo=Enum.ActuatorRelativeTo.World,
			ForceLimitsEnabled=false,VectorVelocity=Vector3.new()},root)
		flight.Orientation=make("AlignOrientation",{Name="RiftHulk_FlightOrientation",Attachment0=flight.Attachment,
			Mode=Enum.OrientationAlignmentMode.OneAttachment,MaxTorque=math.huge,MaxAngularVelocity=math.huge,Responsiveness=18},root)
	end
	hum.AutoRotate=false; hum.PlatformStand=true
	local camera=workspace.CurrentCamera
	local look=camera.CFrame.LookVector
	local forward=Vector3.new(look.X,0,look.Z)
	forward=forward.Magnitude>0.01 and forward.Unit or Vector3.new(0,0,-1)
	local right=Vector3.new(-forward.Z,0,forward.X)
	local direction=Vector3.new()
	if canControl() then
		direction=Vector3.new(hum.MoveDirection.X,0,hum.MoveDirection.Z)
		if direction.Magnitude<0.01 then
			if not controlsAttempted then
				controlsAttempted=true
				pcall(function()
					local scripts=LocalPlayer:FindFirstChild("PlayerScripts")
					local module=scripts and scripts:FindFirstChild("PlayerModule")
					if module then flightControls=require(module):GetControls() end
				end)
			end
			local move
			if flightControls then pcall(function() move=flightControls:GetMoveVector() end) end
			if move then direction=right*move.X+forward*(-move.Z)
			else
				direction=right*((keys[Enum.KeyCode.D] and 1 or 0)-(keys[Enum.KeyCode.A] and 1 or 0))+
					forward*((keys[Enum.KeyCode.W] and 1 or 0)-(keys[Enum.KeyCode.S] and 1 or 0))
			end
		end
		local vertical=(holding("up") or keys[Enum.KeyCode.Space]) and 1 or 0
		vertical-=((holding("down") or keys[Enum.KeyCode.LeftControl] or keys[Enum.KeyCode.RightControl]) and 1 or 0)
		direction+=Vector3.new(0,vertical+look.Y*direction:Dot(forward),0)
	end
	if direction.Magnitude>1 then direction=direction.Unit end
	local desired=direction*Config.FlySpeed
	local alpha=1-math.exp(-12*math.clamp(tonumber(dt) or 1/60,0,0.1))
	flight.Current=canControl() and (flight.Current+(desired-flight.Current)*alpha) or Vector3.new()
	flight.Velocity.VectorVelocity=flight.Current
	flight.Orientation.CFrame=CFrame.lookAt(root.Position,root.Position+forward)
end
local function restoreCollisions()
	for part,value in pairs(collisions) do pcall(function() part.CanCollide=value end) end
	table.clear(collisions)
end
local function restoreMovement()
	if movement then
		pcall(function()
			if movement.SpeedApplied then movement.Hum.WalkSpeed=movement.WalkSpeed end
			if movement.JumpApplied then movement.Hum.JumpPower=movement.JumpPower; movement.Hum.UseJumpPower=movement.UseJumpPower end
		end)
		movement=nil
	end
end
local function restoreLight()
	if not lightSnapshot then return end
	for key,value in pairs(lightSnapshot) do pcall(function() Lighting[key]=value end) end
	lightSnapshot=nil
end
local function restoreAtmospheres()
	for node,values in pairs(atmosphereSnapshots) do pcall(function() node.Density=values.Density; node.Haze=values.Haze end) end
	table.clear(atmosphereSnapshots)
end
local function restoreZoom()
	if zoomSnapshot~=nil then LocalPlayer.CameraMaxZoomDistance=zoomSnapshot; zoomSnapshot=nil end
end
local function restoreCamera()
	if cameraSnapshot then pcall(function() cameraSnapshot.Camera.FieldOfView=cameraSnapshot.FOV end); cameraSnapshot=nil end
end
local function applyMovement()
	local _,hum=body(LocalPlayer)
	if not hum then restoreMovement(); return end
	if movement and movement.Hum~=hum then restoreMovement() end
	if not movement then movement={Hum=hum,WalkSpeed=hum.WalkSpeed,JumpPower=hum.JumpPower,UseJumpPower=hum.UseJumpPower} end
	local sprint=Config.Sprint and canControl() and (holding("sprint") or keys[Enum.KeyCode.LeftShift])
	local wanted=sprint and Config.SprintSpeed or Config.Speed and Config.WalkSpeed or nil
	if wanted then
		if movement.SpeedApplied and hum.WalkSpeed~=movement.SpeedApplied then movement.WalkSpeed=hum.WalkSpeed end
		hum.WalkSpeed=wanted; movement.SpeedApplied=wanted
	elseif movement.SpeedApplied then hum.WalkSpeed=movement.WalkSpeed; movement.SpeedApplied=nil
	else movement.WalkSpeed=hum.WalkSpeed end
	if Config.JumpBoost then
		if not movement.JumpApplied then movement.JumpPower=hum.JumpPower; movement.UseJumpPower=hum.UseJumpPower end
		hum.UseJumpPower=true; hum.JumpPower=Config.JumpPower; movement.JumpApplied=true
	elseif movement.JumpApplied then hum.JumpPower=movement.JumpPower; hum.UseJumpPower=movement.UseJumpPower; movement.JumpApplied=nil end
end
function API.Physics(dt)
	if not alive then return end
	applyFlight(dt)
	if not Config.Noclip then if next(collisions) then restoreCollisions() end; return end
	local model=body(LocalPlayer)
	if not model then restoreCollisions(); return end
	for _,part in ipairs(model:GetDescendants()) do
		if part:IsA("BasePart") then
			if collisions[part]==nil then collisions[part]=part.CanCollide end
			part.CanCollide=false
		end
	end
end
local function applyVisibility()
	if Config.Fullbright or Config.NoFog then
		if not lightSnapshot then lightSnapshot={Brightness=Lighting.Brightness,Ambient=Lighting.Ambient,
			OutdoorAmbient=Lighting.OutdoorAmbient,GlobalShadows=Lighting.GlobalShadows,FogStart=Lighting.FogStart,FogEnd=Lighting.FogEnd} end
		for key,value in pairs(lightSnapshot) do Lighting[key]=value end
		if Config.Fullbright then
			Lighting.Brightness=2.4; Lighting.Ambient=Color3.fromRGB(160,170,160); Lighting.OutdoorAmbient=Color3.fromRGB(160,170,160)
			Lighting.GlobalShadows=false; Lighting.FogEnd=100000
		end
		if Config.NoFog then Lighting.FogStart=100000; Lighting.FogEnd=1000000 end
	else restoreLight() end
	if Config.NoFog then
		for _,node in ipairs(Lighting:GetChildren()) do
			if node:IsA("Atmosphere") then
				if not atmosphereSnapshots[node] then atmosphereSnapshots[node]={Density=node.Density,Haze=node.Haze} end
				node.Density=0; node.Haze=0
			end
		end
	else restoreAtmospheres() end
	if Config.ExtendedZoom then
		if zoomSnapshot==nil then zoomSnapshot=LocalPlayer.CameraMaxZoomDistance end
		LocalPlayer.CameraMaxZoomDistance=math.max(LocalPlayer.CameraMinZoomDistance,Config.ZoomDistance)
	else restoreZoom() end
	local camera=workspace.CurrentCamera
	if cameraSnapshot and (cameraSnapshot.Camera~=camera or not Config.WideView) then restoreCamera() end
	if Config.WideView and camera and camera.CameraType~=Enum.CameraType.Scriptable then
		if not cameraSnapshot then cameraSnapshot={Camera=camera,FOV=camera.FieldOfView} end
		camera.FieldOfView=Config.FOV
	end
end
local function addHumanoid(node)
	if node:IsA("Humanoid") and node.Parent and node.Parent:IsA("Model") then candidates[node.Parent]=true end
end
function API.Refresh()
	if not alive then return end
	for _,node in ipairs(workspace:GetDescendants()) do addHumanoid(node) end
	for _,plr in ipairs(Players:GetPlayers()) do if plr.Character then candidates[plr.Character]=true end end
end
local nearest,nearestDistance,hulkCount=nil,nil,0
local function updateESP()
	local own,ownHum,ownRoot=body(LocalPlayer)
	nearest,nearestDistance,hulkCount=nil,nil,0
	for _,plr in ipairs(Players:GetPlayers()) do if plr.Character then candidates[plr.Character]=true end end
	for model in pairs(candidates) do
		local hum=model.Parent and model:FindFirstChildOfClass("Humanoid")
		local root=model.Parent and (model:FindFirstChild("HumanoidRootPart") or model.PrimaryPart)
		local plr=ownerOf(model)
		local hulk,source=isHulk(model,plr)
		local valid=model.Parent and hum and hum.Health>0 and root and root:IsA("BasePart") and model~=own and (plr or hulk)
		if valid then
			local distance=ownRoot and (root.Position-ownRoot.Position).Magnitude or 0
			if hulk then
				hulkCount+=1
				if ownRoot and (not nearestDistance or distance<nearestDistance) then nearest,nearestDistance=model,distance end
			end
			local row=rows[model]
			if not row then row=newRow(model); rows[model]=row end
			row.Hulk=hulk; row.Source=source
			local enabled=Config.ESP and distance<=Config.Range and (hulk and Config.Hulk or not hulk and Config.Players)
			local color=hulk and C.Green or C.Black
			row.Highlight.Enabled=enabled and Config.Chams
			row.Highlight.DepthMode=Config.ThroughWalls and Enum.HighlightDepthMode.AlwaysOnTop or Enum.HighlightDepthMode.Occluded
			row.Highlight.FillColor=color; row.Highlight.OutlineColor=hulk and C.Green or C.White
			row.Highlight.FillTransparency=1-Config.Opacity
			row.Tag.Adornee=model:FindFirstChild("Head") or root
			row.Tag.Enabled=enabled and Config.Names
			row.Tag.AlwaysOnTop=Config.ThroughWalls; row.Tag.MaxDistance=Config.Range
			row.Name.Visible=Config.Names; row.Name.Text=plr and "@"..plr.Name or model.Name
			row.Name.TextColor3=hulk and C.Green or C.Text

		elseif rows[model] then destroyRow(rows[model]); rows[model]=nil end
		if not model.Parent then candidates[model]=nil end
	end
	API.NearestHulk=nearest; API.HulkDistance=nearestDistance; API.HulkCount=hulkCount
	if healthStat then healthStat.Text=ownHum and tostring(math.floor(ownHum.Health)).." HP" or "RESPAWNING" end
	if playerStat then playerStat.Text=tostring(#Players:GetPlayers()) end
	if hulkStat then hulkStat.Text=nearestDistance and tostring(math.floor(nearestDistance)).." studs" or "Not detected" end
	if headerStatus then headerStatus.Text=hulkCount>0 and "HULK SIGNAL DETECTED" or "MONITORING FACILITY" end
	if warning then
		local selfHulk=own and isHulk(own,LocalPlayer)
		warning.Visible=Config.Warnings and nearestDistance~=nil and nearestDistance<=100 and not selfHulk
		warning.Text=nearestDistance and string.format("HULK NEARBY  ·  %d studs",math.floor(nearestDistance)) or ""
		warning.TextColor3=nearestDistance and nearestDistance<35 and C.Red or C.Green
		if Config.LowHealthAlert and ownHum and ownHum.Health/ math.max(1,ownHum.MaxHealth)<=0.25 then
			warning.Visible=true; warning.Text="LOW HEALTH  ·  FIND COVER"; warning.TextColor3=C.Red
		end
	end
end
local function syncControls()
	for _,paint in ipairs(toggles) do paint() end
	for _,paint in ipairs(sliders) do paint() end
	syncTouch()
end
function API.Set(key,value)
	if not alive then return false,"Hub unloaded" end
	if Config[key]==nil then return false,"Unknown option" end
	if type(Config[key])~=type(value) then return false,"Wrong value type" end
	local bounds={WalkSpeed={16,80},JumpPower={45,120},FOV={60,110},Range={100,2500},Opacity={0,1},FlySpeed={10,100},SprintSpeed={16,80},ZoomDistance={16,200}}
	if bounds[key] then
		if value~=value or math.abs(value)==math.huge then return false,"Invalid number" end
		value=math.clamp(value,bounds[key][1],bounds[key][2])
	end
	if key=="HulkOverride" then value=value:match("^%s*@?(.-)%s*$") or "" end
	Config[key]=value
	if key=="Noclip" and not value then restoreCollisions() end
	if key=="Fly" and not value then restoreFlight(); clearHeld() end
	if key=="Sprint" and not value then clearHeld() end
	applyMovement(); applyVisibility(); updateESP(); syncControls()
	return true
end
function API.Reset()
	if not alive then return end
	for _,key in ipairs({"ESP","Fly","Sprint","Speed","JumpBoost","InfiniteJump","Noclip","AutoHop","AntiIdle",
		"Fullbright","NoFog","WideView","ExtendedZoom","Warnings","LowHealthAlert"}) do Config[key]=false end
	clearHeld(); restoreFlight(); restoreCollisions(); restoreMovement(); restoreLight(); restoreAtmospheres(); restoreCamera(); restoreZoom()
	updateESP(); syncControls(); message("All features off — saved values restored")
end
function API.Report()
	local lines={"Rift Hub / Survive The Hulk / "..API.Version,"Place: "..tostring(game.PlaceId),"Universe: "..tostring(game.GameId),
		"Confirmed Hulk models: "..hulkCount,"Hulk override: "..Config.HulkOverride}
	for _,plr in ipairs(Players:GetPlayers()) do
		local model=plr.Character; local hulk,source=false,"No character"
		if model then hulk,source=isHulk(model,plr) end
		table.insert(lines,"@"..plr.Name.." | Hulk="..tostring(hulk==true).." | source="..tostring(source).." | team="..tostring(plr.Team and plr.Team.Name))
		for _,node in ipairs({plr,model or false}) do if node then
			for key,value in pairs(node:GetAttributes()) do
				if type(value)=="string" or type(value)=="boolean" or type(value)=="number" then table.insert(lines,node.Name..".@"..key.." = "..tostring(value):sub(1,160)) end
			end
		end end
	end
	return table.concat(lines,"\n")
end
function API.Unload()
	if not alive then return end; alive=false
	for _,connection in ipairs(connections) do connection:Disconnect() end; table.clear(connections)
	clearHeld(); restoreFlight(); restoreCollisions(); restoreMovement(); restoreLight(); restoreAtmospheres(); restoreCamera(); restoreZoom()
	for _,row in pairs(rows) do destroyRow(row) end; table.clear(rows); table.clear(candidates)
	if gui then gui:Destroy() end
	if env.RiftHulkHub==API then env.RiftHulkHub=nil end
end
local function label(parent,text,size,color,pos,dimensions,bold)
	return make("TextLabel",{Text=text,TextSize=size,TextColor3=color or C.Text,Font=bold and Enum.Font.GothamBold or Enum.Font.Gotham,
		TextXAlignment=Enum.TextXAlignment.Left,BackgroundTransparency=1,Position=pos or UDim2.new(),Size=dimensions or UDim2.new(1,0,0,20)},parent)
end
local function hover(button)
	local scale=make("UIScale",{Scale=1},button)
	connect(button.MouseEnter,function() animate(scale,{Scale=1.025},0.12) end)
	connect(button.MouseLeave,function() animate(scale,{Scale=1},0.16) end)
	connect(button.InputBegan,function(input)
		if input.UserInputType==Enum.UserInputType.MouseButton1 or input.UserInputType==Enum.UserInputType.Touch then
			animate(scale,{Scale=0.97},0.08); task.delay(0.1,function() if alive and button.Parent then animate(scale,{Scale=1},0.14) end end)
		end
	end)
end
local function section(parent,title,description)
	local box=make("Frame",{Size=UDim2.new(1,0,0,0),AutomaticSize=Enum.AutomaticSize.Y,BackgroundColor3=C.Panel,BorderSizePixel=0},parent)
	round(box,10); make("UIStroke",{Color=C.Line,Transparency=0.35},box)
	make("UIPadding",{PaddingLeft=UDim.new(0,14),PaddingRight=UDim.new(0,14),PaddingTop=UDim.new(0,12),PaddingBottom=UDim.new(0,12)},box)
	make("UIListLayout",{SortOrder=Enum.SortOrder.LayoutOrder,Padding=UDim.new(0,8)},box)
	label(box,title,13,C.Text,nil,UDim2.new(1,0,0,20),true)
	if description then local note=label(box,description,11,C.Sub,nil,UDim2.new(1,0,0,0)); note.TextWrapped=true; note.AutomaticSize=Enum.AutomaticSize.Y end
	return box
end
local function toggle(parent,key,title,description)
	local row=make("TextButton",{Name=key,Size=UDim2.new(1,0,0,description and 59 or 34),Text="",AutoButtonColor=false,
		BackgroundTransparency=1,BorderSizePixel=0},parent)
	label(row,title,12,C.Text,UDim2.fromOffset(0,3),UDim2.new(1,-60,0,20),true)
	if description then label(row,description,10,C.Sub,UDim2.fromOffset(0,25),UDim2.new(1,-58,0,28)).TextWrapped=true end
	local track=make("Frame",{AnchorPoint=Vector2.new(1,0.5),Position=UDim2.new(1,0,0.5,0),Size=UDim2.fromOffset(36,20),BackgroundColor3=C.Line,BorderSizePixel=0},row); round(track,12)
	local knob=make("Frame",{Position=UDim2.fromOffset(3,3),Size=UDim2.fromOffset(14,14),BackgroundColor3=C.Sub,BorderSizePixel=0},track); round(knob,8)
	local previous
	local function paint()
		if previous==Config[key] then return end; previous=Config[key]
		animate(track,{BackgroundColor3=previous and C.DarkGreen or C.Line})
		animate(knob,{Position=previous and UDim2.fromOffset(19,3) or UDim2.fromOffset(3,3),BackgroundColor3=previous and C.Green or C.Sub})
	end
	table.insert(toggles,paint); paint(); hover(row)
	connect(row.Activated,function() API.Set(key,not Config[key]) end)
end
local activeSlider
local function slider(parent,key,title,minimum,maximum,suffix)
	local row=make("Frame",{Name=key,Size=UDim2.new(1,0,0,48),BackgroundTransparency=1},parent)
	label(row,title,12,C.Text,nil,UDim2.new(1,-65,0,20),true)
	local value=label(row,"",11,C.Green,UDim2.new(1,-65,0,0),UDim2.fromOffset(65,20),true); value.TextXAlignment=Enum.TextXAlignment.Right
	local hit=make("TextButton",{Position=UDim2.fromOffset(0,22),Size=UDim2.new(1,0,0,24),BackgroundTransparency=1,Text="",AutoButtonColor=false},row)
	local track=make("Frame",{Position=UDim2.fromOffset(0,9),Size=UDim2.new(1,0,0,4),BackgroundColor3=C.Line,BorderSizePixel=0},hit); round(track,3)
	local fill=make("Frame",{Size=UDim2.fromScale(0,1),BackgroundColor3=C.Green,BorderSizePixel=0},track); round(fill,3)
	local knob=make("Frame",{AnchorPoint=Vector2.new(0.5,0.5),Position=UDim2.fromScale(0,0.5),Size=UDim2.fromOffset(10,10),BackgroundColor3=C.Text,BorderSizePixel=0},track); round(knob,6)
	local function paint()
		local fraction=(Config[key]-minimum)/(maximum-minimum)
		fill.Size=UDim2.fromScale(fraction,1); knob.Position=UDim2.fromScale(fraction,0.5)
		value.Text=key=="Opacity" and string.format("%d%%",math.floor(Config[key]*100+0.5)) or string.format("%d%s",Config[key],suffix or "")
	end
	local function update(x)
		if track.AbsoluteSize.X<=0 then return end
		local alpha=math.clamp((x-track.AbsolutePosition.X)/track.AbsoluteSize.X,0,1)
		local number=minimum+(maximum-minimum)*alpha
		API.Set(key,key=="Opacity" and number or math.floor(number+0.5))
	end
	table.insert(sliders,paint); paint()
	connect(hit.InputBegan,function(input)
		if input.UserInputType==Enum.UserInputType.MouseButton1 or input.UserInputType==Enum.UserInputType.Touch then activeSlider={Input=input,Update=update}; update(input.Position.X) end
	end)
end
local function button(parent,title,caption,fn)
	local item=make("TextButton",{Size=UDim2.new(1,0,0,38),Text=title,Font=Enum.Font.GothamBold,TextSize=12,TextColor3=C.Text,
		BackgroundColor3=C.Hover,AutoButtonColor=false,BorderSizePixel=0},parent); round(item,8); hover(item)
	connect(item.Activated,function() local ok,err=pcall(fn); if not ok then message(tostring(err)) end end)
	if caption then label(parent,caption,10,C.Sub,nil,UDim2.new(1,0,0,26)).TextWrapped=true end
	return item
end
local pages,tabPaint={},{}
local function selectTab(id)
	selectedTab=id
	for name,page in pairs(pages) do page.Visible=name==id end
	for _,paint in ipairs(tabPaint) do paint() end
end
local function build()
	gui=make("ScreenGui",{Name="RiftSurviveTheHulk",ResetOnSpawn=false,IgnoreGuiInset=true,DisplayOrder=950,ZIndexBehavior=Enum.ZIndexBehavior.Sibling},nil)
	local ok=pcall(function() gui.Parent=type(gethui)=="function" and gethui() or game:GetService("CoreGui") end)
	if not ok or not gui.Parent then gui.Parent=LocalPlayer:WaitForChild("PlayerGui") end
	API.Gui=gui
	panel=make("Frame",{Name="Window",AnchorPoint=Vector2.new(0.5,0.5),Position=UDim2.fromScale(0.5,0.5),Size=UDim2.fromOffset(660,460),BackgroundTransparency=1},gui)
	fitScale=make("UIScale",{Scale=1},panel)
	local surface=make("CanvasGroup",{Size=UDim2.fromScale(1,1),BackgroundColor3=C.Base,BorderSizePixel=0,GroupTransparency=1},panel); round(surface,14)
	make("UIStroke",{Color=C.Line,Thickness=1},surface)
	local opening=make("UIScale",{Scale=0.96},surface)
	make("Frame",{Position=UDim2.fromOffset(16,0),Size=UDim2.new(1,-32,0,2),BackgroundColor3=C.Green,BackgroundTransparency=0.16,BorderSizePixel=0},surface)
	local top=make("Frame",{Name="DragHandle",Active=true,Size=UDim2.new(1,0,0,60),BackgroundTransparency=1},surface)
	local mark=make("Frame",{Position=UDim2.fromOffset(16,14),Size=UDim2.fromOffset(34,34),BackgroundColor3=C.DarkGreen,BorderSizePixel=0},top); round(mark,9)
	local logoFallback=label(mark,"R",23,C.Green,UDim2.fromOffset(8,2),UDim2.fromOffset(25,30),true)
	local logoImage=make("ImageLabel",{Position=UDim2.fromOffset(4,3),Size=UDim2.fromOffset(26,27),BackgroundTransparency=1},mark)
	Brand.Apply(logoImage,logoFallback)
	label(top,"RIFT HUB",14,C.Text,UDim2.fromOffset(61,11),UDim2.new(1,-165,0,23),true)
	headerStatus=label(top,"MONITORING FACILITY",9,C.Sub,UDim2.fromOffset(62,35),UDim2.new(1,-165,0,14),true)
	local close=make("TextButton",{Name="Close",Position=UDim2.new(1,-43,0,16),Size=UDim2.fromOffset(28,28),Text="×",TextSize=21,
		Font=Enum.Font.Gotham,TextColor3=C.Sub,BackgroundColor3=C.Panel,AutoButtonColor=false,BorderSizePixel=0},top); round(close,8); hover(close)
	local minimize=make("TextButton",{Name="Minimize",Position=UDim2.new(1,-78,0,16),Size=UDim2.fromOffset(28,28),Text="−",TextSize=20,
		Font=Enum.Font.Gotham,TextColor3=C.Sub,BackgroundColor3=C.Panel,AutoButtonColor=false,BorderSizePixel=0},top); round(minimize,8); hover(minimize)
	local side=make("Frame",{Position=UDim2.fromOffset(0,60),Size=UDim2.new(0,145,1,-60),BackgroundColor3=C.Panel,BorderSizePixel=0},surface)
	sidebarFrame=side
	label(side,"SURVIVE THE HULK",9,C.Green,UDim2.fromOffset(14,14),UDim2.new(1,-20,0,18),true)
	label(side,"CONTAINMENT\nDIVISION",9,C.Sub,UDim2.new(0,14,1,-63),UDim2.new(1,-20,0,38),true)
	local content=make("Frame",{Position=UDim2.fromOffset(145,60),Size=UDim2.new(1,-145,1,-88),BackgroundTransparency=1,ClipsDescendants=true},surface)
	contentFrame=content
	for i,entry in ipairs({{"overview","Overview"},{"visuals","Visuals"},{"movement","Movement"},{"utility","Utility"}}) do
		local id,title=entry[1],entry[2]
		local tab=make("TextButton",{Name=id,Position=UDim2.fromOffset(10,47+(i-1)*43),Size=UDim2.new(1,-20,0,35),Text="  "..title,
			Font=Enum.Font.GothamMedium,TextSize=12,TextXAlignment=Enum.TextXAlignment.Left,TextColor3=C.Sub,
			AutoButtonColor=false,BackgroundColor3=C.DarkGreen,BackgroundTransparency=1,BorderSizePixel=0},side); round(tab,8); hover(tab)
		table.insert(tabPaint,function() animate(tab,{BackgroundTransparency=selectedTab==id and 0 or 1,TextColor3=selectedTab==id and C.Green or C.Sub}) end)
		connect(tab.Activated,function() selectTab(id) end)
		local page=make("ScrollingFrame",{Name=id,Size=UDim2.fromScale(1,1),BackgroundTransparency=1,BorderSizePixel=0,ScrollBarThickness=3,
			ScrollBarImageColor3=C.DarkGreen,CanvasSize=UDim2.new(),AutomaticCanvasSize=Enum.AutomaticSize.Y,Visible=false},content)
		make("UIPadding",{PaddingLeft=UDim.new(0,16),PaddingRight=UDim.new(0,16),PaddingTop=UDim.new(0,14),PaddingBottom=UDim.new(0,16)},page)
		make("UIListLayout",{SortOrder=Enum.SortOrder.LayoutOrder,Padding=UDim.new(0,12)},page)
		label(page,title,21,C.Text,nil,UDim2.new(1,0,0,32),true); pages[id]=page
	end
	local overview=section(pages.overview,"Facility watch","Track the Hulk, keep your bearings, and choose your movement tools.")
	local function stat(title)
		local row=make("Frame",{Size=UDim2.new(1,0,0,32),BackgroundTransparency=1},overview)
		label(row,title,11,C.Sub,nil,UDim2.new(0.55,0,1,0))
		local value=label(row,"—",15,C.Green,UDim2.fromScale(0.55,0),UDim2.fromScale(0.45,1),true); value.TextXAlignment=Enum.TextXAlignment.Right; return value
	end
	healthStat=stat("YOUR HEALTH"); hulkStat=stat("NEAREST HULK"); playerStat=stat("PLAYERS")
	local guide=section(pages.overview,"Read the room","Green = confirmed Hulk. Black = other players, with a pale outline for visibility.")
	local guideText=label(guide,"Visuals start on. Movement changes start off.\nIf Hulk is not detected, use the username override under Visuals.",11,C.Sub,nil,UDim2.new(1,0,0,0))
	guideText.TextWrapped=true; guideText.AutomaticSize=Enum.AutomaticSize.Y
	local visual=section(pages.visuals,"Entity overlay")
	for _,entry in ipairs({{"ESP","Enable ESP"},{"Hulk","Show Hulk"},{"Players","Show other players"},{"Chams","Character highlights"},{"Names","Usernames"},{"ThroughWalls","See through walls"}}) do toggle(visual,entry[1],entry[2]) end
	slider(visual,"Opacity","Highlight fill",0,1)
	slider(visual,"Range","Maximum distance",100,2500," st")
	local identity=section(pages.visuals,"Hulk identity","If the game hides its role data, enter the exact Hulk username. Leave blank for automatic detection.")
	local override=make("TextBox",{Name="HulkOverride",Size=UDim2.new(1,0,0,34),BackgroundColor3=C.Base,TextColor3=C.Text,PlaceholderColor3=C.Sub,
		PlaceholderText="@username (optional)",Text="",ClearTextOnFocus=false,Font=Enum.Font.Gotham,TextSize=12,BorderSizePixel=0},identity); round(override,7)
	connect(override.FocusLost,function() API.Set("HulkOverride",override.Text); override.Text=Config.HulkOverride end)
	local flightBox=section(pages.movement,"Flight","Move with the joystick or WASD. Space / Ctrl: up / down. Minimize the hub for touch flight buttons.")
	toggle(flightBox,"Fly","Fly"); slider(flightBox,"FlySpeed","Flight speed",10,100)
	local move=section(pages.movement,"Movement power","Use modest values first. The game can enforce movement limits.")
	toggle(move,"Sprint","Hold to sprint","Hold LeftShift, or minimize for the touch sprint button.")
	slider(move,"SprintSpeed","Sprint speed",16,80)
	toggle(move,"Speed","Speed boost"); slider(move,"WalkSpeed","Walk speed",16,80)
	toggle(move,"JumpBoost","Jump boost"); slider(move,"JumpPower","Jump power",45,120)
	toggle(move,"InfiniteJump","Infinite jump","Jump again while in the air.")
	toggle(move,"AutoHop","Auto hop","Jump while moving on the ground.")
	toggle(move,"Noclip","Noclip","Pass through parts; watch for floor gaps.")
	local visibility=section(pages.utility,"Visibility & alerts")
	toggle(visibility,"Warnings","Nearby Hulk warning")
	toggle(visibility,"LowHealthAlert","Low-health warning")
	toggle(visibility,"Fullbright","Fullbright")
	toggle(visibility,"NoFog","Clear fog & haze")
	toggle(visibility,"ExtendedZoom","Extended camera zoom"); slider(visibility,"ZoomDistance","Maximum zoom",16,200," st")
	toggle(visibility,"WideView","Custom field of view"); slider(visibility,"FOV","Field of view",60,110,"°")
	toggle(visibility,"ReduceMotion","Reduce UI motion")
	local tools=section(pages.utility,"Session tools")
	toggle(tools,"AntiIdle","Anti-idle","Sends a brief input when Roblox marks you idle.")
	button(tools,"Restore all changes","Turns every feature off and restores saved values. Keeps this UI open.",API.Reset)
	button(tools,"Refresh entity scan",nil,function() API.Refresh(); updateESP(); message("Entity scan refreshed") end)
	button(tools,"Copy Hulk detection report","Use this if the Hulk stays black or is missing.",function()
		local report=API.Report(); print(report)
		if type(setclipboard)=="function" and pcall(setclipboard,report) then message("Report copied — paste it into the chat") else message("Report printed in console; clipboard unavailable") end
	end)
	button(tools,"Rejoin this server",nil,function()
		local teleport=game:GetService("TeleportService")
		if game.JobId~="" then teleport:TeleportToPlaceInstance(game.PlaceId,game.JobId,LocalPlayer) else teleport:Teleport(game.PlaceId,LocalPlayer) end
	end)
	button(tools,"Unload Rift Hub","Restores this script’s movement, lighting and collision changes.",API.Unload)
	statusLabel=label(surface,"Ready",10,C.Sub,UDim2.new(0,160,1,-24),UDim2.new(1,-175,0,18))
	warning=make("TextLabel",{Name="HulkWarning",AnchorPoint=Vector2.new(0.5,1),Position=UDim2.new(0.5,0,1,-26),Size=UDim2.fromOffset(270,32),
		BackgroundColor3=C.Base,BackgroundTransparency=0.12,BorderSizePixel=0,TextColor3=C.Green,Font=Enum.Font.GothamBold,TextSize=12,Text="",Visible=false},gui); round(warning,9)
	bubble=make("TextButton",{Name="Restore",AnchorPoint=Vector2.new(),Position=UDim2.fromOffset(18,150),Size=UDim2.fromOffset(48,48),Text="R",Font=Enum.Font.GothamBold,
		TextSize=24,TextColor3=C.Green,BackgroundColor3=C.Base,BorderSizePixel=0,AutoButtonColor=false,Visible=false},gui); round(bubble,13); make("UIStroke",{Color=C.Green,Transparency=0.45},bubble); hover(bubble)
	local restoreLogo=make("ImageLabel",{Position=UDim2.fromOffset(8,7),Size=UDim2.fromOffset(32,33),BackgroundTransparency=1},bubble)
	Brand.Apply(restoreLogo,bubble)
	local touchPad=make("Frame",{Name="TouchFlight",AnchorPoint=Vector2.new(1,0.5),Position=UDim2.new(1,-20,0.45,0),
		Size=UDim2.fromOffset(58,124),BackgroundTransparency=1,Visible=false},gui)
	local function holdButton(parent,name,text,position,action)
		local item=make("TextButton",{Name=name,Position=position,Size=UDim2.fromOffset(58,56),Text=text,Font=Enum.Font.GothamBold,
			TextSize=11,TextColor3=C.Green,BackgroundColor3=C.Base,BackgroundTransparency=0.12,AutoButtonColor=false,BorderSizePixel=0},parent)
		round(item,12); make("UIStroke",{Color=C.Line},item); hover(item)
		connect(item.InputBegan,function(input)
			if minimized and canControl() and (input.UserInputType==Enum.UserInputType.Touch or input.UserInputType==Enum.UserInputType.MouseButton1) then held[input]=action end
		end)
		return item
	end
	holdButton(touchPad,"FlyUp","UP",UDim2.new(),"up")
	holdButton(touchPad,"FlyDown","DOWN",UDim2.fromOffset(0,68),"down")
	local sprintButton=holdButton(gui,"HoldSprint","SPRINT",UDim2.new(0,20,0.45,0),"sprint")
	syncTouch=function()
		touchPad.Visible=minimized and Input.TouchEnabled==true and Config.Fly
		sprintButton.Visible=minimized and Input.TouchEnabled==true and Config.Sprint and not Config.Fly
	end
	syncTouch()
	local drag,lastDragAt=nil,-10
	local function startDrag(handle,target)
		connect(handle.InputBegan,function(input)
			if input.UserInputType==Enum.UserInputType.MouseButton1 or input.UserInputType==Enum.UserInputType.Touch then drag={Input=input,Start=input.Position,Origin=target.Position,Target=target,Moved=false} end
		end)
	end
	startDrag(top,panel); startDrag(bubble,bubble)
	connect(Input.InputChanged,function(input)
		if activeSlider and (input==activeSlider.Input or input.UserInputType==Enum.UserInputType.MouseMovement and activeSlider.Input.UserInputType==Enum.UserInputType.MouseButton1) then activeSlider.Update(input.Position.X) end
		if drag and (input==drag.Input or input.UserInputType==Enum.UserInputType.MouseMovement and drag.Input.UserInputType==Enum.UserInputType.MouseButton1) then
			local delta=input.Position-drag.Start
			if delta.Magnitude>6 then drag.Moved=true end
			local view=workspace.CurrentCamera and workspace.CurrentCamera.ViewportSize
			if view then
				local width,height=drag.Target==panel and panel.Size.X.Offset*fitScale.Scale or 48,drag.Target==panel and panel.Size.Y.Offset*fitScale.Scale or 48
				local anchor=drag.Target.AnchorPoint
				local x=drag.Origin.X.Scale*view.X+drag.Origin.X.Offset+delta.X
				local y=drag.Origin.Y.Scale*view.Y+drag.Origin.Y.Offset+delta.Y
				drag.Target.Position=UDim2.fromOffset(math.clamp(x,8+width*anchor.X,math.max(8+width*anchor.X,view.X-8-width*(1-anchor.X))),math.clamp(y,8+height*anchor.Y,math.max(8+height*anchor.Y,view.Y-8-height*(1-anchor.Y))))
			end
		end
	end)
	connect(Input.InputEnded,function(input)
		held[input]=nil
		if input.KeyCode then keys[input.KeyCode]=nil end
		if input.UserInputType==Enum.UserInputType.MouseButton1 then
			for press in pairs(held) do if press.UserInputType==Enum.UserInputType.MouseButton1 then held[press]=nil end end
		end
		if activeSlider and input==activeSlider.Input then activeSlider=nil end
		if drag and input==drag.Input then if drag.Moved then lastDragAt=os.clock() end; drag=nil end
	end)
	connect(Input.WindowFocusReleased,function() drag=nil; activeSlider=nil; windowFocused=false; clearHeld() end)
	connect(Input.WindowFocused,function() windowFocused=true end)
	local function minimizeTo(value)
		minimized=value; panel.Visible=not value; bubble.Visible=value; clearHeld(); syncTouch()
	end
	connect(minimize.Activated,function() minimizeTo(true) end)
	connect(bubble.Activated,function() if os.clock()-lastDragAt>0.2 then minimizeTo(false) end end)
	connect(close.Activated,API.Unload)
	connect(Input.InputBegan,function(input,processed)
		if not processed and canControl() and input.UserInputType==Enum.UserInputType.Keyboard then keys[input.KeyCode]=true end
		if not processed and not Input:GetFocusedTextBox() and input.KeyCode==Enum.KeyCode.RightShift then minimizeTo(not minimized) end
	end)
	connect(gui.Destroying,API.Unload)
	selectTab("overview")
	animate(surface,{GroupTransparency=0},0.22); animate(opening,{Scale=1},0.28)
end
local age,viewAge,hopAge=0,0,0
local lastView
function API.Step(dt)
	if not alive then return end
	dt=math.clamp(tonumber(dt) or 0,0,0.5); age+=dt; viewAge+=dt; hopAge+=dt
	if Input:GetFocusedTextBox() then clearHeld() end
	if Config.AutoHop and not Config.Fly and canControl() and hopAge>=0.35 then
		local _,hum=body(LocalPlayer)
		if hum and not hum.Sit and not hum.PlatformStand and hum.MoveDirection.Magnitude>0.05 and hum.FloorMaterial~=Enum.Material.Air then
			hum.Jump=true; hopAge=0
		end
	end
	if viewAge>=0.2 then
		viewAge=0
		local camera=workspace.CurrentCamera; local view=camera and camera.ViewportSize
		if view and view~=lastView then
			lastView=view
			local width,height=math.clamp(view.X-20,320,660),math.clamp(view.Y-32,280,460)
			panel.Size=UDim2.fromOffset(width,height)
			fitScale.Scale=math.max(0.1,math.min(1,(view.X-20)/width,(view.Y-32)/height))
			local sideWidth=width<500 and 110 or 145
			sidebarFrame.Size=UDim2.new(0,sideWidth,1,-60)
			contentFrame.Position=UDim2.fromOffset(sideWidth,60); contentFrame.Size=UDim2.new(1,-sideWidth,1,-88)
			statusLabel.Position=UDim2.new(0,sideWidth+15,1,-24); statusLabel.Size=UDim2.new(1,-sideWidth-30,0,18)
			panel.Position=UDim2.fromScale(0.5,0.5)
		end
	end
	if age<0.1 then return end; age=0
	applyMovement(); applyVisibility(); updateESP()
	if os.clock()-lastMessageAt>6 and statusLabel then statusLabel.Text="RIFT / SURVIVE THE HULK  ·  "..API.Version end
end
local built,buildError=pcall(build)
if not built then API.Unload(); error("[Rift Hulk] UI startup: "..tostring(buildError),0) end
env.RiftHulkHub=API
connect(workspace.DescendantAdded,addHumanoid)
connect(LocalPlayer.CharacterAdded,function() clearHeld(); restoreFlight(); restoreCollisions(); restoreMovement() end)
connect(LocalPlayer.Idled,function()
	if alive and Config.AntiIdle then
		local ok,err=pcall(function()
			local virtualUser=game:GetService("VirtualUser")
			virtualUser:CaptureController(); virtualUser:ClickButton2(Vector2.new(0,0))
		end)
		if not ok then message("Anti-idle unavailable: "..tostring(err)) end
	end
end)
connect(Run.PreSimulation,function(dt)
	local ok,err=pcall(API.Physics,dt)
	if not ok then warn("[Rift Hulk] physics: "..tostring(err)); API.Unload() end
end)
connect(Run.Heartbeat,function(dt)
	local ok,err=pcall(API.Step,dt)
	if not ok then warn("[Rift Hulk] "..tostring(err)); API.Unload() end
end)
connect(Input.JumpRequest,function()
	if alive and Config.InfiniteJump and not Config.Fly and canControl() then local _,hum=body(LocalPlayer); if hum then hum:ChangeState(Enum.HumanoidStateType.Jumping) end end
end)
API.Refresh(); API.Step(0.1)
return API
