--[[
    release by vynix
]]

require("common.log")
module("Vortex Amumu", package.seeall, log.setup)

local clock = os.clock
local insert = table.insert

local _SDK = _G.CoreEx
local Console, ObjManager, EventManager, Geometry, Input, Renderer, Enums, Game = _SDK.Console, _SDK.ObjectManager, _SDK.EventManager, _SDK.Geometry, _SDK.Input, _SDK.Renderer, _SDK.Enums, _SDK.Game
local Menu, Orbwalker, Collision, Prediction, HealthPred = _G.Libs.NewMenu, _G.Libs.Orbwalker, _G.Libs.CollisionLib, _G.Libs.Prediction, _G.Libs.HealthPred
local DmgLib, ImmobileLib, Spell = _G.Libs.DamageLib, _G.Libs.ImmobileLib, _G.Libs.Spell
local SpellSlots, SpellStates = Enums.SpellSlots, Enums.SpellStates
local insert, sort = table.insert, table.sort
local Spell = _G.Libs.Spell

local spells = {
    Q = Spell.Skillshot({
         Slot = Enums.SpellSlots.Q,
         Range = 1100,
         Delay = 0.25,
         Speed = 2000,
         Radius = 160,
         Type = "Linear",
         Collision = {Heroes=true, Minions=true, WindWall=true},
    }),
    W = Spell.Active({
         Slot = Enums.SpellSlots.W,
         Range = 300,
    }),
    E = Spell.Active({
         Slot = Enums.SpellSlots.E,
         Range = 350,
    }),
    R = Spell.Active({
         Slot = Enums.SpellSlots.R,
         Range = 550,
         Delay = 0.25,
    }),
}

local TS = _G.Libs.TargetSelector()
local Amumu = {}
local blocklist = {}


function Amumu.LoadMenu()
    Menu.RegisterMenu("VortexAmumu", "Vortex Amumu", function()
        Menu.ColumnLayout("cols", "cols", 2, true, function()
            Menu.ColoredText("Combo", 0xFFA5E5D3, true)
            Menu.Checkbox("Combo.UseQ", "Use Q", true)
            Menu.Slider("Combo.QHC", "Q Hitchance", 0.7, 0, 1, 0.05)
            Menu.Checkbox("Combo.UseW", "Use W", true)
			Menu.Slider("WMana", "Mana Percent for W", 50, 0, 100)
            Menu.Checkbox("Combo.UseE", "Use E", true)
            Menu.Checkbox("Combo.UseR", "Use R", true)
            Menu.Slider("RT", "Min Target R", 2, 1, 5, 1)

            Menu.NextColumn()

            Menu.ColoredText("KillSteal", 0xFFA5E5D3, true)
            Menu.Checkbox("KSQ", "Use Q", true)
            Menu.Checkbox("KSE", "Use E", true)

            Menu.NextColumn()

            Menu.ColoredText("Waveclear", 0xFFA5E5D3, true)
            Menu.Checkbox("Wave.UseQ", "Use Q", false)
			Menu.Slider("Wave.CastQHC", "Q Min. Hit Count", 1, 0, 10, 1)
            Menu.Checkbox("Wave.UseE", "Use E", true)
            
        end)

        Menu.Separator()
        
        Menu.ColoredText("Drawing", 0xFFA5E5D3, true)
        Menu.Checkbox("DQ", "Draw Q Range")
        Menu.ColorPicker("DQC", "Draw Q Color", 0xFF00D29E)
        Menu.Checkbox("DW", "Draw W Range")
        Menu.ColorPicker("DWC", "Draw W Color", 0xFF00D29E)
        Menu.Checkbox("DE", "Draw E Range")
        Menu.ColorPicker("DEC", "Draw E Color", 0xFF00D29E)
        Menu.Checkbox("DR", "Draw R Range")
        Menu.ColorPicker("DRC", "Draw R Color", 0xFF00D29E)
    end)
end

function Amumu.IsEnabledAndReady(spell, mode)
    return Menu.Get(mode .. ".Use"..spell) and spells[spell]:IsReady()
end

local lastTick = 0
local function CanPerformCast()
    local curTime = clock()
    if curTime - lastTick > 0.25 then
        lasTick = curTime

        local gameAvailable = not (Game.IsChatOpen() or Game.IsMinimized())
        return gameAvailable and not (Player.IsDead or Player.IsRecalling) and Orbwalker.CanCast()
    end
end

function ValidMinion(minion)
    return minion and minion.IsTargetable and minion.MaxHealth > 6
end

function CountEnemiesInRange(pos, range, t)
    local res = 0
    for k, v in pairs(t or ObjManager.Get("neutral", "minions")) do
        local hero = v.AsAI
        if hero and hero.IsTargetable and hero:Distance(pos) < range then
            res = res + 1
        end
    end
    return res
end
function CountEnemiesHeroesInRange(pos, range, t)
    local res = 0
    for k, v in pairs(t or ObjManager.Get("enemy", "heroes")) do
        local hero = v.AsAI
        if hero and hero.IsTargetable and hero:Distance(pos) < range then
            res = res + 1
        end
    end
    return res
