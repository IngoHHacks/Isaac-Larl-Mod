-- SECTION Imports

local json = require("json")

-- SECTION Mod Setup

local mod = RegisterMod("Larl Mod", 1)

-- SECTION API variables

local game = Game()
local music = MusicManager()
local sfx = SFXManager()

-- SECTION Classes

local Utils = {}

-- SECTION Identifiers

local twicetwiceItem = Isaac.GetItemIdByName("Twice Twice")
local antiSoftlockItem = Isaac.GetItemIdByName("Anti-Softlock")
local learnedList = Isaac.GetItemIdByName("Things Carl Has Learned")
local sliderMusic = Isaac.GetMusicIdByName("SM64 Slider")

local itemRoom = 8500
local trollRoom1 = 8501

-- SECTION Data

-- Persistent data for the run
local runData = {
    buttons = {}
}

-- SECTION Utils

--- Iterates over all players in the game
--- @return fun():EntityPlayer
function Utils:iterPlayers()
    local count = game:GetNumPlayers()
    return coroutine.wrap(function()
        for i = 0, count - 1 do
            coroutine.yield(game:GetPlayer(i))
        end
    end)
end

--- Pick a random element from a table and remove it
--- @param t table
--- @return any
function Utils:pickRemove(t)
    return table.remove(t, math.random(#t))
end

--- Pick a random element from a table
--- @param t table
--- @return any
function Utils:pick(t)
    return t[math.random(#t)]
end

--- Binds arguments to a function
--- Arguments are bound from left to right
--- @param f function
--- @param ... any
--- @return function
function Utils:bind(f, ...)
    local boundArgs = {...}

    return function(...)
        local args = {}
        for i = 1, #boundArgs do
            args[#args + 1] = boundArgs[i]
        end
        for i = 1, select('#', ...) do
            args[#args + 1] = select(i, ...)
        end

        return f(table.unpack(args))
    end
end

-- Binds arguments to a function starting at a given argument index
--- Arguments are bound from left to right
--- @param f function
--- @param starting_index number
--- @param ... any
--- @return function
function Utils:bindFrom(f, starting_index, ...)
    local boundArgs = {...}

    return function(...)
        local args = {}
        for i = 1, starting_index - 1 do
            args[#args + 1] = select(i, ...)
        end
        for i = 1, #boundArgs do
            args[#args + 1] = boundArgs[i]
        end
        for i = starting_index, select('#', ...) do
            args[#args + 1] = select(i, ...)
        end

        return f(table.unpack(args))
    end
end

mod:AddCallback(ModCallbacks.MC_POST_PLAYER_INIT, function(player)
    local data = mod:LoadData()
    if data and data ~= "" then
        runData = json.decode(data)
    end
end)

mod:AddCallback(ModCallbacks.MC_PRE_GAME_EXIT, function()
    mod:SaveData(json.encode(runData))
end)

mod:AddCallback(ModCallbacks.MC_POST_GAME_STARTED, function(isContinued)
    if not isContinued then
        runData.buttons = {}
    end
end)

mod:AddCallback(ModCallbacks.MC_POST_NEW_LEVEL, function()

end)

mod:AddCallback(ModCallbacks.MC_POST_NEW_ROOM, function()

end)

-- SECTION External Item Description support

if EID then
    EID:addCollectible(twicetwiceItem, "Tears split in two on contact#Split tears deal half damage#↓ {{Tears}} x0.8 Fire rate multiplier#Rooms have a 10% chance to respawn enemies when cleared#!!! There is no limit to how many times a room can respawn enemies")
    EID:addCollectible(antiSoftlockItem, "Teleports Isaac to a temporary room with a horrible anti-softlock challenge that has to be completed to return to the original room#{{Coin}} Clearing the challenge will reward Isaac with 10 random coins#!!! Leaving the room before completing the challenge will immediately teleport Isaac back and reset the challenge")
    EID:addCollectible(learnedList, "Shows a \"helpful\" tip on the screen")

    function HasDup(id, descObj)
        local type = descObj.ObjSubType
        if id ~= type then
            return false
        end
        for player in Utils:iterPlayers() do
            if player:HasCollectible(type) then
                return true
            end
        end
        return false
    end

    function HasOther(id, otherId, descObj)
        local type = descObj.ObjSubType
        if id ~= type then
            return false
        end
        for player in Utils:iterPlayers() do
            if player:HasCollectible(otherId) then
                return true
            end
        end
        return false
    end

    function AddDesc(text, descObj, keepNewLine)
        if keepNewLine == nil or keepNewLine == true then
            text = "#" .. text
        end
        EID:appendToDescription(descObj, text)
        return descObj
    end

    function DupDescription(descObj)
        EID:appendToDescription(descObj, "#{{Collectible" .. descObj.ObjSubType .. "}} No additional effect from multiple copies")
        return descObj
    end


    EID:addDescriptionModifier("Twice Twice Dup", Utils:bind(HasDup, twicetwiceItem), DupDescription)
    EID:addDescriptionModifier("Twice Twice Parasite", Utils:bind(HasOther, twicetwiceItem, CollectibleType.COLLECTIBLE_PARASITE), Utils:bind(AddDesc, "{{Collectible" .. CollectibleType.COLLECTIBLE_PARASITE .. "}} Overriddes Parasite"))
    EID:addDescriptionModifier("Parasite Twice Twice", Utils:bind(HasOther, CollectibleType.COLLECTIBLE_PARASITE, twicetwiceItem), Utils:bind(AddDesc, "{{Collectible" .. twicetwiceItem .. "}} Overridden by Twice Twice"))
end

-- SECTION Items

-- ITEM Twice Twice

function mod:twiceTwice()
    local room = game:GetRoom()
    if room:GetType() ~= RoomType.ROOM_DEFAULT then
        return
    end
    local anyTwice = false
    for player in Utils:iterPlayers() do
        if player:HasCollectible(twicetwiceItem) then
            anyTwice = true
            break
        end
    end
    if not anyTwice then
        return false
    end
    if math.random(10) == 1 then
        room:RespawnEnemies()
        room:SetAmbushDone(false)
        for _, entity in ipairs(Isaac.GetRoomEntities()) do
            if entity:IsActiveEnemy() then
                entity:AddEntityFlags(EntityFlag.FLAG_AMBUSH)
                for player in Utils:iterPlayers() do
                    if entity.Position:Distance(player.Position) < 100 then
                        entity.Position = room:FindFreePickupSpawnPosition(entity.Position-(player.Position - entity.Position):Normalized() * 100, 0, true)
                    end
                end
            end
        end
        return true
    end
    return false
end

mod:AddCallback(ModCallbacks.MC_PRE_SPAWN_CLEAN_AWARD, mod.twiceTwice)

function mod:applyTwiceTwiceStats(player, cacheFlags)
    if not player:HasCollectible(twicetwiceItem) then
        return
    end
    if cacheFlags & CacheFlag.CACHE_FIREDELAY == CacheFlag.CACHE_FIREDELAY then
        player.MaxFireDelay = player.MaxFireDelay / 0.8
    end
    if cacheFlags & CacheFlag.CACHE_TEARFLAG == CacheFlag.CACHE_TEARFLAG then
        player.TearFlags = player.TearFlags | TearFlags.TEAR_SPLIT
    end
end

mod:AddCallback(ModCallbacks.MC_EVALUATE_CACHE, mod.applyTwiceTwiceStats)

-- ITEM Anti-Softlock

function mod:useAntiSoftlock()
    Isaac.ExecuteCommand("goto s.default.2.0")
    return true
end 

mod:AddCallback(ModCallbacks.MC_USE_ITEM, mod.useAntiSoftlock, antiSoftlockItem)

function mod:applyAntiSoftlock()
    local positions = {
        33,
        35,
        37,
        39,
        41,
        93,
        95,
        97,
        99,
        101
    }
    runData.buttons = {}
    for i = 0, 9 do
        local pos = Utils:pickRemove(positions)
        game:GetRoom():SpawnGridEntity(pos, GridEntityType.GRID_PRESSURE_PLATE, 0, 0, 0)
        runData.buttons[i] = pos
    end
end

function mod:resetAntiSoftlock(wrongButtonPos)
    sfx:Play(SoundEffect.SOUND_THUMBS_DOWN, 1, 10)
    for player in Utils:iterPlayers() do
        local dist = player.Position - wrongButtonPos
        if dist:Length() < 30 then
            player.Velocity = dist:Normalized() * (40 - dist:Length()) * 0.2
        end
    end
    for _, idx in pairs(runData.buttons) do
        local e = game:GetRoom():GetGridEntity(idx)
        if e and e:GetType() == GridEntityType.GRID_PRESSURE_PLATE then
            if e:GetSprite():IsPlaying("On") then
                local playerNearby = false
                for player in Utils:iterPlayers() do
                    local dist = player.Position - e.Position
                    if dist:Length() < 30 then
                        playerNearby = true
                    end
                end
                if not playerNearby then
                    e:GetSprite():Play("Off", true)
                    e.State = 0
                end
            end
        end
    end
end

mod:AddCallback(ModCallbacks.MC_POST_NEW_ROOM, function()
    local room = game:GetLevel():GetCurrentRoom()
    local roomDesc = game:GetLevel():GetCurrentRoomDesc()
    if room:GetType() == RoomType.ROOM_DEFAULT and game:GetLevel():GetCurrentRoomIndex() == -3 and game:GetLevel():GetCurrentRoomDesc().Data.Name == "Start Room" then
        mod:applyAntiSoftlock()
    end
    if (roomDesc.Data.Name == "Carl's Items") then
        Isaac.Spawn(EntityType.ENTITY_PICKUP, PickupVariant.PICKUP_COLLECTIBLE, twicetwiceItem, game:GetRoom():GetGridPosition(32), Vector(0, 0), nil)
        Isaac.Spawn(EntityType.ENTITY_PICKUP, PickupVariant.PICKUP_COLLECTIBLE, antiSoftlockItem, game:GetRoom():GetGridPosition(34), Vector(0, 0), nil)
        Isaac.Spawn(EntityType.ENTITY_PICKUP, PickupVariant.PICKUP_COLLECTIBLE, learnedList, game:GetRoom():GetGridPosition(36), Vector(0, 0), nil)
        game:GetLevel():RemoveCurses(LevelCurse.CURSE_OF_BLIND)
    end
end)

mod:AddCallback(ModCallbacks.MC_POST_UPDATE, function()
    if runData.buttons and #runData.buttons > 0 then
        if music:GetCurrentMusicID() ~= sliderMusic then
            music:Play(sliderMusic, 1)
        end
        if game:GetRoom():GetType() == RoomType.ROOM_DEFAULT and game:GetLevel():GetCurrentRoomIndex() == -3 and game:GetLevel():GetCurrentRoomDesc().Data.Name == "Start Room" then
            local inOrder = true
            local unPressed = false
            local wrongButtonPos = nil
            for _, idx in pairs(runData.buttons) do
                local e = game:GetRoom():GetGridEntity(idx)
                if e and e:GetType() == GridEntityType.GRID_PRESSURE_PLATE and e.State ~= 0 then
                    if unPressed then
                        inOrder = false
                        wrongButtonPos = e.Position
                        break
                    end
                elseif e and e:GetType() == GridEntityType.GRID_PRESSURE_PLATE and e.State == 0 then
                    unPressed = true
                end
            end
            if not inOrder then
                mod:resetAntiSoftlock(wrongButtonPos)
                return
            end
            if not unPressed then
                for _, idx in pairs(runData.buttons) do
                    local e = game:GetRoom():GetGridEntity(idx)
                    Isaac.Spawn(EntityType.ENTITY_PICKUP, PickupVariant.PICKUP_COIN, 0, e.Position, Vector(0, 0), nil)
                end
                runData.buttons = {}
            end
        else --Leaving the anti-softlock early is not allowed
            Isaac.ExecuteCommand("goto s.default.2")
        end
    end
    local room = game:GetLevel():GetCurrentRoomDesc()
    if (room.Data.Name == "Troll Room 1") then
        local pit = Isaac.FindByType(EntityType.ENTITY_PITFALL, -1, -1)
        local dime = Isaac.FindByType(EntityType.ENTITY_PICKUP, PickupVariant.PICKUP_COIN, CoinSubType.COIN_DIME)
        for _, coin in ipairs(dime) do
            coin.EntityCollisionClass = EntityCollisionClass.ENTCOLL_NONE
            for player in Utils:iterPlayers() do
                local c = coin.Position
                local p = player.Position
                local dist = p:Distance(c)
                if dist < 40 then
                    coin.Velocity = Vector(50 - dist, 0)
                end
            end
            if coin.Position.X >= 548 then
                coin:SetColor(Color(coin.Color.R, coin.Color.G, coin.Color.B, coin.Color.A - 0.1, 0, 0, 0), 0, 1, false, false)
                coin.Velocity = Vector(0, 0)
                coin.Position = Vector(548, coin.Position.Y + 1)
                if coin.Color.A <= 0 then
                    coin:Remove()
                end
            else
                if coin.Velocity.Y ~= 0 then
                    coin.Velocity = Vector(coin.Velocity.X, 0)
                end
                if coin.Velocity.X < 0 then
                    coin.Velocity = Vector(0, 0)
                end
            end
        end
        local reset = true
        for player in Utils:iterPlayers() do
            if player.Position.X > 300 then
                reset = false
            end
        end
        if reset then
            if #pit < 1 then
                Isaac.Spawn(EntityType.ENTITY_PITFALL, 0, 0, Vector(548, 280), Vector(0, 0), nil)
            end
            if #dime < 1 then
                Isaac.Spawn(EntityType.ENTITY_PICKUP, PickupVariant.PICKUP_COIN, CoinSubType.COIN_DIME, Vector(520, 280), Vector(0, 0), nil)
            end
        end
    end
end)

-- Actives are disabled while the anti-softlock is active
function mod:disableActives()
    if runData.buttons and #runData.buttons > 0 then
        sfx:Play(SoundEffect.SOUND_THUMBS_DOWN)
        return true
    end
    return false
end

mod:AddCallback(ModCallbacks.MC_PRE_USE_ITEM, function(_, item)
    return mod:disableActives()
end)

-- ITEM Things Carl Has Learned

local tips = {
    "Always take Cursed Eye|for content",
    "Anarchist Cookbook|saves runs",
    "Azazel is the|worst character",
    "Blood Oath|is a free damage up",
    "Bloat is completely|fair and balanced",
    "Brimstone just a|worse Monstro's Lung",
    "Bumbo want coin!",
    "Choiche is an illusion",
    "Coins always matter|late game",
    "Curse of the Tower|provides free bombs",
    "Damage is overrated",
    "Devil Deals are always|worth it",
    "Don't get hit",
    "D4 is just a better D6",
    "External Item Descriptions|is for losers",
    "Guppy's Collar always|works in some cases",
    "Hosts aren't annoying|at all",
    "Larl bad",
    "Like and subscribe",
    "Marked is a free win",
    "Ouroboros Worm is|the best trinket",
    "PHD is useless",
    "Please just do better",
    "Red Hearts are overrated",
    "RNG is fair",
    "Robot Head best item",
    "Secret Rooms are|a waste of time",
    "Shooting tears is|completely optional",
    "Slot Machines can|actually pay out",
    "Soy Milk is DPS up",
    "The most important stat|is luck",
    "The only HP that matters|is the last one",
    "The Wiz doubles your|tear output",

    -- Special tips (with effects)
    "://special_hold"
}

function mod:showTip()
    local txt = Utils:pick(tips)
    if txt == "://special_hold" then
        local dir = ""
        for player in Utils:iterPlayers() do
            local pos = player.Position
            Isaac.Spawn(EntityType.ENTITY_BOMB, BombVariant.BOMB_TROLL, 1, pos, Vector(0, 0), player)
            if dir == "" then
                if game:GetRoom():IsPositionInRoom(pos + Vector(50, 0), 0) and game:GetRoom():GetGridCollisionAtPos(pos + Vector(50, 0)) == GridCollisionClass.COLLISION_NONE then
                    dir = "right"
                else
                    dir = "left"
                end
            end
        end
        txt = "Hold " .. dir .. " at now"
    end
    if txt:find("|") then
        local left, right = txt:match("(.+)|(.+)")
        Game():GetHUD():ShowFortuneText(left, right)
    else
        Game():GetHUD():ShowFortuneText(txt)
    end
    sfx:Play(SoundEffect.SOUND_FORTUNE_COOKIE)
    return true
end

mod:AddCallback(ModCallbacks.MC_USE_ITEM, mod.showTip, learnedList)

-- SECTION Commands

function mod:onCmd(command, args)
    if command == "carlmod" or command == "carl" then
        local cleared = false
        if runData.buttons and #runData.buttons > 0 then
            runData.buttons = {}
            cleared = true
        end
        if args == "anti" then
            mod:useAntiSoftlock()
        elseif args == "items" then
            Isaac.ExecuteCommand("goto s.default." .. itemRoom)
        elseif args == "troll 1" then
            Isaac.ExecuteCommand("goto s.default." .. trollRoom1)
        else
            if cleared then
                print("Disabled anti-softlock")
            else
                print("Unknown command: " .. args)
            end
        end
    end
end

mod:AddCallback(ModCallbacks.MC_EXECUTE_CMD, mod.onCmd)