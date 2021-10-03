VERSION = "0.1"

----------------------------
-- CMAKE STARTS FROM HERE --
----------------------------

local points = {}

local micro, config, shell, buffer, os
function init()
	micro = import("micro")
	config = import("micro/config")
	shell = import("micro/shell")
	buffer = import("micro/buffer")
	os = import("os");

	config.MakeCommand("CMbuild", onCMakeBuild, NoComplete)
	config.MakeCommand("CMgen", onCMakeGen, NoComplete)
	config.MakeCommand("CMrun", onCMakeRun, NoComplete)
	config.MakeCommand("CMset", onCMakeSet, NoComplete)
	config.MakeCommand("CMgdb", onCMakeGdb, NoComplete)
	config.MakeCommand("CMbr", onCMakeBreak, NoComplete)
	config.MakeCommand("CMpts", onCMakePoints, NoComplete)
	config.MakeCommand("CMvis", onCMakeVisualize, NoComplete)

	config.AddRuntimeFile("micmake", config.RTHelp, "help/micmake.md")
end

function onCMakeVisualize(bp)
	buffer.Log("Loading breakpoints\n")
	local name = bp.Buf:GetName()
	if (points[name] == nil) then
		points[name] = {}
	end

	for i, j in pairs(points[name]) do 
		local str = name .. ":" .. i
		bp.Buf:ClearMessages("CMbr-" .. str);
		bp.Buf:AddMessage(j)
		buffer.Log("Loaded " .. str .. "\n")
	end
end

function onBufPaneOpen(bp)
	onCMakeVisualize(bp)
	return true
end

function onCMakePoints(bp, args)
	for i, v in pairs(points) do
		for j, k in pairs(v) do
			buffer.Log(i .. ":" .. j .. "\n");
		end
	end

	micro.InfoBar():Message("Check log.\n")
end

function onCMakeBreak(bp, args)
	local name = bp.Buf:GetName()
	local line =  (bp.Cursor.Loc.Y + 1)
	local str = name .. ":" .. line

	if (points[name] == nil) then
		points[name] = {}
	end
	
	if (points[name][line] ~= nil) then
		bp.Buf:ClearMessages("CMbr-" .. str)
		points[name][line] = nil
		micro.InfoBar():Message("Deleted breakpoint: " .. str .. "\n")
	else
		points[name][line] = buffer.NewMessageAtLine("CMbr-" .. str, "Breakpoint", line, buffer.MTInfo)
		bp.Buf:AddMessage(points[name][line])
		micro.InfoBar():Message("Added breakpoint: " .. str .. "\n")
	end
end

function onCMakeBuild(bp, args)
	os.Chdir("build")
	local str = shell.RunInteractiveShell("make", true, true)
	newbp = bp:HSplitIndex(buffer.NewBuffer(str, "cmake"), true)
	os.Chdir("..")
end

function cmakecallback(out, userargs)
end

local exec = nil
local mode = "Release"

function onCMakeSet(bp, args)
	-- TODO: bound checking
	if (args[1] == "x") then
		exec = args[2]
	elseif (args[1] == "m") then
		if (args[2] == "r") then
			mode = "Release"
		elseif (args[2] == "d") then
			mode = "Debug"
		elseif (args[2] == "r+") then
			mode = "RelWithDebInfo"
		end
	end
end

function onCMakeGdb(bp, args)
	if (exec == nil) then
		micro.InfoBar():Message("Specify executable name by \"CMset x <name>\".\n")
		return
	end

	local cmd = "gdb -e \"build/" .. exec .. "\" -ex \"file build/" .. exec .. "\""

	for i, v in pairs(points) do
		for j, k in pairs(v) do
			local loc = i .. ":" .. j
			cmd = cmd .. " -ex \"br " .. loc .. "\""
		end
	end

	cmd = cmd .. " -ex run"
	shell.RunInteractiveShell(cmd, false, false)
end

function onCMakeRun(bp, args)
	if (exec == nil) then
		micro.InfoBar():Message("Specify executable name by \"CMset x <name>\".\n")
		return
	end

	micro.InfoBar():Message("Run " .. exec .. ".\n")

	os.Chdir("build")
	shell.RunInteractiveShell("./" .. exec, true, false)
	os.Chdir("..")
end

function onCMakeGen(bp, args)
	os.Chdir("build")
	local str = shell.RunInteractiveShell("cmake -DCMAKE_BUILD_TYPE=" .. mode .. " ../", false, true)
	newbp = bp:HSplitIndex(buffer.NewBuffer(str, "cmake"), true)
	os.Chdir("..")
end
