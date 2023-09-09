
local SpellHolder
local IsInParty
local IsinsameGroup
local Wayden_MyNpc
local Main_Character
local isAvatar = {}
local My_Npc = {}
local UUID_NewPC
local SHAPESHIFTRULE = "7ef7b2d8-3d4c-48a4-863e-a9df844697c0"
local TargetNpc
local WAY_InCreation = false
local WAY_CharacterCreated = false
local WAY_SaveLoaded = false
local WAY_Passives = Ext.Require("Server/WAY_Passives.lua")
local WAY_Status = Ext.Require("Server/WAY_Status.lua")
-------------------------------------------------------------------------------------
--                 Eralyne's Appearence Edit Mod's Stolen Features                 --
-------------------------------------------------------------------------------------

--List Flags and some utils funtions, renamed to avoid conflict, i hope

local ERA_Tags = Ext.Require("Server/ERA_Tags.lua")
local ERA_Flags = Ext.Require("Server/ERA_Flags.lua")

local function utils_set(list)
    local set = {}
    for _, l in ipairs(list) do set[l] = true end
    return set
end

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
    SetMaxPartySizeOverride(100)
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
    Ext.Utils.Print(SpellName,"Added")
end

--First Listener, will set up data for the ret of the mod,
Ext.Osiris.RegisterListener("SavegameLoaded", 0, "after", function ()
    WAY_SaveLoaded = true

    Wayden_SetupData()
    Wayden_GiveSpell_ToParty("Party_Manager")
    Wayden_GiveSpell_ToParty("WAY_NPC_clone")
   
end)

-- Remove/Add Character on spell use

------------------------------------------------------------------------------------
--                                                                                --
--                                  Remove | Add                                  --
--                                                                                --
------------------------------------------------------------------------------------

--Same as remove but for recruiting

local function Wayden_Recruit(caster,target,set_faction,register_NPC, ChangePartySize)
    if isOriginChar[target] then
        Osi.PROC_Hirelings_AddToParty(target, caster)
    else
        Osi.PROC_AddDebugCharToParty(target)
    end
    MakePlayer(target)
    if set_faction == 1 then
        Osi.SetFaction(target,GetFaction(Main_Character))
    end
   
    if (not isOriginChar[target] and not isAvatar[target]) then
        if register_NPC == 1 then
            Osi.DB_MyNPC(target)
        end
        Osi.DB_GLO_Playable(target)
        Ext.Utils.Print("NPC Added")
    else
        Ext.Utils.Print("Origin Char Added")--debug
    end
    if ChangePartySize == 1 then
        SetMaxPartySizeOverride(GetMaxPartySize()+1)
    end
end

--Function that removes Character From party 
-- caster is the party owner 
-- target is the one to remove, 
-- restore faction and unregisterNPC self explained bool
local function Wayden_Remove(caster, target, restore_faction, unregister_NPC, ChangePartySize)
    if isOriginChar[target] then
        Osi.PROC_GLO_PartyMembers_Remove(target, caster, 1)
    else
        Osi.PROC_GLO_PartyMembers_Initialize(target)
    end
    if restore_faction == 1 then Osi.SetFaction(target,GetBaseFaction(target)) end
    --Ext.Utils.Print(isOriginChar[target],(not isOriginChar[target] and not isAvatar[target])) --debug
    if (not isOriginChar[target] and not target ~= Main_Character) then 
        Osi.DB_GLO_Playable:Delete(target)
        if unregister_NPC == 1 then
            Osi.DB_MyNPC:Delete(target)
        end
        Ext.Utils.Print("NPC Removed")
    end
    if ChangePartySize == 1 and GetMaxPartySize() > 4 then
        SetMaxPartySizeOverride(GetMaxPartySize()-1)
    end
end

------------------------------------------------------------------------------------
--                                                                                --
--                                  Cloning                                       --
--                                                                                --
------------------------------------------------------------------------------------

local function WAY_FT_TransformToPC()
    WAY_InCreation = true
    StartCharacterCreation()
end

