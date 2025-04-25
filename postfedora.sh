#!/usr/bin/env bash
# Automatization script for fedora post install sequences

# profile
profiles=("Desktop" "Laptop")
my_profile=

# display
#TODO: update deskconfig
desktopmon=$( cat <<EOF
<monitors version="2">
  <configuration>
    <layoutmode>logical</layoutmode>
    <logicalmonitor>
      <x>0</x>
      <y>0</y>
      <scale>1</scale>
      <primary>yes</primary>
      <monitor>
        <monitorspec>
          <connector>DP-1</connector>
          <vendor>GSM</vendor>
          <product>LG ULTRAWIDE</product>
          <serial>0x00013038</serial>
        </monitorspec>
        <mode>
          <width>3440</width>
          <height>1440</height>
          <rate>75.050</rate>
        </mode>
      </monitor>
    </logicalmonitor>
  </configuration>
</monitors>
EOF
)
laptopmon=$( cat <<EOF
<monitors version="2">
  <configuration>
    <layoutmode>logical</layoutmode>
    <logicalmonitor>
      <x>0</x>
      <y>0</y>
      <scale>1</scale>
      <primary>yes</primary>
      <monitor>
        <monitorspec>
          <connector>eDP-1</connector>
          <vendor>BOE</vendor>
          <product>0x0aca</product>
          <serial>0x00000000</serial>
        </monitorspec>
        <mode>
          <width>2560</width>
          <height>1600</height>
          <rate>90.003</rate>
        </mode>
      </monitor>
    </logicalmonitor>
  </configuration>
</monitors>
EOF
)

# git
git_configure=
git_username=
git_email=

# NAS
nas_configure=
nas_ip_address=
nas_folders=("home" "share")
nas_credentials_location="/etc/.nas-cred"
nas_username=
nas_password=

# packages
nvidia_drivers="akmod-nvidia"
dependencies="dconf dconf-editor git gh make typescript gettext just libgtop2-devel glib2-devel lm_sensors sass"
terminal="zsh"
apps="keepassxc codium evolution solaar"
fonts="droidsansmono-nerd-fonts"
games="steam lutris discord"
themes="tela-icon-theme"

# extensions from package manager
gextensions="gnome-tweaks gnome-theme-extra gnome-shell-extension-dash-to-dock gnome-shell-extension-blur-my-shell gnome-shell-extension-caffeine gnome-shell-extension-gsconnect gnome-shell-extension-pop-shell gnome-shell-extension-drive-menu gnome-shell-extension-user-theme"

# system detecion
cpu=
gpu=
deskenv=

##################
# INITIALIZATION #
##################

clear_buffer()
{
    read -N 100 -t 0.01
}

main_menu()
{
    if [ $FEDORA_POST_INSTALL -eq 0 ]
    then
        # INITIALIZATION
        clear
        show_title
        profile_selection
        system_detection
        user_interaction

        # RUNNING
	update_system
	install_dependencies

        if [ -z $my_profile ]
        then
            echo "Profile not found, exiting..."
            exit 1
        fi

        set_monitor
        if [[ $my_profile == "Desktop" ]] ; then mount_games_drive ; fi
        if [[ $git_configure -eq 1 ]] ; then configure_git ; fi
        if [[ $nas_configure -eq 1 ]] ; then configure_nas ; fi
        install_packages
        update_firmware
        if [[ $deskenv == "GNOME" ]] ; then install_gnome_extensions ; fi
        reboot_machine
    elif [ $FEDORA_POST_INSTALL -eq 1 ]
    then
        # POST INITIALIZATION
        clear
        show_title
        system_detection
        install_graphic_driver
        hardware_acceleration
        update_mulimedia_codec
        optimizations
        get_wallpaper
        if [[ $deskenv == "GNOME" ]]
        then
            set_gnome_settings
            set_gnome_settings_extensions
            enable_gnome_extensions
        fi
        reboot_machine
    elif [ $FEDORA_POST_INSTALL -eq 2 ]
    then
        echo "The script is finished, nothing else to do..."
        exit 1
    else
        echo "SCRIPT SEQUENCE NOT KNOWN... exiting !"
        exit 1
    fi
}

###############
# PREPARATION #
###############

