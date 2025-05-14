# Glyphs used in the prompt
typeset -A glyph=(
    ["prompt"]="${VT_GLYPH_PROMPT:-󱞫}"
    ["command"]="${VT_GLYPH_COMMAND:-󱞩}"
    ["separator_left"]="${VT_GLYPH_SEPARATOR_LEFT:-‹}"
    ["separator_right"]="${VT_GLYPH_SEPARATOR_RIGHT:-›}"

    ["git_added"]="${VT_GLYPH_GIT_ADDED:-}"
    ["git_modified_index"]="${VT_GLYPH_GIT_MODIFIED_INDEX:-✱}"
    ["git_modified_workdir"]="${VT_GLYPH_GIT_MODIFIED_WORKDIR:-⭘}"
    ["git_deleted_index"]="${VT_GLYPH_GIT_DELETED_INDEX:-󰆴}"
    ["git_deleted_workdir"]="${VT_GLYPH_GIT_DELETED_WORKDIR:-󰧧}"
    ["git_renamed"]="${VT_GLYPH_GIT_RENAMED:-}"
    ["git_untracked"]="${VT_GLYPH_GIT_UNTRACKED:-}"
    ["git_rebase"]="${VT_GLYPH_GIT_REBASE:-󱌣}"
)

# Colors used in the prompt
typeset -A color=(
    ["normal"]="%F{${VT_COLOR_NORMAL:-254}}"
    ["dark"]="%F{${VT_COLOR_DARK:-242}}"
    ["err"]="%F{${VT_COLOR_ERR:-196}}"
    ["off"]="%f"

    ["git_branch"]="%F{${VT_COLOR_GIT_BRANCH:-43}}"
    ["git_added"]="%F{${VT_COLOR_GIT_ADDED:-40}}"
    ["git_modified_index"]="%F{${VT_COLOR_GIT_MODIFIED_INDEX:-172}}"
    ["git_modified_workdir"]="%F{${VT_COLOR_GIT_MODIFIED_WORKDIR:-192}}"
    ["git_deleted_index"]="%F{${VT_COLOR_GIT_DELETED_INDEX:-197}}"
    ["git_deleted_workdir"]="%F{${VT_COLOR_GIT_DELETED_WORKDIR:-124}}"
    ["git_renamed"]="%F{${VT_COLOR_GIT_RENAMED:-63}}"
    ["git_untracked"]="%F{${VT_COLOR_GIT_UNTRACKED:-244}}"
)

ZLE_RPROMPT_INDENT=0
VI_MODE="insert"

type zsh-defer > /dev/null 2>&1 && _VT_DEFER=true
zle -N dirhistory_zle_dirhistory_back > /dev/null 2>&1 && _VT_DIRHISTORY=true

# Gets the git state
function _vt_git_prompt() {
    local lprompt=""

    # If inside git repository
    if git rev-parse --is-inside-work-tree > /dev/null 2>&1; then
        local dir git_status commit_msg commit_author rebase_current rebase_total git_log

        # setup git state map: state -> file count
        typeset -gA git_states=(
            ["git_added"]=0
            ["git_modified_index"]=0
            ["git_modified_workdir"]=0
            ["git_deleted_index"]=0
            ["git_deleted_workdir"]=0
            ["git_renamed"]=0
            ["git_untracked"]=0
            ["git_conflict"]=0
        )

        # root of the git repository
        dir="$(git rev-parse --show-toplevel)"
        git_status="$(git status --porcelain)"

        git_log="$(git log -1 --pretty=%s@@@%an 2>/dev/null | tr -d '`')"
        commit_msg="${git_log%%@@@*}"
        commit_author="${git_log#*@@@}"

        # If there are some files changed, update the counts
        if [[ -n ${git_status} ]]; then
            while IFS= read -r line; do
                local l="${line:0:2}"
                # One file can be in multiple states, e.g. AM - added in index and modified in workdir
                if [[ ${l} == "A"* ]]; then
                    ((git_states[git_added]++))
                fi
                if [[ ${l} == "M"* ]]; then
                    ((git_states[git_modified_index]++))
                fi
                if [[ ${l} == *"M" ]]; then
                    ((git_states[git_modified_workdir]++))
                fi
                if [[ ${l} == "D"* ]]; then
                    ((git_states[git_deleted_index]++))
                fi
                if [[ ${l} == *"D" ]]; then
                    ((git_states[git_deleted_workdir]++))
                fi
                if [[ ${l} == "R"* ]]; then
                    ((git_states[git_renamed]++))
                fi
                if [[ ${l} == "??" ]]; then
                    ((git_states[git_untracked]++))
                fi
            done <<< "${git_status}"
        fi

        # If there is rebase in progress, get the current state - current commit number and total commit number
        if [[ -d "${dir}/.git/rebase-merge" || -d "${dir}/.git/rebase-apply" ]]; then
            if [[ -d "${dir}/.git/rebase-merge" ]]; then
                rebase_current="$(< "${dir}/.git/rebase-merge/msgnum")"
                rebase_total="$(< "${dir}/.git/rebase-merge/end")"
            else
                rebase_current="$(< "${dir}/.git/rebase-apply/next")"
                rebase_total="$(< "${dir}/.git/rebase-apply/last")"
            fi
        fi

        # Add rebase info to the prompt if not empty
        if [[ -n ${rebase_current} ]]; then
            lprompt+=" ${glyph[git_rebase]}"
            lprompt+=" ${rebase_current}/${rebase_total}"
        fi

        # Define the order of git states to display
        local -a git_states_order=("conflict" "git_added" "git_modified_index" "git_deleted_index" "git_renamed" "git_modified_workdir" "git_deleted_workdir" "git_untracked")
        # Create an array that holds the git states for display
        typeset -a git_state
        for state in ${(k)git_states_order}; do
            # Display only the states that are not empty
            if (( git_states[${state}] > 0)); then
                # The format is <state color><state glyph><count>
                git_state+=("${color[${state}]}${glyph[${state}]}${git_states[${state}]}")
            fi
        done

        # Add to prompt if not empty
        if [[ -n ${git_state[*]} ]]; then
            lprompt+=" ${git_state[*]}"
        fi

        # Append the commit message if not empty (for newly created repositories with no commits)
        if [[ -n ${commit_msg} ]]; then
            # The format is <dark color><left separator><commit message> (<commit author>)<right separator>
            lprompt+=" ${color[dark]}${glyph[separator_left]}${commit_msg} (${commit_author})${glyph[separator_right]}"
        fi
    fi

    echo "${lprompt}"
}

