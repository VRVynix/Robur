--[[
    made by vynix
]]

require("common.log")
module("Vortex Tryndamere", package.seeall, log.setup)

local clock = os.clock
local insert = table.insert
local huge, min, max, abs = math.huge, math.min, math.max, math.abs

local _SDK = _G.CoreEx
local Console, ObjManager, EventManager, Geometry, Input, Renderer, Enums, Game = _SDK.Console, _SDK.ObjectManager, _SDK.EventManager, _SDK.Geometry, _SDK.Input, _SDK.Renderer, _SDK.Enums, _SDK.Game
local Menu, Orbwalker, Collision, Prediction, HealthPred = _G.Libs.NewMenu, _G.Libs.Orbwalker, _G.Libs.CollisionLib, _G.Libs.Prediction, _G.Libs.HealthPred
local DmgLib, ImmobileLib, Spell = _G.Libs.DamageLib, _G.Libs.ImmobileLib, _G.Libs.Spell
local SpellSlots, SpellStates = Enums.SpellSlots, Enums.SpellStates
local insert, sort = table.insert, table.sort
local Spell = _G.Libs.Spell

local spells = {
    W = Spell.Targeted({
        Slot = Enums.SpellSlots.W,
        Range = 850,
        Delay = 0.3,
    }),
    E = Spell.Skillshot({
        Slot = Enums.SpellSlots.E,
        Range = 660,
        Delay = 0,
        Speed = math.huge,
        Radius = 225,
        Type = "Linear",

    }),
    R = Spell.Active({
        Slot = Enums.SpellSlots.R,
    }),
}

local TS = _G.Libs.TargetSelector()
local Tryndamere = {}
local blocklist = {}


function Tryndamere.LoadMenu()
    Menu.RegisterMenu("VortexTryndamere", "Vortex Tryndamere", function()
        Menu.ColumnLayout("cols", "cols", 2, true, function()
            Menu.ColoredText("Combo", 0xFFA5E5D3, true)
            Menu.Checkbox("Combo.UseQ", "Use Q", true)
            Menu.Checkbox("Combo.UseW", "Use W", true)
            Menu.Checkbox("Combo.UseE", "Use E", true)
            Menu.Slider("Combo.EHC", "E Hitchance", 0.7, 0, 1, 0.05)
            Menu.Checkbox("Combo.UseR", "Use R", true)
			Menu.Slider("RH", "Health Percent To Auto R", 10, 0, 100)

            Menu.NextColumn()

            Menu.ColoredText("KillSteal", 0xFFA5E5D3, true)
            Menu.Checkbox("KSE", "Use E", true)
			
			Menu.NextColumn()
			
			Menu.ColoredText("Misc", 0xFFA5E5D3, true)
            Menu.Checkbox("AR", "Auto Cast R To Safe", true)

            Menu.NextColumn()

            Menu.ColoredText("Waveclear", 0xFFA5E5D3, true)
            Menu.Checkbox("Wave.UseE", "Use E", true)
			Menu.Slider("Wave.CastEHC", "E Min. Hit Count", 1, 0, 10)
        end)

        Menu.Separator()

        Menu.ColoredText("Drawing", 0xFFA5E5D3, true)
        Menu.Checkbox("DW", "Draw W Range")
        Menu.ColorPicker("DWC", "Draw W Color", 0xFF00D29E)
        Menu.Checkbox("DE", "Draw E Range")
        Menu.ColorPicker("DEC", "Draw E Color", 0xFF00D29E)
    end)
end

function Tryndamere.IsEnabledAndReady(spell, mode)
    return Menu.Get(mode .. ".Use"..spell) and spells[spell]:IsReady()
end

local lastTick = 0
local function CanPerformCast()
    local curTime = clock()
    if curTime - lastTick > 0.25 then
        lastTick = curTime

        local gameAvailable = not (Game.IsChatOpen() or Game.IsMinimized())
        return gameAvailable and not (Player.IsDead or Player.IsRecalling) and Orbwalker.CanCast()
    end
end

function ValidMinion(minion)
    return minion and minion.IsTargetable and minion.MaxHealth > 6
end

function CountEnemiesInRange(pos, range, t)
    local res = 0
    for k, v in pairs(t or ObjManager.Get("enemy", "minions")) do
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

