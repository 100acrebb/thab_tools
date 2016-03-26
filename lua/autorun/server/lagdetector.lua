--[[


  /)          /)                       
 // _   _   _(/  _ _/_  _  _ _/_ _____ 
(/_(_(_(_/_(_(__(/_(___(/_(__(__(_)/ (_
      .-/                              
     (_/                               

GMod Server Lag Detection Routine
Written by Buzzkill    --    thehundredacrebloodbath.com
https://github.com/100acrebb/thab_tools

LagDetector is a simple tool to help detect and manage server-side lag.  It uses differences between SysTime() and CurTime() to detect
unexpected server lag, and once these deltas have exceeded a certain threshold, action can be taken to help correct.

These thresholds and actions are configurable through cvars:

lagdet_range		- if the difference between SysTime and CurTime exceeds this value in a frame, we have detected frame lag and the system increments the lag counter. Default is 0.07
lagdet_count		- if the lag counter reaches this value, we have detected server lag and we execute lagdet_execute. Default is 5
lagdet_quiet		- indicates how long we must go (in seconds) with no frame lag before our lag counter resets to 0. 
lagdet_execute		- the console command(s) to execute if we detect server lag. Default is a simple say
lagcount_meltdown	- if we detect this many frame lags without a reset, we execute lagexecute_meltdown. Default is 100
lagexecute_meltdown	- these console command(s) are executed in the event of massive lag.  Server is probably in a collision loop or something. Good time to restart the map. Default is a simple say

So, using the defaults..
LagDetector will compare SysTime and CurTime every second.  If the difference between the two >= 0.07, the lag counter increases.
If we go 15 seconds without detecting frame lag, the lag counter resets to 0.
If the lag counter hits 5, we execute the commands in lagdet_execute
If the lag counter hits 100, we execute the commands in lagexecute_meltdown




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

local lagrange = CreateConVar( "lagdet_range", "0.07", { FCVAR_SERVER_CAN_EXECUTE } )
local lagcount = CreateConVar( "lagdet_count", "5", { FCVAR_SERVER_CAN_EXECUTE } )
local lagquiet = CreateConVar( "lagdet_quiet", "15", { FCVAR_SERVER_CAN_EXECUTE } )
local lagverbose = CreateConVar( "lagdet_verbose", "0", { FCVAR_SERVER_CAN_EXECUTE } )

local lagexecute = CreateConVar( "lagdet_execute", "say [LAGDETECTOR] Server is currently detecting measureable lag.", { FCVAR_SERVER_CAN_EXECUTE } )
--local lagexecute = CreateConVar( "lagdet_execute", "ulx consay [LAGDETECTOR] Server is currently detecting measureable lag.", { FCVAR_SERVER_CAN_EXECUTE } )

local lagcount_meltdown = CreateConVar( "lagcount_meltdown", "100", { FCVAR_SERVER_CAN_EXECUTE } )
local lagexecute_meltdown = CreateConVar( "lagexecute_meltdown", "say [LAGDETECTOR] The server appears to having difficulties, Captain!", { FCVAR_SERVER_CAN_EXECUTE } )
--local lagexecute_meltdown = CreateConVar( "lagexecute_meltdown", "ulx maprestart", { FCVAR_SERVER_CAN_EXECUTE } )



-----------------------------------------------------------------------------------------------
-----------------------------------------------------------------------------------------------



local lastSysCurrDiff = 9999
local deltaSysCurrDiff = 0

local currcount = 0
local clearTime = 0
local framecount = 0

hook.Add( "Think", "LagDetThink", function()  framecount = framecount + 1  end)

-- Calculate lag by comparing SysTime to CurTime.  
-- Increased differential indicates potential lag
local function GetCurrentDelta()
	--local frametime = FrameTime()
	--fps = 1 / frametime
	
	local SysCurrDiff = SysTime() - CurTime() -- current differential
	deltaSysCurrDiff = math.Round(SysCurrDiff - lastSysCurrDiff, 6) -- change in differential since last check
	lastSysCurrDiff = SysCurrDiff
	return deltaSysCurrDiff
end
	 


local function LagMonThreshold()

	if currcount > 0 then -- i haz lag?
		if RealTime() > clearTime then -- passed our clear time?
			currcount = 0 -- clear!
			ServerLog("[LAGDETECTOR] Lag has subsided\n")
		end
	end

	local delt = GetCurrentDelta()
	
	if lagverbose:GetInt() == 1 or delt >= lagrange:GetFloat() then
		RunConsoleCommand("stats")
		ServerLog("[LAGDETECTOR] FrameDelta= "..deltaSysCurrDiff.."  LagCount= "..currcount.."  Frames= "..framecount.."  \n")
		
		if currcount == lagcount_meltdown then
			game.ConsoleCommand(lagexecute_meltdown:GetString().."\n")
		end
	end
	
	
	if delt < lagrange:GetFloat() then
		return false
	end
	
	currcount = currcount + 1 -- server is lagging
	clearTime = RealTime() + lagquiet:GetInt() -- bump our clear time
	
	if (currcount == lagcount:GetInt()) then
		return true  -- we've hit our alert threshold. 
	end
	
	
	return false
end

-- really shouldn't change the periodicity!
timer.Create("LagDetCheckPerf",1, 0, function()
	if LagMonThreshold() then
	
		ServerLog("[LAGDETECTOR] Lag detected!\n")
		if (lagexecute:GetString() ~= "") then
			game.ConsoleCommand(lagexecute:GetString().."\n")
		end
	end
	
	framecount = 0
end)


