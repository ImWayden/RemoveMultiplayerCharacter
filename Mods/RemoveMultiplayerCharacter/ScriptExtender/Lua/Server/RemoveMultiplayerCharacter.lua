
local SpellHolder
local IsInParty
local IsinsameGroup
local Wayden_MyNpc
local Main_Character
local isAvatar = {}
local My_Npc = {}


local function utils_set(list)
    local set = {}
    for _, l in ipairs(list) do set[l] = true end
    return set
end
-------------------------------------------------------------------------------------
--                                 "Static" Data                                   --
-------------------------------------------------------------------------------------
local isOriginChar = utils_set({
    "S_Player_Karlach_2c76687d-93a2-477b-8b18-8a14b549304c",
    "S_Player_Minsc_0de603c5-42e2-4811-9dad-f652de080eba",
    "S_GOB_DrowCommander_25721313-0c15-4935-8176-9f134385451b",
    "S_GLO_Halsin_7628bc0e-52b8-42a7-856a-13a6fd413323",
    "S_Player_Jaheira_91b6b200-7d00-4d62-8dc9-99e8339dfa1a",
    "S_Player_Gale_ad9af97d-75da-406a-ae13-7071c563f604",
    "S_Player_Astarion_c7c13742-bacd-460a-8f65-f864fe41f255",
    "S_Player_Laezel_58a69333-40bf-8358-1d17-fff240d7fb12",
    "S_Player_Wyll_c774d764-4a17-48dc-b470-32ace9ce447d",
    "S_Player_ShadowHeart_3ed74f06-3c60-42dc-83f6-f034cb47c679"
})
------------------------------------------------------------------------------------
--                                                                                --
--                   Set Up Data | Add Spell to PartyMember                       --
--                                                                                --
------------------------------------------------------------------------------------

local function Wayden_SetupData()
    Main_Character = Osi.DB_PartyMembers:Get(nil)[1][1]
    Osi.DB_DebugAVATARFound("S_WAY_DEBUGCHAR_00000000-0000-0000-0000-000000000000")
    for _, entry in pairs(Osi["DB_Avatars"]:Get(nil)) do
        table.insert(isAvatar,entry[1])
    end
    isAvatar = utils_set(isAvatar)
end

local function Wayden_GiveSpell_ToParty(SpellName)
    for _, entry in pairs(Osi["DB_PartyMembers"]:Get(nil)) do
        AddSpell(entry[1], SpellName, 0, 0)
    end
end

--First Listener, will set up data for the ret of the mod,
Ext.Osiris.RegisterListener("SavegameLoaded", 0, "after", function ()
    Wayden_SetupData()
    Wayden_GiveSpell_ToParty("Party_Manager") 
    Ext.Utils.Print("Party Manager Spells Added")
end)

-- Remove/Add Character on spell use

------------------------------------------------------------------------------------
--                                                                                --
--                        Remove | Add | Spell Listener                           --
--                                                                                --
------------------------------------------------------------------------------------

--Function that removes Character From party 
-- caster is the party owner 
-- target is the one to remove, 
-- restore faction and unregisterNPC self explained bool

local function Wayden_Remove(caster, target, restore_faction, unregister_NPC)
    if isOriginChar[target] then
        Osi.PROC_GLO_PartyMembers_Remove(target, caster, 1)
    else
        Osi.PROC_GLO_PartyMembers_Initialize(target)
    end
    if restore_faction == 1 then
        Osi.SetFaction(target,GetBaseFaction(target))
    end
    if not isOriginChar[target] and not isAvatar[target] then 
        Osi.DB_GLO_Playable:Delete(target)

        if unregister_NPC == 1 then
            Osi.DB_MyNPC:Delete(target)
        end
        Ext.Utils.Print("NPC Removed")
    else
        Osi.PROC_Hirelings_SendToCamp(target)
        Ext.Utils.Print("Origin Char Removed and send to camp")
    end
end

--Same as recruit but for removing 

local function Wayden_Recruit(caster,target,set_faction,register_NPC)
    if isOriginChar[target] then
        Osi.PROC_Hirelings_AddToParty(target, caster)
    else
        Osi.PROC_AddDebugCharToParty(target)
    end
    MakePlayer(target)
    if set_faction == 1 then
        Osi.SetFaction(target,GetBaseFaction(caster))
    end
    if not isOriginChar[target] and not isAvatar[target] then
        if register_NPC == 1 then
            Osi.DB_MyNPC(target)
        end
        Osi.DB_GLO_Playable(target)
        Ext.Utils.Print("NPC Added")
    else
        Ext.Utils.Print("Origin Char Added")
    end