show_title()
{
    echo $'  _____        _                   ____           _     ___           _        _ _ '
    echo $' |  ___|__  __| | ___  _ __ __ _  |  _ \ ___  ___| |_  |_ _|_ __  ___| |_ __ _| | |'
    echo $' | |_ / _ \/ _  |/ _ \|  __/ _  | | |_) / _ \/ __| __|  | ||  _ \/ __| __/ _  | | |'
    echo $' |  _|  __/ (_| | (_) | | | (_| | |  __/ (_) \__ \ |_   | || | | \__ \ || (_| | | |'
    echo $' |_|  \___|\__,_|\___/|_|  \__,_| |_|   \___/|___/\__| |___|_| |_|___/\__\__,_|_|_|'
    echo
}

profile_selection()
{
    echo -e "Available profiles:\n"
    for ((i=0; i<${#profiles[@]}; i++))
    do
        echo $((i+1))") "${profiles[i]}
    done
    echo
    clear_buffer
    read -n 1 -p "What profile would you apply to your system? " choice
    echo
    until [[ $choice =~ ^[0-9]+$ && $choice -gt 0 && $choice -le ${#profiles[@]} ]]
    do
        echo -e "Incorrect value !"
        read -n 1 -p "What profile would you apply to your system? " choice
        echo
    done
    my_profile=${profiles[choice-1]}
    choice=
    echo -e "You have chosen \e[1m$my_profile\e[0m\n"
}

system_detection()
{
    echo "System detection..."

    # DESKTOP ENVIRONMENT
    case $XDG_CURRENT_DESKTOP in
        "GNOME")
            deskenv="GNOME"
            ;;
        *)
            deskenv="UNKNOWN"
            ;;
    esac
    echo "DE  detected : $deskenv"

    # CPU
    cpuinfo=$( cat /proc/cpuinfo | grep vendor_id | uniq )
    case ${cpuinfo##* } in
        *"Intel"*)
            cpu="INTEL"
            ;;
        *"AMD"*)
            cpu="AMD"
            ;;
        *)
            cpu="UNKNOWN"
            ;;
    esac
    echo "CPU detected : $cpu"

    # GPU
    lspciinfo=$( lspci | grep -E "VGA|3D" )
    case $lspciinfo in
        *"NVIDIA"*)
            gpu="NVIDIA"
            ;;
        *"ATI"* | *"AMD"*)
            gpu="AMD"
            ;;
        *)
            gpu="UNKNOWN"
            ;;
    esac
    echo "GPU detected : $gpu"
    echo
}

user_interaction()
{
    # GIT
    while [ -z $git_configure ]
    do
		clear_buffer
		read -p "Would you like to configure your git user? [Y/n] " choice
		echo
		if [[ -z $choice || "Yy" =~ $choice ]]
		then
	   		git_configure=1
			read -p "GIT> Enter full name: " git_username
			read -p "GIT> Enter email address: " git_email
			echo "GIT> $git_username ($git_email) will be set as global git user!"
		elif [[ "Nn" =~ $choice ]]
		then
			git_configure=0
			echo "GIT will not be configured."
		fi
	done
    choice=
    echo

    # NAS
    while [ -z $nas_configure ]
    do
		clear_buffer
		read -p "Would you like to auto-configure the NAS connection? [Y/n] " choice
		echo
		if [[ -z $choice || "Yy" =~ $choice ]]
		then
		    nas_configure=1
		    read -p "NAS> Enter ip address: " nas_ip_address
		    read -p "NAS> Enter username: " nas_username
		    read -p "NAS> Enter password: " -s nas_password
		    echo
		    echo "NAS> $nas_username will be connected to the NAS!"
		elif [[ "Nn" =~ $choice ]]
		then
			nas_configure=0
		    echo "NAS will not be configured."
		fi
	done
    choice=
    echo
    
    start_script=
    while [ -z $start_script ]
    do
		clear_buffer
		read -p "Ready to lauch the configuration? [Y/n] " choice
		echo
		if [[ -z $choice || "Yy" =~ $choice ]]
		then
			start_script=1
		elif [[ "Nn" =~ $choice ]]
		then
			echo "Cancelling preparation and exiting..."
			exit 1
		fi
	done
    choice=
    echo
}

###########
# RUNNING #
###########

update_system()
{
    echo "Updating system..."
    sudo dnf update -y
}

