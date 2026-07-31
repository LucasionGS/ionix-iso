#!/usr/bin/env bash
# install-completions — Install shell tab-completions for ionixtheme
#
# Links the bash and fish completion scripts into the standard
# per-user completion directories so they load automatically.
#
# Usage: ./install-completions.sh

set -euo pipefail

SCRIPT_DIR="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd)"
COMPLETIONS_DIR="$SCRIPT_DIR/completions"

msg() { printf '\033[1;35m[ionix]\033[0m %s\n' "$*"; }
ok()  { printf '\033[1;32m[ionix]\033[0m %s\n' "$*"; }

install_fish() {
    local dest_dir="${XDG_CONFIG_HOME:-$HOME/.config}/fish/completions"
    mkdir -p "$dest_dir"
    ln -sf "$COMPLETIONS_DIR/ionixtheme.fish" "$dest_dir/ionixtheme.fish"
    ok "fish: linked $dest_dir/ionixtheme.fish"
}

install_bash() {
    local dest_dir="${XDG_DATA_HOME:-$HOME/.local/share}/bash-completion/completions"
    mkdir -p "$dest_dir"
    ln -sf "$COMPLETIONS_DIR/ionixtheme.bash" "$dest_dir/ionixtheme"
    ok "bash: linked $dest_dir/ionixtheme"
    msg "bash: start a new shell (requires the bash-completion package)."
}

main() {
    install_fish
    install_bash
    ok "Completions installed. Open a new shell to use them."
}

main "$@"
