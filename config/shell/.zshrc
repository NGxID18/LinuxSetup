autoload -Uz compinit
compinit

PROMPT='%F{cyan}%~%f> '

# Zsh Autosuggestions (Fedora/Debian/Ubuntu & Arch Linux paths)
for plugin in \
    /usr/share/zsh-autosuggestions/zsh-autosuggestions.zsh \
    /usr/share/zsh/plugins/zsh-autosuggestions/zsh-autosuggestions.zsh; do
    [ -f "$plugin" ] && { source "$plugin"; break; }
done

# Zsh Syntax Highlighting (Fedora/Debian/Ubuntu & Arch Linux paths)
for plugin in \
    /usr/share/zsh-syntax-highlighting/zsh-syntax-highlighting.zsh \
    /usr/share/zsh/plugins/zsh-syntax-highlighting/zsh-syntax-highlighting.zsh; do
    [ -f "$plugin" ] && { source "$plugin"; break; }
done

# CUDA Environment (Arch Linux /opt/cuda or standard /usr/local/cuda)
if [ -d "/opt/cuda" ]; then
    export CUDA_HOME="/opt/cuda"
elif [ -d "/usr/local/cuda" ]; then
    export CUDA_HOME="/usr/local/cuda"
fi

if [ -n "${CUDA_HOME:-}" ]; then
    export PATH="$CUDA_HOME/bin:$PATH"
    export LD_LIBRARY_PATH="$CUDA_HOME/lib64${LD_LIBRARY_PATH:+:$LD_LIBRARY_PATH}"
fi

# Keybindings
bindkey "^[[1;5C" forward-word
bindkey "^[[1;5D" backward-word
bindkey "^[[3~" delete-char
bindkey '^H' backward-kill-word

