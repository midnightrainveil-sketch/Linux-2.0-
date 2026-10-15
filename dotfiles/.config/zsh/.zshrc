# zsh: plain and typed, like the mockup's desk terminal.
#   [atlas@linden ~]$

# ---- history
HISTFILE="${XDG_STATE_HOME:-$HOME/.local/state}/zsh/history"
mkdir -p "${HISTFILE:h}"
HISTSIZE=50000
SAVEHIST=50000
setopt share_history hist_ignore_dups hist_ignore_space hist_reduce_blanks extended_history

# ---- behaviour
setopt auto_cd interactive_comments no_beep prompt_subst
bindkey -e
autoload -Uz compinit && compinit -d "${XDG_CACHE_HOME:-$HOME/.cache}/zcompdump"
zstyle ':completion:*' menu select
zstyle ':completion:*' matcher-list 'm:{a-z}={A-Z}'

# ---- prompt: [user@host dir]$   (no colour but ink; git branch in faded ink)
autoload -Uz vcs_info
zstyle ':vcs_info:git:*' formats ' %F{8}(%b)%f'
precmd() {
    vcs_info
    # window title, read by the bar's breadcrumb and the title bar: "atlas@linden: ~/rice"
    print -Pn "\e]2;%n@%m: %~\a"
}
preexec() { print -Pn "\e]2;%n@%m: %~\a" }
PROMPT='[%n@%m %1~]${vcs_info_msg_0_}%(?..%F{1} %?%f)$ '

# ---- quiet, muted helpers (the palette's madder, sage, ochre... not neon)
export LS_COLORS='di=34:ln=36:so=35:pi=33:ex=32:bd=33:cd=33:su=31:sg=31:tw=34:ow=34'
alias ls='ls --color=auto --group-directories-first'
alias ll='ls -lh'
alias la='ls -lah'
alias grep='grep --color=auto'
alias ff='archive-card'

[[ -r /usr/share/zsh/plugins/zsh-autosuggestions/zsh-autosuggestions.zsh ]] &&
    source /usr/share/zsh/plugins/zsh-autosuggestions/zsh-autosuggestions.zsh
ZSH_AUTOSUGGEST_HIGHLIGHT_STYLE='fg=8'
if [[ -r /usr/share/zsh/plugins/zsh-syntax-highlighting/zsh-syntax-highlighting.zsh ]]; then
    source /usr/share/zsh/plugins/zsh-syntax-highlighting/zsh-syntax-highlighting.zsh
    typeset -A ZSH_HIGHLIGHT_STYLES
    ZSH_HIGHLIGHT_STYLES[command]='fg=default'
    ZSH_HIGHLIGHT_STYLES[builtin]='fg=default'
    ZSH_HIGHLIGHT_STYLES[alias]='fg=default'
    ZSH_HIGHLIGHT_STYLES[unknown-token]='fg=1'
    ZSH_HIGHLIGHT_STYLES[path]='underline'
    ZSH_HIGHLIGHT_STYLES[single-quoted-argument]='fg=2'
    ZSH_HIGHLIGHT_STYLES[double-quoted-argument]='fg=2'
fi

# The desk terminal (opened by Hyprland at login) begins with the index card.
if [[ -n ${ARCHIVE_DESK:-} ]]; then
    unset ARCHIVE_DESK
    archive-card
fi
