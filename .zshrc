export ZSH="/home/lewis/.oh-my-zsh"

ZSH_THEME="agnoster"

export FZF_BASE=~/.fzf/

plugins=(fzf git per-directory-history zsh-syntax-highlighting zsh-autosuggestions zsh-completions zsh-z)

source $ZSH/oh-my-zsh.sh
source $HOME/.aliases
source $HOME/.functions
source $HOME/.path

ZSH_TMUX_AUTOSTART='true'
ZSH_TMUX_AUTOCONNECT='false'

# zsh completions
autoload -U compinit && compinit

export GPG_TTY
export SSH_AUTH_SOCK="/run/user/$UID/gnupg/S.gpg-agent.ssh"

# Make vim the default editor
export EDITOR=vim;
export TERMINAL=vim;
export VISUAL=vim;

# Larger bash history (allow 32³ entries; default is 500)
export HISTSIZE=50000000;
export HISTFILESIZE=$HISTSIZE;
export HISTCONTROL=ignoredups;
# Make some commands not show up in history
export HISTIGNORE=" *:ls:cd:cd -:pwd:exit:date:* --help:* -h:pony:pony add *:pony update *:pony save *:pony ls:pony ls *";

# Prefer GB English and use UTF-8
export LANG="en_GB.UTF-8";
export LC_ALL="en_GB.UTF-8";

# Lets not trust Docker (yet)
export DOCKER_CONTENT_TRUST=0

# if it's an ssh session export GPG_TTY
if [[ -n "$SSH_CLIENT" ]] || [[ -n "$SSH_TTY" ]]; then
	GPG_TTY=$(tty)
	export GPG_TTY
fi

