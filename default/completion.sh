# If kubectl bash completion script is available, source it
if [ -f /etc/bash_completion.d/kubectl ]; then
    source /etc/bash_completion.d/kubectl
fi

if [ ! -f ~/.local/share/bash-completion/completions/mise ]; then
    mkdir -p ~/.local/share/bash-completion/completions
    mise completion bash  > ~/.local/share/bash-completion/completions/mise
fi 

if [ -f ~/.local/share/bash-completion/completions/mise ]; then
    source ~/.local/share/bash-completion/completions/mise
fi 