install_dependencies()
{
    echo "Installing dependencies..."
    sudo dnf install -y $dependencies
}

set_monitor()
{
    echo "Updating monitor settings..."
    if [ $my_profile == "Desktop" ]
    then
        my_mon_settings=("${desktopmon[@]}")
    elif [ $my_profile == "Laptop" ]
    then
        my_mon_settings=("${laptopmon[@]}")
    fi

    echo -e "$my_mon_settings" | sudo dd of=~/.config/monitors.xml status=none

    # send config to GDM
    if [ $deskenv == "GNOME" ]
    then
        echo "Updating GDM monitor settings..."
        sudo cp -f ~/.config/monitors.xml ~gdm/.config/monitors.xml
        sudo chown $(id -u gdm):$(id -g gdm) ~gdm/.config/monitors.xml
        sudo restorecon ~gdm/.config/monitors.xml
    fi
    echo
}

mount_games_drive()
{
    echo "Mounting games drive..."
    fstab="UUID=e8f50cf3-fe9f-4739-a9d0-0b456e2e0b58 /mnt/games ext4 nosuid,nodev,nofail,x-gvfs-show,x-gvfs-name=Games 0 0\n"
    echo -e "$fstab" | sudo dd of=/etc/fstab oflag=append conv=notrunc status=none
    sudo systemctl daemon-reload
    sudo mount /mnt/games
    echo
}

configure_git()
{
    echo "Configuring GIT..."
    git config --global user.name $git_username &> /dev/null
    git config --global user.email $git_email &> /dev/null
    echo
}

configure_nas()
{
    echo "Configuring NAS..."
    declare -A naslocations
    for i in ${nas_folders[@]}
    do
        naslocations[$i]="/mnt/nas-$i"
    done

    nascred="username="$nas_username"\npassword="$nas_password"\ndomain=WORKGROUP"
    nas_username=
    nas_password=

    echo -e "$nascred" | sudo dd of=$nas_credentials_location status=none

    fstab=
    for i in ${!naslocations[@]}
    do
        sudo mkdir ${naslocations[$i]}
        fstab+="//$nas_ip_address/$i  ${naslocations[$i]}  cifs    credentials=$nas_credentials_location,uid=1000,gid=1000    0 0\n"

        echo "Access to \"$i\" (${naslocations[$i]}) has been created."

        if [ $deskenv == "GNOME" ]
        then
            folder=${naslocations[$i]}
            echo "file://$folder ${folder##*/}" | sudo dd of=~/.config/gtk-3.0/bookmarks oflag=append conv=notrunc status=none
        fi
    done

    echo -e "$fstab" | sudo dd of=/etc/fstab oflag=append conv=notrunc status=none

    sudo systemctl daemon-reload
    sudo mount -a
    echo
}

install_packages()
{
    # REMOVE PYCHARM REPO
    echo "Removing PyCharm repo..."
    sudo rm /etc/yum.repos.d/_copr\:copr.fedorainfracloud.org\:phracek\:PyCharm.repo
    # RPM FUSIONS
    echo "Installing rpm fusions repo..."
    sudo dnf install -y https://download1.rpmfusion.org/free/fedora/rpmfusion-free-release-$(rpm -E %fedora).noarch.rpm
    sudo dnf install -y https://download1.rpmfusion.org/nonfree/fedora/rpmfusion-nonfree-release-$(rpm -E %fedora).noarch.rpm
    # TERRA
    echo "Installing terra repo..."
    sudo dnf install -y --nogpgcheck --repofrompath 'terra,https://repos.fyralabs.com/terra$releasever' terra-release
    # UPGRADE
    echo "Updating system and installing packages"
    sudo dnf check-update -y
    sudo dnf group upgrade -y core
    sudo dnf update -y
    sudo dnf install -y $terminal $apps $games $fonts $themes
    # FLATHUB
    echo "Configuring flathub..."
    sudo dnf install -y flatpak
    flatpak remote-add --if-not-exists flathub https://flathub.org/repo/flathub.flatpakrepo
    echo "Installing flathub packages..."
    flatpak install -y flathub com.spotify.Client
    echo
}

update_firmware()
{
    echo "Updating devices firmware..."
    sudo fwupdmgr refresh --force
    sudo fwupdmgr get-devices
    sudo fwupdmgr get-updates
    sudo fwupdmgr update
    echo
}

