# keep zsh's files in ~/.config/zsh
export ZDOTDIR="${XDG_CONFIG_HOME:-$HOME/.config}/zsh"
# the archive-* commands
[[ :$PATH: == *:$HOME/.local/bin:* ]] || export PATH="$HOME/.local/bin:$PATH"
