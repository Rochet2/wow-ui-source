---------------------------------------------------------------------------------
--- Follower List                                                             ---
---------------------------------------------------------------------------------
function GarrisonFollowerList_ScrollListUpdate(self)
	GarrisonFollowerList_Update(self.followerFrame);
end

function GarrisonFollowerList_OnLoad(self)
	self.FollowerList.followers = { };
	self.FollowerList.followersList = { };
	GarrisonFollowerList_DirtyList(self.FollowerList);

	self.FollowerList.listScroll.update = GarrisonFollowerList_ScrollListUpdate;
	HybridScrollFrame_CreateButtons(self.FollowerList.listScroll, "GarrisonMissionFollowerButtonTemplate", 7, -7, nil, nil, nil, -6);
	self.FollowerList.listScroll.followerFrame = self;

	GarrisonFollowerList_Update(self);

	self:RegisterEvent("GARRISON_FOLLOWER_LIST_UPDATE");
	self:RegisterEvent("GARRISON_FOLLOWER_REMOVED");
	self:RegisterEvent("GARRISON_FOLLOWER_XP_CHANGED");
end

function GarrisonFollowerList_OnShow(self)
	GarrisonFollowerList_DirtyList(self);
	GarrisonFollowerList_UpdateFollowers(self)
end

function GarrisonFollowerList_OnHide(self)
	self.followers = nil;
end

function GarrisonFollowerList_OnEvent(self, event, ...)
	if (event == "GARRISON_FOLLOWER_LIST_UPDATE" or event == "GARRISON_FOLLOWER_XP_CHANGED") then
		if (self.FollowerTab and self.FollowerTab.followerID) then
			GarrisonFollowerPage_ShowFollower(self.FollowerTab, self.FollowerTab.followerID);
		end
		
		GarrisonFollowerList_DirtyList(self.FollowerList);
		GarrisonFollowerList_UpdateFollowers(self.FollowerList);
		GarrisonMissionPage_UpdateParty();
		return true;
	elseif (event == "GARRISON_FOLLOWER_REMOVED") then
		if (self.FollowerTab and self.FollowerTab.followerID and not C_Garrison.GetFollowerInfo(self.FollowerTab.followerID)) then
			-- viewed follower got removed, pick someone else
			local index = self.FollowerList.followersList[1];
			if (index and self.FollowerList.followers[index].followerID ~= self.FollowerTab.followerID) then
				GarrisonFollowerPage_ShowFollower(self.FollowerTab, self.FollowerList.followers[index].followerID);
			else
				-- try the 2nd follower
				index = self.FollowerList.followersList[2];
				if (index) then
					GarrisonFollowerPage_ShowFollower(self.FollowerTab, self.FollowerList.followers[index].followerID);
				else
					-- empty page
					GarrisonFollowerPage_ShowFollower(self.FollowerTab, 0);
				end
			end
		end
		GarrisonFollowerList_DirtyList(self.FollowerList);
		return true;
	end

	return false;
end

function GarrisonFollowListEditBox_OnTextChanged(self)
	GarrisonFollowerList_UpdateFollowers(self:GetParent());
end

function GarrisonFollowerList_UpdateFollowers(self)
	local followerList = self;
	if ( followerList.dirtyList ) then
		followerList.followers = C_Garrison.GetFollowers();
		followerList.dirtyList = nil;
	end
	followerList.followersList = { };

	local searchString = followerList.SearchBox:GetText();
	if ( searchString == SEARCH ) then
		searchString = nil;
	end
	
	local numCollected = 0;
	for i = 1, #followerList.followers do
		if ( followerList.followers[i].isCollected ) then
			numCollected = numCollected + 1;
		end
		if ( (self.followers[i].isCollected or self.showUncollected) and (not searchString or searchString == "" or C_Garrison.SearchForFollower(self.followers[i].followerID, searchString)) ) then
			tinsert(self.followersList, i);
		end
	end

	local followerTab = self:GetParent().FollowerTab;
	if ( followerTab ) then
		local maxFollowers = C_Garrison.GetFollowerSoftCap();
		if ( self.isLandingPage ) then
			local countColor = HIGHLIGHT_FONT_COLOR_CODE;
			if ( numCollected > maxFollowers ) then
				countColor = RED_FONT_COLOR_CODE;
			end
			self:GetParent().FollowerTab.NumFollowers:SetText(countColor..numCollected.."/"..maxFollowers..FONT_COLOR_CODE_CLOSE);
		else
			local countColor = NORMAL_FONT_COLOR_CODE;
			if ( numCollected > maxFollowers ) then
				countColor = RED_FONT_COLOR_CODE;
			end
			self:GetParent().FollowerTab.NumFollowers:SetText(format(GARRISON_FOLLOWER_COUNT, countColor, numCollected, maxFollowers, FONT_COLOR_CODE_CLOSE));
		end
	end

	GarrisonFollowerList_SortFollowers(self);
	GarrisonFollowerList_Update(self:GetParent());
