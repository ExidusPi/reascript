--[[
ReaScript name: js_Notation - Set display length of selected notes to double.lua
Version: 1.2
Author: juliansader
Website: http://forum.cockos.com/showthread.php?t=172782&page=25
About:
  # Description
  This script sets the notation displayed lengths of selected notes to double their MIDI lengths, and then
  adds staccato articulations.
  
  The script is intended to help solve the problem of short notes (such as staccato or muted guitar notes) 
  that are notated with extraneous rests in-between.
  
  Simply increasing the displayed length of the notes (by using the built-in action "Nudge length display 
  offset right", for example) will remove the rests, but then the displayed lengths will not accurately 
  reflect the lengths of the underlying MIDI notes.
  
  This script therefore adds staccato articulations to indicate that the underlying MIDI notes are 
  actually shorter. (The standard interpretation of staccato articulations is to halve the length of a note.)
  
  # Forum thread
  http://forum.cockos.com/showthread.php?t=172782&page=25
]]

--[[
Changelog:
  * v1.0
    + Initial beta release.
  * v1.1 (2016-08-15)
    + Script's About info compatible with ReaPack 1.1.
    + Improved accuracy of length calculation.
  * v1.2 (2016-08-15)
    + Bug fix for compatibility with takes that do not start at 0.
  * v1.2.1 (2017/06/02)
    + Removed part that adds staccato articulation - David Healey
]]


---------------------------------------------------------------
-- Returns the textsysex index of a given note's notation info.
-- If no notation info is found, returns -1.
function getTextIndexForNote(take, notePPQ, noteChannel, notePitch)

    reaper.MIDI_Sort(take)
    _, _, _, countTextSysex = reaper.MIDI_CountEvts(take)
    if countTextSysex > 0 then 
    
        -- Use binary search to find text event closest to the left of note's PPQ        
        local rightIndex = countTextSysex-1
        local leftIndex = 0
        local middleIndex
        while (rightIndex-leftIndex)>1 do
            middleIndex = math.ceil((rightIndex+leftIndex)/2)
            local textOK, _, _, textPPQ, _, _ = reaper.MIDI_GetTextSysexEvt(take, middleIndex, true, false, 0, 0, "")
            if textPPQ >= notePPQ then
                rightIndex = middleIndex
            else
                leftIndex = middleIndex
            end     
        end -- while (rightIndex-leftIndex)>1
        
        -- Now search through text events one by one
        for i = leftIndex, countTextSysex-1 do
            local textOK, _, _, textPPQ, type, msg = reaper.MIDI_GetTextSysexEvt(take, i, true, false, 0, 0, "")
            -- Assume that text events are order by PPQ position, so if beyond, no need to search further
            if textPPQ > notePPQ then 
                break
            elseif textPPQ == notePPQ and type == 15 then
                textChannel, textPitch = msg:match("NOTE ([%d]+) ([%d]+)")
                if noteChannel == tonumber(textChannel) and notePitch == tonumber(textPitch) then
                    return i, msg
                end
            end   
        end
    end
    
    -- Nothing was found
    return(-1)
end

--------------------------------------
-- Here the code execution starts
-- function main()
editor = reaper.MIDIEditor_GetActive()
if editor ~= nil then
    take = reaper.MIDIEditor_GetTake(editor)
    if reaper.ValidatePtr2(0, take, "MediaItem_Take*") then    
                        
        reaper.Undo_BeginBlock2(0)

        -- Weird, sometimes REAPER's PPQ is not 960.  So first get PPQ of take.
        local QNstart = reaper.MIDI_GetProjQNFromPPQPos(take, 0)
        PPQ = reaper.MIDI_GetPPQPosFromProjQN(take, QNstart + 1) - reaper.MIDI_GetPPQPosFromProjQN(take, QNstart)
                    
        i = -1
        repeat
            i = reaper.MIDI_EnumSelNotes(take, i)
            if i ~= -1 then
                noteOK, _, _, noteStartPPQ, noteEndPPQ, channel, pitch, _ = reaper.MIDI_GetNote(take, i)
                -- Based on experimentation, it seems that the value of the "disp_len" field (in the notation
                --    editor's text events) represents (change in length)/(quarter note).
                textForField = string.format("%.3f", tostring(  (noteEndPPQ - noteStartPPQ)/PPQ  ))
                
                notationIndex, msg = getTextIndexForNote(take, noteStartPPQ, channel, pitch)
                if notationIndex == -1 then
                    -- If note does not yet have notation info, create new event
                    reaper.MIDI_InsertTextSysexEvt(take, true, false, noteStartPPQ, 15, "NOTE "
                                                                                        ..tostring(channel)
                                                                                        .." "
                                                                                        ..tostring(pitch)
                                                                                        .." "
                                                                                        .." disp_len "
                                                                                        ..textForField)
                else
                    -- Remove existing articulation and length tweaks 
                    msg = msg:gsub(" articulation [%a]+", "")
                    msg = msg:gsub(" disp_len [%-]*[%d]+.[%d]+", "")
                    msg = msg .." disp_len "..textForField
                    reaper.MIDI_SetTextSysexEvt(take, notationIndex, nil, nil, nil, nil, msg, false)
                end
            end
        until i == -1
        
        reaper.Undo_EndBlock2(0, "Notation - Set display length to double and add staccato articulation", -1)
    end
end