####################
# GNOME EXTENSIONS #
####################

install_gnome_extensions()
{
    echo "Installing gnome extensions..."
    sudo dnf install -y $gextensions
	
	cd ~
	
    install_gnome_extensions_from_zip
    install_gnome_extension_appmenu_is_back
    install_gnome_extension_clipboard
    install_gnome_extension_openbar
    install_gnome_extension_roundedwincorners
    install_gnome_extension_spacebar
    echo "Done."
}

install_gnome_extensions_from_zip()
{
    from_archive=(
    "https://gitlab.gnome.org/somepaulo/weather-or-not/-/raw/main/weatherornot@somepaulo.github.io.shell-extension.zip?ref_type=heads" # weather
    "https://github.com/sakithb/media-controls/releases/latest/download/mediacontrols@cliffniff.github.com.shell-extension.zip" # media control
    )

    for i in ${from_archive[@]}
    do
        curl -sL -o archive.zip "$i"
        gnome-extensions install archive.zip --force
        rm archive.zip
    done
}

install_gnome_extension_appmenu_is_back()
{
    git clone https://github.com/fthx/appmenu-is-back.git ~/.local/share/gnome-shell/extensions/appmenu-is-back@fthx
}

install_gnome_extension_clipboard()
{
    git clone https://github.com/Tudmotu/gnome-shell-extension-clipboard-indicator.git ~/.local/share/gnome-shell/extensions/clipboard-indicator@tudmotu.com
}

install_gnome_extension_openbar()
{
    git clone https://github.com/neuromorph/openbar.git
    mv ~/openbar/openbar@neuromorph ~/.local/share/gnome-shell/extensions/openbar@neuromorph
    rm -rf ~/openbar
}

install_gnome_extension_roundedwincorners()
{
    git clone https://github.com/flexagoon/rounded-window-corners
    cd ~/rounded-window-corners
    just install
    cd ~
    rm -rf ~/rounded-window-corners
}

install_gnome_extension_spacebar()
{
    git clone https://github.com/christopher-l/space-bar.git
    ~/space-bar/scripts/build.sh -i
    rm -rf ~/space-bar
}

###############
# END RUNNING #
###############

reboot_machine()
{
    if [[ $FEDORA_POST_INSTALL -eq 0 ]]
    then
		echo 'export FEDORA_POST_INSTALL=1' >> ~/.bashrc
	elif [[ $FEDORA_POST_INSTALL -eq 1 ]]
	then
		sed -i '$ d' ~/.bashrc
        echo 'export FEDORA_POST_INSTALL=2' >> ~/.bashrc
        if [[ $gpu == "NVIDIA" ]]
    	then
    		echo "Waiting for kernel module to be build with nvidia..."
        	while [ -z $( modinfo -F version nvidia 2> /dev/null ) ]
        	do
           		sleep 5s
			done

            drmenabled=$( sudo cat /sys/module/nvidia_drm/parameters/modeset )
            if [ $drmenabled == "N" ] ; then sudo grubby --update-kernel=ALL --args="nvidia-drm.modeset=1" ; fi
		fi
    fi
    
    start_reboot=
    echo "To insure best behaviour, your computer should restart!"
    while [ -z $start_reboot ]
    do
		clear_buffer
		read -p "Would you like to reboot now? [Y/n] " choice
		echo
		if [[ -z $choice || "Yy" =~ $choice ]]
		then
			start_reboot=1
		elif [[ "Nn" =~ $choice ]]
		then
			echo "Closing script..."
			exit 1
		fi
	done
    choice=
    
    sudo systemctl reboot
}

#############
# POST INIT #
#############

install_graphic_driver()
{
    echo "Installing graphic driver..."
    if [ $gpu == "NVIDIA" ] ; then sudo dnf install -y $nvidia_drivers ; fi
    echo
}

