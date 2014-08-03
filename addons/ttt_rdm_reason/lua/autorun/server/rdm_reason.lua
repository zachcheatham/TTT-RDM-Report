local roundRDM = {}
local explainedRDM = {}

local function getByUserID(id)
	for _, ply in ipairs(player.GetAll()) do
		if ply:UserID() == id then
			return ply
		end
	end
	
	return nil
end

local function printExplanation(explanation, disconnected)
	for _, ply in ipairs(player.GetAll()) do
		if ply:IsAdmin() and (GetRoundState() ~= ROUND_ACTIVE or (not ply:Alive() or ply:IsSpec()))then
			if ULib then
				ULib.tsayColor(ply, false, Color(255,0,0), "[RDM Reason] ", Color(205, 205, 205), (explanation.prevMap and "(Previous Map) " or ""), Color(0, 255, 0), explanation.attacker, Color(205, 205, 205), (disconnected and " (Disconnected) " or ""), Color(255, 255, 255), " rdmed ", Color(0, 255, 0), explanation.victim, Color(255, 255, 255), " because " .. explanation.reason)
			else
				ply:PrintMessage(HUD_PRINTTALK, "[RDM Reason] " .. explanation.attacker .. " rdmed " .. explanation.victim .. " because " .. explanation.reason)
			end
		end
	end
end

local function notifyDisconnect(name)
	for _, ply in ipairs(player.GetAll()) do
		if ply:IsAdmin() then
			if ULib then
				ULib.tsayColor(ply, false, Color(255,0,0), "[RDM Reason] ", Color(0, 255, 0), name, Color(255, 255, 255), " disconnected before explaining an rdm.")
			else
				ply:PrintMessage(HUD_PRINTTALK, "[RDM Reason] " .. name .. " disconnected before explaining an rdm.")
			end
		end
	end
end

local function notifyBadReason(name)
	for _, ply in ipairs(player.GetAll()) do
		if ply:IsAdmin() then
			if ULib then
				ULib.tsayColor(ply, false, Color(255,0,0), "[RDM Reason] ", Color(0, 255, 0), name, Color(255, 255, 255), " gave an unintelligible reason for rdming.")
			else
				ply:PrintMessage(HUD_PRINTTALK, "[RDM Reason] " .. name .. " gave an unintelligible reason for rdming.")
			end
		end
	end
end

util.AddNetworkString("RDMReason_Committed")
util.AddNetworkString("RDMReason_Explain")

local function sendRDM(ply)
	local rdms = {}
		
	for k, v in pairs(roundRDM[ply:UserID()]) do
		if not v.sent then
			local rdm = table.Copy(v)
			rdm.attacker = nil
			rdms[k] = rdm
		end
	end

	-- Send table
	net.Start("RDMReason_Committed")
	net.WriteTable(rdms)
	net.Send(ply)
	
	-- Mark everything as sent
	for _, v in pairs(roundRDM[ply:UserID()]) do
		v.sent = true
	end
end

net.Receive("RDMReason_Explain", function(len, ply)
	local reason = net.ReadTable()
	
	-- Player hasn't explained anything
	if not explainedRDM[ply:UserID()] then
		explainedRDM[ply:UserID()] = {}
	end
	
	if roundRDM[ply:UserID()] then
		-- Get that data
		local victimName = roundRDM[ply:UserID()][reason.id].victim
		local prevMap = roundRDM[ply:UserID()][reason.id].prevMap
		local explanation = {reason = reason.reason, victim = victimName, attacker = ply:Nick(), prevMap = prevMap}
		
		-- Remove Pending	
		roundRDM[ply:UserID()][reason.id] = nil
		if table.Count(roundRDM[ply:UserID()]) == 0 then
			roundRDM[ply:UserID()] = nil
		end
		
		if reason.reason and string.len(string.Trim(reason.reason)) > 2 then
			-- Insert Explanation
			if GetRoundState() == ROUND_ACTIVE then
				explainedRDM[ply:UserID()][reason.id] = explanation -- Save for re-print after round ends
				printExplanation(explanation)
			else
				printExplanation(explanation)
			end
		else
			RunConsoleCommand("ulx", "addslay", ply:Nick())
			notifyBadReason(ply:Nick())
		end
	else
		error("Warning: User sent explanation without needing to!")
	end
end)

