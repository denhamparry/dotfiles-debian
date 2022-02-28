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
		# if there is only one option just use that user
		if [ "${#options[@]}" -eq "1" ]; then
			readonly TARGET_USER="${options[0]}"
			echo "Using user account: ${TARGET_USER}"
			return
		fi

		# iterate through the user options and print them
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

setup_sudo() {
	# add user to sudoers
	adduser "$TARGET_USER" sudo

	# add user to systemd groups
	# then you wont need sudo to view logs and shit
	gpasswd -a "$TARGET_USER" systemd-journal
	gpasswd -a "$TARGET_USER" systemd-network

	# create docker group
	sudo groupadd docker
	sudo gpasswd -a "$TARGET_USER" docker

	# add go path to secure path
	{ \
		echo -e "Defaults	secure_path=\"/usr/local/go/bin:/usr/local/sbin:/usr/local/bin:/usr/sbin:/usr/bin:/sbin:/bin:/usr/share/bcc/tools\""; \
		echo -e 'Defaults	env_keep += "ftp_proxy http_proxy https_proxy no_proxy EDITOR"'; \
		echo -e "${TARGET_USER} ALL=(ALL) NOPASSWD:ALL"; \
		echo -e "${TARGET_USER} ALL=NOPASSWD: /sbin/ifconfig, /sbin/ifup, /sbin/ifdown, /sbin/ifquery"; \
	} >> /etc/sudoers

	# setup downloads folder as tmpfs
	mkdir -p "/home/$TARGET_USER/Downloads"
	echo -e "\\n# tmpfs for downloads\\ntmpfs\\t/home/${TARGET_USER}/Downloads\\ttmpfs\\tnodev,nosuid,size=5G\\t0\\t0" >> /etc/fstab
}

setup_sources() {

	apt update || true
	apt install -y \
		apt-transport-https \
		ca-certificates \
		curl \
		dirmngr \
		gnupg2 \
		lsb-release \
		--no-install-recommends

	cat <<-EOF > /etc/apt/sources.list
	deb http://deb.debian.org/debian/ bullseye main non-free contrib
	deb-src http://deb.debian.org/debian/ bullseye main non-free contrib

	deb http://security.debian.org/debian-security bullseye-security main contrib non-free
	deb-src http://security.debian.org/debian-security bullseye-security main contrib non-free

	deb http://deb.debian.org/debian/ bullseye-updates main non-free contrib
	deb-src http://deb.debian.org/debian/ bullseye-updates main non-free contrib
	EOF

	# Docker
	curl -fsSL https://download.docker.com/linux/debian/gpg | sudo gpg --batch --yes --dearmor -o /usr/share/keyrings/docker-archive-keyring.gpg
 	echo "deb [arch=$(dpkg --print-architecture) signed-by=/usr/share/keyrings/docker-archive-keyring.gpg] https://download.docker.com/linux/debian $(lsb_release -cs) stable" | sudo tee /etc/apt/sources.list.d/docker.list > /dev/null

	# Google Chrome
 	echo "deb [arch=amd64] http://dl.google.com/linux/chrome/deb/ stable main" | sudo tee /etc/apt/sources.list.d/google-chrome.list > /dev/null
	wget -O- https://dl.google.com/linux/linux_signing_key.pub | gpg --batch --yes --dearmor > /etc/apt/trusted.gpg.d/google.gpg

	# Google Cloud SDK
	echo "deb [signed-by=/usr/share/keyrings/cloud.google.gpg] https://packages.cloud.google.com/apt cloud-sdk main" | sudo tee /etc/apt/sources.list.d/google-cloud-sdk.list
	curl https://packages.cloud.google.com/apt/doc/apt-key.gpg | sudo apt-key --keyring /usr/share/keyrings/cloud.google.gpg add -

	# VS Code
	wget -qO- https://packages.microsoft.com/keys/microsoft.asc | gpg --batch --yes --dearmor > packages.microsoft.gpg
	sudo install -o root -g root -m 644 packages.microsoft.gpg /etc/apt/trusted.gpg.d/
	sudo sh -c 'echo "deb [arch=amd64,arm64,armhf signed-by=/etc/apt/trusted.gpg.d/packages.microsoft.gpg] https://packages.microsoft.com/repos/code stable main" > /etc/apt/sources.list.d/vscode.list'
	rm -f packages.microsoft.gpg

	#1Password
	curl -sS https://downloads.1password.com/linux/keys/1password.asc | sudo gpg --batch --yes --dearmor --output /usr/share/keyrings/1password-archive-keyring.gpg
	echo 'deb [arch=amd64 signed-by=/usr/share/keyrings/1password-archive-keyring.gpg] https://downloads.1password.com/linux/debian/amd64 stable main' | sudo tee /etc/apt/sources.list.d/1password.list
	sudo mkdir -p /etc/debsig/policies/AC2D62742012EA22/
	curl -sS https://downloads.1password.com/linux/debian/debsig/1password.pol | sudo tee /etc/debsig/policies/AC2D62742012EA22/1password.pol
	sudo mkdir -p /usr/share/debsig/keyrings/AC2D62742012EA22
	curl -sS https://downloads.1password.com/linux/keys/1password.asc | sudo gpg --batch --yes --dearmor --output /usr/share/debsig/keyrings/AC2D62742012EA22/debsig.gpg

	# Signal
	curl -sS https://updates.signal.org/desktop/apt/keys.asc | sudo gpg --batch --yes --dearmor --output /usr/share/keyrings/signal-desktop-keyring.gpg
	echo 'deb [arch=amd64 signed-by=/usr/share/keyrings/signal-desktop-keyring.gpg] https://updates.signal.org/desktop/apt xenial main' | sudo tee /etc/apt/sources.list.d/signal-xenial.list

	# Tailscale
	curl -fsSL https://pkgs.tailscale.com/stable/debian/bullseye.noarmor.gpg | sudo tee /usr/share/keyrings/tailscale-archive-keyring.gpg >/dev/null
	curl -fsSL https://pkgs.tailscale.com/stable/debian/bullseye.tailscale-keyring.list | sudo tee /etc/apt/sources.list.d/tailscale.list

	# turn off translations, speed up apt update
	mkdir -p /etc/apt/apt.conf.d
	echo 'Acquire::Languages "none";' > /etc/apt/apt.conf.d/99translations
}