end

function GarrisonFollowerList_Update(self)
	local followerFrame = self;

	local followers = followerFrame.FollowerList.followers;
	local followersList = followerFrame.FollowerList.followersList;
	local numFollowers = #followersList;
	local scrollFrame = followerFrame.FollowerList.listScroll;
	local offset = HybridScrollFrame_GetOffset(scrollFrame);
	local buttons = scrollFrame.buttons;
	local numButtons = #buttons;
	local expandedHeight = 0;
	local showCounters = followerFrame.FollowerList.showCounters;

	for i = 1, numButtons do
		local button = buttons[i];
		local index = offset + i; -- adjust index
		if ( index <= numFollowers ) then
			local follower = followers[followersList[index]];
			button.id = follower.followerID;
			button.info = follower;
			button.Name:SetText(follower.name);
			button.Class:SetAtlas(follower.classAtlas);
			button.Status:SetText(follower.status);
			local color = ITEM_QUALITY_COLORS[follower.quality];
			button.PortraitFrame.LevelBorder:SetVertexColor(color.r, color.g, color.b);
			button.PortraitFrame.Level:SetText(follower.level);
			SetPortraitTexture(button.PortraitFrame.Portrait, follower.displayID);
			if ( follower.isCollected ) then
				-- have this follower
				button.isCollected = true;
				button.Name:SetTextColor(NORMAL_FONT_COLOR.r, NORMAL_FONT_COLOR.g, NORMAL_FONT_COLOR.b);
				button.Class:SetDesaturated(false);
				button.Class:SetAlpha(0.2);
				button.PortraitFrame.PortraitRingQuality:Show();
				button.PortraitFrame.PortraitRingQuality:SetVertexColor(color.r, color.g, color.b);
				button.PortraitFrame.Portrait:SetDesaturated(false);
				-- if looking at a mission, indicate followers that cannot currently be dragged to it
				if ( followerFrame.followerCounters and follower.status ) then
					button.PortraitFrame.PortraitRingCover:Show();
					button.PortraitFrame.PortraitRingCover:SetAlpha(0.5);
					button.BusyFrame:Show();
				else
					button.PortraitFrame.PortraitRingCover:Hide();
					button.BusyFrame:Hide();
				end
				button.DownArrow:SetAlpha(1);
				-- adjust text position if we have additional text to show below name
				if (follower.level == GARRISON_FOLLOWER_MAX_LEVEL or follower.status) then
					button.Name:SetPoint("LEFT", button.PortraitFrame, "LEFT", 66, 8);
				else
					button.Name:SetPoint("LEFT", button.PortraitFrame, "LEFT", 66, 0);
				end
				-- show iLevel for max level followers	
				if (follower.level == GARRISON_FOLLOWER_MAX_LEVEL) then
					button.ILevel:SetText(ITEM_LEVEL_ABBR.." "..follower.iLevel);
					button.Status:SetPoint("TOPLEFT", button.ILevel, "TOPRIGHT", 4, 0);
				else
					button.ILevel:SetText(nil);
					button.Status:SetPoint("TOPLEFT", button.ILevel, "TOPRIGHT", 0, 0);
				end
				if (follower.xp == 0 or follower.levelXP == 0) then 
					button.XPBar:Hide();
				else
					button.XPBar:Show();
					button.XPBar:SetWidth((follower.xp/follower.levelXP) * GARRISON_FOLLOWER_LIST_BUTTON_FULL_XP_WIDTH);
				end
			else
				-- don't have this follower
				button.isCollected = nil;
				button.Name:SetTextColor(0.25, 0.25, 0.25);
				button.ILevel:SetText(nil);
				button.Status:SetPoint("TOPLEFT", button.ILevel, "TOPRIGHT", 0, 0);
				button.Class:SetDesaturated(true);
				button.Class:SetAlpha(0.1);
				button.PortraitFrame.PortraitRingQuality:Hide();
				button.PortraitFrame.Portrait:SetDesaturated(true);
				button.PortraitFrame.PortraitRingCover:Show();
				button.PortraitFrame.PortraitRingCover:SetAlpha(0.6);
				button.XPBar:Hide();
				button.DownArrow:SetAlpha(0);
				button.BusyFrame:Hide();
			end

			GarrisonFollowerButton_UpdateCounters(button, follower, showCounters);

			if (button.id == followerFrame.openFollower) then
				GarrisonFollowerButton_Select(button);
				expandedHeight = button:GetHeight() - scrollFrame.buttonHeight + 6;
			else
				GarrisonFollowerButton_UnSelect(button);
			end
			button:Show();
		else
			button:Hide();
		end
	end
	
	local totalHeight = numFollowers * scrollFrame.buttonHeight + expandedHeight;
	local displayedHeight = numButtons * scrollFrame.buttonHeight;
	HybridScrollFrame_Update(scrollFrame, totalHeight, displayedHeight);
