# Dotfiles

This Dotfiles repo is linked to a Debian 11 installation. This document is a
step by step guide to setting up the machine to use the Dotfiles.

## Checklist

- [ ] Google Chrome
  - [ ] GitHub
- [ ] 1Password
- [ ] Keybase
- [ ] Signal

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