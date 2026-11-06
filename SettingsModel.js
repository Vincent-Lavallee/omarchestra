// Data model for the Settings app. Kept separate from the QML so Settings.qml
// stays about behavior (state, commands, layout) rather than content.
//
// Imported from Settings.qml with `import "SettingsModel.js" as Data`, then
// exposed as root properties (`sections`, `rows`, `browserOptions`, …) so the
// per-section UI blocks can read them through their `host` reference.

// Sidebar groups, in display order. Each section carries a `group` matching one
// of these; the rail renders a header per group followed by its sections.
var sectionGroups = [
  "Personalization", "Connectivity", "System", "Apps & Defaults", "Security", "About"
]

// The left rail. `keywords` widen search beyond the label/description/section.
var sections = [
  { id: "appearance", group: "Personalization", label: "Appearance", icon: "󰸌",
    keywords: ["theme", "style", "look", "wallpaper", "font", "colors", "dark mode", "animations", "motion", "transitions"] },
  { id: "displays",   group: "Personalization", label: "Displays",    icon: "󰍹",
    keywords: ["monitor", "screen", "resolution", "scaling", "brightness", "external display", "output", "night light"] },
  { id: "sound",      group: "Personalization", label: "Sound",       icon: "󰕾",
    keywords: ["audio", "volume", "speaker", "microphone", "mic", "headphones", "input", "output"] },
  { id: "notifications", group: "Personalization", label: "Notifications", icon: "󰂛",
    keywords: ["notification", "alerts", "dnd", "do not disturb", "mute"] },
  { id: "network",    group: "Connectivity", label: "Network",     icon: "󰖩",
    keywords: ["wifi", "wi-fi", "wireless", "ethernet", "internet", "lan", "dns"] },
  { id: "bluetooth",  group: "Connectivity", label: "Bluetooth",   icon: "󰂯",
    keywords: ["bt", "pair", "device", "headset", "connect", "airpods"] },
  { id: "power",      group: "System", label: "Power & Sleep", icon: "󰐥",
    keywords: ["battery", "sleep", "suspend", "lid", "idle", "lock", "screensaver", "screen saver", "energy"] },
  { id: "storage",    group: "System", label: "Storage",     icon: "󰋊",
    keywords: ["disk", "drive", "space", "snapshot", "usage", "btrfs", "rollback"] },
  { id: "pointer",    group: "System", label: "Trackpad & Mouse", icon: "󰟸",
    keywords: ["touchpad", "trackpad", "mouse", "pointer", "cursor", "tap to click", "right click", "scroll", "scroll direction",
               "scroll speed", "natural scrolling", "swipe", "gesture", "workspace swipe", "acceleration", "sensitivity"] },
  { id: "keyboard",   group: "System", label: "Keyboard & Config", icon: "󰌌",
    keywords: ["keybindings", "shortcut", "hotkeys", "input", "keyboard layout", "language", "layout", "keyboard language"] },
  { id: "terminal",   group: "Apps & Defaults", label: "Terminal",    icon: "󰆍",
    keywords: ["shell", "zsh", "bash", "oh-my-zsh", "command line", "cli", "terminal"] },
  { id: "defaults",   group: "Apps & Defaults", label: "Defaults",    icon: "󰄬",
    keywords: ["default apps", "browser", "terminal", "editor", "agent", "open with"] },
  { id: "security",   group: "Security", label: "Accounts & Security", icon: "󰌾",
    keywords: ["user", "account", "password", "fingerprint", "fido2", "ssh", "encryption", "sudo"] },
  { id: "about",      group: "About", label: "About",       icon: "",
    keywords: ["system info", "version", "specs", "hardware", "about", "documentation"] }
]

