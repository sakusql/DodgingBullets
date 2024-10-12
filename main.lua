-- Variables du jeu
local player
local balls = {}
local gravity = 500
local jumpStrength = -300
local isJumping = false
local score = 0
local bestScore = 0
local lives = 3
local gameOver = false
local heartImages = {}
local heartBrokenImage = nil
local debugMode = false  -- Activer ou désactiver l'affichage des hitboxes

-- Variables pour les effets de dommages
local damageEffectDuration = 0.2  -- Durée de l'effet de dommages
local damageEffectTimer = 0  -- Timer pour l'effet de dommages
local damageEffectActive = false  -- Indicateur d'activation de l'effet
local shakeDuration = 0.2  -- Durée de la vibration
local shakeTimer = 0  -- Timer pour la vibration
local shakeMagnitude = 5  -- Amplitude de la vibration
local screenOffsetX = 0  -- Décalage X pour la vibration

-- Charger les sons
local backgroundMusic = love.audio.newSource("theme.mp3", "stream") 
local gameOverMusic = love.audio.newSource("gameover.mp3", "static")
local damageSound = love.audio.newSource("damage_taken.mp3", "static")

-- Variables pour les vagues
local wave = 1
local waveDuration = {15, 10, 5}  -- Durée pour chaque vague : vague 1 (long), vague 2 (moyen), vague 3 (rapide)
local timer = 0
local spawnRate = 1  -- Taux de génération initial des boules (vague 1 lente)
local spawnTimer = 0
local ballsSpawned = 0

-- Variables pour les boules
local ballsPerWave = 10 -- Nombre initial de boules pour la première vague (facile)
local ballSpeed = 100   -- Vitesse initiale des boules (vague 1 lente)
local difficultyIncreaseRate = 1.5 -- Facteur d'augmentation de la difficulté (vitesse, nombre de boules)

-- Variables de sprint
local sprintActive = false
local sprintTimer = 0
local sprintDuration = 2  -- Durée du sprint en secondes
local sprintCooldown = 5   -- Temps de recharge après un sprint
local sprintRecharge = 0    -- Temps restant avant que le sprint puisse être utilisé à nouveau

function love.load()
    love.window.setTitle("Jeu de golmon en LUA by Saku")
    player = {
        dy = 0,  -- Initialisez la variable dy ici
        x = 400,
        y = 500,
        width = 200,
        height = 200,
        speed = 200,
        direction = "right",
        image_right = love.graphics.newImage("personnage_droite.png"),
        image_left = love.graphics.newImage("personnage_gauche.png"),
        jump_right = love.graphics.newImage("saut_droit.png"),
        jump_left = love.graphics.newImage("saut_gauche.png"),
        hitbox = { x = 400, y = 500, width = 50, height = 50 }
    }

    for i = 1, 3 do
        heartImages[i] = love.graphics.newImage("coeur.png")  -- Assurez-vous que les images de cœur existent
    end
    heartBrokenImage = love.graphics.newImage("coeurbrisé.png")  -- Assurez-vous que l'image du cœur brisé existe

    love.audio.setVolume(0.5)  -- Réglez le volume de la musique
    backgroundMusic:play()  -- Jouez la musique d'arrière-plan
end

