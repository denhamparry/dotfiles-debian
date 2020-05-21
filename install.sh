#!/bin/bash
set -e
set -o pipefail

# install.sh
#	This script installs my basic setup for a debian laptop

export DEBIAN_FRONTEND=noninteractive

# Choose a user account to use for this installation
get_user() {
	if [[ -z "${TARGET_USER-}" ]]; then
		mapfile -t options < <(find /home/* -maxdepth 0 -printf "%f\\n" -type d)
		if [ "${#options[@]}" -eq "1" ]; then
			readonly TARGET_USER="${options[0]}"
			echo "Using user account: ${TARGET_USER}"
			return
		fi
		PS3='command -v user account should be used? '

		select opt in "${options[@]}"; do
			readonly TARGET_USER=$opt
			break
		done
	fi
}

check_is_sudo() {
	if [ "$EUID" -ne 0 ]; then
		echo "Please run as root."
		exit
	fi
}

# Set user up as sudo to prevent lots of passwords
setup_sudo() {
	adduser "$TARGET_USER" sudo
	gpasswd -a "$TARGET_USER" systemd-journal
	gpasswd -a "$TARGET_USER" systemd-network
	sudo groupadd docker
	sudo gpasswd -a "$TARGET_USER" docker
	{ \
		echo -e "Defaults	secure_path=\"/usr/local/go/bin:/home/${TARGET_USER}/.go/bin:/usr/local/sbin:/usr/local/bin:/usr/sbin:/usr/bin:/sbin:/bin:/usr/share/bcc/tools:/home/${TARGET_USER}/.cargo/bin\""; \
		echo -e 'Defaults	env_keep += "ftp_proxy http_proxy https_proxy no_proxy GOPATH EDITOR"'; \
		echo -e "${TARGET_USER} ALL=(ALL) NOPASSWD:ALL"; \
		echo -e "${TARGET_USER} ALL=NOPASSWD: /sbin/ifconfig, /sbin/ifup, /sbin/ifdown, /sbin/ifquery"; \
	} >> /etc/sudoers
	mkdir -p "/home/$TARGET_USER/Downloads"
	echo -e "\\n# tmpfs for downloads\\ntmpfs\\t/home/${TARGET_USER}/Downloads\\ttmpfs\\tnodev,nosuid,size=5G\\t0\\t0" >> /etc/fstab
}

# Install scripts for bin
install_scripts() {
    # speed test from the cli
    curl -sSL https://raw.githubusercontent.com/sivel/speedtest-cli/master/speedtest.py  > /usr/local/bin/speedtest
	chmod +x /usr/local/bin/speedtest
	# install icdiff / improve colour of git commits - github.com/jeffkaufman/icdiff
	curl -sSL https://raw.githubusercontent.com/jeffkaufman/icdiff/master/icdiff > /usr/local/bin/icdiff
	curl -sSL https://raw.githubusercontent.com/jeffkaufman/icdiff/master/git-icdiff > /usr/local/bin/git-icdiff
	chmod +x /usr/local/bin/icdiff
	chmod +x /usr/local/bin/git-icdiff
	# install lolcat
	curl -sSL https://raw.githubusercontent.com/tehmaze/lolcat/master/lolcat > /usr/local/bin/lolcat
	chmod +x /usr/local/bin/lolcat
}

# install graphics drivers
install_graphics() {
	local system=$1

	if [[ -z "$system" ]]; then
		echo "You need to specify whether it's intel, geforce or optimus"
		exit 1
	fi

	local pkgs=( xorg xserver-xorg xserver-xorg-input-libinput xserver-xorg-input-synaptics )

	case $system in
		"intel")
			pkgs+=( xserver-xorg-video-intel )
			;;
		"geforce")
			pkgs+=( nvidia-driver )
			;;
		"optimus")
			pkgs+=( nvidia-kernel-dkms bumblebee-nvidia primus )
			;;
		*)
			echo "You need to specify whether it's intel, geforce or optimus"
			exit 1
			;;
	esac

	apt update || true
	apt -y upgrade

	apt install -y "${pkgs[@]}" --no-install-recommends
}

usage() {
	echo -e "install.sh\\n\\tThis script installs my basic setup for a debian laptop\\n"
	echo "Usage:"
	echo "  sudouser                                - setup user as sudo"
	echo "  scripts                                 - setup bin scripts"
	echo "  graphics								- install grpahics driver"

}

main() {
	local cmd=$1

	if [[ -z "$cmd" ]]; then
		usage
		exit 1
	fi

	if [[ $cmd == "sudouser" ]]; then
		check_is_sudo
		get_user
        setup_sudo

	elif [[ $cmd == "scripts" ]]; then
		check_is_sudo
		install_scripts

	elif [[ $cmd == "graphics" ]]; then
		check_is_sudo
		install_graphics "$2"
	
	else
		usage
	fi
}

main "$@"
