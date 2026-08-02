if command -v eza &> /dev/null; then
    alias ls='eza -lh --group-directories-first --icons=auto'
    alias ll='ls -lah'
    alias lt='eza --tree --level=2 --long --icons --git'
    alias lta='lt -a'
else
    alias ls='ls --color=auto'
    alias ll='ls -la --color=auto'
fi

if command -v task &> /dev/null; then
    alias t="task"
fi

if command -v fzf &> /dev/null && command -v bat &> /dev/null; then
    alias ff="fzf --preview 'bat --style=numbers --color=always {}'"
fi

# Neovim alias, taken from Omarchy's default dotfiles
# /globals/bashrc aliases n='nvim': without unalias, alias expansion renames
# the function below to nvim() at parse time -> infinite recursion -> segfault
unalias n 2>/dev/null
n() { if [ "$#" -eq 0 ]; then nvim .; else nvim "$@"; fi; }

# Clean build/cache dirs (node_modules, target, dist) under /projects
if [ -x "$HOME/.script/clean.sh" ]; then
    alias clean="$HOME/.script/clean.sh"
fi