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
	deb http://httpredir.debian.org/debian buster main contrib non-free
	deb-src http://httpredir.debian.org/debian/ buster main contrib non-free

	deb http://httpredir.debian.org/debian/ buster-updates main contrib non-free
	deb-src http://httpredir.debian.org/debian/ buster-updates main contrib non-free

	deb http://security.debian.org/ buster/updates main contrib non-free
	deb-src http://security.debian.org/ buster/updates main contrib non-free

	deb http://httpredir.debian.org/debian experimental main contrib non-free
	deb-src http://httpredir.debian.org/debian experimental main contrib non-free
	EOF

	# turn off translations, speed up apt update
	mkdir -p /etc/apt/apt.conf.d
	echo 'Acquire::Languages "none";' > /etc/apt/apt.conf.d/99translations

	# Create an environment variable for the correct distribution
	CLOUD_SDK_REPO="cloud-sdk-$(lsb_release -c -s)"
	export CLOUD_SDK_REPO

	# Add the Cloud SDK distribution URI as a package source
	cat <<-EOF > /etc/apt/sources.list.d/google-cloud-sdk.list
	deb http://packages.cloud.google.com/apt $CLOUD_SDK_REPO main
	EOF

	# Import the Google Cloud Platform public key
	curl https://packages.cloud.google.com/apt/doc/apt-key.gpg | apt-key add -

	# Add the Google Chrome distribution URI as a package source
	cat <<-EOF > /etc/apt/sources.list.d/google-chrome.list
	deb [arch=amd64] http://dl.google.com/linux/chrome/deb/ stable main
	EOF

	# kubectl
	cat <<-EOF > /etc/apt/sources.list.d/kubernetes.list
	deb https://apt.kubernetes.io/ kubernetes-xenial main
	EOF
}

base_min() {
	apt update || true
	apt -y upgrade

	apt install -y \
		adduser \
		automake \
		bash-completion \
		bc \
		bzip2 \
		ca-certificates \
		coreutils \
		curl \
		dnsutils \
		file \
		findutils \
		gcc \
		git \
		gnupg \
		gnupg2 \
		grep \
		gzip \
		hostname \
		htop \
		indent \
		iotop \
		iptables \
		jq \
		less \
		libc6-dev \
		locales \
		lsof \
		make \
		mount \
		net-tools \
		nodejs \
		npm \
		policykit-1 \
		silversearcher-ag \
		ssh \
		strace \
		sudo \
		tar \
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

	install_scripts
}

