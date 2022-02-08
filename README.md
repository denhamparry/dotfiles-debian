# Dotfiles

This Dotfiles repo is linked to a Debian 11 installation. This document is a
step by step guide to setting up the machine to use the Dotfiles.

## Install Keybase

```bash
wget https://prerelease.keybase.io/keybase_amd64.deb
sudo apt install ./keybase_amd64.deb
rm keybase_amd64.deb
run_keybase
```

### References

- [How to install Keybase](https://keybase.io/docs/the_app/install_linux)

## Setup existing YubiKey

- Insert YubiKey and USB drive with copy of public key

```bash
sudo apt -y install wget gnupg2 gnupg-agent dirmngr cryptsetup scdaemon pcscd secure-delete hopenpgp-tools yubikey-personalization
cd ~/.gnupg ; wget https://raw.githubusercontent.com/drduh/config/master/gpg.conf
chmod 600 gpg.conf
sudo mount /dev/sda1 /mnt
gpg --import /mnt/0x*txt
export KEYID=0x...
gpg --edit-key $KEYID
gpg> trust
Your decision? 5
Do you really want to set this key to ultimate trust? (y/N) y
```

- Remove and re-insert YubiKey and check the status

```bash
gpg --card-status
```

- Test the key

```bash
echo "test message string" | gpg --encrypt --armor --recipient $KEYID -o encrypted.txt
gpg --decrypt --armor encrypted.txt
```

- Setup SSH

```bash
cd ~/.gnupg
wget https://raw.githubusercontent.com/drduh/config/master/gpg-agent.conf
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
cat << EOF >> ~/.ssh/config
Host github.com
    IdentitiesOnly yes
    IdentityFile ~/.ssh/id_rsa_yubikey.pub
    User git
EOF
ssh github
Hi denhamparry! You've successfully authenticated, but GitHub does not provide shell access.
Connection to github.com closed.
```

#### References

- [YubiKey Guide](https://github.com/drduh/YubiKey-Guide)
- [OpenPGP smartcard under GNOME on Debian 10 Buster](https://blog.josefsson.org/tag/scdaemon/)
- [SSH Github](https://help.github.com/en/github/authenticating-to-github/testing-your-ssh-connection)

### Setup Bluetooth Headphones

```bash
sudo apt install pulseaudio pulseaudio-module-bluetooth pavucontrol bluez-firmware
sudo service bluetooth restart
sudo killall pulseaudio
```

- [How to use Bluetoothctl](https://gist.github.com/denhamparry/b66b40396d5e4040bea8eb5ef5838021)

#### Troubleshooting

```bash
sudo cat << EOF >> /var/lib/gdm3/.config/pulse/client.conf
autospawn = no
daemon-binary = /bin/true
EOF
sudo chown Debian-gdm:Debian-gdm /var/lib/gdm3/.config/pulse/client.conf
rm /var/lib/gdm3/.config/systemd/user/sockets.target.wants/pulseaudio.socket
sudo cat << EOF >> /etc/pulse/default.pa
load-module module-switch-on-connect
EOF
sudo cat << EOF >> /var/lib/gdm3/.config/pulse/default.pa
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
