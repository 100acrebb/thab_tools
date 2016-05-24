STEAMTEAM = {}
STEAMTEAM.Items = {}
STEAMTEAM.Groups = {}


STEAMTEAM.Groups[1] = {}
STEAMTEAM.Groups[1].URL = "http://steamcommunity.com/groups/100acrebb"
STEAMTEAM.Groups[1].OnIsMember = function(self, ply) ply:SetNWBool( "THABMember", true ) end
STEAMTEAM.Groups[1].Bonus = {}

STEAMTEAM.Groups[1].Bonus[1] = {}
STEAMTEAM.Groups[1].Bonus[1].Type = "PSPOINTS"
STEAMTEAM.Groups[1].Bonus[1].Amount = 10000



local memberlist = {}

if not sql.TableExists( "steamteam" ) then
	sql.Query( "CREATE TABLE IF NOT EXISTS steamteam ( playerid INTEGER NOT NULL, groupid INTEGER NOT NULL, bonusid INTEGER NOT NULL, received_count INTEGER DEFAULT 0, PRIMARY KEY ( playerid, groupid, bonusid) );" )
end


local function debugprint(msg)
	print(msg)
end


-- identify if player is a member
function ST_CheckPlayer( ply )

	local sid64 = ply:SteamID64()
	debugprint("Checking "..ply:Name().." for membership...")
	
	if memberlist[sid64] then
		debugprint("Member!")
		-- config'd callback
		if STEAMTEAM.Groups[1].OnIsMember then
			STEAMTEAM.Groups[1]:OnIsMember(ply)
		end
		
		-- if ply.PS_GivePoints == nil then print("STEAMTEAM: no points function") return end -- don't bother for now if PS isn't on
		
		-- now check to see if person should get 
		
		if (STEAMTEAM.Groups[1].Bonus[1].Type == "PSPOINTS" and !ply.PS_GivePoints) then debugprint("Points award, but no PS") return end
		
		local val = sql.QueryValue( "SELECT received_count FROM steamteam WHERE playerid = " .. sid64 .. " and groupid = 1 and bonusid = 1;" )
		if (val) then -- got a row
			val = tonumber(val)
			if (val < 1) then
				debugprint("Existing row, just joined") -- not sure this is a valid use case, but leavig it in for now.
				sql.Query( "UPDATE steamteam SET received_count = 1 WHERE playerid = " .. sid64 .. " and groupid = 1 and bonusid = 1;" )
				ply:PS_GivePoints(STEAMTEAM.Groups[1].Bonus[1].Amount)
				PrintMessage( HUD_PRINTTALK, ply:Name().. " is a member of the Steam Group and has received " .. STEAMTEAM.Groups[1].Bonus[1].Amount .. " points!")
				print(ply:Name().. " is a member of the Steam Group and has received " .. STEAMTEAM.Groups[1].Bonus[1].Amount .. " points!")

			else
				debugprint("Bonus already received")
			end
				
		else
			debugprint("New row, just joined") 
			sql.Query( "INSERT INTO steamteam (playerid, groupid, bonusid, received_count) VALUES ("..sid64..", 1, 1, 1)" )
			ply:PS_GivePoints(STEAMTEAM.Groups[1].Bonus[1].Amount)
			PrintMessage( HUD_PRINTTALK, ply:Name().. " is a member of the Steam Group and has received " .. STEAMTEAM.Groups[1].Bonus[1].Amount .. " points!")
			print(ply:Name().. " is a member of the Steam Group and has received " .. STEAMTEAM.Groups[1].Bonus[1].Amount .. " points!")
		end
		
	end
end

local function ST_PlayerInitialSpawn( ply )
	timer.Simple(10, function() if IsValid(ply) then ST_CheckPlayer(ply) end end)
end
hook.Add( "PlayerInitialSpawn", "STEAMTEAMPlayerInitialSpawn", ST_PlayerInitialSpawn )

local function ST_CheckAllPlayers()
	for k, v in pairs(player.GetAll()) do
		if not v:GetNWBool("THABMember", false) then
			ST_CheckPlayer( v )
		end
	end
end





-- for each page, get total pages if we don't know it and gather all steam ids on the page
local function ST_GetPage(currentPage, totalPages)

	print ("checking page ", STEAMTEAM.Groups[1].URL .. "/memberslistxml/?xml=1&p=" .. currentPage)
	http.Fetch( STEAMTEAM.Groups[1].URL .. "/memberslistxml/?xml=1&p=" .. currentPage,
		function( body, len, headers, code ) -- On Success
			-- get total pages
			body = string.Replace(body, "<", "")
			body = string.Replace(body, ">", "")
			body = string.Replace(body, "/", "")
			if totalPages == 9999 then
				totalPages = 0 -- safety valve in case the assignment gets blown below
				local splitPagesCheck = string.Split( tostring(body), "totalPages")
				totalPages = tonumber(splitPagesCheck[2])
				debugprint ("totalPages "..totalPages)
			end
			
			local splitSteamIDs = string.Explode("steamID64", tostring(body), true)
			for k, v in ipairs( splitSteamIDs ) do
				if string.Left(v,4) == "7656" then
					memberlist[v] = true	
					--debugprint(v)
				end
			end
			
			
			currentPage = currentPage + 1
			if (currentPage <= totalPages) then
				ST_GetPage(currentPage, totalPages) -- recurse
			else
				ST_CheckAllPlayers()
			end
			
		end,
		function(error) -- On fail
			print("Ruh roh! Couldn't get data from the Steam Group")
			return
		end
	)

end

-- start the member table build process
local function ST_BuildMemberList()
	
	local currentPage = 1
	local totalPages = 9999
	memberlist = {}
	
	-- called each time we want a new page
	ST_GetPage(currentPage, totalPages)
end

-- refresh the list every so often
timer.Create( "STEAMTEAMTimer", 600, 0, ST_BuildMemberList ) 
ST_BuildMemberList()