function _vt_end_prompt() {
    local lprompt="$1"

    lprompt+=$'\n'
    # prompt end plyph
    if [[ "${VI_MODE}" == "command" ]]; then
        lprompt+="${color[command]}"
    else
        lprompt+="%(?.${color[normal]}.${color[err]})"
    fi
    lprompt+="${glyph[command]} ${color[off]}"

    PROMPT="${lprompt}"
}

# Beginning of the prompt
function _vt_prompt_head() {
    local git_basic
    if git rev-parse --is-inside-work-tree > /dev/null 2>&1; then
        git_basic=" ${color[git_branch]}"
        local branch="$(git branch --show-current)"
        if [[ -n ${branch} && ${branch} != "HEAD" ]]; then
            git_basic+="${branch}"
        else
            git_basic+="󰜘$(git rev-parse --short HEAD)"
        fi
    fi

    # The format is <normal or err color, based on the last command return code><prompt glyph> <dark color><left separator>user@hostname<right separator> <normal color><pwd> <git branch or commit>
    echo "%(?.${color[normal]}.${color[err]})${glyph[prompt]} ${color[dark]}${glyph[separator_left]}%n@%m${glyph[separator_right]} ${color[normal]}%~${color[git_branch]}${git_basic}"
}

# Create a basic prompt that is displayed first
function _vt_basic_prompt() {
    _vt_end_prompt "$(_vt_prompt_head)"
}

# Create a prompt with full git info once processed
function _vt_full_prompt() {
    local lprompt="$(_vt_prompt_head)"
    lprompt+="$(_vt_git_prompt)"
    _vt_end_prompt "${lprompt}"
}

# Custom accept-line function that hides the prompt when executing the command
function _vt_accept_line() {
    if [[ -n "${BUFFER}" ]]; then
        _vt_clear_prompts
        zle .accept-line
    fi
}
zle -N accept-line _vt_accept_line

# Replaces the prompt with a one simple glyph
function _vt_clear_prompts() {
    PROMPT="${color[dark]}${glyph[command]} ${color[off]}"
    RPROMPT=''
    zle .reset-prompt
}

# Do not add this as a hook to precmd, as each plugin check from zsh-unplugged would trigger this
function precmd() {
    # Create a trap for CTRL+C to hide the prompt
    trap '
        _vt_clear_prompts > /dev/null 2>&1
        # Remove this trap so that we can propagate the interrupt
        trap - INT
        kill -SIGINT $$
    ' INT
    if [[ "${_VT_DEFER}" == "true" ]]; then
        # First show the basic prompt
        _vt_basic_prompt
        # Asynchronously display the full prompt
        zsh-defer _vt_full_prompt
    else
        _vt_full_prompt
    fi
}

# Handle vi mode change
function zle-keymap-select() {
    if [[ ${KEYMAP} == "vicmd" ]]; then
        VI_MODE="command"
    else
        VI_MODE="insert"
    fi
    # Reload the prompt
    precmd
}
zle -N zle-keymap-select

# If dirhistory plugin is loaded, override its functions to play nicely with the transient prompt
if [[ "${_VT_DIRHISTORY}" == "true" ]]; then
    function _vt_dirhistory_back() {
        dirhistory_back
        precmd
    }
    function _vt_dirhistory_forward() {
        dirhistory_forward
        precmd
    }
    function _vt_dirhistory_up() {
        dirhistory_up
        precmd
    }
    function _vt_dirhistory_down() {
        dirhistory_down
        precmd
    }
    zle -N _vt_dirhistory_back
    zle -N _vt_dirhistory_forward
    zle -N _vt_dirhistory_up
    zle -N _vt_dirhistory_down
    bindkey -M viins '^[[1;3D' _vt_dirhistory_back
    bindkey -M viins '^[[1;3C' _vt_dirhistory_forward
    bindkey -M viins '^[[1;3A' _vt_dirhistory_up
    bindkey -M viins '^[[1;3B' _vt_dirhistory_down
fi

# vim: ft=sh et
