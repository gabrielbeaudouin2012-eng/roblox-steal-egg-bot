-- =====================================================
-- BOT ROBLOX - STEAL AN EGG
-- Reste sur le tapis sauf si course détectée
-- Vole les œufs rares automatiquement
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
    -- Positions
    TAPIS_POSITION = Vector3.new(0, 5, 0),  -- Ajuster selon votre map
    SPAWN_EGGS = Vector3.new(50, 5, 50),    -- Zone de spawn des œufs
    
    -- Détection
    DETECT_RADIUS = 100,                    -- Rayon de détection des œufs
    RARE_EGG_COLORS = {                     -- Couleurs des œufs rares
        Color3.fromRGB(255, 215, 0),        -- Or
        Color3.fromRGB(75, 0, 130),         -- Indigo
        Color3.fromRGB(255, 20, 147),       -- Rose foncé
    },
    
    -- Vitesses
    WALK_SPEED = 16,
    SPRINT_SPEED = 25,
    
    -- Seuils
    RARE_EGG_VALUE = 500,                   -- Valeur minimale d'un œuf rare
    RACE_TIMEOUT = 30,                      -- Timeout de course en secondes
}

-- =====================================================
-- VARIABLES GLOBALES
-- =====================================================

local isRacing = false
local raceEndTime = 0
local lastEggTarget = nil
local onTapis = true

-- =====================================================
-- FONCTIONS UTILITAIRES
-- =====================================================

local function distance(pos1, pos2)
    return (pos1 - pos2).Magnitude
end

local function isRareEgg(part)
    -- Vérifier si c'est un œuf
    if not part or not part:IsA("BasePart") then return false end
    if not part.Name:match("Egg") and not part.Name:match("egg") then return false end
    
    -- Vérifier la couleur (œuf rare)
    local partColor = part.Color
    for _, rareColor in ipairs(CONFIG.RARE_EGG_COLORS) do
        local diff = math.abs(partColor.R - rareColor.R) + 
                     math.abs(partColor.G - rareColor.G) + 
                     math.abs(partColor.B - rareColor.B)
        if diff < 0.2 then
            return true
        end
    end
    
    return false
end

local function detectNearbyEggs()
    local found = {}
    local workspace = game:GetService("Workspace")
    
    for _, part in ipairs(workspace:FindPartBoundsInRadius(humanoidRootPart.Position, CONFIG.DETECT_RADIUS)) do
        if isRareEgg(part) then
            table.insert(found, part)
        end
    end
    
    -- Trier par distance
    table.sort(found, function(a, b)
        return distance(humanoidRootPart.Position, a.Position) < 
               distance(humanoidRootPart.Position, b.Position)
    end)
    
    return found
end

local function detectRace()
    -- Vérifier s'il y a une course active (joueurs qui se déplacent rapidement)
    local playersMoving = 0
    
    for _, p in ipairs(Players:GetPlayers()) do
        if p ~= player and p.Character then
            local otherHRP = p.Character:FindFirstChild("HumanoidRootPart")
            if otherHRP then
                local velocity = otherHRP.AssemblyLinearVelocity.Magnitude
                if velocity > 20 then  -- Seuil de vitesse haute
                    playersMoving = playersMoving + 1
                end
            end
        end
    end
    
    return playersMoving > 0
end

local function moveToPosition(targetPos)
    -- Utiliser des humanoid pour se déplacer
    local humanoid = character:FindFirstChild("Humanoid")
    if humanoid then
        humanoid:MoveTo(targetPos)
    end
end

local function returnToTapis()
    if not onTapis then
        print("[BOT] Retour au tapis...")
        moveToPosition(CONFIG.TAPIS_POSITION)
        onTapis = true
    end
end

local function chaseEgg(eggPart)
    if not eggPart or not eggPart.Parent then
        lastEggTarget = nil
        return false
    end
    
    print("[BOT] Chasse d'un œuf rare détecté!")
    moveToPosition(eggPart.Position)
    onTapis = false
    lastEggTarget = eggPart
    return true
end

-- =====================================================
-- BOUCLE PRINCIPALE
-- =====================================================

local mainLoop = RunService.Heartbeat:Connect(function()
    -- Vérifier si le joueur est vivant
    if not character or character:FindFirstChild("Humanoid").Health <= 0 then
        return
    end
    
    -- Détecter si une course est en cours
    if detectRace() then
        isRacing = true
        raceEndTime = tick() + CONFIG.RACE_TIMEOUT
        print("[BOT] Course détectée! Attente...")
        returnToTapis()
    elseif isRacing and tick() < raceEndTime then
        -- Course toujours active, rester sur le tapis
        returnToTapis()
    else
        -- Pas de course, chercher les œufs rares
        isRacing = false
        local eggs = detectNearbyEggs()
        
        if #eggs > 0 then
            chaseEgg(eggs[1])
        else
            -- Aucun œuf détecté, revenir au tapis
            returnToTapis()
        end
    end
end)

-- =====================================================
-- GESTION DES ENTRÉES CLAVIER
-- =====================================================

UserInputService.InputBegan:Connect(function(input, gameProcessed)
    if gameProcessed then return end
    
    if input.KeyCode == Enum.KeyCode.P then
        -- Activer/Désactiver le bot
        if mainLoop.Connected then
            mainLoop:Disconnect()
            print("[BOT] Bot désactivé")
        else
            mainLoop = RunService.Heartbeat:Connect(function()
                -- Redémarrer la boucle
            end)
            print("[BOT] Bot activé")
        end
    end
    
    if input.KeyCode == Enum.KeyCode.H then
        -- Retour d'urgence au tapis
        returnToTapis()
        print("[BOT] Retour d'urgence au tapis")
    end
end)

-- =====================================================
-- NETTOYAGE
-- =====================================================

player.CharacterAdded:Connect(function(newCharacter)
    character = newCharacter
    humanoidRootPart = character:WaitForChild("HumanoidRootPart")
    onTapis = true
    lastEggTarget = nil
end)

print("[BOT] Bot chargé! Appuyez sur P pour activer/désactiver, H pour retour d'urgence")
