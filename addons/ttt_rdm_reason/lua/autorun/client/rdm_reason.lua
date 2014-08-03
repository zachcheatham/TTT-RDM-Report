local helpers = {}

local pendingExplaination = {}
local currentPrompt = nil

local function sendExplaination(id, reason)
	pendingExplaination[id] = nil
	
	net.Start("RDMReason_Explain")
	net.WriteTable({id=id, reason=reason})
	net.SendToServer()
end

function helpers.createPrompt(rdmID, victim, weapon)
	local pnl = vgui.Create("DFrame")

	pnl:SetTitle("Random Deathmatch")
	
	pnl:MakePopup()
	pnl:DoModal()
	pnl:SetDrawOnTop(true)	
	pnl:SetDraggable(false)
	pnl:ShowCloseButton(false)
	
	pnl.messageLabel = vgui.Create("DLabel", pnl)
	pnl.messageLabel:SetTextColor(color_white)
	pnl.messageLabel:SetFont("DermaDefaultBold")
	pnl.messageLabel:SetPos(10, 30)
	pnl.messageLabel:SetText("Why did you RDM " .. victim .. " with a " .. weapon .. "?")
	pnl.messageLabel:SizeToContents()
	
	local h = 109 -- TITLE(20) + submitButton:AlignBottom(35) + TEXTBOX(24) + PADDING(5*2) + LABELTALL(20)
	local w = pnl.messageLabel:GetWide() + 20 -- 20 is PADDING(10*2)
	pnl:SetSize(w, h)
	pnl:SetPos(ScrW() / 2 - w / 2, ScrH() / 2 - h / 2)

	pnl.reasonBox = vgui.Create("DTextEntry", pnl)
	pnl.reasonBox:SetTall(pnl.reasonBox:GetTall() * 1.2)
	pnl.reasonBox:StretchToParent(5, nil, 5, nil)
	pnl.reasonBox:AlignBottom(35)
	
	pnl.submitButton = vgui.Create("DButton", pnl)
	pnl.submitButton:SetText("Submit")
	pnl.submitButton:StretchToParent(5, nil, 5, nil)
	pnl.submitButton:AlignBottom(5)
	pnl.submitButton.DoClick = function()
		sendExplaination(rdmID, pnl.reasonBox:GetValue())
		
		pnl:Close()
		currentPrompt = nil
		
		helpers.promptExplaination()
	end	
	
	pnl.reasonBox.OnEnter = function()
		pnl.submitButton.DoClick()
	end
	
	pnl.reasonBox:RequestFocus()
	
	return pnl
end

function helpers.promptExplaination()
	if not currentPrompt and table.Count(pendingExplaination) > 0 then
		local rdmID = table.GetFirstKey(pendingExplaination)
		local rdm = table.GetFirstValue(pendingExplaination)
		
		local weapon = weapons.Get(rdm.weapon)
		local weaponName = ""
		if weapon then
			weaponName = LANG.TryTranslation(weapon.PrintName)
		else
			weaponName = rdm.weapon
		end
		
		local dialog = helpers.createPrompt(rdmID, rdm.victim, weaponName)
		currentPrompt = dialog
	end
end

net.Receive("RDMReason_Committed", function(length, client)
	local newRDM = net.ReadTable()
	table.Merge(pendingExplaination, newRDM)
	
	helpers.promptExplaination()
end)

local function roundStart()
	if currentPrompt then
		currentPrompt:Close()
	end

	pendingExplaination = {}
	currentPrompt = nil
end
hook.Add("TTTBeginRound", "RDMReason_BeginRound", roundStart)