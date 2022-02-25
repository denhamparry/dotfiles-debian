# Notes

## Keyring

When using console-based login, edit `/etc/pam.d/login`:

Add `auth optional pam_gnome_keyring.so` at the end of the auth section and `session optional pam_gnome_keyring.so auto_start` at the end of the session section.

- [References](https://wiki.archlinux.org/title/GNOME/Keyring#Installation)

