-- VoxSeas Script Interface Avançada (Delta Mobile)
-- Versão: 2025-07-26 V5 - Depuração do FarmLevel
-- Baseado em informações coletadas com o usuário

-- Variáveis de controle do farm (controladas pelo console do Delta)
local AutoFarmLevel = false
local FarmBoss = false
local LocalizarFrutas = false
local TeleportarIlha = false

-- Serviços do Roblox
local Players = game:GetService("Players")
local Workspace = game:GetService("Workspace")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local UserInputService = game:GetService("UserInputService")

local LocalPlayer = Players.LocalPlayer
local Character = nil
local Humanoid = nil
local HumanoidRootPart = nil

-- Função para inicializar Character, Humanoid, HumanoidRootPart de forma segura
local function InitializePlayerComponents()
    repeat
        task.wait()
        Character = LocalPlayer.Character
    until Character ~= nil

    local success, hum = pcall(function() return Character:WaitForChild("Humanoid", 10) end)
    if success and hum then
        Humanoid = hum
    else
        print("InitializePlayerComponents: Falha ao encontrar Humanoid. Tentando novamente...")
        return false
    end

    local success2, hrp = pcall(function() return Character:WaitForChild("HumanoidRootPart", 10) end)
    if success2 and hrp then
        HumanoidRootPart = hrp
    else
        print("InitializePlayerComponents: Falha ao encontrar HumanoidRootPart. Tentando novamente...")
        return false
    end

    print("Componentes do jogador inicializados com sucesso!")
    return true
end

-- Conecta a função ao evento CharacterAdded
LocalPlayer.CharacterAdded:Connect(function(newCharacter)
    Character = newCharacter
    InitializePlayerComponents()
end)

-- Chame uma vez para o personagem inicial, caso já esteja carregado.
task.spawn(function()
    if not InitializePlayerComponents() then
        print("Problema na inicialização inicial do personagem. Reinicie o script ou o jogo se persistir.")
    end
end)


-- Funções Auxiliares (com verificações adicionais)
local function Teleport(position)
    if HumanoidRootPart and Humanoid then
        Humanoid.Sit = true
        HumanoidRootPart.CFrame = CFrame.new(position)
        task.wait(0.5)
        Humanoid.Sit = false
    else
        print("Teleporte: Componentes do jogador não disponíveis.")
    end
end

local function GetNearestInstance(parent, name, maxDistance)
    local nearestInstance = nil
    local minDistance = maxDistance or math.huge

    if not parent or not HumanoidRootPart then return nil, minDistance end

    for _, obj in ipairs(parent:GetChildren()) do
        if obj:IsA("Model") and obj.Name == name and obj:FindFirstChild("HumanoidRootPart") and obj:FindFirstChild("Humanoid") then
            if obj.HumanoidRootPart then
                local distance = (HumanoidRootPart.Position - obj.HumanoidRootPart.Position).Magnitude
                if distance < minDistance then
                    minDistance = distance
                    nearestInstance = obj
                end
            end
        elseif obj:IsA("Part") and obj.Name == name then
            if obj then
                local distance = (HumanoidRootPart.Position - obj.Position).Magnitude
                if distance < minDistance then
                    minDistance = distance
                    nearestInstance = obj
                end
            end
        end
    end
    return nearestInstance, minDistance
end

local function FindMobAround(mobName)
    local foundMob = nil
    local shortestDistance = math.huge

    if not HumanoidRootPart then return nil end

    local searchAreas = {
        Workspace,
        Workspace:FindFirstChild("Playability") and Workspace.Playability:FindFirstChild("Enemies") and Workspace.Playability.Enemies:FindFirstChild("Orange Town") or nil
    }
    
    for _, area in ipairs(searchAreas) do
        if area then
            for _, obj in ipairs(area:GetChildren()) do
                if obj:IsA("Model") and obj:FindFirstChild("HumanoidRootPart") and obj:FindFirstChild("Humanoid") then
                    local originalNameValue = obj:FindFirstChild("OriginalName")
                    if originalNameValue and originalNameValue:IsA("StringValue") and originalNameValue.Value == mobName then
                        if obj.HumanoidRootPart then
                            local distance = (HumanoidRootPart.Position - obj.HumanoidRootPart.Position).Magnitude
                            if distance < shortestDistance then
                                shortestDistance = distance
                                foundMob = obj
                            end
                        end
                    elseif obj.Name == mobName then
                        if obj.HumanoidRootPart then
                            local distance = (HumanoidRootPart.Position - obj.HumanoidRootPart.Position).Magnitude
                            if distance < shortestDistance then
                                shortestDistance = distance
                                foundMob = obj
                            end
                        end
                    end
                end
            end
        end
    end
    return foundMob
