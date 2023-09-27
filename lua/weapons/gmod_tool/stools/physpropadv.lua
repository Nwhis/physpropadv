
TOOL.Category = "Construction"
TOOL.Name = "#tool.physpropadv.name"

TOOL.ClientConVar[ "gravity" ] = 1
TOOL.ClientConVar[ "material" ] = "metal_bouncy"
TOOL.ClientConVar[ "enabled" ] = 1
TOOL.ClientConVar[ "footsteps" ] = "grass"
TOOL.ClientConVar[ "footsteps_enabled" ] = 1
TOOL.ClientConVar[ "footsteps_mode" ] = 1

TOOL.Information = { { name = "left" }, {name = "right"}, {name = "reload"} }

local footstep_sounds = {}
local footstep_lookup = {}

local function CacheMaterialSnd(name)
	footstep_sounds[name] = {}
	local snd = {}
	snd[1] = sound.GetProperties(name.."Left")
	snd[2] = sound.GetProperties(name.."Right")
	if not snd[1] then -- invalid sound
		footstep_sounds[name] = "invalid"
		return "invalid"
	end
	for k,v in ipairs(snd) do
		if not v then
			snd[k] = {silent = true}
		else
			if isstring(v.sound) then
				snd[k].sound = {v.sound}
			end
		end
	end
	table.Merge(footstep_sounds[name],snd)
	return footstep_sounds[name]
end

local function GetMaterialSnd(mat) -- get footstep sound from physics material (and cache it)
	if footstep_lookup[mat] then return footstep_lookup[mat] end --if we've already cached this sound, return it
	local surfdata = util.GetSurfaceData(util.GetSurfaceIndex(mat))
	if not surfdata then return nil end
	local name = string.sub(surfdata.stepLeftSound,1,-5) --Plastic_Barrel.Step
	footstep_lookup[mat] = name
	CacheMaterialSnd(name)
	return name -- return the sound name
end