local function WAY_CopyTagsFlagsPassiveStatus()
    for _,entry in pairs(ERA_Flags) do
        if Osi.GetFlag(TargetNpc,entry) == 1 and Osi.GetFlag(UUID_NewPC,entry) == 0 then
            Osi.SetFlag(entry,UUID_NewPC,0,1)
        elseif Osi.GetFlag(TargetNpc,entry) == 0 and Osi.GetFlag(UUID_NewPC,entry) == 1 then
            Osi.ClearFlag(entry,UUID_NewPC,0,0)
        end
    end
    Ext.Utils.Print("Flags Clonned")
    for _,entry in pairs(ERA_Tags) do
        if Osi.IsTagged(TargetNpc, entry) == 1 and Osi.IsTagged(UUID_NewPC, entry) == 0 then
            Osi.SetTag(UUID_NewPC,entry)
        elseif Osi.IsTagged(TargetNpc, entry) == 0 and Osi.IsTagged(UUID_NewPC, entry) == 1 then
            Osi.ClearTag(UUID_NewPC,entry)
        end
    end
    Ext.Utils.Print("Tags Clonned")
    for _t,entry in pairs(WAY_Passives) do
        if Osi.HasPassive(TargetNpc,entry) == 1 and Osi.HasPassive(UUID_NewPC,entry) == 0 then
            Osi.AddPassive(UUID_NewPC, entry)
        elseif Osi.HasPassive(TargetNpc,entry) == 0 and Osi.HasPassive(UUID_NewPC,entry) == 1 then
            Osi.RemovePassive(UUID_NewPC, entry)
        end
    end
    Ext.Utils.Print("Passives Clonned")
    for _,entry in pairs(WAY_Status) do
        if Osi.HasActiveStatus(TargetNpc,entry) == 1 and Osi.HasActiveStatus(UUID_NewPC,entry) == 0 then
            Osi.ApplyStatus(UUID_NewPC, entry,GetStatusCurrentLifetime(TargetNpc,entry),1,UUID_NewPC)
        elseif Osi.HasActiveStatus(TargetNpc,entry) == 0 and Osi.HasActiveStatus(UUID_NewPC,entry) == 1 then
            Osi.RemoveStatus(UUID_NewPC, entry,UUID_NewPC)
        end
    end
    Ext.Utils.Print("Status Clonned")
end


local function WAY_ResetCreationVariables()
    WAY_InCreation = false
    UUID_NewPC = nil
    WAY_CharacterCreated = false
    TargetNpc = nil
    Ext.Utils.Print("Reseted Variables")--debug
end

local function WAY_Set_InParty()
    Wayden_Remove(Main_Character,UUID_NewPC,0,0,0)
    Osi.DB_DebugAVATARFound:Delete(nil)
    Wayden_Recruit(Main_Character,UUID_NewPC,1,1,1)
    Ext.Utils.Print("Character added to party")--debug
    Osi.SetTadpoleTreeState(UUID_NewPC, 2)
    Ext.Utils.Print("Tadpole added")--debug
    TeleportTo(UUID_NewPC,Main_Character,"",1,1,1,1,1)
    Ext.Utils.Print("Teleport to Party Done")--debug
end


local function WAY_Cloning()
    if Osi.IsTagged(UUID_NewPC,"b42a97b3-7264-4d98-19b4-0514c9f832ed") == 1 then --idk why it's needed to reverse the tag sometimes
            WAY_CopyTagsFlagsPassiveStatus()
        if TargetNpc == "S_GLO_Nightsong_6c55edb0-901b-4ba4-b9e8-3475a8392d9b" then
            Transform(UUID_NewPC,"9671ecbb-4030-48ff-b63e-f138e988835f",SHAPESHIFTRULE)
        else
            Transform(UUID_NewPC,TargetNpc,SHAPESHIFTRULE)
        end
    end
    Osi.SetTag(UUID_NewPC,"b42a97b3-7264-4d98-b419-1405f8c9ed32")
    Ext.Utils.Print("Clone Tag Added")
    
end


Ext.Osiris.RegisterListener("Activated", 1, "after", function (uuid)
    if WAY_SaveLoaded and WAY_CharacterCreated and WAY_InCreation and not (string.find(uuid, "S_", 1, true) == 1) then
        UUID_NewPC = uuid
        WAY_Cloning()
        Ext.Utils.Print("Cloned")
        WAY_Set_InParty()
        Ext.Utils.Print("Set in Party Done")
        WAY_ResetCreationVariables()
        Ext.Utils.Print("InCreation Variables reseted")
    end
end)

--Taken from appareance editmod 
Ext.Osiris.RegisterListener("CharacterCreationFinished", 0, "before", function ()
    if WAY_SaveLoaded  and WAY_InCreation then
        WAY_CharacterCreated = true
        -- Remove Daisies
        
        for _, entry in pairs(Osi["DB_GLO_DaisyAwaitsAvatar"]:Get(nil, nil)) do
            Osi.SetOnStage(entry[1], 0)
            Osi["DB_GLO_DaisyAwaitsAvatar"]:Delete(table.unpack(entry))
            Ext.Utils.Print("Daisy Cleaned Up")
        end
    end
end)
------------------------------------------------------------------------------------
--                                                                                --
--                               Spell Listener                                   --
--                                                                                --
------------------------------------------------------------------------------------

