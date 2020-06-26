# Dotfiles

This Dotfiles repo is linked to a Debian 10 installation, this document is a step by step guide to setting up the machine to use the Dotfiles.

## Setup Debian 10

### Remove media from `source.list`

```bash
$ sudo vi /etc/apt/source.list
# delete any reference to usb
```

### Update Kernel

```bash
$ uname -a
$ echo deb http://deb.debian.org/debian buster-backports main contrib non-free | sudo tee /etc/apt/sources.list.d/buster-backports.list
$ sudo apt update
$ sudo apt install -t buster-backports linux-image-amd64
$ sudo apt install -t buster-backports firmware-linux firmware-linux-nonfree
$ sudo reboot
$ uname -a
```

Boot failed, disconnected all devices when booting machine.
Possible solution from [Lenovo](https://support.lenovo.com/br/en/solutions/ht508988)

#### References

- [Stack Exchange - How to upgrade the Debian 10 kernel from backports](https://unix.stackexchange.com/questions/545601/how-to-upgrade-the-debian-10-kernel-from-backports-without-recompiling-it-from-s)

### NVIDIA

```txt
FROM:
deb http://deb.debian.org/debian/ buster main
deb-src http://deb.debian.org/debian/ buster main
TO:
deb http://deb.debian.org/debian/ buster main non-free
deb-src http://deb.debian.org/debian/ buster main non-free
```

```bash
$ sudo apt update
$ sudo apt -y install nvidia-detect
$ sudo nvidia-detect
```

- If the above doesn't work...

### Disable Nouveau

```bash
$ sudo bash -c "echo blacklist nouveau > /etc/modprobe.d/blacklist-nvidia-nouveau.conf"
$ sudo bash -c "echo options nouveau modeset=0 >> /etc/modprobe.d/blacklist-nvidia-nouveau.conf"
$ cat /etc/modprobe.d/blacklist-nvidia-nouveau.conf
blacklist nouveau
options nouveau modeset=0
$ sudo update-initramfs -u
$ sudo reboot
```

Download driver from [here](https://www.nvidia.com/en-us/drivers/unix/).  Store the file somewhere that isn't the `Downloads` folder.

```bash
$ sudo apt -y install linux-headers-$(uname -r) build-essential
$ echo blacklist nouveau > sudo /etc/modprobe.d/blacklist-nvidia-nouveau.conf
$ systemctl set-default multi-user.target
$ systemctl reboot
```

```bash
$ sudo su
$ bash NVIDIA-Linux-x86_64-390.116.run
$ systemctl set-default graphical.target
$ systemctl reboot
```

#### References

- [Linux Config - Install Nvidia driver on Debian 10 Buster](https://linuxconfig.org/how-to-install-nvidia-driver-on-debian-10-buster-linux)
- [Linux Config - Disable Nouveau](https://linuxconfig.org/how-to-disable-nouveau-nvidia-driver-on-ubuntu-18-04-bionic-beaver-linux)

### Install Wifi / Bluetooth

```bash
$ sudo apt install -t buster-backports firmware-iwlwifi
$ sudo reboot
```

#### References

- [Stack Exchange - Wifi driver for Debian 10](https://unix.stackexchange.com/questions/590439/wifi-driver-for-debian-10?noredirect=1&lq=1)

### Install Keybase

```bash
$ wget https://prerelease.keybase.io/keybase_amd64.deb
$ sudo apt install ./keybase_amd64.deb
$ rm keybase_amd64.deb
$ run_keybase
```

#### References

- [How to install Keybase](https://keybase.io/docs/the_app/install_linux)

### Install Chrome

```bash
$ wget https://dl.google.com/linux/direct/google-chrome-stable_current_amd64.deb
$ sudo apt install ./google-chrome-stable_current_amd64.deb
$ rm google-chrome-stable_current_amd64.deb
$ google-chrome &
```

#### References

- [How to install Google Chrome](https://linuxize.com/post/how-to-install-google-chrome-web-browser-on-debian-9/)

### Setup existing YubiKey

- Insert YubiKey and USB drive with copy of public key

```bash
$ sudo apt -y install wget gnupg2 gnupg-agent dirmngr cryptsetup scdaemon pcscd secure-delete hopenpgp-tools yubikey-personalization
$ cd ~/.gnupg ; wget https://raw.githubusercontent.com/drduh/config/master/gpg.conf
$ chmod 600 gpg.conf
$ sudo mount /dev/sda1 /mnt
$ gpg --import /mnt/0x*txt
$ export KEYID=0x...
$ gpg --edit-key $KEYID
gpg> trust
Your decision? 5
Do you really want to set this key to ultimate trust? (y/N) y
```

- Remove and re-insert YubiKey and check the status

```bash
$ gpg --card-status
```

- Test the key

```bash
$ echo "test message string" | gpg --encrypt --armor --recipient $KEYID -o encrypted.txt
$ gpg --decrypt --armor encrypted.txt
```

- Setup SSH

```bash
$ cd ~/.gnupg
$ wget https://raw.githubusercontent.com/drduh/config/master/gpg-agent.conf
```

- Update `~/.bashrc` with the following:

```txt
export GPG_TTY="$(tty)"
export SSH_AUTH_SOCK=$(gpgconf --list-dirs agent-ssh-socket)
gpgconf --launch gpg-agent
```

- Write the public key for `.ssh`

```bash
ssh-add -L > ~/.ssh/id_rsa_yubikey.pub
```

- Create the `~/.ssh/config` file:

```bash
$ cat << EOF >> ~/.ssh/config
Host github.com
    IdentitiesOnly yes
    IdentityFile ~/.ssh/id_rsa_yubikey.pub
    User git
EOF
$ ssh github
Hi denhamparry! You've successfully authenticated, but GitHub does not provide shell access.
Connection to github.com closed.
```

#### References

- [YubiKey Guide](https://github.com/drduh/YubiKey-Guide)
- [OpenPGP smartcard under GNOME on Debian 10 Buster](https://blog.josefsson.org/tag/scdaemon/)
- [SSH Github](https://help.github.com/en/github/authenticating-to-github/testing-your-ssh-connection)

### Install Code-Insiders

```bash
$ wget -O code-insiders.deb https://go.microsoft.com/fwlink/?LinkID=760865
$ sudo dpkg -i code-insiders.deb
$ rm code-insiders.deb
```

#### References

- [Code Insiders Deb](https://code.visualstudio.com/docs/?dv=linux64_deb&build=insiders)

### Install PaperWM

```bash
$ git clone git@github.com:paperwm/PaperWM.git
$ cd PaperWM
$ ./install.sh
```

#### References

- [PaperWM](https://github.com/paperwm/PaperWM)

### Setup Bluetooth Headphones

```bash
$ sudo apt install pulseaudio pulseaudio-module-bluetooth pavucontrol bluez-firmware
$ sudo service bluetooth restart
$ sudo killall pulseaudio
```

#### Troubleshooting

```bash
$ sudo cat << EOF >> /var/lib/gdm3/.config/pulse/client.conf
autospawn = no
daemon-binary = /bin/true
EOF
$ sudo chown Debian-gdm:Debian-gdm /var/lib/gdm3/.config/pulse/client.conf
$ rm /var/lib/gdm3/.config/systemd/user/sockets.target.wants/pulseaudio.socket
$ sudo cat << EOF >> /etc/pulse/default.pa
load-module module-switch-on-connect
EOF
$ sudo cat << EOF >> /var/lib/gdm3/.config/pulse/default.pa
#!/usr/bin/pulseaudio -nF
#

# load system wide configuration
.include /etc/pulse/default.pa

### unload driver modules for Bluetooth hardware
.ifexists module-bluetooth-policy.so
  unload-module module-bluetooth-policy
.endif

.ifexists module-bluetooth-discover.so
  unload-module module-bluetooth-discover
.endif
EOF
```

#### References

- [a2dp](https://wiki.debian.org/BluetoothUser/a2dp)

### Install Spotify

```bash
$ curl -sS https://download.spotify.com/debian/pubkey.gpg | sudo apt-key add - 
$ echo "deb http://repository.spotify.com stable non-free" | sudo tee /etc/apt/sources.list.d/spotify.list
$ sudo apt-get update && sudo apt-get install spotify-client
```

#### References

- [Install Spotify on Linux](https://www.spotify.com/uk/download/linux/)

### Install Switcher

```bash
$ mkdir -p ~/.local/share/gnome-shell/extensions 
$ cd ~/.local/share/gnome-shell/extensions
$ git clone https://github.com/daniellandau/switcher.git switcher@landau.fi
```

### References

- [Switcher](https://github.com/daniellandau/switcher)

### Install Dash to Dock

```bash
$ git clone https://github.com/micheleg/dash-to-dock.git
$ cd dash-to-dock
$ make
$ make install
```

#### References

- [Dash to Dock](https://micheleg.github.io/dash-to-dock)

### Install Docker

```bash
$ sudo apt update
$ sudo apt install apt-transport-https ca-certificates curl software-properties-common gnupg2
$ curl -fsSL https://download.docker.com/linux/debian/gpg | sudo apt-key add -
$ sudo add-apt-repository "deb [arch=amd64] https://download.docker.com/linux/debian $(lsb_release -cs) stable"
$ sudo apt update
$ sudo apt install docker-ce
$ sudo systemctl status docker
$ docker -v
$ sudo usermod -aG docker $USER
```
