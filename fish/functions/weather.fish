function weather --description 'Show weather via wttr.in (defaults to auto-locate)'
    set -l where ""
    if test (count $argv) -ge 1
        set where (string join + $argv)
    end
    curl -fsS "https://wttr.in/$where?lang=zh&F&T" 2>/dev/null; or echo "no network"
end
