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

    # Passthrough: if either end of stdio is not a TTY (piped input or piped
    # output), or -h/--help/-r are given, the alt-enter re-run trick doesn't
    # make sense. Just exec the binary transparently.
    if [[ ! -t 0 || ! -t 1 ]]; then
        "$_k8sel_bin" "$@"
        return
    fi
    for arg in "$@"; do
        case $arg in
            -h|--help|-r) "$_k8sel_bin" "$@"; return ;;
        esac
    done

    # Locate the yaml file argument (if any) so we can reconstruct the
    # command for `print -z` in the alt-enter case.
    local yaml_file=""
    for arg in "$@"; do
        if [[ -f $arg ]]; then
            yaml_file=$arg
            break
        fi
    done

    local out rc=0
    out=$("$_k8sel_bin" "$@") || rc=$?

    case $rc in
        0)
            # Normal enter: print the selected YAML (or nothing).
            [[ -n $out ]] && print -r -- "$out"
            ;;
        10)
            # Alt-Enter: `$out` is a newline-separated list of kind/name@ns
            # identifiers. Rebuild a re-runnable command onto the prompt.
            local -a ids
            ids=(${(f)out})
            if [[ -z $yaml_file ]]; then
                print -u2 -- "k8sel: cannot inject re-run command (no yaml file arg)"
                return 1
            fi
            print -z -- "k8sel ${(q)yaml_file} -r ${(j: :)${(q)ids}}"
            ;;
        *)
            return $rc
            ;;
    esac
}
