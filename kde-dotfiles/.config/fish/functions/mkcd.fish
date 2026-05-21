function mkcd --description '创建目录并 cd 进去'
    if test (count $argv) -ne 1
        echo "用法: mkcd <dir>" >&2
        return 2
    end
    mkdir -p -- $argv[1]; and cd -- $argv[1]
end
