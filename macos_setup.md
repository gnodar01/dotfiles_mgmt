# MacOS Fresh Install

## Settings

settings -> touch id & password -> setup touch id 
settings -> keyboard -> keyboard shortcuts -> modifier keys -> caps lock to escape
settings -> appearance -> Dark 
settings -> accessibility -> Motion -> Reduce motion
settings -> accessibility -> Zoom
  -> Use keyboard shortcuts to zoom (on)
  -> Use scroll gestures with modifier keys to zoom
settings -> accessibility -> Display
  -> Increase contrast (optional)
  -> Differentiate without color
desktop & dock -> Automatically hide and show the Dock

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

#### Hammerspoon

launch hammerspoon.app

settings -> privacy & security -> accessibility -> hammerspoon on
settings -> general -> login items & extensions -> add hammerspoon

#### 1Password

launch 1password, sign in

Setup 1Password ssh

1password settings -> Developer -> turn on SSH Agent

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

settings -> privacy & security -> full disk access -> Alfred on
settings -> privacy & security -> accessibility -> Alfred on
settings -> keyboard -> keyboard shortcuts -> spotlight -> show spotlight search: opt-space
alfred preferences -> general -> alfred hotkey: cmd-space
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