end


-- FUNÇÃO GETQUESTINFO (sem alterações)
function GetQuestInfo()
    local player = Players.LocalPlayer
    local playerGui = player:FindFirstChild("PlayerGui")

    if not playerGui then
        return nil, 0, 0
    end

    local questGui = playerGui:FindFirstChild("MainUI")
    if not questGui then
        return nil, 0, 0
    end

    local currentQuestFrame = questGui:FindFirstChild("CurrentQuest")
    if not currentQuestFrame then
        return nil, 0, 0
    end

    local targetNameLabel = currentQuestFrame:FindFirstChild("Title")
    local progressLabel = currentQuestFrame:FindFirstChild("Count")

    if not targetNameLabel or not progressLabel then
        return nil, 0, 0
    end

    local mobName = targetNameLabel.Text or ""
    local progressText = progressLabel.Text or ""

    local current = 0
    local required = 0

    local currentStr, requiredStr = string.match(progressText, "(%d+)/(%d+)")
    if currentStr and requiredStr then
        current = tonumber(currentStr)
        required = tonumber(requiredStr)
    end

    if mobName ~= "" and required > 0 then
        print(string.format("Missão Detectada: Alvo: '%s', Progresso: %d/%d", mobName, current, required))
        return mobName, current, required
    end

    return nil, 0, 0
end