// Each row: { section, label, description, icon, command, keywords }.
// Commands are the same strings the launcher menu runs, or direct summons of
// the existing per-topic panels.
//
// Optional flags:
//   bottom   — render below the section's custom blocks instead of above them
//              (used for "open the config file" escape hatches).
//   featured — draw the row as a highlighted call-to-action.
var rows = [
  // Appearance
  { section: "appearance", label: "Theme", description: "Switch the color theme", icon: "󱐋",
    command: "theme=$(omarchy-theme-switcher); [[ -n $theme ]] && omarchy-theme-set \"$theme\"",
    keywords: ["color scheme", "colors", "accent", "palette", "dark", "light", "theme"] },
  { section: "appearance", label: "Background", description: "Change the wallpaper (the lock screen shows it too)", icon: "󰸉",
    command: "background=$(omarchy-theme-bg-switcher); [[ -n $background ]] && omarchy-theme-bg-set \"$background\"",
    keywords: ["wallpaper", "desktop picture", "image", "bg", "wall", "photo"] },
  { section: "appearance", label: "Font", description: "Pick the system font", icon: "󰛖",
    command: "omarchy menu summon style.font",
    keywords: ["typeface", "typography", "font size", "text size", "monospace"] },
  { section: "appearance", label: "Menu bar", description: "Position and transparency", icon: "󰍜",
    command: "omarchy menu summon style.bar",
    keywords: ["taskbar", "status bar", "top bar", "panel", "bar position", "transparency", "dock"] },
  // Omarchy's own lock screen has no wallpaper setting: it shows the current
  // wallpaper, blurred. So this opens the same picker as "Background", under the
  // name people look for — no extra plugin needed.
  { section: "appearance", label: "Lock screen", description: "Pick the wallpaper shown behind the lock screen", icon: "󰌾",
    command: "background=$(omarchy-theme-bg-switcher); [[ -n $background ]] && omarchy-theme-bg-set \"$background\"",
    keywords: ["lock", "lockscreen", "lock screen wallpaper", "wallpaper", "background", "unlock", "login", "blur"] },
  { section: "appearance", label: "Boot screen", description: "The disk-unlock screen shown at startup", icon: "󰟵",
    command: "omarchy menu summon style.unlock",
    keywords: ["boot", "boot lock screen", "plymouth", "splash", "startup", "disk unlock", "encryption", "login", "unlock"] },

  // Displays
  { section: "displays", label: "Displays", description: "Brightness, scale, and output layout", icon: "󰍹",
    command: "omarchy-shell shell summon omarchy.monitor",
    keywords: ["monitor", "screen", "resolution", "scaling", "brightness", "display", "multi-monitor", "external"] },
  { section: "displays", label: "Night light", description: "Toggle the blue-light filter", icon: "󰌵",
    command: "omarchy toggle nightlight",
    keywords: ["blue light", "redshift", "night shift", "warm", "color temperature", "eye strain", "flux"] },

  // Sound
  { section: "sound", label: "Audio", description: "Output, input, and volume", icon: "󰕾",
    command: "omarchy-shell shell summon omarchy.audio",
    keywords: ["volume", "speaker", "microphone", "mic", "headphones", "output", "input", "sink", "source"] },

  // Network
  { section: "network", label: "Network", description: "Wi-Fi and ethernet", icon: "󰖩",
    command: "omarchy-shell shell summon omarchy.network",
    keywords: ["wifi", "wi-fi", "wireless", "ethernet", "internet", "lan", "ssid", "hotspot"] },
  { section: "network", label: "DNS", description: "Choose a DNS provider", icon: "󰇖",
    command: "omarchy menu summon setup.network.dns",
    keywords: ["resolver", "nameserver", "dns provider", "cloudflare", "google", "custom dns"] },

  // Bluetooth
  { section: "bluetooth", label: "Bluetooth", description: "Paired and nearby devices", icon: "󰂯",
    command: "omarchy-shell shell summon omarchy.bluetooth",
    keywords: ["bt", "pair", "device", "headset", "airpods", "connect", "unpair"] },

  // Notifications
  { section: "notifications", label: "Send test notification", description: "Show a sample notification", icon: "󰂛",
    command: "omarchy notification send 'Hello from Settings'",
    keywords: ["test", "sample", "preview", "notification test"] },
  { section: "notifications", label: "Clear notifications", description: "Dismiss all current notifications", icon: "󰈔",
    command: "omarchy-shell notifications dismissAll",
    keywords: ["dismiss", "clear", "remove", "notification center"] },

  // Power & Sleep
  { section: "power", label: "Power", description: "Battery and power profiles", icon: "󰐥",
    command: "omarchy-shell shell summon omarchy.power",
    keywords: ["battery", "charge", "power profile", "performance", "balanced", "saver", "laptop"] },
  { section: "power", label: "Enable screensaver", description: "Turn the screensaver on or off", icon: "󱄄",
    command: "omarchy toggle screensaver",
    keywords: ["screen saver", "screensaver", "display sleep", "ambient", "idle screen"] },
  { section: "power", label: "Start screensaver now", description: "Launch it immediately", icon: "󰐊",
    command: "omarchy-launch-screensaver force",
    keywords: ["screensaver now", "preview screensaver", "show screensaver"] },
  { section: "power", label: "Screensaver text & image", description: "Customize what it shows", icon: "󰌾",
    command: "omarchy menu summon style.screensaver",
    keywords: ["screensaver customize", "screensaver text", "screensaver image", "branding"] },
  { section: "power", label: "Reboot to firmware", description: "Restart into BIOS / UEFI setup", icon: "󰌢",
    command: "omarchy-launch-floating-terminal-with-presentation 'sudo systemctl reboot --firmware-setup'",
    keywords: ["bios", "uefi", "firmware setup", "boot menu", "restart"] },

  // Storage
  { section: "storage", label: "Drive info", description: "Disks and free space", icon: "󰋊",
    command: "omarchy-launch-floating-terminal-with-presentation 'lsblk -o NAME,SIZE,TYPE,FSTYPE,MOUNTPOINTS,MODEL && df -h'",
    keywords: ["disk", "drive", "free space", "partition", "storage usage", "capacity", "gb", "lsblk"] },
  { section: "storage", label: "Disk speed test", description: "Benchmark a disk", icon: "󰓅",
    command: "omarchy-launch-floating-terminal-with-presentation omarchy-disk-speedtest",
    keywords: ["benchmark", "speed test", "disk benchmark", "write speed", "read speed", "nvme", "ssd"] },
  { section: "storage", label: "Create snapshot", description: "Capture a system snapshot", icon: "󰌪",
    command: "omarchy-launch-floating-terminal-with-presentation 'omarchy-snapshot create'",
    keywords: ["btrfs", "snapper", "snapshot", "backup", "time machine"] },
  { section: "storage", label: "Restore snapshot", description: "Roll back to a snapshot", icon: "󰌪",
    command: "omarchy-launch-floating-terminal-with-presentation 'omarchy-snapshot restore'",
    keywords: ["btrfs", "snapper", "rollback", "restore point", "backup"] },

  // Accounts & Security
  { section: "security", label: "Security", description: "Fingerprint, FIDO2, SSH, and more", icon: "󰌾",
    command: "omarchy menu summon setup.security",
    keywords: ["fingerprint", "fido2", "ssh", "sshd", "encryption", "sudo", "2fa", "yubikey", "lock down"] },
  { section: "security", label: "Change password", description: "Update the user password", icon: "󰢪",
    command: "omarchy-launch-floating-terminal-with-presentation passwd",
    keywords: ["passwd", "password change", "user password", "reset password"] },

  // Keyboard & Config
  { section: "keyboard", label: "Keybindings", description: "View and edit keyboard shortcuts", icon: "󰌌", bottom: true,
    command: "omarchy-launch-config-editor \"$HOME/.config/hypr/bindings.lua\"",
    keywords: ["keyboard shortcuts", "hotkeys", "bindings", "shortcut", "keys", "rebind"] },
  { section: "keyboard", label: "Input config", description: "Advanced: edit input.lua (repeat rate, numlock, and more)", icon: "󰌌", bottom: true,
    command: "omarchy-launch-config-editor \"$HOME/.config/hypr/input.lua\"",
    keywords: ["keyboard", "mouse", "touchpad", "trackpad", "input device", "repeat rate", "layout", "input.lua"] },

  // About
  // Opens in the default browser (not a webapp window) so GitHub is already
  // signed in.
  { section: "about", label: "Request a feature", description: "Missing a setting, or found a bug? Tell us on GitHub", icon: "󰅺", featured: true,
    command: "omarchy-launch-browser 'https://github.com/Vincent-Lavallee/omarchestra/issues/new/choose'",
    keywords: ["feature", "request", "suggest", "idea", "issue", "bug", "feedback", "github", "report", "omarchestra"] },
  { section: "about", label: "About this computer", description: "Hardware and system overview", icon: "",
    command: "omarchy launch about",
    keywords: ["system info", "specs", "hardware", "overview", "fastfetch", "about", "version"] },
  { section: "about", label: "System stats", description: "CPU and memory usage", icon: "󰍛",
    command: "omarchy-launch-floating-terminal-with-presentation 'omarchy system stats'",
    keywords: ["cpu", "memory", "ram", "usage", "performance", "load"] },
  { section: "about", label: "Documentation", description: "Open the Omarchy manual", icon: "󰈔",
    command: "omarchy-launch-webapp 'https://omarchy.org/manual/'",
    keywords: ["docs", "manual", "help", "guide", "website"] }
]

