function extract --description '万能解压：自动识别后缀'
    if test (count $argv) -lt 1
        echo "用法: extract <archive> [archive...]" >&2
        return 2
    end
    for f in $argv
        if not test -f $f
            echo "extract: 不是文件: $f" >&2
            continue
        end
        switch $f
            case '*.tar.gz' '*.tgz';    tar -xzf $f
            case '*.tar.xz' '*.txz';    tar -xJf $f
            case '*.tar.bz2' '*.tbz2';  tar -xjf $f
            case '*.tar.zst';           tar --zstd -xf $f
            case '*.tar';               tar -xf $f
            case '*.zip';               unzip -q $f
            case '*.7z';                7z x $f
            case '*.rar';               unrar x $f
            case '*.gz';                gunzip $f
            case '*.bz2';               bunzip2 $f
            case '*.xz';                unxz $f
            case '*.zst';               unzstd $f
            case '*';                   echo "extract: 不认识的格式: $f" >&2
        end
    end
end
