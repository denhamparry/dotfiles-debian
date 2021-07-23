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

# Install essentials
install_essentials() {
	sudo apt install -y curl git
}

# Setup Dotfiles (and Vim)
install_dotfiles() {
	# Setup Dotfiles
	cd ~
	using ssh for personal automation
	git clone git@github.com:denhamparry/dotfiles.git
	#Setup Vim
	git clone --recursive https://github.com/denhamparry/.vim.git .vim
	cd ~/.vim
	make install update-vundle
}

# Install Starship for nice looking prompt
install_starship(){
	sh -c "$(curl -fsSL https://starship.rs/install.sh)"
}

usage() {
	echo -e "install.sh\\n\\tThis script installs my basic setup for a debian laptop\\n"
	echo "Usage:"
	echo "  sudouser                                - setup user as sudo"
	echo "  essentials								- install essential tools"
	echo "  scripts                                 - setup bin scripts"

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

	elif [[ $cmd == "essentials" ]]; then
		check_is_sudo
		install_essentials

	elif [[ $cmd == "dotfiles" ]]; then
		install_dotfiles

	elif [[ $cmd == "all" ]]; then
		check_is_sudo
		get_user
        setup_sudo
		install_essentials
		install_dotfiles
	
	else
		usage
	fi
}

main "$@"
