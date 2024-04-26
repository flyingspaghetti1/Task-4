#!/bin/bash

LOG_TAG="up"
LOCK_FILE="/tmp/up_script.lock"

log() {
    logger -t "$LOG_TAG" "$1"
}

check_network_connectivity() {
    local count=0
    local timeout=15 
    local checks=3  
    log "Checking network connectivity..."
    while [ $count -lt $checks ]; do
        if ping -c 1 google.com &> /dev/null; then
            echo "Network is up."
            log "Network is up."
            return 0
        else
            log "Network is down."
            ((count++))
            sleep 5
        fi
    done

    log "No network connectivity after $((checks * 5)) seconds."
    log "No network connectivity. Update cancelled."
    exit 1
}

check_for_running_instances() {
    if [ -f "$LOCK_FILE" ]; then
        log "Another instance of the script is already running."
        exit 1
    fi
}

create_lock_file() {
    touch "$LOCK_FILE"
}

remove_lock_file() {
    rm -f "$LOCK_FILE"
}

trap 'remove_lock_file' EXIT

password="passfile"

update_system() {
    log "Updating package lists..."
    sudo -S apt update < "$password" -y
    log "exit code $?"

    log "Upgrading installed packages..."
    sudo -S apt upgrade < "$password" -y
    log "exit code $?"

    log "Cleaning up..."
    sudo -S apt autoremove < "$password" -y
    log "exit code $?"
}

update_git_mirror() {
    local mirror_repo="$1"
    local local_mirror="$2"

    if [ ! -d "$local_mirror" ]; then
        log "Cloning repository..."
        if git clone --mirror "$mirror_repo" "$local_mirror"; then
            log "Mirror created successfully."
        else
            log "Failed to create mirror '$local_mirror'. Exiting."
            return 
        fi
    fi

    cd "$local_mirror" || return 1 

    log "Fetching latest changes for mirror..."
    if git fetch --all --prune; then
        log "Mirror '$local_mirror' updated successfully."
    else
        log "Failed to update mirror '$local_mirror'. Continuing..."
    fi 
}

#MAIN

log "Script started."

check_for_running_instances
create_lock_file
check_network_connectivity
update_system
update_git_mirror "https://github.com/torvalds/linux" "linux"
update_git_mirror "https://github.com/bminor/glibc" "glibc"

log "System update complete!"
log "Script ended."


