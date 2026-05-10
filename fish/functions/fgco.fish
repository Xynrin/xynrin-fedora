function fgco --description 'Fuzzy pick a git branch (local+remote) and checkout'
    set -l branch (git branch --all --color=never --sort=-committerdate \
        | string replace -r '^\*?\s+' '' \
        | string replace -r '^remotes/[^/]+/' '' \
        | string match -v 'HEAD -> *' \
        | awk '!seen[$0]++' \
        | fzf --prompt='branch> ' --height=40% --reverse)
    test -z "$branch"; and return 0
    git checkout $branch
end
