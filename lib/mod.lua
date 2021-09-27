local mod = require 'core/mods'
local util = require 'lib/util'

local tuning = require 'tuning/lib/tuning'
local tunings_builtin = require 'tuning/lib/tunings_builtin'

local tuning_state = {
   root_note = 69,
   root_freq = 440,
   selected_tuning = 'ji_ptolemaic'
}

local tunings = {}
local tuning_keys= {}
local tuning_keys_rev = {}
local num_tunings = 0

local build_tunings = function()
   tunings = {}
   tuning_keys = {}
   tuning_keys_rev = {}
   num_tunings = 0
   for k,v in pairs(tunings_builtin) do
      tunings[k] = v
      table.insert(tuning_keys, k)
      num_tunings = num_tunings + 1
   end

   --------------
   -- TODO: read additional tunings from disk here
   --------------
   
   table.sort(tuning_keys)
   for i,v in ipairs(tuning_keys) do
      -- print('tuning key ' .. i .. ' = '..v)
      tuning_keys_rev[v] = i
   end
end

-------------------------------------
-- wrappers for dynamic monkeying

local note_freq = function(note)
   --print('note_freq: '..tuning_state.selected_tuning)
   return tunings[tuning_state.selected_tuning].note_freq(note, tuning_state.root_note, tuning_state.root_freq)
end

local interval_ratio = function(interval)
   return tunings[tuning_state.selected_tuning].interval_ratio(interval)
end

local apply_mod = function()
   print('tuning mod: patching musicutil')
   
   if not musicutil then
      musicutil = require 'lib/musicutil'
   end
   
   musicutil.note_num_to_freq = note_freq

   if MusicUtil then
      MusicUtil = musicutil
   end
   
   if Musicutil then
      Musicutil = musicutil
   end
   
end


----------------------
--- state persistanc
local state_path = _path.data .. 'tuning_state.lua'

local save_tuning_state = function()
   local f = io.open(state_path, 'w')
   io.output(f)
   io.write('return { \n')
   local keys = {'selected_tuning', 'root_note', 'root_freq'}
   for _,k in pairs(keys) do
      local v = tuning_state[k]
      local vstr = v
      if type(v) == 'string' then vstr = "'"..v.."'" end
      io.write('  '..k..' = '..vstr..',\n')
   end
   io.write('}\n')
   io.close(f)
end

local recall_tuning_state = function()
   local f = io.open(state_path)
   if f then
      io.close(f)
      tuning_state = dofile(state_path)
   end
end

-----------------------------
---- hooks!

mod.hook.register("system_post_startup", "init tuning mod", build_tunings)

-- this kinda does have to happen on each script,
-- because of the various ways of including MusicUtil
mod.hook.register("script_pre_init", "apply tuning mod", apply_mod)

mod.hook.register("system_post_startup", "recall tuning mod settings", recall_tuning_state)

mod.hook.register("system_pre_shutdown", "save tuning mod settings", save_tuning_state)

-----------------------------
---- menu UI

local edit_select = {
   [1] = 'tuning',
   [2] = 'note',
   [3] = 'freq'
}
local num_edit_select = 3

local m = {
   edit_select = 1
}

m.key = function(n, z)
  if n == 2 and z == 1 then
    -- return to the mod selection menu
    mod.menu.exit()
  end
end

m_enc = {
   [2] = function(d)
      m.edit_select = util.clamp(m.edit_select + d, 1, num_edit_select)
   end,
   
   [3] = function(d)
      (m_incdec[m.edit_select])(d)
   end
}

m_incdec = {
   -- edit tuning selection
   [1] = function(d)
      local i = tuning_keys_rev[tuning_state.selected_tuning]
      i = util.clamp(i + d, 1, num_tunings)
      tuning_state.selected_tuning = tuning_keys[i]
   end,
   -- edit root note
   [2] = function(d)   
      tuning_state.root_note = tuning_state.root_note + d
      tuning_state.root_note = util.clamp(tuning_state.root_note, 0, 127)
   end,
   -- edit base frequency
   [3] = function(d)
      tuning_state.root_freq = tuning_state.root_freq + (d/2)
      tuning_state.root_freq = util.clamp(tuning_state.root_freq, 1, 10000)
   end,     
}

m.enc = function(n, d)
   if m_enc[n] then (m_enc[n])(d) end
   mod.menu.redraw()
end

m.redraw = function()
   screen.clear()
   
   screen.move(0, 10)
   if edit_select[m.edit_select] == 'tuning' then
      screen.level(15)
   else
      screen.level(4)
   end
   screen.text(tuning_state.selected_tuning)
   
   screen.move(0, 20)
   if edit_select[m.edit_select] == 'note' then
      screen.level(15)
   else
      screen.level(4)
   end
   screen.text(tuning_state.root_note)
   
   screen.move(0, 30)
   if edit_select[m.edit_select] == 'freq' then
      screen.level(15)
   else
      screen.level(4)
   end
   screen.text(tuning_state.root_freq)
   
   screen.update()
end

m.init = function()
   build_tunings()
end

m.deinit = function()
   --- ... ???
end

mod.menu.register(mod.this_name, m)


----------------------
--- API

local api = {}

api.get_tuning_state = function()
  return tuning_state
end

api.get_tuning_data = function()
  return tunings
end

api.save_state = save_tuning_state
api.recall_state = recall_tuning_state

return api