base() {

	apt update || true
	apt -y upgrade
	apt install -y \
		1password \
		adduser \
		apparmor \
		automake \
		autorandr \
		bash-completion \
		bc \
		bluez-firmware \
		bridge-utils \
		bzip2 \
		ca-certificates \
		cgroupfs-mount \
		cifs-utils \
		cryptsetup \
		code-insiders \
		compton \
		containerd.io \
		coreutils \
		curl \
		docker-ce \
		docker-ce-cli \
		direnv \
		dirmngr \
		dnsutils \
		feh \
		ffmpeg \
		file \
		findutils \
		forensics-all \
		fwupd \
		fwupdate \
		gcc \
		gettext \
		git \
		git-crypt \
		gnome-keyring \
		gnupg \
		gnupg-agent \
		gnupg2 \
		google-chrome-stable \
		google-cloud-sdk \
		graphviz \
		grep \
		gzip \
		hopenpgp-tools \
		hostname \
		hplip \
		htop \
		i3lock-fancy \
		imagemagick \
		indent \
		iotop \
		iptables \
		iwd \
		jq \
		kitty \
		less \
		libapparmor-dev \
		libc6-dev \
		libimobiledevice6 \
		libltdl-dev \
		libnotify-bin \
		libpam-systemd \
		libseccomp-dev \
		locales \
		lsof \
		lxappearance \
		make \
		mount \
		ncdu \
		neofetch \
		neovim \
		net-tools \
		nfs-common \
		nodejs \
		npm \
		obs-studio \
		parallel \
		pavucontrol \
		pcscd \
		pinentry-curses \
		pinentry-gtk2 \
		pinentry-tty \
		playerctl \
		policykit-1 \
		progress \
		pulseaudio \
		pulseaudio-module-bluetooth \
		python3-pip \
		rclone \
		rofi \
		scdaemon \
		screenfetch \
		screenkey \
		seahorse \
		secure-delete \
		shellcheck \
		signal-desktop \
		silversearcher-ag \
		ssh \
		strace \
		sudo \
		systemd \
		tailscale \
		tar \
		tmux \
		tree \
		thunar \
		tzdata \
		unzip \
		vim \
		wget \
		xsel \
		xz-utils \
		yubikey-personalization \
		zip \
		--no-install-recommends

	apt autoremove
	apt autoclean
	apt clean

	pip install legit
}

