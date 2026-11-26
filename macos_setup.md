# MacOS Fresh Install

## Settings

System Settings
  -> Touch ID & Password -> setup touch id 
  -> Keyboard -> keyboard shortcuts
    -> Mission Control
      -> Mission Control (ctrl-up)
      -> Application Windows (ctrl-left)
      -> Show Desktop (ctrl-down)
      -> Mission Control
        -> Move left a space (opt-H)
        -> Move right a space (opt-L)
        -> Switch to Desktop 1 (ctrl-1)
      -> Windows
        -> TODO (replaces hammerspoon)
    -> modifier keys
      -> caps lock to escape
      -> Globe key (ctrl or globe)
  -> Appearance -> Dark 
  -> Accessibility
    -> Motion -> Reduce motion
    -> Zoom
      -> Use keyboard shortcuts to zoom (on)
      -> Use scroll gestures with modifier keys to zoom
    -> Display
      -> Increase contrast (optional)
      -> Differentiate without color
  -> Desktop & Dock
    -> Automatically hide and show the Dock (on)
    -> Show suggested and recent apps in Dock (off)
    -> Windows -> Prefer tabs when opening documents (Always)
    -> Drag windows to left or right edge of screen to tile (off)
    -> Drag windows to menu bar to fill screen (off)
    -> Mission Control
      -> Automatically rearrange Spaces based on most recent use (off)
      -> Displays have separate Spaces (on or off)
    -> Hot Corners... (all off)
  -> Menu Bar
    -> Automatically hide and show the menu bar (Always)
    -> Spotlight (off)
    -> Wi-Fi (off)
    -> 1Password (off)
    -> Alfred (off)
    -> CrashPlan (off)
    -> Self Service+ (off)
    -> SentinalAgent (off)
    -> Menu Bar Controls -> Add Controls...

Finder -> Settings
  -> General
    -> Show these items on the desktop:
      - Hard disks (on)
      - Connected servers (on)
    -> New Finder windows show ($HOME)
    -> Open folders in tabs instead of new windows (on)
  -> Sidebar -> Show these items in the sidebar:
    -> Recents (off)
    -> Shared (on or off)
    -> Favorites
      -> /Applications (on)
      -> Desktop (on)
      -> Documents (on)
      -> Downloads (on)
    -> Locations
      -> iCloud Drive (on or off)
      -> Cloud Storage (on or off)
      -> ngogober (on)
      -> <hostname> (on)
      -> Hard disks (off)
      -> External disks (on or off)
      -> AirDrop (on)
      -> Bonjour computers (on or off)
      -> Connected servers (on)
      -> Trash (on)
      -> Tags -> Recent Tags (on or off)
  -> Advanced
    -> Show all filename extensions (on)
    -> Show warning before changing an extension (off)
Finder -> View
  -> Show Tab Bar (shft-cmd-T)
  -> Show Path Bar (opt-cmd-P)

## Set up

```sh
mkdir ~/Applications
mkdir ~/Developer
```

### Homebrew

Visit [brew.sh](https://brew.sh/) and run install script in terminal (requires sudo first). This installs Xcode command line tools as well.

```sh
/opt/homebrew/bin/brew analytics off
```

Install Brewfile contents

```sh
brew bundle install ...
```

### Post-Homebrew

settings -> Desktop & Dock -> Default web browser (Firefox)

#### Hammerspoon

launch hammerspoon.app

settings -> Privacy & Security -> Accessibility -> hammerspoon (on)
settings -> General -> Login Items & Extensions -> add hammerspoon

#### 1Password

launch 1password, sign in

Setup 1Password ssh

1password settings -> Developer -> SSH Agent (on)

write ~/.config/1Password/ssh/agent.toml

```toml
[[ssh-keys]]
vault = "Work"
```

#### Firefox

launch firefox, sign in
enable sync
enable firefox containers sync
vertical tabs

#### Alfred


launch alfred -> begin setup
activate powerpack (key in 1pass)

settings -> privacy & security -> full disk access -> Alfred (on)
settings -> privacy & security -> accessibility -> Alfred (on)
settings -> keyboard -> keyboard shortcuts -> spotlight -> show spotlight search (opt-space)
alfred preferences -> general -> alfred hotkey (cmd-space)
[download theme](https://github.com/dracula/alfred/blob/master/Dracula.alfredappearance) and open
alfred preferences -> appearance -> options (bottom right)
  -> Hide hat on Alfred
  -> Hide menu bar icon

### Setup dotfiles

```sh
yadm clone https://github.com/gnodar01/dotfiles.git
```

#### Pixi

[Install pixi](https://pixi.prefix.dev/latest/#installation)

```sh
curl -fsSL https://pixi.sh/install.sh | sh
# new zsh
pixi global install python
``` 

#### volta and nvim

```sh
cp ~/.config/yadm/alt/superhome/config/zsh/.zshrc\#\#default ~/.config/yadm/alt/superhome/config/zsh/.zshrc\#\#hostname.$(uname -n)
yadm add ~/.config/yadm/alt/superhome/config/zsh
yadm alt
# new tab
volta install node@latest
# new tab
vim <some_file>
nv <some_file>
```

#### Rust

```sh
rustup toolchain install stable
```

#### atuin

```sh
atui iport auto
atuin setup --sync cloud
# key is in 1password, or run atuin key on a machine that syncs already

# remove anything added to rc files
yadm restore ~/.config/yadm/alt/.bashrc##default
yadm restore ~/.config/yadm/alt/.zshrc##default
```

## TODO
- vim coming first in path because homebrew is too late, compared to /usr/bin
- plain vim is doing too much on startup
