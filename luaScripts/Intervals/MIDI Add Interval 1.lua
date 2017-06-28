package.path = debug.getinfo(1,"S").source:match[[^@?(.*[\/])[^\/]-$]] .."../?.lua;".. package.path
require('daves reaper midi package v1-0')

local INTERVAL = 1;

reaper.Undo_BeginBlock();
drmp.addIntervalToSelectedNotes(INTERVAL)
reaper.Undo_EndBlock("MIDI Add Interval To Selected Notes 1",-1);