// ---- static dropdown option lists --------------------------------------

var animOptions = [
  { value: "none", label: "None" },
  { value: "slide", label: "Slide" },
  { value: "slidevert", label: "Slide vertical" },
  { value: "slidefade", label: "Slide + fade" },
  { value: "fade", label: "Fade" }
]

// Window padding presets. "default" is Omarchy's gaps (5 inner / 10 outer);
// it maps to removing the override so the system default always wins.
var windowPaddingOptions = [
  { value: "none", label: "None" },
  { value: "compact", label: "Compact" },
  { value: "default", label: "Default" },
  { value: "comfortable", label: "Comfortable" },
  { value: "large", label: "Large" }
]

// Scroll direction. `natural` is Hyprland's natural_scroll = true. The labels say
// what actually happens, per device, instead of a product name.
var touchpadScrollDirectionOptions = [
  { value: "natural", label: "Follows your fingers" },
  { value: "traditional", label: "Traditional" }
]

var mouseScrollDirectionOptions = [
  { value: "natural", label: "Follows the wheel" },
  { value: "traditional", label: "Traditional" }
]

// Workspace swipe feel. While a swipe is on, these are written alongside the
// gesture. `distance` is how far you swipe for a whole workspace (Hyprland's
// default is 300: a short swipe flies past); `cancelRatio` is how far you must
// get before letting go commits to the next workspace; `minSpeedToForce` is the
// flick speed that commits regardless. Tune here if the swipe still feels off.
//
// Bump `version` whenever you change these: it makes the app regenerate the
// files it already wrote, so existing installs pick the new values up.
var swipeTuning = { version: 1, distance: 500, cancelRatio: 0.2, minSpeedToForce: 8 }

