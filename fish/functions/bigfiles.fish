function bigfiles --description 'Find N biggest files under PATH (default: 20 under .)'
    set -l top 20
    set -l dir .
    if test (count $argv) -ge 1
        set dir $argv[1]
    end
    if test (count $argv) -ge 2
        set top $argv[2]
    end
    find $dir -type f -not -path '*/.git/*' -printf '%s\t%p\n' 2>/dev/null \
        | sort -rn \
        | head -n $top \
        | awk 'BEGIN{IFS="\t"} {
            s=$1; $1="";
            if      (s>=1073741824) printf "%7.2f GB\t%s\n", s/1073741824, $0;
            else if (s>=1048576)    printf "%7.2f MB\t%s\n", s/1048576, $0;
            else if (s>=1024)       printf "%7.2f KB\t%s\n", s/1024, $0;
            else                    printf "%7d  B\t%s\n", s, $0;
        }'
end
