--[[

    __  ___          ______                __            
   /  |/  /___ _____/_  __/________ ______/ /_____  _____
  / /|_/ / __ `/ __ \/ / / ___/ __ `/ ___/ __/ __ \/ ___/
 / /  / / /_/ / /_/ / / / /  / /_/ / /__/ /_/ /_/ / /    
/_/  /_/\__,_/ .___/_/ /_/   \__,_/\___/\__/\____/_/     
            /_/                                          


GMod Map Stats Routine
Written by Buzzkill    --    thehundredacrebloodbath.com
https://github.com/100acrebb/thab_tools
MapTractor generates statistics around server map usage, with a focus on identifying what maps attract or repel players. MapTractor polls the server every minute and updates 
the json file "data/maptractor.txt" with statistics for the current map. Here's an example entry:

"deathrun_cb_egypt_v1":      			<- map name
	{
		"version": 2,					<- statistics version.
		"totaltime": 3734,				<- total minutes the map has run on the server.
		"timempty": 695,				<- total minutes the map has been empty.
		"playerscore": 27746,			<- cumulative total players seen in this map, per minute.
		"magnetscore": 11673,			<- cumulative total players added to this map since it started, per minute.
		"playermetric": 7.4306,			<- the map's player score / total time
		"magnetmetric": 3.1261			<- the map's magnet score / total time
	},

"playermetric" is essentially the average playercount for the map.  "magnetmetric" takes it further and considers how many players were on the map when it started versus at the moment, 
thereby indicating the relative attractiveness or repulsiveness of a certain map.  In other words, do players tend to join or leave the server while this map is running?

A sample ULX implementation is included.  The ulx command "ulx mapstats / !mapstats" will generate a list of map statistics sorted by magnetmetric to console.

To Do:
  Build out an optional routine to load the most popular map(s) when the server goes empty.
  Eliminate the need for ULX for the !mapstats command
  Incorporate peak time / off time concepts, so maps don't get penalized for running during off-hours, etc.
  Timers wont start on a restarted server until first player joins.  Figure out a workaround that doesn't involve cheese (ie, temp bot, etc).
  
  

This program is free software: you can redistribute it and/or modify
it under the terms of the GNU General Public License as published by
the Free Software Foundation, either version 3 of the License, or
(at your option) any later version.
This program is distributed in the hope that it will be useful,
but WITHOUT ANY WARRANTY; without even the implied warranty of
MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
GNU General Public License for more details.
You should have received a copy of the GNU General Public License
along with this program.  If not, see <http://www.gnu.org/licenses/>.
]]


if SERVER then

	local MaptractorTable = {}
	local TimerInMins = 1
	local PlayersAtFirstCheck = -1
	local version = 2
	
	local function MaptractorInit()
	
		print("Initializing maptractor...")
		if !file.Exists( "maptractor.txt", "DATA" ) then
			file.Write( "maptractor.txt", util.TableToJSON(MaptractorTable) ) 
		end
		
		local MaptractorData = file.Read( "maptractor.txt", "DATA" ) 
		MaptractorTable = util.JSONToTable(MaptractorData)
		
		-- does map exist
		if (MaptractorTable[game.GetMap()] == null) then
			MaptractorTable[game.GetMap()] = {}
		end
		
		-- data version check
		if (MaptractorTable[game.GetMap()].version == null) then
			MaptractorTable[game.GetMap()] = {}
		end
		
		local MapStats = MaptractorTable[game.GetMap()]
		
		-- safety valve, for new maps and/or newly added metrics and old data
		if (MapStats.playerscore == nil) then MapStats.playerscore = 0 end
		if (MapStats.magnetscore == nil) then MapStats.magnetscore = 0 end
		if (MapStats.timempty == nil) then MapStats.timempty = 0 end
		if (MapStats.totaltime == nil) then MapStats.totaltime = 0 end
		
		MapStats.version = version
		file.Write( "maptractor.txt", util.TableToJSON(MaptractorTable), true) 
		
		
		timer.Create( "MaptractorTimer", TimerInMins * 60, 0, function() 
		
			if (PlayersAtFirstCheck == -1) then
				PlayersAtFirstCheck = #player.GetAll()
			end
			
			local MapStats = MaptractorTable[game.GetMap()]
			
			-- let's calc some stats, bitches!
			MapStats.totaltime = MapStats.totaltime + TimerInMins
			MapStats.playerscore = MapStats.playerscore + #player.GetAll()
			MapStats.magnetscore = MapStats.magnetscore + (#player.GetAll() - PlayersAtFirstCheck)
			
			MapStats.playermetric = MapStats.playerscore / MapStats.totaltime
			MapStats.magnetmetric = MapStats.magnetscore / MapStats.totaltime
			
			if (#player.GetAll() == 0) then
				MapStats.timempty = MapStats.timempty + TimerInMins
			end
			
			file.Write( "maptractor.txt", util.TableToJSON(MaptractorTable, true) ) 
		end)
		
	
	end
	hook.Add( "Initialize", "MaptractorInit", MaptractorInit )


end


-- Sample implementation
if ulx then

	function ulx.mapstats( calling_ply )

		local MaptractorData = file.Read( "maptractor.txt", "DATA" ) 
		MaptractorTable = util.JSONToTable(MaptractorData)
		
		if (calling_ply) then
			ULib.console( calling_ply, "map\tmmetric\tpmetric\ttottime\ttimeempty" )
		end
		
		for k, v in SortedPairsByMemberValue( MaptractorTable, "magnetmetric", true ) do   -- SortedPairsByMemberValue( MaptractorTable, "id", true ) do
			if (k ~= nil and v.magnetmetric ~= nil and v.playermetric ~= nil and v.totaltime ~= nil and v.timempty ~= nil) then
				if (calling_ply) then
					ULib.console( calling_ply, k.."\t"..v.magnetmetric.."\t"..v.playermetric.."\t"..v.totaltime.."\t"..v.timempty )
				end
			end
		end
	end	
	local mapstats = ulx.command( "THAB", "ulx mapstats", ulx.mapstats, { "!mapstats" } )
	mapstats:defaultAccess( ULib.ACCESS_ADMIN )
	mapstats:help( "Prints map score info to console" )

end
