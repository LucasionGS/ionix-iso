-- ╔══════════════════════════════════════════════════════════════╗
-- ║  Ionix - User Hyprland Configuration                         ║
-- ║  ~/.config/hypr/hyprland.lua                                 ║
-- ║                                                              ║
-- ║  System defaults are loaded first from /etc/hypr/.           ║
-- ║  Add your personal overrides below the dofile line.          ║
-- ╚══════════════════════════════════════════════════════════════╝

-- Load system defaults
dofile("/etc/hypr/hyprland.lua")
dofile( os.getenv("HOME") .. "/.config/hypr/monitors.lua")
dofile( os.getenv("HOME") .. "/.config/hypr/workspaces.lua")

local function file_exists(name)
   local f=io.open(name,"r")
   if f~=nil then io.close(f) return true else return false end
end

if file_exists(os.getenv("HOME") .. "/.config/hypr/theme.lua") then
  dofile(os.getenv("HOME") .. "/.config/hypr/theme.lua")
end

hl.notification.create({
  text = "Your Hyprland configuration has been loaded successfully.",
  timeout = 2000,
})

-- ── Your Overrides ────────────────────────────────────────────
-- Add your custom configuration below. Anything here takes
-- precedence over the system defaults above.
--
-- Examples:
--
-- Custom monitor layout:
--   hl.monitor({ output = "DP-1", mode = "2560x1440@144", position = "0x0", scale = 1 })
--   hl.monitor({ output = "HDMI-A-1", mode = "1920x1080@60", position = "2560x0", scale = 1 })
--
-- Change keyboard layout (the default is the system's: `localectl set-x11-keymap`):
--   hl.config({ input = { kb_layout = "de" } })
--
-- Add new keybindings. The description is what the shortcut list (Super+F1) shows:
--   hl.bind(mainMod .. " + code:60", hl.dsp.exec_cmd("yourapp"), { description = "Apps: Your app" })
--
-- Override gaps:
--   hl.config({ general = { gaps_in = 3, gaps_out = 6 } })