hardware_acceleration()
{
    echo "Configuring hardware acceleration..."

    sudo dnf install -y ffmpeg-libs libva libva-utils

    case $cpu in
        "Intel")
            sudo dnf swap -y libva-intel-media-driver intel-media-driver --allowerasing
            ;;
        "AMD")
            sudo dnf swap -y mesa-va-drivers mesa-va-drivers-freeworld
            sudo dnf swap -y mesa-vdpau-drivers mesa-vdpau-drivers-freeworld
            sudo dnf swap -y mesa-va-drivers.i686 mesa-va-drivers-freeworld.i686
            sudo dnf swap -y mesa-vdpau-drivers.i686 mesa-vdpau-drivers-freeworld.i686
            ;;
        *)
            ;;
    esac
    echo
}

update_mulimedia_codec()
{
    echo "Updating multimedia codecs..."
    sudo dnf group upgrade -y multimedia 
    sudo dnf swap -y 'ffmpeg-free' 'ffmpeg' --allowerasing
    sudo dnf upgrade -y @multimedia --setopt="install_weak_deps=False" --exclude=PackageKit-gstreamer-plugin
    sudo dnf group install -y sound-and-video
    echo
}

optimizations()
{
    echo "Launching miscellaneous optimizations..."
    sudo systemctl disable NetworkManager-wait-online.service
    sudo rm /etc/xdg/autostart/org.gnome.Software.desktop
    sudo rm -f /usr/lib64/firefox/browser/defaults/preferences/firefox-redhat-default-prefs.js
    sudo hostnamectl set-hostname "fedora"
    echo
}

get_wallpaper()
{
    sudo curl -sL -o /usr/share/backgrounds/astronaut.png https://raw.githubusercontent.com/orangci/walls/main/astronaut.png
}

set_gnome_settings()
{
    echo "Updating gnome settings..."

    weatherlocation="[<(uint32 2, <('Ottignies', '', false, [(0.88429474975634159, 0.079744969689317949)], @a(dd) [])>)>]"
    
    dconf write /org/gnome/desktop/background/picture-uri "'file:///usr/share/backgrounds/astronaut.png'"
    dconf write /org/gnome/desktop/background/picture-uri-dark "'file:///usr/share/backgrounds/astronaut.png'"
    dconf write /org/gnome/desktop/interface/accent-color "'orange'"
    dconf write /org/gnome/desktop/interface/clock-format "'24h'"
    dconf write /org/gnome/desktop/interface/clock-show-weekday true
    dconf write /org/gnome/desktop/interface/color-scheme "'prefer-dark'"
    dconf write /org/gnome/desktop/interface/gtk-theme "'Adwaita-dark'"
    dconf write /org/gnome/desktop/interface/icon-theme "'Tela'"
    dconf write /org/gnome/desktop/interface/show-battery-percentage true
    dconf write /org/gnome/desktop/peripherals/mouse/accel-profile "'flat'"
    dconf write /org/gnome/desktop/peripherals/mouse/speed 0.0
    dconf write /org/gnome/desktop/session/idle-delay "uint32 300"
    dconf write /org/gnome/desktop/wm/preferences/num-workspaces 6
    dconf write /org/gnome/desktop/wm/preferences/workspace-names "['󰥟', '', '󰿎', '󰺵', '󰑋', '']"
    dconf write /org/gnome/mutter/dynamic-workspaces false
    dconf write /org/gnome/settings-daemon/plugins/media-keys.custom-keybindings "['/org/gnome/settings-daemon/plugins/media-keys/custom-keybindings/custom0/']"
    dconf write /org/gnome/settings-daemon/plugins/media-keys/custom-keybindings/custom0/name "'Terminal'"
    dconf write /org/gnome/settings-daemon/plugins/media-keys/custom-keybindings/custom0/command "'ptyxis'"
    dconf write /org/gnome/settings-daemon/plugins/media-keys/custom-keybindings/custom0/binding "'<Ctrl><Alt>t'"
    dconf write /org/gnome/settings-daemon/plugins/power/ambient-enabled true
    dconf write /org/gnome/settings-daemon/plugins/power/power-button-action "'suspend'"
    dconf write /org/gnome/settings-daemon/plugins/power/sleep-inactive-ac-type "'nothing'"
    dconf write /org/gnome/settings-daemon/plugins/power/sleep-inactive-battery-timeout 1800
    dconf write /org/gnome/settings-daemon/plugins/power/sleep-inactive-battery-type "'suspend'"
    dconf write /org/gnome/shell/favorite-apps "['org.gnome.Ptyxis.desktop', 'org.gnome.Nautilus.desktop', 'org.mozilla.firefox.desktop', 'org.gnome.Evolution.desktop', 'org.gnome.Calendar.desktop', 'org.gnome.TextEditor.desktop', 'codium.desktop', 'org.gnome.Calculator.desktop', 'com.spotify.Client.desktop', 'steam.desktop', 'net.lutris.Lutris.desktop', 'discord.desktop', 'org.gnome.Boxes.desktop', 'org.keepassxc.KeePassXC.desktop', 'org.gnome.Software.desktop', 'org.gnome.Settings.desktop']"
    dconf write /org/gnome/shell/weather/locations "$weatherlocation"
    dconf write /org/gnome/system/locale/region "'fr_BE.UTF-8'"
    dconf write /org/gnome/Weather/locations "$weatherlocation"
    dconf write /system/locale/region "'fr_BE.UTF-8'"
}