# installs base packages
# the utter bare minimal shit
base() {

	apt update || true
	apt -y upgrade

	apt install -y \
		apparmor \
		bridge-utils \
		cgroupfs-mount \
		compton \
		forensics-all \
		ffmpeg \
		fwupd \
		fwupdate \
		gettext \
		git-crypt \
		gnupg-agent \
		google-cloud-sdk \
		graphviz \
		hplip \
		iwd \
		imagemagick \
		kitty \
		kubectl \
		libapparmor-dev \
		libimobiledevice6 \
		libltdl-dev \
		libnotify-bin \
		libpam-systemd \
		libseccomp-dev \
		neovim \
		nfs-common
		obs-studio \
		parallel \
		pinentry-curses \
		playerctl \
		python3-pip \
		scdaemon \
		screenfetch \
		shellcheck \
		systemd \
		tmux \
		--no-install-recommends

	setup_sudo

	# 1password
	sudo apt-key --keyring /usr/share/keyrings/1password.gpg adv --keyserver keyserver.ubuntu.com --recv-keys 3FEF9748469ADBE15DA7CA80AC2D62742012EA22
	echo 'deb [arch=amd64 signed-by=/usr/share/keyrings/1password.gpg] https://onepassword.s3.amazonaws.com/linux/debian edge main' | sudo tee /etc/apt/sources.list.d/1password.list
	sudo apt update && sudo apt install 1password

	apt autoremove
	apt autoclean
	apt clean

	pip install legit
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

# install rust
install_rust() {
	curl https://sh.rustup.rs -sSf | sh
}

# install/update golang from source
install_golang() {
	export GO_VERSION
	GO_VERSION=$(curl -sSL "https://golang.org/VERSION?m=text")
	export GO_SRC=/usr/local/go

	# if we are passing the version
	if [[ -n "$1" ]]; then
		GO_VERSION=$1
	fi

	# purge old src
	if [[ -d "$GO_SRC" ]]; then
		sudo rm -rf "$GO_SRC"
		sudo rm -rf "$GOPATH"
	fi

	GO_VERSION=${GO_VERSION#go}

	# subshell
	(
	kernel=$(uname -s | tr '[:upper:]' '[:lower:]')
	curl -sSL "https://storage.googleapis.com/golang/go${GO_VERSION}.${kernel}-amd64.tar.gz" | sudo tar -v -C /usr/local -xz
	local user="$USER"
	# rebuild stdlib for faster builds
	sudo chown -R "${user}" /usr/local/go/pkg
	CGO_ENABLED=0 go install -a -installsuffix cgo std
	)

	# get commandline tools
	(
	set -x
	set +e
	go get golang.org/x/lint/golint
	go get golang.org/x/tools/cmd/cover
	go get golang.org/x/tools/cmd/gopls
	go get golang.org/x/review/git-codereview
	go get golang.org/x/tools/cmd/goimports
	go get golang.org/x/tools/cmd/gorename
	go get golang.org/x/tools/cmd/guru

	go get github.com/genuinetools/amicontained
	go get github.com/genuinetools/apk-file
	go get github.com/genuinetools/audit
	go get github.com/genuinetools/bpfd
	go get github.com/genuinetools/bpfps
	go get github.com/genuinetools/certok
	go get github.com/genuinetools/netns
	go get github.com/genuinetools/pepper
	go get github.com/genuinetools/reg
	go get github.com/genuinetools/udict
	go get github.com/genuinetools/weather

	go get github.com/jessfraz/gmailfilters
	go get github.com/jessfraz/junk/sembump
	go get github.com/jessfraz/secping
	go get github.com/jessfraz/ship
	go get github.com/jessfraz/tdash

	go get github.com/axw/gocov/gocov
	go get honnef.co/go/tools/cmd/staticcheck

	# Tools for vimgo.
	go get github.com/jstemmer/gotags
	go get github.com/nsf/gocode
	go get github.com/rogpeppe/godef

	aliases=( genuinetools/contained.af genuinetools/binctr genuinetools/img docker/docker moby/buildkit opencontainers/runc )
	for project in "${aliases[@]}"; do
		owner=$(dirname "$project")
		repo=$(basename "$project")
		if [[ -d "${HOME}/${repo}" ]]; then
			rm -rf "${HOME:?}/${repo}"
		fi

		mkdir -p "${GOPATH}/src/github.com/${owner}"

		if [[ ! -d "${GOPATH}/src/github.com/${project}" ]]; then
			(
			# clone the repo
			cd "${GOPATH}/src/github.com/${owner}"
			git clone "https://github.com/${project}.git"
			# fix the remote path, since our gitconfig will make it git@
			cd "${GOPATH}/src/github.com/${project}"
			git remote set-url origin "https://github.com/${project}.git"
			)
		else
			echo "found ${project} already in gopath"
		fi

		# make sure we create the right git remotes
		if [[ "$owner" != "jessfraz" ]] && [[ "$owner" != "genuinetools" ]]; then
			(
			cd "${GOPATH}/src/github.com/${project}"
			git remote set-url --push origin no_push
			git remote add jessfraz "https://github.com/jessfraz/${repo}.git"
			)
		fi
	done

	# do special things for k8s GOPATH
	mkdir -p "${GOPATH}/src/k8s.io"
	kubes_repos=( community kubernetes release sig-release )
	for krepo in "${kubes_repos[@]}"; do
		git clone "https://github.com/kubernetes/${krepo}.git" "${GOPATH}/src/k8s.io/${krepo}"
		cd "${GOPATH}/src/k8s.io/${krepo}"
		git remote set-url --push origin no_push
		git remote add jessfraz "https://github.com/jessfraz/${krepo}.git"
	done
	)

	# symlink weather binary for motd
	sudo ln -snf "${GOPATH}/bin/weather" /usr/local/bin/weather

	# Control Plane
	go get github.com/go-jira/jira/cmd/jira
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

	# install hadolint
	curl -sSL https://github.com/hadolint/hadolint/releases/download/v1.18.0/hadolint-Linux-x86_64 > /usr/local/bin/hadolint
	chmod +x /usr/local/bin/hadolint

	# install conftest
	wget https://github.com/open-policy-agent/conftest/releases/download/v0.21.0/conftest_0.21.0_Linux_x86_64.tar.gz
	tar xzf conftest_0.21.0_Linux_x86_64.tar.gz
	sudo mv conftest /usr/local/bin

	# Hashicorp
	curl -fsSL https://apt.releases.hashicorp.com/gpg | sudo apt-key add -
	sudo apt-add-repository "deb [arch=amd64] https://apt.releases.hashicorp.com $(lsb_release -cs) main"
	sudo apt-get update && sudo apt-get install vault

	local scripts=( have light )

	for script in "${scripts[@]}"; do
		curl -sSL "https://misc.j3ss.co/binaries/$script" > "/usr/local/bin/${script}"
		chmod +x "/usr/local/bin/${script}"
	done
}

install_npm() {
	curl -sL https://raw.githubusercontent.com/nvm-sh/nvm/v0.34.0/install.sh -o install_nvm.sh
	chmod +x install_nvm.sh
	./install_nvm.sh
	rm install_nvm.sh
	sourced
	nvm install v14.12.0
	npm install netlify-cli -g
	npm install -g firebase-tools
}

install_tools() {
	echo "Installing golang..."
	echo
	install_golang;

	echo
	echo "Installing rust..."
	echo
	install_rust;

	echo
	echo "Installing npm..."
	echo
	install_rust;

	echo
	echo "Installing scripts..."
	echo
	sudo install.sh scripts;
}

install_emojis() {
	cd "mktemp -d"
	wget https://github.com/eosrei/twemoji-color-font/releases/download/v12.0.1/TwitterColorEmoji-SVGinOT-Linux-12.0.1.tar.gz
	tar zxf TwitterColorEmoji-SVGinOT-Linux-12.0.1.tar.gz
	cd TwitterColorEmoji-SVGinOT-Linux-12.0.1
	./install.sh
	cd "${HOME}"
}

usage() {
	echo -e "install.sh\\n\\tThis script installs my basic setup for a debian laptop\\n"
	echo "Usage:"
	echo "  base                                - setup sources & install base pkgs"
	echo "  basemin                             - setup sources & install base min pkgs"
	echo "  golang                              - install golang and packages"
	echo "  rust                                - install rust"
	echo "  npm                                 - install npm"
	echo "  scripts                             - install scripts"
	echo "  tools                               - install golang, rust, and scripts"
	echo "  emojis                            	- install emojis"
}

main() {
	local cmd=$1

	if [[ -z "$cmd" ]]; then
		usage
		exit 1
	fi

	if [[ $cmd == "base" ]]; then
		check_is_sudo
		get_user
		
		# setup /etc/apt/sources.list
		setup_sources

		base
	elif [[ $cmd == "basemin" ]]; then
		check_is_sudo
		get_user

		# setup /etc/apt/sources.list
		setup_sources

		base_min
	elif [[ $cmd == "dotfiles" ]]; then
		get_user
		get_dotfiles
	elif [[ $cmd == "vim" ]]; then
		install_vim
	elif [[ $cmd == "rust" ]]; then
		install_rust
	elif [[ $cmd == "golang" ]]; then
		install_golang "$2"
	elif [[ $cmd == "npm" ]]; then
		install_npm
	elif [[ $cmd == "scripts" ]]; then
		install_scripts
	elif [[ $cmd == "tools" ]]; then
		install_tools
	elif [[ $cmd == "emojis" ]]; then
		install_emojis
	elif [[ $cmd == "golang" ]]; then
		install_golang "$2"
	else
		usage
	fi
}

main "$@"