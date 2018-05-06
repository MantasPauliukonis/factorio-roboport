USER=${USER:="factorio"}
REPO_URI=${REPO_URI:="factorio"}
SERVER_DIR=${SERVER_DIR:="server"}
SERVICE_NAME=${SERVICE_NAME:="factorio-server"}
SYSTEMD_DIR=${SYSTEMD_DIR:="/etc/systemd/system"}

# Create a dedicated factorio user

if id -u $USER; then
    echo "User $USER already exists"
else
    echo "Creating $USER user"
    sudo useradd -m $USER
fi

cd ~$USER
# Clone script into users' directory
sudo -u $USER git clone $REPO_URI $SERVER_DIR

# Install and enable systemd script
cd $SERVER_DIR

if [ ! -d "$SYSTEMD_DIR" ]; then
    echo "Systemd directory not found"
    exit 1
fi

service_file="$SYSTEMD_DIR/$SERVICE_NAME.service"

if [ -f "$service_file" ]; then
    echo "Service file ${service_file} already exists. Please use a different name"
    exit 1
fi

sudo cp systemd.service $service_file

sudo systemctl daemon-reload
sudo systemctl enable $SERVICE_NAME
sudo systemctl start $SERVICE_NAME