.PHONY: all
all: bin dotfiles #usr ## Installs the bin and the dotfiles.

.PHONY: bin
bin: ## Installs the bin directory files.
	# add aliases for things in bin
	for file in $(shell find $(CURDIR)/bin -type f -not -name "*-backlight" -not -name ".*.swp"); do \
		f=$$(basename $$file); \
		sudo ln -sf $$file /usr/local/bin/$$f; \
	done

.PHONY: dotfiles
dotfiles: ## Installs the dotfiles.
	# add aliases for dotfiles
	for file in $(shell find $(CURDIR) -name ".*" -not -name ".gitignore" -not -name ".git" -not -name ".config" -not -name ".github" -not -name ".*.swp" -not -name ".gnupg"); do \
		f=$$(basename $$file); \
		ln -sfn $$file $(HOME)/$$f; \
	done; \
	# gpg
	gpg --list-keys || true;
	mkdir -p $(HOME)/.gnupg
	for file in $(shell find $(CURDIR)/.gnupg); do \
		f=$$(basename $$file); \
		ln -sfn $$file $(HOME)/.gnupg/$$f; \
	done; \
	# git
	ln -fn $(CURDIR)/gitignore $(HOME)/.gitignore;
	git update-index --skip-worktree $(CURDIR)/.gitconfig;
	# config
	mkdir -p $(HOME)/.config
	ln -sfn $(CURDIR)/config/git/ $(HOME)/.config/;
	ln -sfn $(CURDIR)/config/gnupg/gpg-agent.conf $(HOME)/.gnupg/gpg-agent.conf;
	ln -sfn $(CURDIR)/config/i3/ $(HOME)/.config/;
	ln -sfn $(CURDIR)/config/dunst/ $(HOME)/.config/;
	ln -sfn $(CURDIR)/config/rofi/ $(HOME)/.config/;
	ln -sfn $(CURDIR)/config/kitty/ $(HOME)/.config/;
	ln -sfn $(CURDIR)/config/starship/starship.toml $(HOME)/.config/;
	# bash
	ln -snf $(CURDIR)/.bash_profile $(HOME)/.profile;
	# fonts
	mkdir -p $(HOME)/.local/share;
	ln -snf $(CURDIR)/.fonts $(HOME)/.local/share/fonts;
	# pictures
	mkdir -p $(HOME)/Pictures
	ln -sfn $(CURDIR)/background.png $(HOME)/Pictures/background.png
	
	xrdb -merge $(HOME)/.Xdefaults || true
	xrdb -merge $(HOME)/.Xresources || true
	fc-cache -f -v || true

dotfiles-review: ## Review for dotfiles.
	if [ -f /usr/local/bin/pinentry ]; then \
		sudo ln -snf /usr/bin/pinentry /usr/local/bin/pinentry; \
	fi;
	mkdir -p $(HOME)/.config/fontconfig;
	ln -snf $(CURDIR)/.config/fontconfig/fontconfig.conf $(HOME)/.config/fontconfig/fontconfig.conf;

.PHONY: usr
usr: ## Installs the usr directory files.
	for file in $(shell find $(CURDIR)/usr -type f -not -name ".*.swp"); do \
		f=$$(echo $$file | sed -e 's|$(CURDIR)||'); \
		sudo mkdir -p $$(dirname $$f); \
		sudo ln -f $$file $$f; \
	done

.PHONY: vim
vim: ## Setup Vim configuration
	git clone https://github.com/denhamparry/.vim.git $(HOME)/.vim
	ln -sf $(HOME)/.vim/vimrc $(HOME)/.vimrc
	cd $(HOME)/.vim

.PHONY: test
test: shellcheck ## Runs all the tests on the files in the repository.

# if this session isn't interactive, then we don't want to allocate a
# TTY, which would fail, but if it is interactive, we do want to attach
# so that the user can send e.g. ^C through.
INTERACTIVE := $(shell [ -t 0 ] && echo 1 || echo 0)
ifeq ($(INTERACTIVE), 1)
	DOCKER_FLAGS += -t
endif

.PHONY: shellcheck
shellcheck: ## Runs the shellcheck tests on the scripts.
	docker run --rm -i $(DOCKER_FLAGS) \
		--name df-shellcheck \
		-v $(CURDIR):/usr/src:ro \
		--workdir /usr/src \
		r.j3ss.co/shellcheck ./test.sh

.PHONY: help
help:
	@grep -E '^[a-zA-Z_-]+:.*?## .*$$' $(MAKEFILE_LIST) | sort | awk 'BEGIN {FS = ":.*?## "}; {printf "\033[36m%-30s\033[0m %s\n", $$1, $$2}'
