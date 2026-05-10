function backup --description 'Copy file/dir to same path with .bak.YYYYMMDD-HHMMSS suffix'
    if test (count $argv) -eq 0
        echo "usage: backup <path> [path ...]"
        return 1
    end
    set -l stamp (date +%Y%m%d-%H%M%S)
    for p in $argv
        if not test -e $p
            echo "skip: $p (not found)"
            continue
        end
        set -l dest "$p.bak.$stamp"
        cp -a -- $p $dest; and echo "-> $dest"
    end
end
