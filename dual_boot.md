# Dual boot: Arch alongside Bazzite (shared NVMe)

Disk-level procedure for installing Arch onto free space on the same NVMe drive
as an existing Bazzite (OSTree/immutable Fedora) install, without touching
Bazzite's partitions or its EFI System Partition. This is the "how do I get
the drive and bootloaders set up" doc; for the rest of the Arch install
(locale, users, network, packages) see [arch_setup.md](arch_setup.md) and the
[Arch Installation Guide](https://wiki.archlinux.org/title/Installation_guide).

## Starting layout

```
nvme0n1
├─p1  600M   EFI System Partition (/boot/efi)                → shared, do not touch
├─p2  1G     /boot (Bazzite)                                 → do not touch
└─p3  3.6T   btrfs: /var /sysroot /etc (Bazzite OSTree root) → shrink this
```

Confirm UEFI mode on any live ISO before doing anything:

```bash
ls /sys/firmware/efi
```

## 1. Shrink the Bazzite partition

**Shrink the filesystem before shrinking the partition — not after.** Btrfs
records its own size in the superblock; if the partition table entry is
shrunk first (or the filesystem is never told to shrink), the filesystem
still believes it owns the old size and refuses to mount (`open_ctree
failed`, `device total_bytes should be at most X but found Y`). Recovering
from that requires `btrfs rescue fix-device-size` from a live ISO — avoid it
entirely by doing the resize in the right order.

1. Boot normally into Bazzite.
2. Shrink the btrfs filesystem itself, live, to a size comfortably smaller
   than where the partition boundary will end up (leave some headroom, don't
   cut it exactly to size):

   ```bash
   sudo btrfs filesystem resize <target-size> /
   # e.g. sudo btrfs filesystem resize 3200G /
   ```

3. Verify it took effect and there are no errors:

   ```bash
   sudo btrfs filesystem usage /
   ```

4. Reboot into a live ISO (Arch ISO is fine for this step — no OSTree tools
   needed yet).
5. Shrink the **partition table entry** for `p3` to match (at or above the
   new filesystem size from step 2):

   ```bash
   cfdisk /dev/nvme0n1
   # select nvme0n1p3, resize smaller, leave free space at the end,
   # do NOT format it, write changes
   ```

6. Reboot into Bazzite and confirm it's still healthy before doing anything
   else:

   ```bash
   rpm-ostree status               # one active deployment, no errors
   findmnt /                       # / mounted via ostree, fstype btrfs
   sudo btrfs filesystem usage /   # no size-mismatch warnings
   ```

   If any of these show errors, stop and fix the filesystem before
   proceeding — do not install Arch on top of an unhealthy Bazzite.

## 2. Partition the freed space for Arch

Boot a live ISO again. In the space freed up in step 1:

```
/        (ext4 or btrfs)   e.g. 50-100G
/home    (optional, ext4/btrfs)  remainder
swap     (optional)
```

Do **not** create a new EFI partition — Arch will reuse the existing one
(`p1`).

Format the new partitions, e.g.:

```bash
mkfs.ext4 /dev/nvme0n1p4      # Arch /
mkfs.ext4 /dev/nvme0n1p5      # Arch /home (optional)
```

## 3. Mount and install the base system

```bash
mount /dev/nvme0n1p4 /mnt
mkdir /mnt/home
mount /dev/nvme0n1p5 /mnt/home

mkdir -p /mnt/boot/efi
mount /dev/nvme0n1p1 /mnt/boot/efi
```

Do **not** mount Bazzite's `/boot` (`p2`) or any of its btrfs subvolumes
under `/mnt` — Arch only needs the shared ESP.

```bash
pacstrap /mnt base linux linux-firmware grub efibootmgr base-devel sudo networkmanager
genfstab -U /mnt >> /mnt/etc/fstab
arch-chroot /mnt
```

Enable networking now, inside the chroot, so first boot has it working
(see [arch_setup.md](arch_setup.md#network-configuration) for the full
network setup this repo actually settled on):

```bash
systemctl enable NetworkManager
```

Continue with the rest of the standard base install (timezone, locale,
hostname, root password, user creation) per the
[Arch Installation Guide](https://wiki.archlinux.org/title/Installation_guide)
and [arch_setup.md](arch_setup.md).

## 4. Install Arch's own bootloader (independent, no chainload)

OSTree systems don't expose a traditional `/boot/vmlinuz` that `os-prober`
can detect, and Bazzite manages its own boot entries — so don't bother with
`os-prober` or chainloading. The correct, low-maintenance setup is two
independent bootloaders, selected via the UEFI firmware boot menu:

```bash
grub-install --target=x86_64-efi --efi-directory=/boot/efi --bootloader-id=Arch
grub-mkconfig -o /boot/grub/grub.cfg
```

Exit and reboot:

```bash
exit
umount -R /mnt
reboot
```

## 5. Selecting an OS at boot

There is no unified boot menu — this is expected, not a bug. Each OS boots
independently once selected in firmware:

* UEFI firmware boot menu (on this board: TUF Gaming UEFI BIOS Utility →
  Boot Priority → **Boot Menu (F8)**) lists both `Arch` and `Fedora` as
  top-level entries.
* Picking `Arch` boots straight into Arch's GRUB → Arch.
* Picking `Fedora` boots into Bazzite's own GRUB, which lists the OSTree
  deployments (`Bazzite (ostree:0)`, `Bazzite (ostree:1)`, ...).

## 6. Post-install verification

**In Bazzite:**

```bash
rpm-ostree status                  # one active deployment, no errors
findmnt /                          # ostree-managed, btrfs
sudo btrfs filesystem usage /      # no device-size mismatch
sudo efibootmgr -v                 # both entries present, same disk:
                                   #   Boot____* Fedora HD(...)/EFI/fedora/grubx64.efi
                                   #   Boot____* Arch   HD(...)/EFI/Arch/grubx64.efi
ls /boot/efi/EFI                   # exactly: Arch/ fedora/ (no dupes like fedora(1))
```

**In Arch:**

```bash
grub-mkconfig -o /boot/grub/grub.cfg
grep -i bazzite /boot/grub/grub.cfg   # should print nothing —
                                      # confirms Arch isn't trying to manage Bazzite
nmcli device status                   # networking came up on first boot
```

## 7. Optional cosmetic cleanup

Set a default boot order or rename entries from either OS:

```bash
sudo efibootmgr                       # see current BootOrder
sudo efibootmgr -o 0001,0002          # reorder (numbers from the listing above)
sudo efibootmgr -b 0001 -L "Bazzite"  # rename for clarity
sudo efibootmgr -b 0002 -L "Arch Linux"
```

## What NOT to do

* Don't shrink the btrfs partition table entry before shrinking the
  filesystem itself — this is what causes the device-size mismatch.
* Don't format `/boot/efi`, or create a second EFI partition for Arch.
* Don't touch or reformat Bazzite's `/boot` (`p2`).
* Don't rely on `os-prober` to detect Bazzite, or chainload Bazzite from
  Arch's GRUB — treat the two bootloaders as independent peers selected at
  the firmware level.
* Don't install Arch inside Bazzite via distrobox/toolbox — this is a real
  separate install on its own partitions.
