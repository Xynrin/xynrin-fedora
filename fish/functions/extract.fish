function extract --description 'Extract any archive by extension'
    if test (count $argv) -eq 0
        echo "usage: extract <file> [file ...]"
        return 1
    end
    for f in $argv
        if not test -f $f
            echo "skip: $f (not a file)"
            continue
        end
        echo "-> $f"
        switch $f
            case '*.tar.bz2' '*.tbz2'; tar xjf $f
            case '*.tar.gz'  '*.tgz';  tar xzf $f
            case '*.tar.xz'  '*.txz';  tar xJf $f
            case '*.tar.zst';          tar --zstd -xf $f
            case '*.tar';              tar xf $f
            case '*.bz2';              bunzip2 $f
            case '*.gz';               gunzip $f
            case '*.xz';               unxz $f
            case '*.zst';              unzstd $f
            case '*.zip' '*.jar';      unzip $f
            case '*.rar';              unrar x $f
            case '*.7z';               7z x $f
            case '*.Z';                uncompress $f
            case '*';                  echo "unknown type: $f"; continue
        end
    end
end