# install custom scripts/binaries
install_scripts() {

	# prep directory
	mkdir -p /tmp/scripts

	# download binaries
	curl -sSL https://raw.githubusercontent.com/tehmaze/lolcat/master/lolcat > /tmp/scripts/lolcat
	curl -sSL https://raw.githubusercontent.com/sivel/speedtest-cli/master/speedtest.py  > /tmp/scripts/speedtest
	curl -sSL https://raw.githubusercontent.com/jeffkaufman/icdiff/master/icdiff > /tmp/scripts/icdiff
	curl -sSL https://raw.githubusercontent.com/jeffkaufman/icdiff/master/git-icdiff > /tmp/scripts/git-icdiff

	# set to executable and move to bin
	sudo chmod +x /tmp/scripts/*
	sudo mv /tmp/scripts/* /usr/local/bin/

	# install fzf
	if [ -d "$HOME/.fzf" ] 
	then
		git -C "$HOME/.fzf" pull
	else
		git clone --depth 1 https://github.com/junegunn/fzf.git ~/.fzf
	fi
	echo y | ~/.fzf/install
	

	# install tmux plugin manager
	if [ -d "$HOME/.tmux/plugins/tpm" ] 
	then
		git -C "$HOME/.tmux/plugins/tpm" pull
	else
		git clone https://github.com/tmux-plugins/tpm ~/.tmux/plugins/tpm
	fi

	# kubectl
	cd /tmp/scripts/
	curl -LO "https://dl.k8s.io/release/$(curl -L -s https://dl.k8s.io/release/stable.txt)/bin/linux/amd64/kubectl"
	curl -LO "https://dl.k8s.io/$(curl -L -s https://dl.k8s.io/release/stable.txt)/bin/linux/amd64/kubectl.sha256"
	echo "$(<kubectl.sha256)  kubectl" | sha256sum --check
	sudo install -o root -g root -m 0755 kubectl /usr/local/bin/kubectl
	kubectl version --client
	cd -

	# starship
	sudo bin/install-starship.sh -y

	# keybase
	curl --remote-name https://prerelease.keybase.io/keybase_amd64.deb
	sudo apt install ./keybase_amd64.deb
	rm -rf keybase_amd64.deb

	# op
	curl -LO https://cache.agilebits.com/dist/1P/op/pkg/v1.12.4/op_linux_amd64_v1.12.4.zip
	unzip op_linux_amd64_v1.12.4.zip
	# sudo gpg --receive-keys 3FEF9748469ADBE15DA7CA80AC2D62742012EA22
	# sudo gpg --verify op.sig op
	sudo mv op /usr/local/bin
	op --version
	rm op_linux_amd64_v1.12.4.zip
	rm op.sig
}

install_themes() {

	# prep directory
	mkdir -p /tmp/themes
	mkdir -p /tmp/themes/gtk

	# download binaries
	curl -sSL https://github.com/dracula/gtk/archive/master.zip > /tmp/themes/gtk.zip
	unzip -o /tmp/themes/gtk.zip -d /tmp/themes/gtk/

	sudo cp -r /tmp/themes/gtk/gtk-master/ /usr/share/themes/Dracula/

	# prep directory
	mkdir -p /tmp/icons
	mkdir -p /tmp/icons/gtk

	# download binaries
	curl -sSL https://github.com/dracula/gtk/files/5214870/Dracula.zip > /tmp/icons/gtk.zip
	unzip -o /tmp/icons/gtk.zip -d /tmp/icons/gtk/
	sudo cp -r /tmp/icons/gtk/Dracula/ /usr/share/icons/

	# GRUB
	mkdir -p ~/git/dracula/
	mkdir -p /boot/grub/themes/dracula
	git clone https://github.com/dracula/grub.git ~/git/dracula/grub/
	sudo cp -r ~/git/dracula/grub/dracula/* /boot/grub/themes/dracula
	echo "GRUB_THEME=\"/boot/grub/themes/dracula/theme.txt\"" >> /etc/default/grub
	sudo grub-mkconfig -o /boot/grub/grub.cfg
}

usage() {
	echo -e "install.sh\\n Repeatable setup\\n"
	echo "Usage:"
	echo "  sudo                                - setup user for sudo"
	echo "  base                                - setup sources & install base pkgs"
	echo "  scripts                             - install scripts"
	echo "  themes				    - install themes"
	echo "  all				    - install everything"
}

main() {
	local cmd=$1

	if [[ -z "$cmd" ]]; then
		usage
		exit 1
	fi

	if [[ $cmd == "sudo" ]]; then
		check_is_sudo
		get_user
		setup_sudo
	elif [[ $cmd == "base" ]]; then
		check_is_sudo
		setup_sources
		base
	elif [[ $cmd == "scripts" ]]; then
		check_is_sudo
		install_scripts
	elif [[ $cmd == "themes" ]]; then
		check_is_sudo
		install_themes
	elif [[ $cmd == "all" ]]; then
		check_is_sudo
		setup_sources
		base
		install_scripts
		install_themes
	else
		usage
	fi
}

main "$@"
