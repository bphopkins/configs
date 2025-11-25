# 70-task-list.sh
# List unchecked Markdown tasks under a directory tree.
#
# Usage:
#   ls-tasks            # scan from current directory (.)
#   ls-tasks PATH       # scan from PATH (relative or absolute)
#
# For each line in any *.md file that begins with an unchecked Markdown
# checkbox ("- [ ]", with any indentation), print:
#   <relative-directory>: <original-line>
#
# Directories are printed relative to the scan root:
#   - with no argument: relative to $PWD
#   - with an argument: relative to that argument
#
# Example output:
#   .: - [ ] top-level task
#   notes:     - [ ] finish notes on X
#   notes/subdir:   - [ ] do something

ls_tasks() {
  local root file dir display_dir line

  # Determine scan root
  if [[ $# -eq 0 ]]; then
    root="."
  elif [[ $# -eq 1 ]]; then
    root=$1
  else
    printf 'ls-tasks: too many arguments (at most one path)\n' >&2
    return 2
  fi

  # Root must be an existing directory
  if [[ ! -d $root ]]; then
    printf 'ls-tasks: "%s" is not a directory\n' "$root" >&2
    return 1
  fi

  # Run in a subshell so cd doesn't affect the caller
  (
    cd "$root" || exit 1

    # Find all Markdown files under the root, safely handling spaces/nulls
    find . -type f -name '*.md' -print0 |
      while IFS= read -r -d '' file; do
        dir=$(dirname "$file")

        # Strip leading "./" for nicer relative output
        if [[ $dir == "." ]]; then
          display_dir="."
        else
          display_dir=${dir#./}
        fi

        # For each matching line in the file, print "<dir>: <line>"
        while IFS= read -r line; do
          printf '%s: %s\n' "$display_dir" "$line"
        done < <(
          # Match lines with any indentation, then "- [ ]" (unchecked box)
          grep -E '^[[:space:]]*-[[:space:]]+\[[[:space:]]\]' -- "$file" || true
        )
      done
  )
}

# Provide the hyphenated command name as an alias to the function
alias ls-tasks='ls_tasks'
