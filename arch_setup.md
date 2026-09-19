## Initial

Follow [Installation Guide](https://wiki.archlinux.org/title/Installation_guide),
with some differences to acount for UEFI to dual-boot Bazzite.

See [dual_boot.md](dual_boot.md) for details.

### Network Configuration

hostname was set in initiall installation guide above

Start with [network configuration](https://wiki.archlinux.org/title/Installation_guide#Network_configuration)
* [enable network interface](https://wiki.archlinux.org/title/Network_configuration#Enabling_and_disabling_network_interfaces) (`eno1` ethernet)
* use the [systemd-networkd network manager](https://wiki.archlinux.org/title/Network_configuration#Network_managers)
  * [configure](https://wiki.archlinux.org/title/Systemd-networkd#Configuration) it
  * [enable](https://wiki.archlinux.org/title/Systemd-networkd) it
* [enable systemd-resolved](https://wiki.archlinux.org/title/Systemd-resolved) for DNS resolution

```bash
ip link set eno1 up
ln -s /usr/lib/systemd/network/80-wifi-station.network.example /etc/systemd/network/80-wifi-station.network
ln -s /usr/lib/systemd/network/89-ethernet.network.example /etc/systemd/network/89-ethernet.network
systemctl enable systemd-networkd.service
systemctl enable --now systemd-resolved.service # turn on DNS
```

validate:

```bash
systemctl is-system-running
ls -l /etc/resolv.conf # ensure was created
networkctl status eno1 # eno1 shows routable and configured
ip addr show eno1 # inet (ipv4) shows up
resolvectl status
journalctl -u systemd-networkd -b
ping -c 3 9.9.9.9
ping -c 3 archlinux.org
getent ahosts archlinux.org # can resolve a domain name
```

WARN: should at some point install firewall, e.g. `ufw`, bluetooth (`bluez`, `bluez-utils`, `blueman`), wifi

The validation above (`ping`, and `getent`) go through glibc's NSS layer.
Right now `/etc/resolv.conf` is just comments, no content.
Some systems don't use that, they query systemd-resolved over D-Bus and never read `/etc/resolv.conf`.
But some systems do use that, bypassing NSS entirely, and reading the blank file with no nameserver.
This is important for installing `yay` later, since it's written in Go and uses its own resolver.
This fixes things:

```bash
ln -sf /run/systemd/resolve/stub-resolv.conf /etc/resolv.conf
```

## Post-Install

### Update Keyring

Update the keyring (it's older than the live cd, so upgrades will fail without it)

NOTE: I don't remember running `pacman-key --init`,
and `/etc/pacman.conf` says you must run it before first using pacman.
It may be that I was supposed to run that before/after/instead of this.
Not sure.

NOTE: claude says: "On your `pacman-key --init` uncertainty — `pacstrap` initializes the keyring when it installs `base`, and the `archlinux-keyring` package runs the populate step in a post-install hook. Since your `pacman -S archlinux-keyring` verified signatures and succeeded, the keyring was already initialized correctly. Nothing to redo."

```bash
pacman -S archlinux-keyring
```

Install zsh to use it as a default shell for new user

```bash
pacman -S zsh
```

[Create user account](https://wiki.archlinux.org/title/Users_and_groups#User_management)

```bash
useradd -m -s /usr/bin/zsh nodar
passwd nodar
```

[Setup sudo](https://wiki.archlinux.org/title/Sudo)

```bash
pacman -S vim # needed to run visudo
ln -s ./vim /usr/bin/vim # vi is vim
pacman -S sudo
visudo
# uncomment the following line:
#%wheel ALL=(ALL:ALL) ALL
```

Add `nodar` to `wheel` group

```bash
gpasswd -a nodar wheel
# confirm:
groups nodar
```

Switch to `nodar`.

### Install preliminary packages

```bash
pacman -S yadm
```

#### Genral System Maintanance

Use [reflector](https://wiki.archlinux.org/title/Reflector) to set mirrors for `pacman`.

```bash
sudo pacman -S reflector
relector --country US --latest 10 --sort rate
# use --save /etc/pacman.d/mirrorlist
# or mnually add to /etc/pacman.d/mirrorlist
```

[List of installed packages](https://wiki.archlinux.org/title/Pacman/Tips_and_tricks#List_of_installed_packages)

```bash
pacman -Qqe
```

While there's no distinction between packages installed by `pacman` or `yay`,
packages not installed via main repos (pkgbuild), ie the AUR, can be queried with:

```bash
pacman -Qm
```

[Upgrade packages](https://wiki.archlinux.org/title/System_maintenance#Upgrading_the_system)
WARN: can be dangerous

```bash
pacman -Syu
```

[install packages](https://wiki.archlinux.org/title/Pacman#Installing_specific_packages)

```bash
pacman -S <package_name1> <package_name2> ...
```

search for packages

```bash
pacman -Ss <package_name>
```

search for packages locally (to see if they are installed)

```bash
pacman -Qs <package_name>
```

dependants

```bash
pacman -Sii <package_name> # Required By section
```

remove package

```bash
pacman -Rn <package_name>
# also remove unused deps
pacman -Rsn <package_name>
```

### Dotfiles

already installed:
`curl`, `gnupg`, `tar`, `sed`, `awk`, `git`

install:
`make`, `gcc`, `g++`

```bash
sudo pacman -S base-devel
```

install very basics:
`wget`, `openssh`, `unzip`, `less`, `man-db`

```bash
sudo pacman -S wget unzip less openssh
```

install [yay](https://github.com/jguer/yay) for [Arch User Repsoitory (AUR) packages](https://wiki.archlinux.org/title/Arch_User_Repository)

```bash
git clone https://aur.archlinux.org/yay.git
cd yay
makepkg -si # installs go
cd
rm -rf yay
```

install others

`pacman -S yazi` produces the message that there are 74 providers available for `ttf-font-nerd`,
and makes you choose. Option 54 is `ttf-meslo-nerd`.
Or just install it directly, before `yazi`.

```bash
pacman -S ttf-meslo-nerd
```

```bash
pacman -S \
    pixi \
    file \
    ripgrep \
    fd-find \
    bat \
    jq \
    yazi \
    fzf \
    eza \
    hexyl \
    git-delta \
    starship \
    nvim \
    luarocks \
    tree-sitter-cli

pixi global install nodejs
```

For `yazi`, consider `poppler` for PDF preview, `resvg` for SVG preview
Also for `yazi` but in general consider
`imagemagick`
`wl-clipboard` (wayland clipboard)
`chafa` for ascii iamge preview fallback

Yadm clone and bootsrap

WARN: This screws up the default terminal, which is not kitty.
Temporarily, can switch to `bash`, until kitty set up (which requires a display server).

NOTE: Have to use `https` because can't get ssh key set up yet.

```bash
yadm clone https://github.com/gnodar01/dotfiles.git
```

### hyprland

Install hyprland

```bash
sudo pacman -S hyprland
```

Now following hyprland's [master tutorial](https://wiki.hypr.land/Getting-Started/Master-Tutorial/).

`start-hyperland` (super-M to quit, with super as `opt`) has an interactive getting started guide, it recommends the following categories:

* Authentication Agent - `hyprpolkitagent`
* Terminal - `kitty`
* Wallpaper (optional) - `swaybg`
* Notification Daemon - `fnott`
* Application Launcher (optional) - `fuzzel`
* File Manager (installed - `yazi`) - `dolphin`? or `nautilus`? or `thunar`?
* Pipewire - `pipewire` `wireplumber` `pipewire-pulse` `pipewire-alsa` `pipewire-jack`
* XDG Desktop Portal - `xdg-desktop-portal-hyprland`
* Status Bar / Desktop Shell (optional) - `ashell`
* Clipboard - `wl-clipboard`, `wl-copy`

NOTE: on the right side, above, are the choices I made, not what was required/recommended; other choices exist.

Login Managers are [not officially supported](https://wiki.hypr.land/getting-started/master-tutorial/#launching-hyprland) but several work well, such as `sddm`.

### Terminal

Install kitty terminal

```bash
sudo pacman -S kitty
```

### XDG Desktop Portal

[Install XDG Desktop Portal](https://wiki.hypr.land/Hypr-Ecosystem/xdg-desktop-portal-hyprland/) (XDPH).
It lets other applications communicate with the compositor through D-Bus.

```bash
sudo pacman -S xdg-desktop-portal-hyprland
```

### Pipewire

Install [Pipewire](https://wiki.hypr.land/Useful-Utilities/Must-have/#pipewire) for audio and video handling.
`pipewire` is the base daemon, and XDPH already depends on it, mostly video (eg screencasting).
`wireplumber` is the session manager which connects streams to applications.
`pipewire-docs` for documentation.

The [Arch Wiki](https://wiki.archlinux.org/title/PipeWire#Usage) recommends:
`pipewire-audio` for the actual audio handling, needed by audio clients, sound cards, etc.
`pipewire-pulse` for clients using the PulseAudio API (common)
`pipewire-alsa` for clients using the bare ALSA API (semi-common)
`pipewire-jack` for clients using that (rare, but `pacman -S firefox` asks to choose from 2 providers, `jack2`, and `pipewire-jack`)

```bash
sudo pacman -S pipewire wireplumber pipewire-audio pipewire-pulse pipewire-alsa
```

Reset and confirm all is working:

```bash
systemctl --user status pipewire wireplumber
wpctl status # ships with wireplumber, lists devices and sinks
pactl info # reports server as PulseAudio running on PipeWire
```

[hyprpwcenter](https://wiki.hypr.land/hypr-ecosystem/user/hyprpwcenter/) is a useful GUI for pipewire.

```bash
sudo pacman -S hyprpwcenter
```

### QT Wayland

Qt Wayland Support is [generally recommended](https://wiki.hypr.land/useful-utilities/must-have/#qt-wayland-support).

```bash
sudo pacman -S qt5-wayland qt6-wayland
```

### Fonts

Install [Fonts](https://wiki.hypr.land/Useful-Utilities/Must-have/#fonts).
In addition to Meslo (`ttf-meslo-nerd`), installed above, need to install fonts for hyprland.
This is to not show squares instead of text, icons to display, and for Firefox.

`ttf-font` needed as a general text font

```bash
sudo pacman -S noto-fonts noto-fonts-emoji
# verify
fc-match sans-serif
fc-match monospace
```

### Firefox

[Install Firefox browser](https://wiki.archlinux.org/title/Firefox).

```bash
sudo pacman -S firefox
```

Launch Firefox with:

```bash
firefox & disown
# or in zsh:
#firefox &!
# or to get rid of stderr chatter
firefox >/dev/null 2>&1 & disown
```

### Clipboard

Several [clipboard managers](https://wiki.hypr.land/useful-utilities/clipboard-managers/) are suggested, but at the least the `wayland-clipboard` is needed for quality of life.

Install [wayland clipboard](https://wiki.hypr.land/Useful-Utilities/Clipboard-Managers/).

```bash
sudo pacman -S wl-clipboard
```

### 1Password

Install [1Password](https://wiki.archlinux.org/title/1Password).

```bash
yay -S 1password 1password-cli
```

NOTE: `1password-cli` has the name `op`.

I have 1Password set up such that when I launch it on a new device, I have to complete 2-factor authentication.
Once I enter the code, 1Password needs somewhere to set up a device token, so that it doesn't need to ask me again on this device.
There needs to be a Secret Service provider of some sort.
The token needs to be placed in the system keyring via `libsecret`, which talks to the `org.freedesktop.secrets` D-Bus service.
On full Desktop environments there are things like [GNOME Keyring](https://wiki.archlinux.org/title/GNOME/Keyring) and [KDE Wallet](https://wiki.archlinux.org/title/KDE_Wallet) for example.
On hyprland nothing is providing this service:

```bash
busctl --user list | grep secrets # prints nothing
```

Install the `gnome-keyring` daemon for the provider, and `libsecret`, which gives the `secret-tool` CLI for testing.

```bash
sudo pacman -S gnome-keyring libsecret
```

Then wire it up into PAM so the keyring unlocks with the login password:

```bash
sudo vim /etc/pam.d/login

# at the end of the `auth` block:
# auth optional pam_gnome_keyring.so

# at the end of the `session` block:
# session optional pam_gnome_keyring.so auto_start

# keep the keyring in sync when changing user password
# at the end of the `password` block:
# password optional pam_gnome_keyring.so
```

NOTE: If you're launching Hyprland from a TTY with Hyprland after login,
`/etc/pam.d/login` is the right file.
If you later add a display manager like greetd or sddm,
the PAM config moves to that service's file instead and you'll need to repeat the above step there.

Verify it worked:

```bash
busctl --user list | grep secrets
secret-tool store --label=test svc test
secret-tool lookup svc test
# cleanup
secret-tool lookup svc test
```

`secret-tool` is the CLI for the same Secret Service 1Password uses.
A keyring is value + attributes, rather than key/value, where attributes are arbitrary name/value pairs.
A secret is retrieved by supplying the same set it was stored with.
`store` is a subcommand which writes a secret.
`--label=test` is a purely cosmetic human-readable name, showin in keyring UIs.
`svc` is the attribute name.
`test` is the attribute value.
So `svc=test` is stored with the label of `"test"`.

Final verification is ensuring 1Password stores the token.

Finally, setting up the 1Password SSH Agent.
Settings -> Developer -> Set up SSH Agent.
Allow adding ssh key names to disk.

```bash
nv ~/.ssh/config

# add:
#Host *
#        IdentityAgent ~/.1password/agent.sock
```

Due to my own 1Password setup, will also need to do:

```bash
mkdir -p ~/.config/1Password/ssh
nv ~/.config/1Password/ssh/agent.toml

# add:
#[[ssh-keys]]
#vault = "Developer"
# or whatever vault to use, e.g. "Work"
```

Now `yadm` can properly use the `ssh` git url:

```bash
yadm remote set-url origin git@github.com:gnodar01/dotfiles.git
```

### App Launcher - Fuzzel

Install [fuzzel](https://wiki.hypr.land/useful-utilities/app-launchers/#fuzzel) app launcher.

```bash
sudo pacman -S fuzzel
```

Install [wltype](https://wiki.archlinux.org/title/Wayland#Automation) for use with [fuzzmoji](https://codeberg.org/codingotaku/fuzzmoji).
It will simulate typing, for things like emojis.

```bash
sudo pacman -S wtype
```

[Icons](https://wiki.archlinux.org/title/Icons) are supported via the [rofi extended dmenu protocol](https://man.archlinux.org/man/extra/rofi/rofi-thumbnails.5.en).

### Authentication Agent - hyprpolkitagent

[Authentication agents](https://wiki.hypr.land/useful-utilities/must-have/#authentication-agent) ask for permission to elevate privilages.

`hyprpolkitagent` is [generally recommended](https://wiki.hypr.land/hypr-ecosystem/user/hyprpolkitagent/).

A [polkit](https://wiki.archlinux.org/title/Polkit) is a specific app-level toolkit for this, extended by `hyperpolkitagent`, and [others](https://wiki.archlinux.org/title/Polkit#Authentication_agents).

Install `hyperpolkitagent`.

```bash
sudo pacman -S hyperpolkitagent
```

`systemctl --user start hyprpolkitagent` added to hyperland config's autostart, then restart.

Verify with

```bash
systemctl --user status hyprpolkitagent

pkexec whoami # should trigger prompt
```

### Notification Daemon - fnott

A notification daemon is [generally recommended](https://wiki.hypr.land/useful-utilities/must-have/#a-notification-daemon).

It starts automatically via D-Bus activation, when a notification is emmitted.

The `notify-send` utility [uses `libnotify`](https://wiki.archlinux.org/title/Desktop_notifications) for a desktop-agnostic implementation of the Desktop Notifications Specification.

```bash
sudo pacman -S fnott libnotify
```

Reboot and test with:

```bash
notify-send "hello"
notify-send "world"
notify-send "wow"
fnottctl dismiss
fnottctl dismiss all
```

Use `fnottctl pause` to disable notifications. `fnottctl unpause` to re-enable.

### Status Bar / Desktop Shell - ashell

[Install ashell](https://wiki.hypr.land/useful-utilities/status-bars/#ashell),
a ready-to-go Wayland status bar.

```bash
yay -S ashell
mkdir ~/.config/ashell
# touch ~/.config/ashell/config.toml
```

Install [hyprshutdown](https://wiki.hypr.land/hypr-ecosystem/user/hyprshutdown/) for the shutdown/reboot/logout buttons.

```bash
sudo pacman -S hyprshutdown
```

#### NetworkManager

Install [NetworkManager](https://wiki.archlinux.org/title/NetworkManager) to use as a network status backend.

```bash
sudo pacman -Q networkmanager
systemctl enable NetworkManager.service
reboot
```

#### Bluetooth

[Bluetooth](https://wiki.archlinux.org/title/Bluetooth) is enabled through the `Bluez` protocol stack.

`bluez` provides the Bluetooth protocol stack, `bluez-utils` the `bluetoothctl` util, and `bluez-deprecated-tools` gives additional utils.
Many frontends exist, both in console like `bluetoothctl`, and graphical, like `Blueman`.

```bash
sudo pacman -S bluez bluez-utils blueman
sudo systemctl enable bluetooth.service
```

### Wallpaper - swaybg

[Install swaybg](https://wiki.hypr.land/useful-utilities/wallpapers/#swaybg).

```bash
pacman -S swaybg
```

### Display (Login) Manager

`ly` [is a TUI Display Manager](https://wiki.archlinux.org/title/Ly).

NOTE: Follow the Arch wiki, rather than the Codeberg or the mirror on GitHub.

Install:

```bash
# install
sudo pacman -S ly
# if desired, list relevant files
# NOTE: config is in /etc/ly/config.ini,
# not /etc/ly/config.lua
# code repo states either can be used
pacman -Ql ly
sudo systemctl enable ly@tty2.service
sudo systemctl disable getty@tty2.service
```

Verify:

```bash
systemctl is-enabled getty@tty1.servce # should be "enabled"
systemctl is-enabled getty@tty2.servce # should be "disabled"
```

If `ly` misbehaves, then in TTY console do
ctrl-alt-f1 to switch to conole 1
and `systemctl disable ly@tty2.service`.

NOTE: `ly` replaces launching Hyprland by hand from a TTY,
and it also changes where PAM/gnome-keyring config lives (when logging in via `ly` instead of TTY).
The keyring line added to `/etc/pam.d/login` above won't apply to `ly` logins.
The equivalent must be placed in `/etc/pam.d/ly`, otherwise 1Password will start asking for 2FA again.
*however*, `ly` seems to ship the gnome-keyring module setup as optional already,
so no manual changes are actually needed.
The first line of `/etc/pam.d/ly` also is `auth include login` which pulls in all of `/etc/pam.d/login`,
therefore there is actually duplication.
Since this is harmless but redundant and potentially confusing in the futre,
*however* it's still needed in case of logging in directly from console and starting Hyprland by hand.

### Session Lock

The display manager is seperate from a [lockscreen manager](https://wiki.archlinux.org/title/Session_lock).

Install [waylock](https://codeberg.org/ifreund/waylock).

```bash
sudo pacman -S waylock
```

### Screen Capture

[Screen capture](https://wiki.archlinux.org/title/Screen_capture) software for screenshots and screencasts (screen recording) [varies](https://wiki.hypr.land/useful-utilities/screenshots-and-recording/) a lot.

[hyprshot](https://github.com/Gustash/hyprshot) is a convenience script wrapping `grim` (takes screenshots) and `slurp` (to select regions).
However it is unmaintained, and has at least one bug, so I keep a modified copy in my dotfiles.

NOTE: for the `-z, --freeze` option, [hyprpicker](https://wiki.hypr.land/hypr-ecosystem/user/hyprpicker/) is needed.

NOTE: [hyprcap](https://github.com/alonso-herreros/hyprcap) is a similar wrapper, integrating with `fuzzel`, but also also useful for screen recording via `wl-recorder`, only on the AUR.

[satty](https://github.com/Satty-org/Satty) is a screenshot annotation tool.

Install `satty` and `hyprshot` deps (`grim` and `slurp`).

```bash
sudo pacman -S grim slurp satty
```

### MPV

Install [MPV](https://wiki.archlinux.org/title/Mpv).

```bash
sudo pacman -S mpv
```

### Flatpak

[Install flatpak](https://wiki.archlinux.org/title/Flatpak) and reboot.

```bash
sudo pacman -S flatpak
reboot
```

Verify that the main repo is setup:

```bash
flatpak remtoes --show-details -json
```

Install [flatseal](https://flathub.org/en/apps/com.github.tchx84.Flatseal), [Warehouse](https://flathub.org/en/apps/io.github.flattool.Warehouse), [Bazaar](https://flathub.org/en/apps/io.github.kolunmi.Bazaar).

```bash
flatpak install flathub com.github.tchx84.Flatseal
# flatpak run com.github.tchx84.Flatseal
flatpak install flathub io.github.flattool.Warehouse
# flatpak run io.github.flattool.Warehouse
flatpak install flathub io.github.kolunmi.Bazaar
# flatpak run io.github.kolunmi.Bazaar
```

## TODO

* configure hyprland keybindings
    * better zoom
* auto-sleep? (idle managment daemon, `hypridle`)
* firewall (eg `ufw`), and other hardening
* clipboard manager
* containers
    * podman
    * distrobox?
* XDG
    * config
    * XDG_PICTURES_DIR (`hyprshot` respects this)
* [free desktop](https://wiki.archlinux.org/title/XDG_Desktop_Portal)
    * `~/.config/xdg-desktop-portal/portals.conf`
    * org.freedesktop.portal.Settings
    * org.freedesktop.portal.InhibitSettings
    * org.freedesktop.portal.FileChooser
* `uwsm`?
* fonts (noto symbols, etc)
* useful apps (prioritize flatpak?)
    * [okular](https://okular.kde.org/) - document viewer (pdf, comics, epub, markdown, more)
    * [gwenview](https://apps.kde.org/gwenview/) - image viewer
    * [file roller](https://fileroller.sourceforge.net/features.html) - archive manager (7z, tgz, etc)
* GUI themeing
    * GTK
        * [adw-gtk-theme](https://github.com/lassekongo83/adw-gtk3)
        * [nwg-look](https://github.com/nwg-piotr/nwg-look), [gui](https://nwg-piotr.github.io/nwg-shell/nwg-look)
    * QT
        * [qt6ct-kde](https://aur.archlinux.org/packages/qt6ct-kde)
            * WARN: [do not](https://www.reddit.com/r/hyprland/comments/1mx954f/why_tf_do_i_need_qt6ctkde_in_order_to_theme/) get normal `qt5ct`, it's unpatched for KDE apps, and dead in general
            * `hl.env("QT_QPA_PLATFORMTHEME", "qt6ct")`
        * [qt5ct-kde](https://aur.archlinux.org/packages/qt5ct-kde)
            * WARN: [do not](https://www.reddit.com/r/hyprland/comments/1mx954f/why_tf_do_i_need_qt6ctkde_in_order_to_theme/) get normal `qt5ct`, it's unpatched for KDE apps, and dead in general
        * [kvantum](https://github.com/tsujan/kvantum)
            * [qt5](https://archlinux.org/packages/extra/x86_64/kvantum-qt5/)
            * [qt6](https://archlinux.org/packages/extra/x86_64/kvantum/) (required by above)
        * `hypr.conf`
    * KDE Plasma's Breeze style
        * [breeze](https://archlinux.org/packages/extra/x86_64/breeze/)
        * [breeze-gtk](https://archlinux.org/packages/extra/any/breeze-gtk/)