local function ignoreRDM(ply)
	return ply:GetUserGroup() == "owner"
end

local function checkDeathRDM(victim, inflictor, attacker)
	-- Record RDM
	if victim:IsPlayer() and attacker:IsPlayer() and not ignoreRDM(attacker) then -- Players are real and aren't on bypass
		if victim ~= attacker then -- Victim didn't kill himself
			if (victim:GetRole() ~= ROLE_TRAITOR and attacker:GetRole() ~= ROLE_TRAITOR) or (victim:GetRole() == ROLE_TRAITOR and attacker:GetRole() == ROLE_TRAITOR) then -- Check if death was rdm
				local weapon = ""
				if inflictor:IsPlayer() then
					weapon = inflictor:GetActiveWeapon():GetClass() -- Inflictor was player's weapon
				else
					weapon = inflictor:GetClass() -- Inflictor was fire or something (I hope)
				end
				
				if not roundRDM[attacker:UserID()] then -- Player has not rdmed yet
					roundRDM[attacker:UserID()] = {} -- So create him a table
				end
				
				roundRDM[attacker:UserID()][victim:UserID()] = {victim = victim:Nick(), weapon = weapon}
			end
		end
	end
		
	-- Send them their rdms
	if roundRDM[victim:UserID()] then
		sendRDM(victim)
	end
end
hook.Add("PlayerDeath", "RDMReason_Kills", checkDeathRDM)

local function roundEnd()
	-- Print explained rdms
	for _, explanations in pairs(explainedRDM) do
		for _, v in pairs(explanations) do
			printExplanation(v)
		end
	end
	
	-- Send users their rdms
	for _, ply in ipairs(player.GetAll()) do
		if roundRDM[ply:UserID()] then
			sendRDM(ply)
		end
	end
end
hook.Add("TTTEndRound", "RDMReason_EndRound", roundEnd)

local function roundStart()
	PrintTable(roundRDM)

	-- Slay them assholes
	for userID, _ in pairs(roundRDM) do
		local slayPly = getByUserID(userID)
		
		if slayPly then
			slayPly:Kill()
			if ULib then
				ULib.tsayColor(nil, false, Color(255,0,0), slayPly:Nick(), Color(205, 205, 205), " has been killed for not explaining rdm.")
			else
				local text = slayPly:Nick() .. " has been killed for not explaining rdm."
				for _, ply in ipairs(player.GetAll()) do
					ply:PrintMessage(HUD_PRINTTALK, text)
				end
			end
		end
	end
	
	-- Cleanup
	roundRDM = {}
	explainedRDM = {}
end
hook.Add("TTTBeginRound", "RDMReason_BeginRound", roundStart)

local function playerDisconnect(ply)
	if roundRDM[ply:UserID()] then
		RunConsoleCommand("ulx", "addslayid", ply:SteamID())
		roundRDM[ply:UserID()] = nil
		notifyDisconnect(ply:Nick())
	end
end
hook.Add("PlayerDisconnected", "RDMReason_Disconnect", playerDisconnect)

local function serverShutdown()
	if table.Count(roundRDM) > 0 then
		for userID, rdms in pairs(roundRDM) do
			local ply = getByUserID(userID)
			if ply then
				for _, v in pairs(rdms) do
					v.sent = nil
					v.prevMap = true
				end
				
				local unexplained = {timestamp = os.time(), rdms = rdms}
				ply:SetPData("unexplained_rdm", util.TableToJSON(unexplained))
			end
		end
	end
end
hook.Add("ShutDown", "RDMReason_Shutdown", serverShutdown)

local function sendPreLevelRDM(ply)
	local unexplained = ply:GetPData("unexplained_rdm")
	ply:RemovePData("unexplained_rdm")
	if unexplained then
		unexplained = util.JSONToTable(unexplained)
		if os.time() - unexplained.timestamp < 600 then
			roundRDM[ply:UserID()] = unexplained.rdms
			sendRDM(ply)
		end
	end
end
hook.Add("PlayerInitialSpawn", "RDMReason_InitSpawn", sendPreLevelRDM)