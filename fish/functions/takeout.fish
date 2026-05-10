function takeout --description 'Run a long command and desktop-notify when done'
    if test (count $argv) -eq 0
        echo "usage: takeout <command...>"
        return 1
    end
    set -l start (date +%s)
    $argv
    set -l rc $status
    set -l dur (math (date +%s) - $start)
    set -l msg "$argv (exit $rc, $dur"s")"
    if test $rc -eq 0
        notify-send -i dialog-information "✓ done" "$msg" 2>/dev/null
    else
        notify-send -u critical -i dialog-error "✗ failed" "$msg" 2>/dev/null
    end
    return $rc
end
