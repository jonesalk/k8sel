# k8sel oh-my-zsh plugin
#
# Thin zsh wrapper around the standalone `k8sel` binary (expected on PATH,
# typically a symlink from ~/.local/bin/k8sel to this repo's ./k8sel script).
#
# The binary does all the real work (fzf UI, filtering, previews, etc.).
# This plugin only translates the binary's exit code 10 ("user pressed
# Alt-Enter") into a `print -z` call, which puts a re-runnable command
# onto the next shell prompt so the user can pipe it through another tool.

# If k8sel is not on PATH, check the plugin directory itself (so the plugin
# works when the repo is cloned directly into oh-my-zsh custom/plugins/k8sel
# without a separate ~/.local/bin symlink).
# Resolve to an absolute path so that calling "$_k8sel_bin" inside the k8sel()
# function always invokes the binary, never the function itself.
_k8sel_bin=""
if (( $+commands[k8sel] )); then
    _k8sel_bin="${commands[k8sel]}"
elif [[ -x ${0:A:h}/k8sel ]]; then
    _k8sel_bin="${0:A:h}/k8sel"
else
    print -u2 -- "k8sel plugin: 'k8sel' binary not found on PATH and not found in plugin dir (${0:A:h})."
    return 0
fi

k8sel() {
    emulate -L zsh
    setopt localoptions no_aliases pipefail

    # Passthrough if non -h/--help/-r are given
    for arg in "$@"; do
        case $arg in
            -h|--help|-r) "$_k8sel_bin" "$@"; return ;;
        esac
    done

    local out rc=0

    # Run the binary inside a command substitution so we can capture stdout.
    # - Normal enter (rc=0): binary outputs selected YAML → we print it.
    # - Alt-enter (rc=10):  push out  onto the next prompt with print -z.
    out=$("$_k8sel_bin" "$@") || rc=$?
    case $rc in
        0)
            [[ -n $out ]] && print -r -- "$out"
            ;;
        10)
            [[ -n $out ]] && print -z -- "$out"
            ;;
        *)
            return $rc
            ;;
    esac
}