// The slide that plays when you let go of a swipe (and on every workspace
// switch). It's a spring, not a bezier curve, the same kind of motion macOS uses:
// it glides to a stop with a long soft tail, and if a new swipe interrupts it
// mid-slide it carries its speed over instead of restarting. Measured on this
// hardware (share of the slide done at 50% / 90% / 99% of the way): about
// 108 / 267 / 442 ms, so it's as quick to move as the old 450 ms bezier but lands
// more gently. `stiffness` is how fast it moves, `damping` how little it rings
// (25 is just short of critical damping: no bounce). Keep `mass` at 1. Hyprland
// ignores the animation's `speed` for springs, so the spring alone sets the timing.
// Bump `version` when you change it, as with swipeTuning above.
var slideAnimation = { version: 2, mass: 1, stiffness: 170, damping: 25 }

// Touchpad right-click: Hyprland's `clickfinger_behavior` (false = press the
// bottom-right corner, true = click with two fingers anywhere). The corner's
// size is fixed by libinput and not configurable.
var rightClickOptions = [
  { value: "corner", label: "Bottom-right corner" },
  { value: "twofinger", label: "Two-finger click" }
]

// Touchpad workspace swipe: a horizontal N-finger swipe switches workspaces.
var swipeOptions = [
  { value: "off", label: "Off" },
  { value: "3", label: "3 fingers" },
  { value: "4", label: "4 fingers" }
]

