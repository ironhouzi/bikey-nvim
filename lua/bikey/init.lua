local dbus_proxy = require'dbus_proxy'
local cjson = require 'cjson'


local function set_config()
  local bikey_dbus = nil
  local de = nil
  local gnome_input_sources = 'imports.ui.status.keyboard.'
    .. 'getInputSourceManager().inputSources'

  local os_configs = {
    kde = {
      connection = {
        bus = dbus_proxy.Bus.SESSION,
        name = 'org.kde.keyboard',
        interface = 'org.kde.KeyboardLayouts',
        path = '/Layouts',
      },
      normal_mode = function()
        bikey_dbus:setLayout(0)
      end,
      insert_mode = function()
        bikey_dbus:setLayout(vim.b.bikey_active and 1 or 0)
      end,
      kbd_layout_list = function()
        local result = {}
        local layouts = bikey_dbus:getLayoutsList()
        -- layouts fmt: {{"us", "", "English (US"}, ...}
        for _, layout in ipairs(layouts) do
          table.insert(result, {
            id = layout[1],
            fullname = layout[3],
            shortname = vim.inspect(layout[3]:sub(1,2):lower()),
          })
        end
        return result
      end,
    },
    gnome = {
      connection = {
        bus = dbus_proxy.Bus.SESSION,
        name = 'org.gnome.Shell',
        interface = 'org.gnome.Shell',
        path = '/org/gnome/Shell',
      },
      normal_mode = function()
        bikey_dbus:Eval(gnome_input_sources .. '[0].activate()')
      end,
      insert_mode = function()
        local i = vim.b.bikey_active and 1 or 0
        bikey_dbus:Eval(gnome_input_sources .. '[' .. i .. '].activate()')
      end,
      kbd_layout_list = function()
        local result = {}
        local layouts = bikey_dbus:Eval(gnome_input_sources)
        -- layouts fmt: { true, '{"0":{"__caller__":null,"type":"xkb","id":"us",
        --                "displayName":"English (US)","_shortName":"en",
        --                "index":0,"properties":null,"xkbId":"us",
        --                "_signalConnections":[...],"_nextConnectionId":3}, ... }'}
        -- TODO: Find way to avoid explicit deserialization with cjson
        for _, layout in pairs(cjson.decode(layouts[2])) do
          table.insert(result, {
            id = layout['id'],
            fullname = layout['displayName'],
            shortname = layout['_shortName'],
          })
        end
        return result
      end,
    },
  }

  for desktop_env, cfg in pairs(os_configs) do
    if pcall(function() dbus_proxy.Proxy:new(cfg.connection) end) then
      bikey_dbus = dbus_proxy.Proxy:new(cfg.connection)
      de = desktop_env
      break
    end
  end

  assert(de ~= nil)
  assert(bikey_dbus ~= nil)
  return os_configs[de]
end

local bikey = set_config()

local function get_status()
end

local function toggle_bikey()
  vim.b.bikey_active = not vim.b.bikey_active
  print('Bikey active: ' .. (vim.b.bikey_active and 'True' or 'False'))
end

local function setup()
  vim.cmd [[
      augroup bikey
        autocmd!
        autocmd InsertEnter * :lua require"bikey".insert_mode()
        autocmd InsertLeave,FocusGained * :lua require"bikey".normal_mode()
      augroup END
  ]]
end

return {
  toggle = toggle_bikey,
  normal_mode = bikey.normal_mode,
  insert_mode = bikey.insert_mode,
  kbd_layouts = bikey.kbd_layout_list,
  setup = setup,
  -- init = function()
  --   require'plenary.popup'.create('', {width = 80, height = 80})
  -- end,
}
