#!/bin/bash

# Save game path
SAVE=${SAVE:="./save.zip"}
#
EXTRACT_DIR=${EXTRACT_DIR:="./factorio"}
# Server files will be downloaded to thus directory. Warning: must not be named "factorio"
SERVER_DIR=${SERVER_DIR:="./current"}
# Directory with files that are overlayed after each updated
OVERLAY_DIR=${OVERLAY_DIR:="./overlay"}
# Game binary within server directory
BINARY=${BINARY:="./bin/x64/factorio"}
# 
DOWNLOAD_URI=${DOWNLOAD_URI:="https://www.factorio.com/get-download/stable/headless/linux64"}


binary_path="$SERVER_DIR/$BINARY"

# Configuration sanity logs
echo "Current working directory is $(pwd)"
echo "map-gen-settings path is ${MAP_GEN_CFG:-"unspecified"}"
echo "map-settings path path is ${MAP_CFG:-"unspecified"}"
echo "server-settings path path is ${SERVER_CFG:-"unspecified"}"


echo "Binary path is $binary_path"

function download {
    download_file=$(get_update_version)

    # Download file from Factorio website
    if ! curl -o $download_file -J -L $DOWNLOAD_URI; then
        echo "Failed to download file"
        return 1
    fi

    echo "File downloaded successfuly"

    # Check archive integrity
    if ! tar -xf $download_file -O > /dev/null; then
        echo "Downloaded archive integrity check failed"
        return 1
    fi

    echo "Archive integrity is OK"

    # Extract archive
    if ! tar -xf $download_file; then
        echo "Archive extraction failed"
        return 0
    fi
}

function update {
    rm -rf $SERVER_DIR
    cp -a $EXTRACT_DIR $SERVER_DIR
    cp -af $OVERLAY_DIR $SERVER_DIR
    rm -rf $EXTRACT_DIR
}

function get_update_version {
    # Aquire link after redirect
    uri=$(curl -w "%{url_effective}\n" -I -L -s -S $DOWNLOAD_URI -o /dev/null)

    # Cut off parameters
    base_uri=$(echo $uri | cut -f1 -d"?")

    # Get just the file name
    echo ${base_uri##*/}
}

function check_update {
    download_file=$(get_update_version)

    if [ -f $download_file ]; then
        return 1
    else
        return 0
    fi
}

# Updates server script if needed
function script_update {
    server_buf=$(<server.sh)
    install_buf=$(<install.sh)
    
    git pull
    
    server_updated_buf=$(<server.sh)
    install_updated_buf=$(<install.sh)
    
    # Comparing difference after repo update
    if [ "$install_buf" != "$install_updated_buf" ]; then
        echo "Install script has changed"
        # Running install
        bash ./install.sh
        # Exiting script so it will be reloaded by systemd automatically
        exit 0
    fi
    
    if [ "$server_buf" != "$server_updated_buf" ]; then
        echo "Server script has changed"
        # Exiting script so it will be reloaded by systemd automatically
        exit 0
    fi
    
    echo "No updates"
}

function get_server_command {
    action=${1:-"start-server"}
    path="$binary_path --$action $SAVE"

    # TODO: remove
    if [ -n "$SERVER_CFG" ]; then
        path+=" --server-settings=$SERVER_CFG"
    fi

    if [ -n "$MAP_GEN_CFG" ]; then
        path+=" --map-gen-settings=$MAP_GEN_CFG"
    fi

    if [ -n "$MAP_CFG" ]; then
        path+=" --map-settings=$MAP_CFG"
    fi

    echo $path
}

while true
do
    echo "Loop"

    if [ -d ".git" ]; then
        script_update
    else
        echo "Git repository not found. Script auto-updates will not be available"
    fi

    # If updates are available or server files are not installed
    if [ ! -f $binary_path ] || check_update; then
        echo "$binary_path does not exist or updates are available"

        # Download the new version first
        download

         # If server is running
        if [ -n "$server_pid" ]; then
            echo "Server is running, stopping the server"
            # Stop the server
            kill $server_pid
        fi

        # Update server files
        update
    fi

    # Check if save file exists
    if [ ! -f $SAVE ]; then
        echo "Save file $SAVE does not exist. Creating"
        $(get_server_command create)
    fi

    # Checks if server is running
    if [ -z "$server_pid" ] || ! ps -p $server_pid &> /dev/null; then
        command=$(get_server_command)
        echo "Starting server with command $command"

        # Starts the server
        $(get_server_command) 2>&1 >/dev/null &
        server_pid=$!

        echo "Server started with PID of $server_pid"
    fi

    sleep 5
done
