local SpellHolder
local IsInParty
local IsinsameGroup
local Wayden_MyNpc
-- Give player Resculpt spell on load
Ext.Osiris.RegisterListener("SavegameLoaded", 0, "after", function ()
        SpellHolder = GetHostCharacter()
        Ext.Utils.Print(SpellHolder)
        --Add a Debug char inside the DB so essential NPC don't lose their dialogues
        Osi.DB_DebugAVATARFound("S_WAY_DEBUGCHAR_00000000-0000-0000-0000-000000000000")
        Wayden_MyNpc = Osi.DB_PartyMembers:Get(nil)
        for i = 1, #Wayden_MyNpc do
            AddSpell(SpellHolder, "Party_Manager", 0, 0)
        end
    Ext.Utils.Print("Party Manager Spells Added")

    -- Remove/Add Character on spell use
    Ext.Osiris.RegisterListener("UsingSpellOnTarget", 6, "after", function (caster, target, name, _, _, _, _)
        if name == 'Party_Manager' then
            IsInParty = IsPartyMember(target, 0)
            if  IsInParty == 1 then
                Osi.PROC_GLO_PartyMembers_Remove(target, caster, 1)
                Osi.PROC_GLO_PartyMembers_Initialize(target)
                --Osi.PROC_Hirelings_SendToCamp(target) Not a good Idea
                Osi.SetFaction(target,GetBaseFaction(target))
                Osi.DB_MyNPC:Delete(target)
                Ext.Utils.Print("Character Removed")
            else
                Osi.SetFaction(target,GetBaseFaction(caster))
                Osi.PROC_Hirelings_AddToParty(target, caster)
                Osi.PROC_AddDebugCharToParty(target)
                MakePlayer(target)
                Osi.DB_MyNPC(target)
                Ext.Utils.Print("CharacterAdded")
            end
        end
    end)
--event TeleportToWaypoint((CHARACTER)_Character, (TRIGGER)_Trigger)
--Custom function to teleport every registered NPC To teleporting party character
-- for i,NPC in pairs(Osi.DB_MyNPC:Get(nil)) do
    local function Wayden_TPNpc_01(target)
        target = GetUUID(target)
        if  target == GetHostCharacter() then    
            Wayden_MyNpc = Osi.DB_MyNPC:Get(nil)
            for i = 1, #Wayden_MyNpc do
                local NPC = Wayden_MyNpc[i][1]        
                IsinsameGroup = InSamePartyGroup(target,NPC)
                if IsinsameGroup == 1 then
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
end)

