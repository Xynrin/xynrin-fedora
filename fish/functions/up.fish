function up --description 'Update dnf + flatpak (run fisher update manually when needed)'
    if type -q dnf
        echo "== dnf upgrade =="
        sudo dnf upgrade --refresh -y; or return
        sudo dnf autoremove -y
    end

    if type -q flatpak
        echo "== flatpak update =="
        flatpak update -y
        flatpak uninstall --unused -y
    end
end
