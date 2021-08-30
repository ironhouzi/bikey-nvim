dbus_proxy = require'dbus_proxy'


local Supported = {
  'KDE',
  'ubuntu:GNOME',
}

local gnome_input_sources = 'imports.ui.status.keyboard.'
  .. 'getInputSourceManager().inputSources'

local config = {
  ['KDE'] = {
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
      return bikey_dbus:getLayoutsList(val)
    end,
  },
  ['ubuntu:GNOME'] = {
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
      return bikey_dbus:Eval(gnome_input_sources)
    end,
  },
}

local desktop_env = os.getenv('XDG_CURRENT_DESKTOP')
local bikey_config = config[desktop_env]
assert(bikey_config, 'Unsupported desktop environment: '
       .. desktop_env .. '. Supported are: ' .. table.concat(Supported, ', '))

bikey_dbus = dbus_proxy.Proxy:new(bikey_config.connection)

local function toggle_bikey()
  vim.b.bikey_active = not vim.b.bikey_active
  print('Bikey active: ' .. (vim.b.bikey_active and 'True' or 'False'))
end

local function nvim_create_augroups(definitions)
	for group_name, definition in pairs(definitions) do
		vim.api.nvim_command('augroup '..group_name)
		vim.api.nvim_command('autocmd!')
		for _, def in ipairs(definition) do
			local command = table.concat(vim.tbl_flatten{'autocmd', def}, ' ')
			vim.api.nvim_command(command)
		end
		vim.api.nvim_command('augroup END')
	end
end

local function setup()
  nvim_create_augroups {
    bikey = {
      { 'InsertEnter', '*', ':lua require"bikey".insert_mode()' },
      { 'InsertLeave,FocusGained', '*', ':lua require"bikey".normal_mode()' },
    },
  }
end

setup()

return {
  set_kbd_layout = set_kbd_layout,
  toggle = toggle_bikey,
  normal_mode = bikey_config.normal_mode,
  insert_mode = bikey_config.insert_mode,
  setup = setup,
  -- init = function()
  --   require'plenary.popup'.create('', {width = 80, height = 80})
  -- end,
}
