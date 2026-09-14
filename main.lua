-- =====================================================
-- BOT ROBLOX - STEAL AN EGG (VERSION AUTO CHAT)
-- Écoute AUTOMATIQUEMENT le chat de tous les joueurs
-- Détecte les messages mentionnant des œufs rares
-- Extrait le NOM et la ZONE automatiquement
-- =====================================================

local Players = game:GetService("Players")
local RunService = game:GetService("RunService")
local UserInputService = game:GetService("UserInputService")

local player = Players.LocalPlayer
local character = player.Character or player.CharacterAdded:Wait()
local humanoidRootPart = character:WaitForChild("HumanoidRootPart")

-- =====================================================
-- CONFIGURATION
-- =====================================================

local CONFIG = {
    TAPIS_POSITION = Vector3.new(0, 5, 0),
    DETECT_RADIUS = 300,
    DEBUG = true,
}

-- =====================================================
-- VARIABLES GLOBALES
-- =====================================================

local isHunting = false
local targetEggName = nil
local targetPosition = nil
local targetEggPart = nil
local onTapis = true
local lastHuntTime = 0

-- =====================================================
-- FONCTIONS
-- =====================================================

local function log(message)
    if CONFIG.DEBUG then
        print("[🤖 STEAL-EGG-AUTO] " .. message)
    end
end

local function distance(pos1, pos2)
    return (pos1 - pos2).Magnitude
end

local function extractEggInfo(message)
    -- Extraire automatiquement le NOM de l'œuf et la ZONE du message du chat
    
    log("📝 Analyse du message: " .. message)
    
    -- Vérifier si c'est un message sur un œuf rare
    local lowerMsg = message:lower()
    if not (lowerMsg:match("rare") and lowerMsg:match("egg")) and 
       not lowerMsg:match("oeufs?%s+rare") then
        return nil
    end
    
    log("✅ Message d'œuf rare détecté!")
    
    local eggInfo = {
        name = nil,
        position = nil
    }
    
    -- ============================================
    -- EXTRAIRE LE NOM DE L'ŒUF
    -- ============================================
    
    -- Pattern 1: "egg: EggRare" ou "egg: Egg_Gold"
    eggInfo.name = message:match("egg[%s:]*([%w_]+)")
    if eggInfo.name then
        log("📛 Nom trouvé (pattern 1): " .. eggInfo.name)
        if not eggInfo.name:match("^Egg") then
            eggInfo.name = "Egg" .. eggInfo.name
        end
    end
    
    -- Pattern 2: nom entre guillemets "EggRare"
    if not eggInfo.name then
        eggInfo.name = message:match('"([^"]+)"')
        if eggInfo.name then
            log("📛 Nom trouvé (pattern 2): " .. eggInfo.name)
        end
    end
    
    -- Pattern 3: œuf rare <nom>
    if not eggInfo.name then
        eggInfo.name = message:match("œuf%s+rare%s+([%w_]+)")
        if eggInfo.name then
            log("📛 Nom trouvé (pattern 3): " .. eggInfo.name)
            if not eggInfo.name:match("^Egg") then
                eggInfo.name = "Egg" .. eggInfo.name
            end
        end
    end
    
    -- ============================================
    -- EXTRAIRE LES COORDONNÉES
    -- ============================================
    
    -- Pattern 1: "x, y, z" ou "x,y,z"
    local x, y, z = message:match("([%-]?%d+)[,%s]+([%-]?%d+)[,%s]+([%-]?%d+)")
    if x and y and z then
        eggInfo.position = Vector3.new(tonumber(x), tonumber(y), tonumber(z))
        log("📍 Position trouvée: (" .. x .. ", " .. y .. ", " .. z .. ")")
    end
    
    -- Pattern 2: "zone: X Y Z"
    if not eggInfo.position then
        x, y, z = message:match("zone[%s:]+([%-]?%d+)%s+([%-]?%d+)%s+([%-]?%d+)")
        if x and y and z then
            eggInfo.position = Vector3.new(tonumber(x), tonumber(y), tonumber(z))
            log("📍 Zone trouvée: (" .. x .. ", " .. y .. ", " .. z .. ")")
        end
    end
    
    -- Si pas de position exacte, chercher une zone/région
    if not eggInfo.position then
        if lowerMsg:match("spawn") then
            eggInfo.position = Vector3.new(50, 10, 50)
            log("📍 Zone: Spawn")
        elseif lowerMsg:match("cave") then
            eggInfo.position = Vector3.new(100, 10, 100)
            log("📍 Zone: Cave")
        elseif lowerMsg:match("mountain") or lowerMsg:match("montagne") then
            eggInfo.position = Vector3.new(150, 50, 150)
            log("📍 Zone: Montagne")
        end
    end
    
    -- Vérifier qu'on a trouvé au moins le nom
    if not eggInfo.name then
        log("❌ Impossible d'extraire le nom de l'œuf")
        return nil
    end
    
    log("🎯 Infos extraites: " .. eggInfo.name .. " @ " .. tostring(eggInfo.position))
    return eggInfo