function Tryndamere.GetTargets(range)
    return {TS:GetTarget(range, true)}
end

function Tryndamere.Edmg()
    return(80 + (spells.E:GetLevel() - 1) * 30) + (1.3 * Player.BonusAD) + (0.8 * Player.TotalAP)
end

function Tryndamere.OnTick()

    local gameTime = Game.GetTime()
    if gameTime < (lastTick + 0.25) then return end
    lastTick = gameTime
	
	if Tryndamere.AutoR() then return end
	if Tryndamere.KsE() then return end

	local ModeToExecute = Tryndamere[Orbwalker.GetMode()]
    if ModeToExecute then
        ModeToExecute()
    end


	if Orbwalker.GetMode() == "Waveclear" then
			Tryndamere.Waveclear()
	end
end
function Tryndamere.ComboLogic(mode)
    if Tryndamere.IsEnabledAndReady("W", mode) then
		local targ = spells.W:GetTarget()
			if targ then
			if spells.W:IsReady() then
				spells.W:Cast(targ)
				return
			end
		end
	end
    if Tryndamere.IsEnabledAndReady("E", mode) then
        local targ = spells.E:GetTarget()
        if targ then
            local eChance = Menu.Get(mode .. ".EHC")
            if spells.E:IsReady() and #TS:GetTargets(spells.E.Range, true) then
                if spells.E:CastOnHitChance(targ, eChance) then
                    return
                end
            end
        end
    end
	if Tryndamere.IsEnabledAndReady("R", mode) then
        local HP = Player.Health / Player.MaxHealth * 100
        local HS = Menu.Get("RH")
        if HP < HS then
            return
			spells.R:Cast()
        end
    end
end

function Tryndamere.KsE()
    if Menu.Get("KSE") then
	    for k, eTarget in ipairs(TS:GetTargets(spells.E.Range, true)) do
		    local eDmg = DmgLib.CalculateMagicalDamage(Player, eTarget, Tryndamere.Edmg())
		    local ksHealth = spells.E:GetKillstealHealth(eTarget)
		    if eDmg > ksHealth and spells.E:CastOnHitChance(eTarget, Enums.HitChance.Medium) then
			    return
		    end
	    end
    end
end

function Tryndamere.Combo()  Tryndamere.ComboLogic("Combo")  end

function Tryndamere.Waveclear()

    local pPos, pointsE = Player.Position, {}
    	
	for k, v in pairs(ObjManager.Get("enemy", "minions")) do
		local minion = v.AsAI
		if ValidMinion(minion) then
			local posE = minion:FastPrediction(spells.E.Delay)
			if posE:Distance(pPos) < spells.E.Range and minion.IsTargetable then
				table.insert(pointsE, posE)
			end 
		end    
	end

		
	if #pointsE == 0 then
		for k, v in pairs(ObjManager.Get("neutral", "minions")) do
			local minion = v.AsAI
			if ValidMinion(minion) then
				local posE = minion:FastPrediction(spells.E.Delay)
				if posE:Distance(pPos) < spells.E.Range then
					table.insert(pointsE, posE)
				end   
			end
		end
	end
	
	local bestPosE, hitCountE = spells.E:GetBestLinearCastPos(pointsE)
	if bestPosE and hitCountE >= Menu.Get("Wave.CastEHC")
		and spells.E:IsReady() and Menu.Get("Wave.UseE") then
		spells.E:Cast(bestPosE)
    end
end

function Tryndamere.OnDraw()
    if Menu.Get("DW") then
        Renderer.DrawCircle3D(Player.Position, spells.W.Range, 25, 2, Menu.Get("DWC"))
    end
    if Menu.Get("DE") then
        Renderer.DrawCircle3D(Player.Position, spells.E.Range, 25, 2, Menu.Get("DEC"))
    end
end

function Tryndamere.AutoR()
	if Menu.Get("AR") then
	local HP = Player.Health / Player.MaxHealth * 100
        local HS = Menu.Get("RH")
        if HP < HS then
            return
			spells.R:Cast()
		end
	end
end

function OnLoad()
    if Player.CharName == "Tryndamere" then
        Tryndamere.LoadMenu()
        for eventName, eventId in pairs(Enums.Events) do
            if Tryndamere[eventName] then
                EventManager.RegisterCallback(eventId, Tryndamere[eventName])
            end
        end
    return true
    end
end