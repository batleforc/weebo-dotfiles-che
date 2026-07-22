CODE_CLI_DIR="/checode/checode-linux-libc/ubi9/bin/remote-cli"

# Make code-oss available as `code` in the remote CLI dir
if [ -f "$CODE_CLI_DIR/code-oss" ] && [ ! -e "$CODE_CLI_DIR/code" ]; then
    ln -s "$CODE_CLI_DIR/code-oss" "$CODE_CLI_DIR/code"
fi