end

local function findEggByName(eggName, searchArea)
    -- Chercher l'œuf avec le NOM EXACT dans la zone
    local workspace = game:GetService("Workspace")
    
    local success, allParts = pcall(function()
        return workspace:FindPartBoundsInRadius(searchArea, CONFIG.DETECT_RADIUS)
    end)
    
    if not success then
        log("⚠️ Erreur de détection")
        return nil
    end
    
    -- Match EXACT
    for _, part in ipairs(allParts) do
        if part.Name == eggName then
            log("✅ Œuf trouvé: " .. part.Name .. " @ " .. tostring(part.Position))
            return part
        end
    end
    
    -- Match partiel (case-insensitive)
    for _, part in ipairs(allParts) do
        if part.Name:lower():match(eggName:lower()) then
            log("⚠️ Match partiel: " .. part.Name)
            return part
        end
    end
    
    log("❌ Œuf '" .. eggName .. "' non trouvé")
    return nil
end

local function moveToPosition(targetPos)
    local humanoid = character:FindFirstChild("Humanoid")
    if humanoid then
        humanoid:MoveTo(targetPos)
    end
end

local function returnToTapis()
    if not onTapis then
        log("↩️ Retour au tapis")
        moveToPosition(CONFIG.TAPIS_POSITION)
        onTapis = true
        isHunting = false
        targetEggName = nil
        targetPosition = nil
        targetEggPart = nil
    end
end

-- =====================================================
-- ÉCOUTE AUTOMATIQUE DU CHAT
-- =====================================================

local function setupChatListener()
    log("🔧 Initialisation de l'écoute du chat...")
    
    -- Chercher les remotes de chat
    local success, err = pcall(function()
        local ReplicatedStorage = game:GetService("ReplicatedStorage")
        
        -- Si le jeu utilise un système de chat personnalisé
        if ReplicatedStorage:FindFirstChild("DefaultChatSystemChatEvents") then
            local chatEvents = ReplicatedStorage:FindFirstChild("DefaultChatSystemChatEvents")
            local messagePosted = chatEvents:FindFirstChild("OnMessageDoneFiltering")
            
            if messagePosted then
                messagePosted.OnClientEvent:Connect(function(message)
                    log("💬 Chat: " .. message.Message)
                    
                    local eggInfo = extractEggInfo(message.Message)
                    if eggInfo then
                        isHunting = true
                        targetEggName = eggInfo.name
                        targetPosition = eggInfo.position
                        targetEggPart = nil
                        lastHuntTime = tick()
                        log("🚨 CHASSE LANCÉE!")
                    end
                end)
                
                log("✅ Écoute du chat activée (DefaultChatSystem)")
            end
        end
    end)
    
    -- Alternative: écouter via Chatted signal
    if not success or not chat_listener_active then
        log("⚠️ Utilisation de la méthode alternative...")
        
        for _, plr in ipairs(Players:GetPlayers()) do
            if plr ~= player then
                plr.Chatted:Connect(function(message)
                    log("💬 [" .. plr.Name .. "]: " .. message)
                    
                    local eggInfo = extractEggInfo(message)
                    if eggInfo then
                        isHunting = true
                        targetEggName = eggInfo.name
                        targetPosition = eggInfo.position
                        targetEggPart = nil
                        lastHuntTime = tick()
                        log("🚨 CHASSE LANCÉE!")
                    end
                end)
            end
        end
        
        -- Connecter les nouveaux joueurs
        Players.PlayerAdded:Connect(function(newPlayer)
            if newPlayer ~= player then
                newPlayer.Chatted:Connect(function(message)
                    log("💬 [" .. newPlayer.Name .. "]: " .. message)
                    
                    local eggInfo = extractEggInfo(message)
                    if eggInfo then
                        isHunting = true
                        targetEggName = eggInfo.name
                        targetPosition = eggInfo.position
                        targetEggPart = nil
                        lastHuntTime = tick()
                        log("🚨 CHASSE LANCÉE!")
                    end
                end)
            end
        end)
        
        log("✅ Écoute du chat activée (Chatted events)")
    end