-- FUNÇÃO FARMLEVEL - ATUALIZADA com mais logs de depuração
function FarmLevel()
    print("FarmLevel: Iniciando ciclo da função.")

    if not Humanoid or not HumanoidRootPart or not Character then
        print("FarmLevel: Componentes do jogador não prontos. Aguardando...")
        task.wait(1)
        return
    end

    local playerLvl = LocalPlayer.leaderstats and LocalPlayer.leaderstats.Level and LocalPlayer.leaderstats.Level.Value or 0
    print("FarmLevel: Nível do jogador detectado: " .. playerLvl)

    if playerLvl == 0 then
        print("FarmLevel: Não foi possível obter o nível do jogador. Verifique 'leaderstats.Level'.")
        return
    end

    local npcName = nil
    local npcCoords = nil
    local targetMobName = nil

    if playerLvl >= 125 and playerLvl < 180 then
        npcName = "Joy Pirate Hunter"
        npcCoords = Vector3.new(-687, -412, 22.78)
        targetMobName = "Pirate Officer"
        print("FarmLevel: Configuração de missão para o nível " .. playerLvl .. ": NPC: " .. npcName .. ", Mob: " .. targetMobName)
    else
        print("FarmLevel: Nível do jogador (" .. playerLvl .. ") não corresponde a nenhuma configuração de missão conhecida (ex: 125-179).")
        -- Se o nível não estiver no range, o script vai parar aqui para o farm de nível.
        return
    end

    if not npcName or not npcCoords or not targetMobName then
        print("FarmLevel: Configuração de missão para o nível " .. playerLvl .. " não encontrada ou incompleta (Variáveis nulas).")
        return
    end

    local mobNameOnGui, currentQuestProgress, requiredQuestProgress = GetQuestInfo()
    print(string.format("FarmLevel: Informações da GUI: Mob: '%s', Progresso: %d/%d", mobNameOnGui or "N/A", currentQuestProgress, requiredQuestProgress))


    if mobNameOnGui ~= targetMobName or (currentQuestProgress == 0 and requiredQuestProgress == 0) then
        print("FarmLevel: Missão atual não corresponde ou já foi concluída/não iniciada. Tentando pegar a missão correta.")
        
        if (HumanoidRootPart.Position - npcCoords).Magnitude > 20 then
            print("FarmLevel: Teleportando para o NPC: " .. npcName .. " em " .. tostring(npcCoords))
            Teleport(npcCoords)
            task.wait(1)
        end

        local npcInstance = GetNearestInstance(Workspace:FindFirstChild("NPCs") and Workspace.NPCs:FindFirstChild("Orange Town") or Workspace, npcName, 30)
        
        if npcInstance and npcInstance:FindFirstChild("HumanoidRootPart") then
            print("FarmLevel: NPC '" .. npcName .. "' encontrado. Movendo-se para ele.")
            Humanoid:MoveTo(npcInstance.HumanoidRootPart.Position)
            Humanoid.MoveToFinished:Wait(2)

            local interactRemote = ReplicatedStorage:FindFirstChild("Remotes") and ReplicatedStorage.Remotes:FindFirstChild("InteractNPC")
            if not interactRemote then
                interactRemote = ReplicatedStorage:FindFirstChild("Events") and ReplicatedStorage.Events:FindFirstChild("Interact")
            end

            if interactRemote then
                print("FarmLevel: Tentando interagir com o NPC: " .. npcName .. " via RemoteEvent.")
                interactRemote:FireServer(npcInstance)
                task.wait(1)
            else
                print("FarmLevel: RemoteEvent de interação com NPC não encontrado. Pode ser necessário um clique ou tecla. Verifique logs do console para 'Interact'.")
            end
            task.wait(2)
        else
            print("FarmLevel: NPC '" .. npcName .. "' não encontrado para pegar a missão. Verifique as coordenadas e o nome do NPC ou se ele está spawnado.")
            task.wait(5)
        end
        return
    end

    -- Se a missão estiver ativa e correta
    print("FarmLevel: Missão correta (" .. targetMobName .. ") ativa. Procurando mob para farmar.")
    local mobInstance = FindMobAround(targetMobName)

    if mobInstance and mobInstance:FindFirstChild("Humanoid") and mobInstance.Humanoid.Health > 0 then
        print("FarmLevel: Mob '" .. mobInstance.Name .. "' encontrado. Vida: " .. mobInstance.Humanoid.Health)
        
        if (HumanoidRootPart.Position - mobInstance.HumanoidRootPart.Position).Magnitude > 10 then
            print("FarmLevel: Movendo para perto do mob.")
            Humanoid:MoveTo(mobInstance.HumanoidRootPart.Position)
            Humanoid.MoveToFinished:Wait(2)
        end

        local attackEvent = ReplicatedStorage:FindFirstChild("BetweenSides") 
            and ReplicatedStorage.BetweenSides:FindFirstChild("Remotes")
            and ReplicatedStorage.BetweenSides.Remotes:FindFirstChild("Events")
            and ReplicatedStorage.BetweenSides.Remotes.Events:FindFirstChild("SkillEvent")

        if attackEvent then
            print("FarmLevel: Atacando " .. mobInstance.Name .. " com SkillEvent:FireServer(mobInstance.HumanoidRootPart)")
            attackEvent:FireServer(mobInstance.HumanoidRootPart)
            
            task.wait(0.1) 
        else
            print("FarmLevel: RemoteEvent de ataque (SkillEvent) não encontrado. Verifique o caminho ou se ele existe.")
            task.wait(1)
        end
    else
        print("FarmLevel: Nenhum mob '" .. targetMobName .. "' encontrado ou já morto. Aguardando respawn/próximo mob...")
        task.wait(2)
    end
end

-- Loop principal do Farm
task.spawn(function()
    while task.wait(0.5) do
        if AutoFarmLevel then
            FarmLevel()
        end
    end
end)

-- Loop para Teleporte
task.spawn(function()
    while task.wait(1) do
        if TeleportarIlha then
            print("Teleportando para a ilha de teste...")
            Teleport(Vector3.new(0, 500, 0))
            TeleportarIlha = false
        end
    end
end)

print("Script VoxSeas carregado! Use o console do Delta para controlar.")
print("Verifique o Roblox Console (o da esquerda) para logs da missão e do farm.")
print("Comandos úteis para o console do Delta:")
print("  AutoFarmLevel = true  -- Para iniciar o auto-farm")
print("  AutoFarmLevel = false -- Para parar o auto-farm")
print("  TeleportarIlha = true -- Para testar o teleporte (ajuste a coordenada no script se necessário)")
print("  print(game.Players.LocalPlayer.Character.HumanoidRootPart.Position) -- Para pegar sua posição atual")
