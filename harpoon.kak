declare-option str-list harpoon_files

define-command harpoon-add -docstring "harpoon-add: Add the current file to the list of harpoons" %{
  evaluate-commands %sh{
    eval set -- "$kak_quoted_opt_harpoon_files"
    index=0
    while [ $# -gt 0 ]; do
      index=$(($index + 1))
      shift
    done
    index=$(($index + 1))
    printf "%s\\n" "
      set-option -add global harpoon_files $(echo $kak_quoted_bufname | xargs):$kak_cursor_line:$kak_cursor_column
      echo '$index: $kak_bufname:$kak_cursor_line:$kak_cursor_column'
    "
  }
}

define-command harpoon-nav -params 1 -docstring "harpoon-nav <index>: navigate to the harpoon at <index>" %{
  evaluate-commands %sh{
    index=$1

    eval set -- "$kak_quoted_opt_harpoon_files"

		bufname=$(printf "$1" | awk -F '[:]' '{ print $1 }')
		line=$(printf "$1" | awk -F '[:]' '{ print $2 }')
		column=$(printf "$1" | awk -F '[:]' '{ print $3 }')

    if [ -n "$bufname" ]; then
      echo "edit '$bufname'"
      echo "select $line.$column,$line.$column"
      echo "echo '$index: $bufname'"
    else
      echo "fail 'No harpoon at index $index'"
    fi
  }
}

define-command harpoon-show-list -docstring "harpoon-show-list: show all harpoons in the *harpoons* buffer" %{
  evaluate-commands -save-regs dquote %{
    try %{
      set-register dquote %opt{harpoon_files}
      edit -scratch *harpoon*
      execute-keys -draft '%"_d<a-P>a<ret><esc>I<c-r>#: <esc>gjxd'
    }
    try %{ execute-keys ggghwl } catch %{
      delete-buffer *harpoon*
      fail "No harpoons are set"
    }
  }
}

define-command -hidden harpoon-update-from-list %{
  evaluate-commands -save-regs dquote %{
    try %{
      execute-keys -draft -save-regs '' '%<a-s><a-k>^\d*:<ret><a-;>;wl<a-l>y'
      set-option global harpoon_files %reg{dquote}
      harpoon-show-list
    } catch %{
      set-option global harpoon_files
    }
    echo "Updated harpoons"
  }
}

define-command harpoon-add-bindings -docstring "Add convenient keybindings for navigating harpoons" %{
  map global normal <a-1> ":harpoon-nav 1<ret>"
  map global normal <a-2> ":harpoon-nav 2<ret>"
  map global normal <a-3> ":harpoon-nav 3<ret>"
  map global normal <a-4> ":harpoon-nav 4<ret>"
  map global normal <a-5> ":harpoon-nav 5<ret>"
  map global normal <a-6> ":harpoon-nav 6<ret>"
  map global normal <a-7> ":harpoon-nav 7<ret>"
  map global normal <a-8> ":harpoon-nav 8<ret>"
  map global normal <a-9> ":harpoon-nav 9<ret>"

  map global user h ":harpoon-add<ret>" -docstring "add harpoon"
  map global user H ":harpoon-show-list<ret>" -docstring "show harpoons"
}

hook global BufCreate \*harpoon\* %{
  map buffer normal <ret> ':harpoon-nav %val{cursor_line}<ret>'
  map buffer normal <c-o> ':delete-buffer *harpoon*<ret>'
  alias buffer write harpoon-update-from-list
  alias buffer w harpoon-update-from-list
  add-highlighter buffer/harpoon-indices regex ^\d: 0:function
}

# State saving - save by PWD and git branch, if any

declare-option str harpoon_state_file

define-command -hidden harpoon-load %{
  evaluate-commands %sh{
    if [ -f "$kak_opt_harpoon_state_file" ]; then
      printf "set-option global harpoon_files "
      cat "$kak_opt_harpoon_state_file"
    fi
  }
}

define-command -hidden harpoon-save %{
  evaluate-commands %sh{
    if [ -z "$kak_opt_harpoon_state_file" ]; then
      exit
    fi
    if [ -z "$kak_quoted_opt_harpoon_files" ]; then
      rm -f "$kak_opt_harpoon_state_file"
      exit
    fi
    printf "$kak_quoted_opt_harpoon_files" > "$kak_opt_harpoon_state_file"
  }
}

define-command -hidden harpoon-check %{
  evaluate-commands %sh{
    # Ignore scratch files
    if [ -z "${kak_buffile%\**\*}" ]; then
      exit
    fi
    git_branch=$(git -C "${kak_buffile%/*}" rev-parse --abbrev-ref HEAD 2>/dev/null)
    state_file=$(printf "%s" "$PWD-$git_branch" | sed -e 's|_|__|g' -e 's|/|_-|g')
    state_dir=${XDG_STATE_HOME:-~/.local/state}/kak/harpoon
    state_path="$state_dir/$state_file"
    if [ "$state_path" != "$kak_opt_harpoon_state_file" ]; then
      mkdir -p "$state_dir"
      printf "%s\\n" "
        harpoon-save
        set-option global harpoon_state_file '$state_path'
        harpoon-load
      "
    fi
  }
}

hook global FocusIn .* harpoon-check
hook global WinDisplay .* harpoon-check
hook global KakEnd .* harpoon-save