set_gnome_settings_extensions()
{
    echo "Updating gnome extensions settings..."

    # caffeine
    dconf write /org/gnome/shell/extensions/caffeine/show-indicator "'always'"

    # weather
    dconf write /org/gnome/shell/extensions/weatherornot/position "'clock-right-centered'"

    # media control
    dconf write /org/gnome/shell/extensions/mediacontrols/show-control-icons-seek-backward false
    dconf write /org/gnome/shell/extensions/mediacontrols/show-control-icons-seek-forward false
    dconf write /org/gnome/shell/extensions/mediacontrols/show-player-icon false
    dconf write /org/gnome/shell/extensions/mediacontrols/extension-index "uint32 4"
    dconf write /org/gnome/shell/extensions/mediacontrols/labels-order "['ARTIST', '-', 'TITLE']"
    dconf write /org/gnome/shell/extensions/mediacontrols/elements-order "['ICON', 'CONTROLS', 'LABEL']"

    # pop shell
    dconf write /org/gnome/shell/extensions/pop-shell/tile-by-default false
    dconf write /org/gnome/shell/extensions/pop-shell/active-hint-border-radius "uint32 0"
    dconf write /org/gnome/shell/extensions/pop-shell/gap-outer "uint32 1"
    dconf write /org/gnome/shell/extensions/pop-shell/gap-inner "uint32 1"

    # rounder windows corners
    dconf write /org/gnome/shell/extensions/rounded-window-corners-reborn/global-rounded-corner-settings "{'padding': <{'left': uint32 1, 'right': 1, 'top': 1, 'bottom': 1}>, 'keepRoundedCorners': <{'maximized': false, 'fullscreen': false}>, 'borderRadius': <uint32 12>, 'smoothing': <0.0>, 'borderColor': <(1.0, 1.0, 1.0, 1.0)>, 'enabled': <true>}"
    dconf write /org/gnome/shell/extensions/rounded-window-corners-reborn/border-width 1
    dconf write /org/gnome/shell/extensions/rounded-window-corners-reborn/skip-libadwaita-app false
    
    # blur-my-shell
    dconf write /org/gnome/shell/extensions/blur-my-shell/panel/blur false
    dconf write /org/gnome/shell/extensions/blur-my-shell/overview/blur true
    dconf write /org/gnome/shell/extensions/blur-my-shell/appfolder/blur true
    dconf write /org/gnome/shell/extensions/blur-my-shell/dash-to-dock/blur false
    dconf write /org/gnome/shell/extensions/blur-my-shell/dash-to-dock/static-blur false
    dconf write /org/gnome/shell/extensions/blur-my-shell/dash-to-dock/sigma 25
    dconf write /org/gnome/shell/extensions/blur-my-shell/dash-to-dock/brightness 0.75
    dconf write /org/gnome/shell/extensions/blur-my-shell/dash-to-dock/override-background true
    dconf write /org/gnome/shell/extensions/blur-my-shell/dash-to-dock/style-dash-to-dock 0
    dconf write /org/gnome/shell/extensions/blur-my-shell/dash-to-dock/unblur-in-overview true
    dconf write /org/gnome/shell/extensions/blur-my-shell/applications/blur false
    dconf write /org/gnome/shell/extensions/blur-my-shell/lockscreen/blur false
    dconf write /org/gnome/shell/extensions/blur-my-shell/screenshot/blur false
    dconf write /org/gnome/shell/extensions/blur-my-shell/window-list/blur false

    # space bar
    dconf write /org/gnome/shell/extensions/space-bar/behavior/system-workspace-indicator false
    dconf write /org/gnome/shell/extensions/space-bar/behavior/position-index 0
    dconf write /org/gnome/shell/extensions/space-bar/behavior/indicator-style "'workspaces-bar'"
    dconf write /org/gnome/shell/extensions/space-bar/appearance/active-workspace-background-color "'rgb(255,255,255)'"
    dconf write /org/gnome/shell/extensions/space-bar/appearance/active-workspace-text-color "'rgb(237,91,0)'"

    # open bar
    dconf write /org/gnome/shell/extensions/openbar/bartype "'Islands'"
    dconf write /org/gnome/shell/extensions/openbar/margin 1.0
    dconf write /org/gnome/shell/extensions/openbar/wmaxbar false
    dconf write /org/gnome/shell/extensions/openbar/bwidth 1.0
    dconf write /org/gnome/shell/extensions/openbar/border-wmax true
    dconf write /org/gnome/shell/extensions/openbar/bgalpha-wmax 1.0
    dconf write /org/gnome/shell/extensions/openbar/buttonbg-wmax true
    dconf write /org/gnome/shell/extensions/openbar/font "'DroidSansM Nerd Font Mono Bold 12'"
    dconf write /org/gnome/shell/extensions/openbar/neon false
    dconf write /org/gnome/shell/extensions/openbar/bradius 8.0
    dconf write /org/gnome/shell/extensions/openbar/isalpha 1.0
    dconf write /org/gnome/shell/extensions/openbar/bgalpha 0.0
    dconf write /org/gnome/shell/extensions/openbar/boxalpha 0.0
    dconf write /org/gnome/shell/extensions/openbar/dark-mscolor "['0.929', '0.357', '0.000']"
    dconf write /org/gnome/shell/extensions/openbar/mscolor "['0.929', '0.357', '0.000']"
    dconf write /org/gnome/shell/extensions/openbar/dashdock-style "'Custom'"
    dconf write /org/gnome/shell/extensions/openbar/disize 42.0
    dconf write /org/gnome/shell/extensions/openbar/dshadow false
    dconf write /org/gnome/shell/extensions/openbar/dbradius 8.0
    dconf write /org/gnome/shell/extensions/openbar/dbgalpha 0.60

    # dash-to-dock
    dconf write /org/gnome/shell/extensions/dash-to-dock/dash-max-icon-size 42
    dconf write /org/gnome/shell/extensions/dash-to-dock/custom-theme-shrink true
    dconf write /org/gnome/shell/extensions/dash-to-dock/transparency-mode "'DEFAULT'"
    dconf write /org/gnome/shell/extensions/dash-to-dock/hot-keys false
    dconf write /org/gnome/shell/extensions/dash-to-dock/disable-overview-on-startup true
    dconf write /org/gnome/shell/extensions/dash-to-dock/show-apps-at-top true
    dconf write /org/gnome/shell/extensions/dash-to-dock/show-mounts-network true
    dconf write /org/gnome/shell/extensions/dash-to-dock/isolate-locations false

    echo
}

enable_gnome_extensions()
{
    echo "Enabling gnome extensions..."
    extensions=(
        "appindicatorsupport@rgcjonas.gmail.com"
        "caffeine@patapon.info"
        "clipboard-indicator@tudmotu.com"
        "drive-menu@gnome-shell-extensions.gcampax.github.com"
        "gsconnect@andyholmes.github.io"
        "mediacontrols@cliffniff.github.com"
        "pop-shell@system76.com"
        "rounded-window-corners@fxgn"
        "weatherornot@somepaulo.github.io"
        "wireless-hid@chlumskyvaclav.gmail.com"
        "appmenu-is-back@fthx"
        "blur-my-shell@aunetx"
        "space-bar@luchrioh"
        "openbar@neuromorph"
        "dash-to-dock@micxgx.gmail.com"
    )
    for i in ${extensions[@]}
    do
        echo "Enabling $i..."
        gnome-extensions enable $i
        sleep 1s
    done
    echo
}

#####################
# START SCRIPT HERE #
#####################
if [ -z $FEDORA_POST_INSTALL ] ; then FEDORA_POST_INSTALL=0 ; fi
main_menu
