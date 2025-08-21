#!/bin/bash

# Pizzaria Auto-Deploy Script
# This script installs required packages, clones/pulls the latest code,
# and deploys the pizzaria application using Docker Compose

REPO_URL="https://github.com/Fcondera/docker-file.git"
APP_DIR="/opt/proway-pizzaria"
LOG_FILE="/var/log/pizzaria-deploy.log"
CRON_JOB="*/5 * * * * root /opt/proway-pizzaria/deploy.sh"

# Function for logging
log() {
echo "$(date '+%Y-%m-%d %H:%M:%S') - $1" | tee -a $LOG_FILE
}

# Check if running as root
if [ "$EUID" -ne 0 ]; then
echo "Please run as root"
exit 1
fi

# Install required packages
install_dependencies() {
log "Installing dependencies..."
apt-get update >> $LOG_FILE 2>&1
apt-get install -y docker.io docker-compose git >> $LOG_FILE 2>&1

# Start and enable docker service
systemctl start docker >> $LOG_FILE 2>&1
systemctl enable docker >> $LOG_FILE 2>&1
}

# Clone or update repository
update_repository() {
if [ ! -d "$APP_DIR" ]; then
log "Cloning repository..."
git clone $REPO_URL $APP_DIR >> $LOG_FILE 2>&1
else
log "Pulling latest changes..."
cd $APP_DIR
git fetch origin >> $LOG_FILE 2>&1

# Check if there are changes
LOCAL=$(git rev-parse @)
REMOTE=$(git rev-parse @{u})

if [ $LOCAL = $REMOTE ]; then
log "No changes detected."
return 1
else
log "Changes detected, pulling updates..."
git pull origin main >> $LOG_FILE 2>&1
return 0
fi
fi
}

# Build and deploy with Docker Compose
deploy_application() {
log "Building and deploying application..."
cd $APP_DIR

# Rebuild images and deploy
docker-compose down >> $LOG_FILE 2>&1
docker-compose build --no-cache >> $LOG_FILE 2>&1
docker-compose up -d >> $LOG_FILE 2>&1

log "Application deployed successfully!"
}

# Install cron job for auto-updates
install_cron() {
if [ ! -f /etc/cron.d/pizzaria-deploy ]; then
log "Installing cron job..."
echo "$CRON_JOB" > /etc/cron.d/pizzaria-deploy
chmod 644 /etc/cron.d/pizzaria-deploy
fi
}

# Main execution
main() {
log "Starting deployment process..."

# Install dependencies if not already installed
if ! command -v docker &> /dev/null; then
install_dependencies
fi

# Update repository and check for changes
if update_repository; then
# Only deploy if changes were detected
deploy_application
fi

# Ensure cron job is installed
install_cron

log "Deployment process completed."
}

# Execute main function
main "$@"