function love.update(dt)
    if not gameOver then
        -- Mise à jour du timer de vagues
        timer = timer + dt

        -- Gestion des vagues
        if wave <= #waveDuration then
            if timer >= waveDuration[wave] then
                wave = wave + 1
                timer = 0
                ballsSpawned = 0  -- Réinitialiser le compteur de boules générées
            end
        else
            -- Après la vague 3, on passe à la nouvelle vague toutes les 3 secondes
            if timer >= 3 then  -- 3 secondes pour la nouvelle vague
                wave = wave + 1
                timer = 0
                ballsSpawned = 0  -- Réinitialiser le compteur de boules générées

                -- Ajustements de difficulté pour chaque nouvelle vague
                ballsPerWave = ballsPerWave + 5  -- Augmente le nombre de boules par vague
                ballSpeed = ballSpeed + 50  -- Augmente la vitesse des boules
                spawnRate = math.max(0.1, spawnRate - 0.05)  -- Réduire le taux de spawn (minimum 0.1)
            end
        end

        -- Génération des boules
        spawnTimer = spawnTimer + dt
        if spawnTimer > spawnRate and ballsSpawned < ballsPerWave then
            spawnBall()
            spawnTimer = 0
            ballsSpawned = ballsSpawned + 1
        end

        -- Déplacement du joueur
        local playerSpeed = player.speed
        if love.keyboard.isDown("space") and sprintRecharge <= 0 then
            sprintActive = true
            playerSpeed = player.speed * 3
        end

        if sprintActive then
            sprintTimer = sprintTimer + dt
            if sprintTimer >= sprintDuration then
                sprintActive = false
                sprintRecharge = sprintCooldown
                sprintTimer = 0
            end
        else
            if sprintRecharge > 0 then
                sprintRecharge = sprintRecharge - dt
            end
        end

        if love.keyboard.isDown("left") then
            player.x = player.x - playerSpeed * dt
            player.direction = "left"
        elseif love.keyboard.isDown("right") then
            player.x = player.x + playerSpeed * dt
            player.direction = "right"
        end

        -- Empêcher le joueur de sortir de l'écran
        if player.x < 0 then
            player.x = 0
        elseif player.x + player.width > love.graphics.getWidth() then
            player.x = love.graphics.getWidth() - player.width
        end

        -- Gestion de la gravité
        player.dy = player.dy + gravity * dt
        player.y = player.y + player.dy * dt

        -- Mise à jour de la hitbox du joueur
        local offsetZ = 20
        player.hitbox.x = player.x + (player.width - player.hitbox.width) / 2
        player.hitbox.y = player.y + (player.height - player.hitbox.height) / 2 + offsetZ

        -- Vérifie si le joueur est au sol
        if player.y + player.height >= 600 then
            player.y = 600 - player.height
            player.dy = 0
            isJumping = false
        end

        -- Saut
        if love.keyboard.isDown("up") and not isJumping then
            player.dy = jumpStrength
            isJumping = true
        end

        -- Mise à jour des boules et vérification des collisions
        for i = #balls, 1, -1 do  -- Itération à l'envers
            local ball = balls[i]
            if ball then  -- Vérifie que 'ball' n'est pas nil
                ball.y = ball.y + ball.speed * dt

                -- Vérifier la collision entre le joueur et la boule
                if checkCollision(ball, player.hitbox) then
                    table.remove(balls, i)
                    lives = lives - 1
                    damageSound:play()  -- Joue le son des dégâts

                    -- Activer les effets
                    damageEffectActive = true
                    damageEffectTimer = damageEffectDuration
                    shakeTimer = shakeDuration
                end
                
                -- Vérifier si la boule est en dehors de l'écran
                if ball.y > love.graphics.getHeight() then
                    score = score + 1  -- Incrémente le score quand une boule est évitée
                    table.remove(balls, i)  -- Enlever la boule si elle est évitée
                end
            end
        end

        -- Gestion des effets de dommages et de vibration
if damageEffectActive then
    damageEffectTimer = damageEffectTimer - dt
    if damageEffectTimer <= 0 then
        damageEffectActive = false
        damageEffectTimer = 0
    end
end

-- Gestion de la vibration de l'écran
if shakeTimer > 0 then
    shakeTimer = shakeTimer - dt
    if shakeTimer > 0 then
        screenOffsetX = math.random(-shakeMagnitude, shakeMagnitude)
    else
        screenOffsetX = 0
    end
end

        -- Dessiner le joueur avec le décalage
        love.graphics.translate(screenOffsetX, 0)  -- Appliquer le décalage pour la vibration

        -- Vérifier si le joueur est à 0 vies
        if lives <= 0 then
            gameOver = true
            backgroundMusic:stop()  -- Arrête la musique d'arrière-plan
            gameOverMusic:play()  -- Joue la musique de game over
            if score > bestScore then
                bestScore = score
            end
        end

        -- Vérifier si la durée de la manche est écoulée
        if wave <= #waveDuration and timer >= waveDuration[wave] then
            wave = wave + 1
            timer = 0  -- Réinitialiser le timer pour la prochaine manche

            ballsPerWave = ballsPerWave + 1
            ballSpeed = ballSpeed + 50  -- Augmenter la vitesse des boules
        end
    end

    -- Gérer le game over
    if gameOver then
        if love.keyboard.isDown("escape") then
            resetGame()
        elseif love.keyboard.isDown("q") then
            love.event.quit()
        end
    end
end

function love.draw()
    -- Dessiner le ciel
    love.graphics.setColor(0.5, 0.7, 1)
    love.graphics.rectangle("fill", 0, 0, love.graphics.getWidth(), love.graphics.getHeight())

    -- Dessiner le sol
    love.graphics.setColor(0.2, 0.6, 0.2)
    love.graphics.rectangle("fill", 0, 550, love.graphics.getWidth(), 50)

    -- Dessiner le joueur
    love.graphics.setColor(1, 1, 1)  -- Réinitialiser la couleur à blanc
if damageEffectActive then
    love.graphics.setColor(1, 0, 0, 0.5)  -- Couleur rouge avec transparence pour l'effet de dommages
end