if CLIENT then
	local t = "tool.physpropadv."
	language.Add(t.."name","Physical Properties Advanced")
	language.Add(t.."desc","Modifies physical properties and footsteps on props")
	language.Add(t.."left","Apply physical properties")
	language.Add(t.."right","Copy physical properties")
	language.Add(t.."reload","Reset physical properties")
	language.Add(t.."material","Physical Material")
	language.Add(t.."material.fric","Friction")
	language.Add(t.."material.elas","Elasticity")
	language.Add(t.."enable","Apply physical properties")
	language.Add(t.."footsteps","Footstep Override")
	language.Add(t.."gravity","Enable Gravity")
	language.Add(t.."footsteps_enable","Apply footstep sounds")
	language.Add(t.."footsteps_mode","Footsteps Mode")
	language.Add(t.."tooltip.list","Double-click an entry to preview its sounds")
	language.Add(t.."tooltip.combobox",[[Choose Manually: Use the sound that's selected below
Prop Default: Use the prop's original footstep sounds
Same as Physprop: Use the selected physprop's footstep sounds
(or the prop's current physprop, if "Apply physical properties" is disabled)]])
	
	local l = Vector(0, 0, -1)
	hook.Add("PlayerFootstep", "footstep_override", function(ply, pos, foot, snd, vol)
		local p = ply:GetPos()
		local tr = util.TraceEntity({start = p, endpos = p + l, filter = ply}, ply)
		local ent = tr.Entity
		if not ent or not ent:IsValid() then return end
		
		local mat = ent:GetNWString("footstep_override")
		if not mat or mat == "" then return end
		if mat == "_silent" then return true end
		
		local override = footstep_sounds[mat]
		if not override then override = CacheMaterialSnd(mat) end
		if override == "invalid" then return end
		
		local data = override[foot+1]
		if data.silent then return true end
		
		local pitch = data.pitch
		if istable(pitch) then pitch = math.random(pitch[1],pitch[2]) end
		
		ply:EmitSound(table.Random(data.sound), data.level, pitch, vol, CHAN_BODY)
		
		return true
	end)
	
	net.Receive("getdefaultphysprop",function()
		local template = ents.CreateClientProp(net.ReadString())
		local template_mat = template:GetPhysicsObject():GetMaterial()
		template:Remove()
		net.Start("defaultphysprop")
		net.WriteString(template_mat)
		net.SendToServer()
	end)
else
	util.AddNetworkString("getdefaultphysprop")
	util.AddNetworkString("defaultphysprop")
	util.AddNetworkString("updatelists")
	duplicator.RegisterEntityModifier("footstep_override", function(ply, ent, data)
		if not ent or not ent:IsValid() then return end
		ent:SetNWString("footstep_override", data.material)
	end)
end
function TOOL:LeftClick( trace )

	if ( !IsValid( trace.Entity ) ) then return false end
	if ( trace.Entity:IsPlayer() || trace.Entity:IsWorld() ) then return false end

	-- Make sure there's a physics object to manipulate
	if ( SERVER && !util.IsValidPhysicsObject( trace.Entity, trace.PhysicsBone ) ) then return false end

	-- Client can bail out here and assume we're going ahead
	if ( CLIENT ) then return true end

	-- Get the entity/bone from the trace
	local ent = trace.Entity
	local Bone = trace.PhysicsBone

	-- Get client's CVars
	local material = self:GetClientNumber("enabled") == 1
	
	-- Set the properties
	if material then
		material = self:GetClientInfo( "material" )
		local gravity = self:GetClientNumber( "gravity" ) == 1
		construct.SetPhysProp( self:GetOwner(), ent, Bone, nil, { GravityToggle = gravity, Material = material } )
	end
	
	local footsteps = self:GetClientNumber("footsteps_enabled") == 1

	if footsteps then
		footsteps = self:GetClientInfo("footsteps")
		local footsteps_mode = self:GetClientNumber("footsteps_mode")
		if footsteps_mode == 0 then footsteps = "" end
		if footsteps_mode == 1 then
			if not material then material = ent:GetPhysicsObject():GetMaterial() end
			footsteps = GetMaterialSnd(material) end
		ent:SetNWString("footstep_override",footsteps)
		duplicator.StoreEntityModifier(ent, "footstep_override", {material = footsteps})
	end
	

	DoPropSpawnedEffect( ent )

	return true

end

function TOOL:RightClick( trace )
	tr = trace.Entity
	if ( !IsValid( tr ) ) then return false end
	if ( tr:IsPlayer() || tr:IsWorld() ) then return false end

	-- Make sure there's a physics object to manipulate
	if ( SERVER && !util.IsValidPhysicsObject( tr, trace.PhysicsBone ) ) then return false end

	-- Client can bail out here and assume we're going ahead
	if ( CLIENT ) then return true end
	
	local m = tr:GetPhysicsObject():GetMaterial()
	local f = tr:GetNWString("footstep_override")
	if f == "" then --GetMaterialSnd(m) end
		net.Start("getdefaultphysprop")
		net.WriteString(tr:GetModel())
		net.Send(self:GetOwner())
		net.Receive("defaultphysprop",function(_,ply)
			if ply != self:GetOwner() then return end
			f = GetMaterialSnd(net.ReadString()) -- yes, it really is this complicated
			self:GetOwner():ConCommand("physpropadv_footsteps "..f)
		end)
	else self:GetOwner():ConCommand("physpropadv_footsteps "..f) end
	self:GetOwner():ConCommand("physpropadv_material "..m)
	net.Start("updatelists") net.WriteString(m) net.WriteString(f) net.Send(self:GetOwner())
	return true
end
function TOOL:Reload( trace )
	local ent = trace.Entity
	if ( !IsValid( ent ) ) then return false end
	if ( ent:IsPlayer() || ent:IsWorld() ) then return false end

	-- Make sure there's a physics object to manipulate
	local bone = trace.PhysicsBone
	if ( SERVER && !util.IsValidPhysicsObject( ent, bone ) ) then return false end

	-- Client can bail out here and assume we're going ahead
	if ( CLIENT ) then return true end
	net.Start("getdefaultphysprop")
	net.WriteString(ent:GetModel())
	net.Send(self:GetOwner())
	net.Receive("defaultphysprop",function(_,ply)
		if ply != self:GetOwner() then return end
		local material = net.ReadString()
		construct.SetPhysProp( self:GetOwner(), ent, bone, nil, { GravityToggle = true, Material = material } )
	end)
	ent:SetNWString("footstep_override","")
	duplicator.ClearEntityModifier(ent, "footstep_override")
	return true
end
	

local ConVarsDefault = TOOL:BuildConVarList()

local materials_list = {
	{"default","Default"},
	{"solidmetal","Metal Solid"},
	{"metal_box","Metal Box"},
	{"metal","Metal"},
	{"slipperymetal","Metal Slippery"},
	{"metal_bouncy","Metal Bouncy"},
	{"metalgrate","Metal Grate"},
	{"metalvent","Metal Vent"},
	{"metalpanel","Metal Panel"},
	{"dirt","Dirt"},
	{"mud","Mud"},
	{"slipperyslime","Slime Slippery"},
	{"grass","Grass"},
	{"tile","Tile"},
	{"wood","Wood"},
	{"wood_box","Wood Box"},
	{"wood_crate","Wood Crate"},
	{"wood_plank","Wood Plank"},
	{"wood_solid","Wood Solid"},
	{"wood_furniture","Wood Furniture"},
	{"wood_panel","Wood Panel"},
	{"water","Water"},
	{"slime","Slime"},
	{"wade","Water Wade"},
	{"glass","Glass"},
	{"computer","Computer"},
	{"concrete","Concrete"},
	{"rock","Rock"},
	{"boulder","Boulder"},
	{"gravel","Gravel"},
	{"concrete_block","Concrete Block"},
	{"chainlink","Chainlink"},
	{"flesh","Flesh"},
	{"bloodyflesh","Flesh Bloody"},
	{"watermelon","Watermelon"},
	{"snow","Snow"},
	{"ice","Ice"},
	{"carpet","Carpet"},
	{"plaster","Plaster"},
	{"cardboard","Cardboard"},
	{"plastic_barrel","Plastic Barrel"},
	{"plastic_box","Plastic Box"},
	{"plastic","Plastic"},
	{"rubber","Rubber"},
	{"rubbertire","Rubber Tire"},
	{"glassbottle","Glass Bottle"},
	{"pottery","Pottery"},
	{"grenade","Grenade"},
	{"canister","Canister"},
	{"metal_barrel","Metal Barrel"},
	{"roller","Metal Roller"},
	{"popcan","Pop Can"},
	{"paintcan","Paint Can"},
	{"papercup","Paper Cup"},
	{"ceiling_tile","Ceiling Tile"},
	{"weapon","Metal Weapon"},
	{"metalvehicle","Metal Vehicle"},
	{"crowbar","Metal Crowbar"},
	{"gunship","Gunship"},
	{"strider","Strider"},
	{"jalopytire","Jalopy Tire"},
	{"jalopy","Jalopy"},
	{"gmod_ice","Super Ice"},
	{"gmod_bouncy","Super Bouncy"},
	{"phx_tire_normal","Phx Tire Normal"},
	{"phx_explosiveball","Phx Explosive Ball"},
	{"gm_ps_woodentire","Phx Wooden Wheel"},
	{"gm_ps_metaltire","Phx Metal Wheel"},
	{"gm_ps_soccerball","Soccer Ball"},
	{"phx_rubbertire","Phx RubberTire"},
	{"phx_rubbertire2","Phx RubberTire 2"},
	{"default_silent","Silent"},
	{"jeeptire","Jeep Tire"}
}

local footsteps_list = {
	{"dirt.step","Dirt"},
	{"grass.step","Grass"},
	{"gravel.step","Gravel"},
	{"sand.step","Sand"},
	{"snow.step","Snow"},
	{"concrete.step","Concrete"},
	{"tile.step","Tile"},
	{"rubber.step","Rubber"},
	{"cardboard.step","Cardboard"},
	{"ceiling_tile.step","Ceiling Tile"},
	{"drywall.step","Drywall"},
	{"plastic_box.step","Plastic Box"},
	{"plastic_barrel.step","Plastic Barrel"},
	{"wood.step","Wood"},
	{"wood_panel.step","Wood Panel"},
	{"wood_box.step","Wood Box"},
	{"glass.step","Glass"},
	{"glassbottle.step","Glass Bottle"},
	{"solidmetal.step","Metal Solid"},
	{"metal_box.step","Metal Box"},
	{"metalgrate.step","Metal Grate"},
	{"metalvent.step","Metal Vent"},
	{"chainlink.step","Chainlink"},
	{"ladder.step","Ladder"},
	{"flesh.step","Flesh"},
	{"weapon.step","Weapon"},
	{"grenade.step","Grenade"},
	{"slipperyslime.step","Slime"},
	{"water.step","Water"},
	{"wade.step","Water Wade"},
	{"npc_stalker.footstep","Stalker"},
	{"npc_citizen.runfootstep","Concrete Boot"},
	{"_silent","Silent"}
}

for k,v in ipairs(materials_list) do
	local data = util.GetSurfaceData(util.GetSurfaceIndex(v[1]))
	table.insert(v,math.Round(data.friction,4))
	table.insert(v,math.Round(data.elasticity,4))
	--list.Set("AdvPhysMaterials","#physpropadv_mat."..v[1],{physpropadv_material = v[1]})
end
/*
for k,v in ipairs(footsteps_list) do
	list.Set("AdvPhysFootsteps","#physpropadv_foot."..v[1],{physpropadv_footsteps = v[1]})
end*/
local function SortTbl(tbl)
	local newtbl = {}
	for id, str in SortedPairsByMemberValue(tbl,2) do
		if ( !table.HasValue( newtbl, str ) ) then
			table.insert( newtbl, str )
		end
	end
	return newtbl
end

local list_phys
local list_foot
local function FindRow(list,f,col)
	for k,v in ipairs(list:GetLines()) do
		if v:GetValue(col) == f then return v end
	end
end
net.Receive("updatelists",function()
	if not list_phys then return end
	list_phys:ClearSelection()
	list_foot:ClearSelection()
	local sel = FindRow(list_phys,net.ReadString(),4)
	if sel then list_phys:SelectItem(sel) end
	sel = FindRow(list_foot,net.ReadString(),2)
	if sel then list_foot:SelectItem(sel) end
end)

function TOOL.BuildCPanel( CPanel )
	for k,v in ipairs(materials_list) do
		language.Add("physpropadv_mat."..v[1],v[2])
	end
	
	for k,v in ipairs(footsteps_list) do
		language.Add("physpropadv_foot."..v[1],v[2])
	end

	CPanel:AddControl( "ComboBox", { MenuButton = 1, Folder = "physpropadv", Options = { [ "#preset.default" ] = ConVarsDefault }, CVars = table.GetKeys( ConVarsDefault ) } )

	--CPanel:AddControl( "ListBox", { Label = "#tool.physpropadv.material", Options = list.Get( "AdvPhysMaterials" ) } )
	
	CPanel:CheckBox("#tool.physpropadv.enable","physpropadv_enabled")
	
	--CPanel:AddControl( "CheckBox", { Label = "#tool.physpropadv.gravity", Command = "physpropadv_gravity" } )
	CPanel:CheckBox("#tool.physpropadv.gravity","physpropadv_gravity")
	
	--CPanel:Help("#tool.physpropadv.clickhelp")
	
	list_phys = vgui.Create("DListView",CPanel)
	list_phys:SetDataHeight(18)
	list_phys:AddColumn("#tool.physpropadv.material")
	list_phys:AddColumn("#tool.physpropadv.material.fric"):SetMaxWidth(50)
	list_phys:AddColumn("#tool.physpropadv.material.elas"):SetMaxWidth(50)
	list_phys:AddColumn("data"):SetFixedWidth(0)
	local sorted = SortTbl(materials_list)
	for k, mat in ipairs( sorted ) do
		local line = list_phys:AddLine( mat[2],mat[3],mat[4],mat[1] )
		if ( GetConVarString( "physpropadv_material" ) == tostring( mat[1] ) ) then line:SetSelected( true ) end
	end
	list_phys:SetSize(0,300)
	CPanel:AddItem(list_phys)
	list_phys:SetTooltip("#tool.physpropadv.tooltip.list")
	
	list_phys.OnRowSelected = function(panel,rowIndex,row)
		RunConsoleCommand("physpropadv_material",row:GetValue(4))
	end
	list_phys.DoDoubleClick = function(list,index)
		local mat = list:GetLine(index):GetValue(4)
		local data = util.GetSurfaceData(util.GetSurfaceIndex(mat))
		local vol = math.Rand(1,2)
		local snd = vol > 1.5 and data.impactHardSound or data.impactSoftSound
		LocalPlayer():EmitSound(snd,nil,nil,vol*0.1)
	end
	--CPanel:AddControl( "ListBox", { Label = "#tool.physpropadv.footsteps", Options = list.Get( "AdvPhysFootsteps" ) } )
	
	CPanel:CheckBox("#tool.physpropadv.footsteps_enable","physpropadv_footsteps_enabled")
	
	--local combobox = vgui.Create("DComboBox",CPanel)
	local combobox = CPanel:ComboBox("#tool.physpropadv.footsteps_mode","physpropadv_footsteps_mode")
	combobox:SetMinimumSize(nil,25)
	combobox:AddChoice("Prop Default",0)
	combobox:AddChoice("Same as Physprop",1)
	combobox:AddChoice("Choose Manually",2)
	combobox:SetTooltip("#tool.physpropadv.tooltip.combobox")
	--CPanel:AddItem(Label("#tool.physpropadv.footsteps_mode",CPanel),combobox)
	
	list_foot = vgui.Create("DListView",CPanel)
	list_foot:AddColumn("#tool.physpropadv.footsteps")
	list_foot:AddColumn("data"):SetFixedWidth(0)
	sorted = SortTbl(footsteps_list)
	for k, snd in ipairs( sorted ) do
		local line = list_foot:AddLine( snd[2],snd[1] )
		if ( GetConVarString( "physpropadv_footsteps" ) == tostring( snd[1] ) ) then line:SetSelected( true ) end
	end
	list_foot:SetSize(0,200)
	CPanel:AddItem(list_foot)
	list_foot:SetTooltip("#tool.physpropadv.tooltip.list")
	
	list_foot.OnRowSelected = function(panel,rowIndex,row)
		RunConsoleCommand("physpropadv_footsteps",row:GetValue(2))
	end
	list_foot.DoDoubleClick = function(list,index)
		local click = list:GetLine(index):GetValue(2)
		local data = footstep_sounds[click]
		print(data)
		if not data then data = CacheMaterialSnd(click) end
		print(data)
		local snd = data[math.random(1,2)].name
		LocalPlayer():EmitSound(snd)
	end
	
end

/*
list.Set( "PhysicsMaterials", "#physpropadv.metalbouncy", { physprop_material = "metal_bouncy" } )
list.Set( "PhysicsMaterials", "#physpropadv.metal", { physprop_material = "metal" } )
list.Set( "PhysicsMaterials", "#physpropadv.dirt", { physprop_material = "dirt" } )
list.Set( "PhysicsMaterials", "#physpropadv.slime", { physprop_material = "slipperyslime" } )
list.Set( "PhysicsMaterials", "#physpropadv.wood", { physprop_material = "wood" } )
list.Set( "PhysicsMaterials", "#physpropadv.glass", { physprop_material = "glass" } )
list.Set( "PhysicsMaterials", "#physpropadv.concrete", { physprop_material = "concrete_block" } )
list.Set( "PhysicsMaterials", "#physpropadv.ice", { physprop_material = "ice" } )
list.Set( "PhysicsMaterials", "#physpropadv.rubber", { physprop_material = "rubber" } )
list.Set( "PhysicsMaterials", "#physpropadv.paper", { physprop_material = "paper" } )
list.Set( "PhysicsMaterials", "#physpropadv.flesh", { physprop_material = "zombieflesh" } )
list.Set( "PhysicsMaterials", "#physpropadv.superice", { physprop_material = "gmod_ice" } )
list.Set( "PhysicsMaterials", "#physpropadv.superbouncy", { physprop_material = "gmod_bouncy" } )*/


