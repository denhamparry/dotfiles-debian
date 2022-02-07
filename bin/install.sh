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
		echo -e "Defaults	secure_path=\"/usr/local/go/bin:/home/${TARGET_USER}/.go/bin:/usr/local/sbin:/usr/local/bin:/usr/sbin:/usr/bin:/sbin:/bin:/usr/share/bcc/tools:/home/${TARGET_USER}/.cargo/bin\""; \
		echo -e 'Defaults	env_keep += "ftp_proxy http_proxy https_proxy no_proxy GOPATH EDITOR"'; \
		echo -e "${TARGET_USER} ALL=(ALL) NOPASSWD:ALL"; \
		echo -e "${TARGET_USER} ALL=NOPASSWD: /sbin/ifconfig, /sbin/ifup, /sbin/ifdown, /sbin/ifquery"; \
	} >> /etc/sudoers

	# setup downloads folder as tmpfs
	# that way things are removed on reboot
	# i like things clean but you may not want this
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

	# turn off translations, speed up apt update
	mkdir -p /etc/apt/apt.conf.d
	echo 'Acquire::Languages "none";' > /etc/apt/apt.conf.d/99translations

}

base() {

	apt update || true
	apt -y upgrade

	apt install -y \
		adduser \
		apparmor \
		automake \
		autorandr \
		bash-completion \
		bc \
		bridge-utils \
		bzip2 \
		ca-certificates \
		cgroupfs-mount \
		compton \
		coreutils \
		curl \
		direnv \
		dnsutils \
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
		gnupg \
		gnupg-agent \
		gnupg2 \
		graphviz \
		grep \
		gzip \
		hostname \
		hplip \
		htop \
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
		make \
		mount \
		neovim \
		net-tools \
		nfs-common \
		nodejs \
		npm \
		obs-studio \
		parallel \
		pinentry-curses \
		playerctl \
		policykit-1 \
		progress \
		python3-pip \
		scdaemon \
		screenfetch \
		screenkey \
		shellcheck \
		silversearcher-ag \
		ssh \
		strace \
		sudo \
		systemd \
		tar \
		tmux \
		tree \
		tzdata \
		unzip \
		vim \
		xz-utils \
		zip \
		--no-install-recommends

	apt autoremove
	apt autoclean
	apt clean

	pip install legit
}

# install custom scripts/binaries
install_scripts() {
	# install speedtest
	curl -sSL https://raw.githubusercontent.com/sivel/speedtest-cli/master/speedtest.py  > /usr/local/bin/speedtest
	chmod +x /usr/local/bin/speedtest

	# install icdiff
	curl -sSL https://raw.githubusercontent.com/jeffkaufman/icdiff/master/icdiff > /usr/local/bin/icdiff
	curl -sSL https://raw.githubusercontent.com/jeffkaufman/icdiff/master/git-icdiff > /usr/local/bin/git-icdiff
	chmod +x /usr/local/bin/icdiff
	chmod +x /usr/local/bin/git-icdiff

	# install lolcat
	curl -sSL https://raw.githubusercontent.com/tehmaze/lolcat/master/lolcat > /usr/local/bin/lolcat
	chmod +x /usr/local/bin/lolcat

	# install fzf
	git clone --depth 1 https://github.com/junegunn/fzf.git ~/.fzf
	~/.fzf/install

	# install tmux plugin manager
	git clone https://github.com/tmux-plugins/tpm ~/.tmux/plugins/tpm

	# install aws cli
	curl "https://awscli.amazonaws.com/awscli-exe-linux-x86_64.zip" -o "awscliv2.zip"
	unzip awscliv2.zip
	sudo ./aws/install

	# kubectl
	curl -LO "https://dl.k8s.io/release/$(curl -L -s https://dl.k8s.io/release/stable.txt)/bin/linux/amd64/kubectl"
	curl -LO "https://dl.k8s.io/$(curl -L -s https://dl.k8s.io/release/stable.txt)/bin/linux/amd64/kubectl.sha256"
	echo "$(<kubectl.sha256)  kubectl" | sha256sum --check
	sudo install -o root -g root -m 0755 kubectl /usr/local/bin/kubectl
	kubectl version --client
}

usage() {
	echo -e "install.sh\\n Repeatable setup\\n"
	echo "Usage:"
	echo "  sudo                                - setup user for sudo"
	echo "  base                                - setup sources & install base pkgs"
	echo "  scripts                             - install scripts"
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
		get_user
		setup_sources
		base
	elif [[ $cmd == "scripts" ]]; then
		check_is_sudo
		get_user
		install_scripts
	else
		usage
	fi
}

main "$@"


# google-cloud-sdk
# kubectl