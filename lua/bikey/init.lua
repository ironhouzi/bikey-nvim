local dbus_proxy = require'dbus_proxy'


local function set_config()
  local bikey_dbus = nil
  local os = nil
  local gnome_input_sources = 'imports.ui.status.keyboard.'
    .. 'getInputSourceManager().inputSources'

  local os_configs = {
    ubuntu = {
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
        local layouts = bikey_dbus:Eval(gnome_input_sources)
        print(vim.inspect(layouts))
        return layouts
      end,
    },
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
        local layouts = bikey_dbus:getLayoutsList()
        print(vim.inspect(layouts))
        return layouts
      end,
    },
  }

  for distro, cfg in pairs(os_configs) do
    if pcall(function() dbus_proxy.Proxy:new(cfg.connection) end) then
      bikey_dbus = dbus_proxy.Proxy:new(cfg.connection)
      os = distro
      break
    end
  end

  assert(os ~= nil)
  assert(bikey_dbus ~= nil)
  return os_configs[os]
end

local bikey = set_config()

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