end
-- Listener Usingspellontarget 
Ext.Osiris.RegisterListener("UsingSpellOnTarget", 6, "after", function (caster, target, name, _, _, _, _)
    if name == 'Party_Manager' then
        if IsPartyMember(target, 1) == 1 then
            Wayden_Remove(caster,target,1,1)
        else
            Wayden_Recruit(caster,target)
        end
    end
end)

------------------------------------------------------------------------------------
--                                                                                --
--                        Bug Fix Long Rest                                       --
--                                                                                --
------------------------------------------------------------------------------------

--When Long rest ends Restore all the NPC to the party and restore their health

Ext.Osiris.RegisterListener("LongRestFinished",0,"after", function ()
    
    for _, entry in pairs(Osi["DB_MyNPC"]:Get(nil)) do 
        Wayden_Recruit(Main_Character,entry[1],0,0)
        Ext.Utils.Print("Character Restored")
    end
    RestoreParty(GetHostCharacter())
end)

--When Long rest start removes all NPC from the party

Ext.Osiris.RegisterListener("LongRestStarted",0, "after", function ()
    for _, entry in pairs(Osi["DB_MyNPC"]:Get(nil)) do 
        Wayden_Remove(Main_Character,entry[1], 0, 0)    
        if IsOnStage(entry[1]) == nil then --if character has been totaly removed by the game removes it from My_NPC
            Osi.DB_MyNPC:Delete(entry[1])
        end
        Ext.Utils.Print("Character Temp removed")
    end
end)

--Need to add listener on short rest to manually do it for NPC 

------------------------------------------------------------------------------------
--                                                                                --
--                        Teleportation Listeners                                 --
--                                                                                --
------------------------------------------------------------------------------------

--event TeleportToWaypoint((CHARACTER)_Character, (TRIGGER)_Trigger)
--Custom function to teleport every registered NPC To teleporting party character
-- for i,NPC in pairs(Osi.DB_MyNPC:Get(nil)) do
local function Wayden_TPNpc_01(target)
    if target == nil then
        return
    end
    target = GetUUID(target)
    if  target == GetHostCharacter() then    
        Wayden_MyNpc = Osi.DB_MyNPC:Get(nil)
        for i = 1, #Wayden_MyNpc do
            local NPC = Wayden_MyNpc[i][1]        
            IsinsameGroup = InSamePartyGroup(target,NPC)
            if (IsOnStage(NPC) == 0) then --for character that left the party due to game events
                SetOnStage(NPC, 1)
                TeleportTo(NPC,target,"",1,1,1,1,1)
            elseif IsinsameGroup == 1 then --to force tp dead NPC to camp since wither can't do it but perhaps it can if i add it to good DB
                TeleportTo(NPC,target,"",1,1,1,1,1)
            end
        end
    end
end
--call TeleportTo((GUIDSTRING)_SourceObject, (GUIDSTRING)_TargetObject, (STRING)_Event, (INTEGER)_TeleportLinkedCharacters, (INTEGER)_TeleportPartyFollowers, (INTEGER)_TeleportSummons, (INTEGER)_LeaveCombat, (INTEGER)_SnapToGround)
Ext.Osiris.RegisterListener("TeleportToWaypoint", 2,"after",function (target,_,_)
    Wayden_TPNpc_01(target)
end)
--TeleportToFleeWaypoint((CHARACTER)_Character, (TRIGGER)_Trigger)
Ext.Osiris.RegisterListener("TeleportToFleeWaypoint", 2,"after",function (target,_,_)
    Wayden_TPNpc_01(target)
    Ext.Utils.Print("EndTP")
end)
--event TeleportedFromCamp((CHARACTER)_Character) (3,0,1138,1)
Ext.Osiris.RegisterListener("TeleportedFromCamp", 1,"after",function (target,_)
    Wayden_TPNpc_01(target)
end)
--event TeleportedToCamp((CHARACTER)_Character
Ext.Osiris.RegisterListener("TeleportedToCamp", 1,"after",function (target,_)
    Wayden_TPNpc_01(target)
end)
--Teleported((CHARACTER)_Target, (CHARACTER)_Cause, (REAL)_OldX, (REAL)_OldY, (REAL)_OldZ, (REAL)_NewX, (REAL)_NewY, (REAL)_NewZ, (STRING)_Spell)
--Probably used for spell tp
--[[  
    Ext.Osiris.RegisterListener("Teleported", 9, "after", function (target,cause,_,_,_,_,_,_,_,name)
    end)
]]--