local function WAY_Spells(caster, target, name)
    if name == 'Party_Manager' then
        if IsPartyMember(target, 1) == 1 then
            Wayden_Remove(caster, target, 1, 1, 1)
        else
            Wayden_Recruit(caster, target, 1, 1, 1)
        end
    elseif name == 'WAY_NPC_clone' then
        if not target or Osi.IsTagged(target, "b42a97b3-7264-4d98-b419-1405f8c9ed32") == 1 then
            return
        end -- Si c'est un clone, ne pas cloner
        TargetNpc = target
        WAY_FT_TransformToPC()
    end
end

-- Listener Usingspellontarget 
Ext.Osiris.RegisterListener("UsingSpellOnTarget", 6, "after", function (caster, target, name, _, _, _, _)
    Ext.Utils.Print("your spell target is", target)--debug
    WAY_Spells(caster, target, name)
end)

------------------------------------------------------------------------------------
--                                                                                --
--                        Bug Fix Long Rest                                       --
--                                                                                --
------------------------------------------------------------------------------------

--When Long rest ends Restore all the NPC to the party and restore their health
local function WAY_Temp_Removal()
    for _, entry in pairs(Osi["DB_MyNPC"]:Get(nil)) do 
        Wayden_Remove(Main_Character,entry[1], 0, 0, 0)    
        if IsOnStage(entry[1]) == nil then --if character has been totaly removed by the game removes it from My_NPC should not be usefull anymore since i added every character to the global level
            Osi.DB_MyNPC:Delete(entry[1])
        end
        Ext.Utils.Print("Character Temp removed")
    end
end

local function WAY_Remove_Avatar_Tags()
    for _, entry in pairs(Osi["DB_MyNPC"]:Get(nil)) do 
        if(not (string.find(entry[1], "S_", 1, true) == 1)) then --only if it's a clone and not a original character since originall larian's character have a name starting with S_
            Osi.PROC_TryClearAvatarTag(entry[1])
            Ext.Utils.Print("Removed avatar tag on", entry[1])--debug
        end
    end
    IsSleeping = true
end

local function WAY_Rerecruit_As_Avatar()
    for _, entry in pairs(Osi["DB_MyNPC"]:Get(nil)) do
        if(not (string.find(entry[1], "S_", 1, true) == 1)) then --this part removes the registered debug avatar
            Osi.DB_DebugAVATARFound:Delete(nil)
            Ext.Utils.Print("Delete avatar debug", entry[2])
        end 
        Wayden_Recruit(Main_Character,entry[1],1,0,0)
        if (IsOnStage(entry[1]) == 0) then --for character that left the party due to game events
                SetOnStage(entry[1], 1)
                TeleportTo(entry[1],Main_Character,"",1,1,1,1,1)
        end
        Ext.Utils.Print("Character Restored")
    end
    RestoreParty(GetHostCharacter())-- because recruited and not cloned npc doesn't heal by themself
end

Ext.Osiris.RegisterListener("TimerFinished", 1, "after", function (event)
    if event == "WAYDEN_RERECRUIT_CLONE" and not IsSleeping then
        WAY_Rerecruit_As_Avatar()
    end
end)


Ext.Osiris.RegisterListener("LongRestFinished",0,"after", function ()
    Osi.TimerLaunch("WAYDEN_RERECRUIT_CLONE", 1000)
    IsSleeping = nil
end)

--When Long rest start removes all NPC from the party
Ext.Osiris.RegisterListener("LongRestStarted",0, "before", function ()
    if WAY_SaveLoaded then
        WAY_Remove_Avatar_Tags()
    end
end)

Ext.Osiris.RegisterListener("LongRestStarted",0, "after", function ()
    WAY_Temp_Removal()
end)


Ext.Osiris.RegisterListener("EnteredCombat", 2, "after", function (object, combatguid)
    if GetUUID(object) == GetUUID(Main_Character) and IsSleeping then
        Wayden_Rerecruit_As_Avatar()
    end
end)



--Need to add listener on short rest to manually do it for NPC / shouldn't be needed anymore

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
            elseif (IsinsameGroup == 1 or IsDead(target) == 1) then --to force tp dead NPC to camp since wither can't do it but perhaps it can if i add it to good DB
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


-------------