end

function GarrisonFollowerButton_UpdateCounters(button, follower, showCounters)
	local numShown = 0;
	if ( showCounters and button.isCollected and (not follower.status or follower.status == GARRISON_FOLLOWER_IN_PARTY or follower.status == GARRISON_FOLLOWER_WORKING) ) then
		--if a mission is being viewed, show mechanics this follower can counter
		--for followers you have, show counters if they are or could be on the mission
		local counters = GarrisonMissionFrame.followerCounters and GarrisonMissionFrame.followerCounters[follower.followerID];
		if ( counters ) then
			for i = 1, #counters do
				-- max of 4 icons
				if ( numShown == 4 ) then
					break;
				end			
				numShown = numShown + 1;
				GarrisonFollowerButton_SetCounterButton(button, numShown, counters[i]);
			end
		end
		local traits = GarrisonMissionFrame.followerTraits and GarrisonMissionFrame.followerTraits[follower.followerID];
		if ( traits ) then
			for i = 1, #traits do
				-- max of 4 icons
				if ( numShown == 4 ) then
					break;
				end
				numShown = numShown + 1;
				GarrisonFollowerButton_SetCounterButton(button, numShown, traits[i]);
			end
		end
	end
	if ( numShown == 1 or numShown == 2 ) then
		button.Counters[1]:SetPoint("TOPRIGHT", -8, -16);
	else
		button.Counters[1]:SetPoint("TOPRIGHT", -8, -4);
	end
	for i = numShown + 1, #button.Counters do
		button.Counters[i].info = nil;
		button.Counters[i]:Hide();
	end
end

function GarrisonFollowerButton_SetCounterButton(button, index, info)
	local counter = button.Counters[index];
	if ( not counter ) then
		button.Counters[index] = CreateFrame("Frame", nil, button, "GarrisonMissionAbilityCounterTemplate");
		if (index % 2 == 0) then
			button.Counters[index]:SetPoint("RIGHT", button.Counters[index-1], "LEFT", -6, 0);
		else
			button.Counters[index]:SetPoint("TOP", button.Counters[index-2], "BOTTOM", 0, -6);
		end
		counter = button.Counters[index];
	end
	counter.info = info;
	counter.Icon:SetTexture(info.icon);
	if ( info.traitID ) then
		counter.tooltip = nil;
		counter.info.showCounters = false;
		counter.Border:Hide();
	else
		counter.tooltip = info.name;
		counter.info.showCounters = true;
		counter.Border:Show();
	end
	counter:Show();
end

