function serve --description 'Quick HTTP server for current dir (default :8000)'
    set -l port 8000
    if test (count $argv) -ge 1
        set port $argv[1]
    end
    set -l addr (ip -4 -o addr show scope global | awk '{print $4}' | cut -d/ -f1 | head -1)
    echo "serving $PWD"
    test -n "$addr"; and echo "  http://$addr:$port"
    echo "  http://127.0.0.1:$port"
    python3 -m http.server $port
end
