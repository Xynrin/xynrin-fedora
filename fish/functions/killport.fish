function killport --description 'Kill process listening on a port'
    if test (count $argv) -eq 0
        echo "usage: killport <port> [port ...]"
        return 1
    end
    for port in $argv
        set -l pids (ss -lptn "sport = :$port" 2>/dev/null | string match -rg 'pid=(\d+)')
        if test -z "$pids"
            echo "port $port: no listener"
            continue
        end
        for pid in $pids
            set -l cmd (ps -p $pid -o comm= 2>/dev/null)
            echo "killing $cmd (pid $pid) on :$port"
            kill $pid
        end
    end
end