end

function Amumu.GetTargets(range)
    return {TS:GetTarget(range, true)}
end

function Amumu.Qdmg()
    return(80 + (spells.Q:GetLevel() - 1) * 50) + (0.7 * Player.TotalAP)
end

function Amumu.Edmg()
    return(75 + (spells.E:GetLevel() - 1) * 20) + (0.5 * Player.TotalAP)
end

function Amumu.OnTick()

    local gameTime = Game.GetTime()
    if gameTime < (lastTick + 0.25) then return end
    lastTick = gameTime
	
	if Amumu.KsQ() then return end
	
	if Orbwalker.GetMode() == "Waveclear" then
	
		Amumu.Waveclear()
	end
	
	local ModeToExecute = Amumu[Orbwalker.GetMode()]
    if ModeToExecute then
        ModeToExecute()
    end
end
	
function Amumu.ComboLogic(mode)
	if Amumu.IsEnabledAndReady("Q", mode) then
		local targ = spells.Q:GetTarget()
		if targ then
		local qChance = Menu.Get(mode .. ".QHC")
		if spells.Q:IsReady() and #TS:GetTargets(spells.Q.Range, true) then
			if spells.Q:CastOnHitChance(targ, qChance) then
			return
		end
	end
 end
end
	if Amumu.IsEnabledAndReady("W", mode) then
		for k, wTarget in ipairs(Amumu.GetTargets(spells.W.Range)) do
		if not Player:GetBuff("AuraOfDespair") then
			spells.W:Cast()
			return
		end
	end
end
	local Man = Player.Mana / Player.MaxMana * 100
	local SlM = Menu.Get("WMana")
	if SlM > Man then
	return
	end
	if spells.W:IsReady() and Player:GetBuff("AuraOfDespair") then 
        if CountEnemiesHeroesInRange(Player.Position,spells.W.Range) < 1 then
            spells.W:Cast() return
		end
	end
	if Amumu.IsEnabledAndReady("E", mode) then
        for k, eTarget in ipairs(Amumu.GetTargets(spells.E.Range)) do
            if spells.E:Cast() then
                return
            end
        end
    end
	if Amumu.IsEnabledAndReady("R", mode) then
		if spells.R:IsReady() and #TS:GetTargets(spells.R.Range, true) >= Menu.Get("RT") then
			spells.R:Cast()
			return
		end
	end
end
function Amumu.Combo()  Amumu.ComboLogic("Combo")  end

function Amumu.KsQ()
  if Menu.Get("KSQ") then
	for k, qTarget in ipairs(TS:GetTargets(spells.Q.Range, true)) do
		local qDmg = DmgLib.CalculateMagicalDamage(Player, qTarget, Amumu.Qdmg())
		local ksHealth = spells.Q:GetKillstealHealth(qTarget)
		if qDmg > ksHealth and spells.Q:CastOnHitChance(qTarget, Enums.HitChance.Medium) then
			return
		end
	end
  end
end

function Amumu.OnDraw() 
if Menu.Get("DQ") then
        Renderer.DrawCircle3D(Player.Position, spells.Q.Range, 25, 2, Menu.Get("DQC"))
    end
    if Menu.Get("DW") then
        Renderer.DrawCircle3D(Player.Position, spells.W.Range, 25, 2, Menu.Get("DWC"))
    end
	if Menu.Get("DE") then
        Renderer.DrawCircle3D(Player.Position, spells.E.Range, 25, 2, Menu.Get("DEC"))
    end
	if Menu.Get("DR") then
        Renderer.DrawCircle3D(Player.Position, spells.R.Range, 25, 2, Menu.Get("DRC"))
    end
end

function Amumu.Waveclear()

	local pPos, pointsQ, pointsE = Player.Position, {}, {}
		
	-- Jungle Minions
	if #pointsQ == 0 or pointsE == 0 then
		for k, v in pairs(ObjManager.Get("neutral", "minions")) do
			local minion = v.AsAI
			if ValidMinion(minion) then
				local posQ = minion:FastPrediction(spells.Q.Delay)
				local posE = minion:FastPrediction(spells.E.Delay)
				if posE:Distance(pPos) < spells.E.Range then
					table.insert(pointsE, posE)
				end
				if posQ:Distance(pPos) < spells.Q.Range then
					table.insert(pointsQ, posQ)
				end     
			end
		end
	end
	
	local bestPosQ, hitCountQ = spells.Q:GetBestLinearCastPos(pointsQ)
	if bestPosQ and hitCountQ >= Menu.Get("Wave.CastQHC")
		and spells.Q:IsReady() and Menu.Get("Wave.UseQ") then
		spells.Q:Cast(bestPosQ)
    end
	if spells.E:IsReady() and Menu.Get("Wave.UseE") then
		spells.E:Cast()
    end
end

function OnLoad()
	if Player.CharName == "Amumu" then
		Amumu.LoadMenu()
		for eventName, eventId in pairs(Enums.Events) do
			if Amumu[eventName] then
				EventManager.RegisterCallback(eventId, Amumu[eventName])
			end
		end
    return true
 end
end