if isJumping then
    if player.direction == "right" then
        love.graphics.draw(player.jump_right, player.x + screenOffsetX, player.y, 0, player.width / player.jump_right:getWidth(), player.height / player.jump_right:getHeight())
    else
        love.graphics.draw(player.jump_left, player.x + screenOffsetX, player.y, 0, player.width / player.jump_left:getWidth(), player.height / player.jump_left:getHeight())
    end
else
    if player.direction == "right" then
        love.graphics.draw(player.image_right, player.x + screenOffsetX, player.y, 0, player.width / player.image_right:getWidth(), player.height / player.image_right:getHeight())
    else
        love.graphics.draw(player.image_left, player.x + screenOffsetX, player.y, 0, player.width / player.image_left:getWidth(), player.height / player.image_left:getHeight())
    end
end

love.graphics.setColor(1, 1, 1)  -- Réinitialiser la couleur


    -- Dessiner les boules
    for _, ball in ipairs(balls) do
        love.graphics.setColor(ball.color)
        love.graphics.circle("fill", ball.x, ball.y, ball.radius)
    end

    -- Dessiner le score et les vies
    love.graphics.setColor(1, 1, 1)
    love.graphics.print("Score: " .. score, 10, 10)
    love.graphics.print("Meilleur Score: " .. bestScore, 10, 30)
    love.graphics.print("Manche: " .. wave, 10, 70)  -- Assurez-vous d'ajouter ceci

-- Dessiner les cœurs
love.graphics.setColor(1, 1, 1)

-- Position initiale pour les cœurs, juste en dessous du score
local heartY = 100  -- Y pour les cœurs, à ajuster selon vos préférences
local heartSize = 0.5  -- Facteur de mise à l'échelle pour rendre les cœurs plus petits
local heartSpacing = 10  -- Espacement entre les cœurs

-- Calculer la largeur totale des cœurs
local totalHeartWidth = 0
for i = 1, 3 do
    if i <= lives then
        totalHeartWidth = totalHeartWidth + (heartImages[i]:getWidth() * heartSize) + heartSpacing
    else
        totalHeartWidth = totalHeartWidth + (heartBrokenImage:getWidth() * heartSize) + heartSpacing
    end
end

-- Position X pour centrer les cœurs
local startX = (love.graphics.getWidth() - totalHeartWidth + heartSpacing) / 2  -- + heartSpacing pour ajuster l'espacement supplémentaire

for i = 1, 3 do
    if i <= lives then
        love.graphics.draw(heartImages[i], startX + (i - 1) * (heartImages[i]:getWidth() * heartSize + heartSpacing), heartY, 0, heartSize, heartSize)
    else
        love.graphics.draw(heartBrokenImage, startX + (i - 1) * (heartBrokenImage:getWidth() * heartSize + heartSpacing), heartY, 0, heartSize, heartSize)
    end
end


    -- Affichage de la hitbox si debugMode est activé
    if debugMode then
        love.graphics.setColor(1, 0, 0)  -- Rouge pour la hitbox
        love.graphics.rectangle("line", player.hitbox.x, player.hitbox.y, player.hitbox.width, player.hitbox.height)
        for _, ball in ipairs(balls) do
            love.graphics.rectangle("line", ball.x - ball.radius, ball.y - ball.radius, ball.radius * 2, ball.radius * 2)
        end
    end

    -- Afficher "Game Over" si le jeu est terminé
    if gameOver then
        love.graphics.setColor(1, 0, 0)  -- Rouge pour le texte "Game Over"
        love.graphics.printf("Game Over", 0, love.graphics.getHeight() / 2 - 50, love.graphics.getWidth(), "center")
        love.graphics.setColor(1, 1, 1)
        love.graphics.printf("Appuyez sur Échap pour recommencer ou Q pour quitter", 0, love.graphics.getHeight() / 2, love.graphics.getWidth(), "center")
    end
end

function spawnBall()
    local ball = {
        x = math.random(50, love.graphics.getWidth() - 50),  -- Générer la boule dans la largeur de la fenêtre
        y = -30,  -- Commencer au-dessus de l'écran
        radius = 20,
        speed = ballSpeed,
        color = {math.random(), math.random(), math.random()}  -- Couleur aléatoire
    }
    table.insert(balls, ball)
end

function checkCollision(a, b)
    return a.x < b.x + b.width and
           a.x + a.radius * 2 > b.x and
           a.y < b.y + b.height and
           a.y + a.radius * 2 > b.y
end

function resetGame()
    score = 0
    lives = 3
    gameOver = false
    wave = 1
    timer = 0
    balls = {}
    spawnRate = 1
    sprintActive = false
    sprintTimer = 0
    sprintRecharge = 0
    backgroundMusic:play()  -- Rejouer la musique de fond
end