var accelOptions = [
  { value: "adaptive", label: "Adaptive (speeds up as you move faster)" },
  { value: "flat", label: "Flat (same speed, no acceleration)" }
]

var lidActionOptions = [
  { value: "ignore", label: "Do nothing" },
  { value: "lock", label: "Lock" },
  { value: "suspend", label: "Suspend" },
  { value: "hibernate", label: "Hibernate" },
  { value: "poweroff", label: "Power off" }
]

var lockTimeoutOptions = [
  { value: "never", label: "Never" },
  { value: "60", label: "1 minute" },
  { value: "300", label: "5 minutes" },
  { value: "600", label: "10 minutes" },
  { value: "1800", label: "30 minutes" }
]

var sleepTimeoutOptions = [
  { value: "never", label: "Never" },
  { value: "5", label: "5 minutes" },
  { value: "15", label: "15 minutes" },
  { value: "30", label: "30 minutes" },
  { value: "60", label: "1 hour" },
  { value: "120", label: "2 hours" }
]

var muteOptions = [
  { value: "", label: "Choose a duration…" },
  { value: "15", label: "15 minutes" },
  { value: "30", label: "30 minutes" },
  { value: "60", label: "1 hour" },
  { value: "120", label: "2 hours" },
  { value: "240", label: "4 hours" },
  { value: "480", label: "8 hours" }
]

var sudoOptions = [
  { value: "15", label: "15 minutes" },
  { value: "60", label: "1 hour" },
  { value: "240", label: "4 hours" }
]

var browserOptions = [
  { value: "chromium", label: "Chromium" },
  { value: "chrome", label: "Chrome" },
  { value: "brave", label: "Brave" },
  { value: "brave-origin", label: "Brave Origin" },
  { value: "edge", label: "Edge" },
  { value: "firefox", label: "Firefox" },
  { value: "zen", label: "Zen" }
]

var terminalOptions = [
  { value: "alacritty", label: "Alacritty" },
  { value: "foot", label: "Foot" },
  { value: "ghostty", label: "Ghostty" },
  { value: "kitty", label: "Kitty" }
]

var editorOptions = [
  { value: "nvim", label: "Neovim" },
  { value: "code", label: "VSCode" },
  { value: "cursor", label: "Cursor" },
  { value: "zed", label: "Zed" },
  { value: "sublime_text", label: "Sublime Text" },
  { value: "helix", label: "Helix" },
  { value: "vim", label: "Vim" },
  { value: "emacs", label: "Emacs" }
]

var agentOptions = [
  { value: "pi", label: "Pi" },
  { value: "omp", label: "Oh My Pi" },
  { value: "opencode", label: "OpenCode" },
  { value: "claude", label: "Claude Code" },
  { value: "codex", label: "Codex" },
  { value: "grok", label: "Grok" },
  { value: "gemini", label: "Gemini" },
  { value: "copilot", label: "GitHub Copilot" },
  { value: "crush", label: "Crush" }
]
