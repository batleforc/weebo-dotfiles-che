if command -v eza &> /dev/null; then
    alias ls='eza -lh --group-directories-first --icons=auto'
    alias ll='ls -lah'
    alias lt='eza --tree --level=2 --long --icons --git'
    alias lta='lt -a'
else
    alias ls='ls --color=auto'
    alias ll='ls -la --color=auto'
fi

if command -v fzf &> /dev/null; then
    alias ff="fzf --preview 'bat --style=numbers --color=always {}'"
fi

# Neovim alias, taken from Omarchy's default dotfiles
n() { if [ "$#" -eq 0 ]; then nvim .; else nvim "$@"; fi; }