# Read .env file
export $(egrep -v '^#' .env | xargs)

if [ ! -f ".env" ]; then
    # Copy example env file
    cp .env.example .env
    echo "Edit .env file to customize defaults and run this script again"
    exit 0
fi

# Create overlay directory if does not exist
mkdir -p $OVERLAY_DIR

# Create a dedicated factorio user

if id -u $SERVER_USER; then
    echo "User $SERVER_USER already exists"
else
    echo "Creating $SERVER_USER user"
    sudo useradd -m $SERVER_USER
fi

cd ~$SERVER_USER
# Clone script into users' directory
sudo -u $SERVER_USER git clone $REPO_URI $SERVER_DIR

# Install and enable systemd script
cd $SERVER_DIR

if [ ! -d "$SYSTEMD_DIR" ]; then
    echo "Systemd directory not found"
    exit 1
fi

service_file="$SYSTEMD_DIR/$SERVICE_NAME.service"

echo "[Unit]
Description=FactorioServer

[Service]
WorkingDirectory=/home/${SERVER_USER}/server
ExecStart=/home/${SERVER_USER}/server/server.sh
Restart=always
# Restart service after 10 seconds if service crashes
RestartSec=10
# Output to syslog
StandardOutput=syslog
# Output to syslog
StandardError=syslog
SyslogIdentifier=${SERVICE_NAME}
User=${SERVER_USER}

[Install]
WantedBy=multi-user.target" > $service_file

sudo systemctl daemon-reload
sudo systemctl enable $SERVICE_NAME
sudo systemctl start $SERVICE_NAME