function GarrisonFollowerButton_Select(self)
	if ( not self.isCollected ) then
		return;
	end

	self.UpArrow:Show();
	self.DownArrow:Hide();
	local abHeight = 0;
	if (not self.info.abilities) then
		self.info.abilities = C_Garrison.GetFollowerAbilities(self.info.followerID);
	end
	for i=1, #self.info.abilities do
		if (not self.Abilities[i]) then
			self.Abilities[i] = CreateFrame("Frame", nil, self, "GarrisonFollowerListButtonAbilityTemplate");
			self.Abilities[i]:SetPoint("TOPLEFT", self.Abilities[i-1], "BOTTOMLEFT", 0, -2);
		end
		local Ability = self.Abilities[i];
		local ability = self.info.abilities[i];
		Ability.abilityID = ability.id;
		Ability.Name:SetText(ability.name);
		Ability.Icon:SetTexture(ability.icon);
		Ability.tooltip = ability.description;
		Ability:Show();
		abHeight = abHeight + Ability:GetHeight() + 3;
	end
	for i=(#self.info.abilities + 1), #self.Abilities do
		self.Abilities[i]:Hide();
	end
	if (abHeight > 0) then
		abHeight = abHeight + 8;
		self.AbilitiesBG:Show();
		self.AbilitiesBG:SetHeight(abHeight);
	else
		self.AbilitiesBG:Hide();
	end
	self:SetHeight(51 + abHeight);
end

function GarrisonFollowerButton_UnSelect(self)
	self.UpArrow:Hide();
	self.DownArrow:Show();
	self.AbilitiesBG:Hide();
	for i=1, #self.Abilities do
		self.Abilities[i]:Hide();
	end
	self:SetHeight(56);
end

function GarrisonFollowerListButton_OnClick(self, button)
	local followerFrame = self:GetParent():GetParent().followerFrame;
	if ( button == "LeftButton" ) then
		if ( self.isCollected ) then
			if (not C_Garrison.CastSpellOnFollower(self.id)) then
				if (followerFrame.openFollower == self.id) then
					followerFrame.openFollower = nil;
				else
					followerFrame.openFollower = self.id;
				end
			end
		else
			followerFrame.openFollower = nil;
		end
		GarrisonFollowerList_Update(followerFrame);
		if ( followerFrame.FollowerTab ) then
			GarrisonFollowerPage_ShowFollower(followerFrame.FollowerTab, self.id);
		end
		CloseDropDownMenus();
	elseif ( button == "RightButton" ) then
		if ( self.isCollected ) then
			if ( GarrisonFollowerOptionDropDown.followerID ~= self.id ) then
				CloseDropDownMenus();
			end
			GarrisonFollowerOptionDropDown.followerID = self.id;
			ToggleDropDownMenu(1, nil, GarrisonFollowerOptionDropDown, "cursor", 0, 0);
		else
			GarrisonFollowerOptionDropDown.followerID = nil;
			CloseDropDownMenus();
		end
	end
end

function GarrisonFollowerListButton_OnModifiedClick(self, button)
	if ( IsModifiedClick("CHATLINK") ) then
		local followerLink;
		if (self.info.isCollected) then
			followerLink = C_Garrison.GetFollowerLink(self.info.followerID);
		else
			followerLink = C_Garrison.GetFollowerLinkByID(self.info.followerID);
		end
		
		if ( followerLink ) then
			ChatEdit_InsertLink(followerLink);
		end
	end
end

---------------------------------------------------------------------------------
--- Follower filtering and searching                                          ---
---------------------------------------------------------------------------------
function GarrisonFollowerList_DirtyList(self)
	self.dirtyList = true;
end

function GarrisonFollowerList_SortFollowers(self)
	local followers = self.followers;
	local followerCounters = GarrisonMissionFrame.followerCounters;
	local followerTraits = GarrisonMissionFrame.followerTraits;
	local checkAbilities = followerCounters and followerTraits and GarrisonMissionFrame.MissionTab:IsVisible();
	local comparison = function(index1, index2)
		local follower1 = followers[index1];
		local follower2 = followers[index2];

		if ( follower1.isCollected ~= follower2.isCollected ) then
			return follower1.isCollected;
		end
		if ( follower1.status and not follower2.status ) then
			return false;
		elseif ( not follower1.status and follower2.status ) then
			return true;
		end

		-- sorting: level > item level > (num counters for mission) > (num traits for mission) > quality > name
		if ( follower1.level ~= follower2.level ) then
			return follower1.level > follower2.level;
		end
		if ( follower1.level == GARRISON_FOLLOWER_MAX_LEVEL and follower1.iLevel ~= follower2.iLevel ) then		-- only checking follower 1 because follower 2 has same level at this point
			return follower1.iLevel > follower2.iLevel;
		end
		if ( checkAbilities and not follower1.status and follower1.isCollected ) then		-- only checking follower 1 because follower 2 has same status and collected-ness at this point
			local numCounters1 = followerCounters[follower1.followerID] and #followerCounters[follower1.followerID] or 0;
			local numCounters2 = followerCounters[follower2.followerID] and #followerCounters[follower2.followerID] or 0;
			if ( numCounters1 ~= numCounters2 ) then
				return numCounters1 > numCounters2;
			end
			local numTraits1 = followerTraits[follower1.followerID] and #followerTraits[follower1.followerID] or 0;
			local numTraits2 = followerTraits[follower2.followerID] and #followerTraits[follower2.followerID] or 0;
			if ( numTraits1 ~= numTraits2 ) then
				return numTraits1 > numTraits2;
			end
		end
		if ( follower1.quality ~= follower2.quality ) then
			return follower1.quality > follower2.quality;
		end
		return strcmputf8i(follower1.name, follower2.name) < 0;
	end

	table.sort(self.followersList, comparison);
end

---------------------------------------------------------------------------------
--- Models                                                                    ---
---------------------------------------------------------------------------------
function GarrisonMission_SetFollowerModel(modelFrame, followerID, displayID)
	if ( not displayID or displayID == 0 ) then
		modelFrame:ClearModel();
		modelFrame.followerID = nil;
	else
		modelFrame:SetDisplayInfo(displayID);
		modelFrame.followerID = followerID;
		GarrisonMission_SetFollowerModelItems(modelFrame);
	end
end

function GarrisonMission_SetFollowerModelItems(modelFrame)
	if ( modelFrame.followerID ) then
		local follower =  C_Garrison.GetFollowerInfo(modelFrame.followerID);
		if ( follower.isCollected ) then
			local modelItems = C_Garrison.GetFollowerModelItems(modelFrame.followerID);
			for i = 1, #modelItems do
				modelFrame:EquipItem(modelItems[i]);
			end
		end
	end
end

function GarrisonCinematicModelBase_OnLoad(self)
	self:RegisterEvent("UI_SCALE_CHANGED");
	self:RegisterEvent("DISPLAY_SIZE_CHANGED");
end

function GarrisonCinematicModelBase_OnEvent(self)
	self:RefreshCamera();
end

---------------------------------------------------------------------------------
--- Follower Page                                                             ---
---------------------------------------------------------------------------------
GARRISON_FOLLOWER_PAGE_HEIGHT_MULTIPLIER = .65;
GARRISON_FOLLOWER_PAGE_SCALE_MULTIPLIER = 1.3

function GarrisonFollowerPageItemButton_OnEvent(self, event)
	if ( not self:IsShown() and self.itemID ) then
		GarrisonFollowerPage_SetItem(self, self.itemID, self.itemLevel);
	end
end

function GarrisonFollowerPage_SetItem(itemFrame, itemID, itemLevel)
	if ( itemID and itemID > 0 ) then
		itemFrame.itemID = itemID;
		itemFrame.itemLevel = itemLevel;
		local itemName, _, itemQuality, _, _, _, _, _, _, itemTexture = GetItemInfo(itemID);
		if ( itemName ) then
			itemFrame.Icon:SetTexture(itemTexture);
			itemFrame.Name:SetText(itemName);
			itemFrame.Name:SetTextColor(GetItemQualityColor(itemQuality));
			itemFrame.ItemLevel:SetFormattedText(GARRISON_FOLLOWER_ITEM_LEVEL, itemLevel);
			itemFrame:Show();			
			return;
		end
	else
		itemFrame.itemID = nil;
		itemFrame.itemLevel = nil;
	end
	itemFrame:Hide();
end

function GarrisonFollowerPage_ShowFollower(self, followerID)
	local followerInfo = C_Garrison.GetFollowerInfo(followerID);

	if (followerInfo) then
		self.followerID = followerID;
		self.NoFollowersLabel:Hide();
		self.PortraitFrame:Show();
		GarrisonMission_SetFollowerModel(self.Model, followerInfo.followerID, followerInfo.displayID);
		if (followerInfo.height) then
			self.Model:SetHeightFactor(followerInfo.height * GARRISON_FOLLOWER_PAGE_HEIGHT_MULTIPLIER)
		end
		if (followerInfo.scale) then
			self.Model:InitializeCamera(followerInfo.scale * GARRISON_FOLLOWER_PAGE_SCALE_MULTIPLIER)
		end
	else
		self.followerID = nil;
		self.NoFollowersLabel:Show();
		followerInfo = { };
		followerInfo.quality = 1;
		followerInfo.abilities = { };
		self.PortraitFrame:Hide();
		self.Model:ClearModel();
	end

	GarrisonMissionFrame_SetFollowerPortrait(self.PortraitFrame, followerInfo);
	self.Name:SetText(followerInfo.name);
	local color = ITEM_QUALITY_COLORS[followerInfo.quality];	
	self.Name:SetVertexColor(color.r, color.g, color.b);
	self.ClassSpec:SetText(followerInfo.className);
	self.Class:SetAtlas(followerInfo.classAtlas);
	if ( followerInfo.isCollected ) then
		-- Follower cannot be upgraded anymore
		if (followerInfo.level == GARRISON_FOLLOWER_MAX_LEVEL and followerInfo.quality >= GARRISON_FOLLOWER_MAX_UPGRADE_QUALITY) then
			self.XPLabel:Hide();
			self.XPBar:Hide();
			self.XPText:Hide();
		else
			if (followerInfo.level == GARRISON_FOLLOWER_MAX_LEVEL) then
				self.XPLabel:SetText(GARRISON_FOLLOWER_XP_UPGRADE_STRING);
			else
				self.XPLabel:SetText(GARRISON_FOLLOWER_XP_STRING);
			end
			self.XPLabel:Show();
			self.XPBar:Show();
			self.XPBar:SetMinMaxValues(0, followerInfo.levelXP);
			self.XPBar:SetValue(followerInfo.xp);
			local xpLeft = followerInfo.levelXP - followerInfo.xp;
			self.XPText:SetText(format(GARRISON_FOLLOWER_XP_LEFT, xpLeft));
			self.XPText:Show();
		end
	else
		self.XPText:Hide();
		self.XPLabel:Hide();
		self.XPBar:Hide();
	end

	self.TraitsText:ClearAllPoints();
	if (not followerInfo.abilities) then
		followerInfo.abilities = C_Garrison.GetFollowerAbilities(followerID);
	end
	local lastAbilityAnchor, lastTraitAnchor;
	local numCounters = 0;

	for i=1, #followerInfo.abilities do
		local ability = followerInfo.abilities[i];

		local abilityFrame = self.Abilities[i];
		if ( not abilityFrame ) then
			abilityFrame = CreateFrame("Frame", nil, self, "GarrisonFollowerPageAbilityTemplate");
			self.Abilities[i] = abilityFrame;
		end

		if ( self.isLandingPage ) then
			abilityFrame.Description:SetText("");
			abilityFrame.Name:SetFontObject("GameFontHighlightMed2");
			abilityFrame.Name:ClearAllPoints();
			abilityFrame.Name:SetPoint("LEFT", abilityFrame.IconBorder, "RIGHT", 10, 0);
			abilityFrame.Name:SetWidth(150);
		else
			abilityFrame.Description:SetText(ability.description);
			abilityFrame.Name:SetFontObject("GameFontNormalLarge2");
			abilityFrame.Name:ClearAllPoints();
			abilityFrame.Name:SetPoint("TOPLEFT", abilityFrame.IconBorder, "TOPRIGHT", 10, 0);
			abilityFrame.Name:SetWidth(0);
		end
		abilityFrame.Name:SetText(ability.name);
		abilityFrame.IconButton.Icon:SetTexture(ability.icon);
		abilityFrame.IconButton.abilityID = ability.id;

		local hasCounters = false;
		if ( ability.counters and not ability.isTrait and not self.isLandingPage ) then
			for id, counter in pairs(ability.counters) do
				numCounters = numCounters + 1;
				local counterFrame = self.Counters[numCounters];
				if ( not counterFrame ) then
					counterFrame = CreateFrame("Frame", nil, self, "GarrisonMissionMechanicTemplate");
					self.Counters[numCounters] = counterFrame;
				end
				counterFrame.Icon:SetTexture(counter.icon);
				counterFrame.tooltip = counter.name;
				counterFrame:ClearAllPoints();
				if ( hasCounters ) then			
					counterFrame:SetPoint("LEFT", self.Counters[numCounters - 1], "RIGHT", 10, 0);
				else
					counterFrame:SetPoint("LEFT", abilityFrame.CounterString, "RIGHT", 2, -2);
				end
				counterFrame:Show();
				counterFrame.info = counter;
				hasCounters = true;
			end
		end
		if ( hasCounters ) then
			abilityFrame.CounterString:Show();
		else
			abilityFrame.CounterString:Hide();
		end
		-- anchor ability
		if ( ability.isTrait ) then
			lastTraitAnchor = GarrisonFollowerPage_AnchorAbility(abilityFrame, lastTraitAnchor, self.TraitsText, hasCounters);
		else
			lastAbilityAnchor = GarrisonFollowerPage_AnchorAbility(abilityFrame, lastAbilityAnchor, self.AbilitiesText, hasCounters);
		end
		abilityFrame:Show();
	end

	if ( lastAbilityAnchor ) then
		self.AbilitiesText:Show();
	else
		self.AbilitiesText:Hide();
	end
	if ( lastTraitAnchor ) then
		self.TraitsText:Show();
		if ( lastAbilityAnchor ) then
			self.TraitsText:SetPoint("LEFT", self.AbilitiesText, "LEFT");
			if ( self.isLandingPage ) then
				self.TraitsText:SetPoint("TOP", lastAbilityAnchor, "BOTTOM", 0, -24);
			else
				self.TraitsText:SetPoint("TOP", lastAbilityAnchor, "BOTTOM", 0, -16);
			end
		else
			self.TraitsText:SetPoint("TOPLEFT", self.AbilitiesText, "TOPLEFT");
		end
	else
		self.TraitsText:Hide();
	end
	
	for i = #followerInfo.abilities + 1, #self.Abilities do
		self.Abilities[i]:Hide();
	end
	for i = numCounters + 1, #self.Counters do
		self.Counters[i]:Hide();
	end
	
	-- gear	/ source
	if ( followerInfo.isCollected and not self.isLandingPage ) then
		local weaponItemID, weaponItemLevel, armorItemID, armorItemLevel = C_Garrison.GetFollowerItems(followerInfo.followerID);
		GarrisonFollowerPage_SetItem(self.ItemWeapon, weaponItemID, weaponItemLevel);
		GarrisonFollowerPage_SetItem(self.ItemArmor, armorItemID, armorItemLevel);
		if ( followerInfo.level == GARRISON_FOLLOWER_MAX_LEVEL ) then
			self.ItemAverageLevel.Level:SetText(ITEM_LEVEL_ABBR .. " " .. followerInfo.iLevel);
			self.ItemAverageLevel.Level:Show();
		else
			self.ItemWeapon:Hide();
			self.ItemArmor:Hide();
			self.ItemAverageLevel.Level:Hide();
		end
		self.Source.SourceText:Hide();
	else
		self.ItemWeapon:Hide();
		self.ItemArmor:Hide();
		self.ItemAverageLevel.Level:Hide();		

		self.Source.SourceText:SetText(C_Garrison.GetFollowerSourceTextByID(followerID));		
		self.Source.SourceText:Show();
	end	
end

function GarrisonFollowerPage_AnchorAbility(abilityFrame, lastAnchor, headerString, hasCounters)
	abilityFrame:ClearAllPoints();
	if ( lastAnchor ) then
		abilityFrame:SetPoint("LEFT", lastAnchor:GetParent());
		abilityFrame:SetPoint("TOP", lastAnchor, "BOTTOM", 0, -16);			
	else
		abilityFrame:SetPoint("TOPLEFT", headerString, "BOTTOMLEFT", 2, -12);
	end
	if ( hasCounters ) then
		return abilityFrame.CounterString;
	else
		return abilityFrame.Description;
	end
end