end

-- =====================================================
-- BOUCLE PRINCIPALE
-- =====================================================

local huntLoop = RunService.Heartbeat:Connect(function()
    if not character or not character:FindFirstChild("Humanoid") then
        return
    end
    
    if character:FindFirstChild("Humanoid").Health <= 0 then
        return
    end
    
    if isHunting and targetEggName and targetPosition then
        -- Sécurité: timeout après 60 secondes
        if tick() - lastHuntTime > 60 then
            log("⏱️ Timeout de chasse")
            returnToTapis()
            return
        end
        
        -- Étape 1: Se diriger vers la zone
        local distToZone = distance(humanoidRootPart.Position, targetPosition)
        
        if distToZone > 15 then
            moveToPosition(targetPosition)
            return
        end
        
        -- Étape 2: Chercher l'œuf dans la zone
        if not targetEggPart or not targetEggPart.Parent then
            targetEggPart = findEggByName(targetEggName, targetPosition)
        end
        
        if targetEggPart then
            local dist = distance(humanoidRootPart.Position, targetEggPart.Position)
            moveToPosition(targetEggPart.Position)
            onTapis = false
            
            -- Vérifier si on l'a pris
            if dist < 8 then
                log("💰 ŒUFF " .. targetEggName .. " VOLÉ! ✨")
                isHunting = false
                targetEggName = nil
                targetPosition = nil
                targetEggPart = nil
                wait(2)
                returnToTapis()
            end
        else
            log("❌ Œuf non trouvé à la zone")
            isHunting = false
            targetEggName = nil
            targetPosition = nil
            returnToTapis()
        end
    else
        if not onTapis then
            returnToTapis()
        end
    end
end)

-- =====================================================
-- CONTRÔLES CLAVIER
-- =====================================================

UserInputService.InputBegan:Connect(function(input, gameProcessed)
    if gameProcessed then return end
    
    if input.KeyCode == Enum.KeyCode.P then
        if huntLoop.Connected then
            huntLoop:Disconnect()
            log("❌ Bot DÉSACTIVÉ")
        else
            huntLoop = RunService.Heartbeat:Connect(function() end)
            log("✅ Bot ACTIVÉ")
        end
    end
    
    if input.KeyCode == Enum.KeyCode.H then
        returnToTapis()
        log("🆘 Annulation")
    end
end)

-- =====================================================
-- INITIALISATION
-- =====================================================

player.CharacterAdded:Connect(function(newCharacter)
    character = newCharacter
    humanoidRootPart = character:WaitForChild("HumanoidRootPart")
    onTapis = true
    log("🔄 Personnage régénéré")
end)

-- Configurer l'écoute du chat
setupChatListener()

log("✅ Bot chargé et prêt!")
log("━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━")
log("📢 Écoute AUTOMATIQUE du chat")
log("━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━")
log("Format reconnus:")
log("  'Rare egg: EggRare 50,10,40'")
log("  'egg: EggGold at zone 100, 20, 50'")
log("  'Rare egg \"EggLegendary\" X: 75 Y: 15 Z: 30'")
log("")
log("Contrôles: P = On/Off | H = Annuler")
log("━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━")
