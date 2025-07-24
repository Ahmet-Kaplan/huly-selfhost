#!/bin/bash

HULY_VERSION="v0.6.501"
DOCKER_NAME="huly"
CONFIG_FILE="huly.conf"
ENV_FILE=".env"

# Parse command line arguments
RESET_VOLUMES=false
SECRET=false

for arg in "$@"; do
    case $arg in
        --secret)
            SECRET=true
            ;;
        --reset-volumes)
            RESET_VOLUMES=true
            ;;
        --help)
            echo "Usage: $0 [OPTIONS]"
            echo "Options:"
            echo "  --secret         Generate a new secret key"
            echo "  --reset-volumes  Reset all volume paths to default Docker named volumes"
            echo "  --help           Show this help message"
            exit 0
            ;;
        *)
            echo "Unknown option: $arg"
            echo "Use --help for usage information"
            exit 1
            ;;
    esac
done

if [ "$RESET_VOLUMES" == true ]; then
    echo -e "\033[33m--reset-volumes flag detected: Resetting all volume paths to default Docker named volumes.\033[0m"
    sed -i \
        -e '/^VOLUME_DB_PATH=/s|=.*|=|' \
        -e '/^VOLUME_ELASTIC_PATH=/s|=.*|=|' \
        -e '/^VOLUME_FILES_PATH=/s|=.*|=|' \
        "$CONFIG_FILE"
    exit 0
fi

if [ -f "$CONFIG_FILE" ]; then
    source "$CONFIG_FILE"
fi

# Volume path configuration
echo -e "\n\033[1;34mDocker Volume Configuration:\033[0m"

    echo "You can specify custom paths for persistent data storage, or leave empty to use default Docker named volumes."
    echo -e "\033[33mTip: To revert from custom paths to default volumes, enter 'default' or just press Enter when prompted.\033[0m"

    # Database volume configuration
    if [[ -n "$VOLUME_DB_PATH" ]]; then
        current_db="custom: $VOLUME_DB_PATH"
    else
        current_db="default Docker volume"
    fi
    read -p "Enter custom path for database volume [current: ${current_db}]: " input
    if [[ "$input" == "default" ]]; then
        _VOLUME_DB_PATH=""
    else
        _VOLUME_DB_PATH="${input:-${VOLUME_DB_PATH}}"
    fi

    # Elasticsearch volume configuration
    if [[ -n "$VOLUME_ELASTIC_PATH" ]]; then
        current_elastic="custom: $VOLUME_ELASTIC_PATH"
    else
        current_elastic="default Docker volume"
    fi
    read -p "Enter custom path for Elasticsearch volume [current: ${current_elastic}]: " input
    if [[ "$input" == "default" ]]; then
        _VOLUME_ELASTIC_PATH=""
    else
        _VOLUME_ELASTIC_PATH="${input:-${VOLUME_ELASTIC_PATH}}"
    fi

    # Files volume configuration
    if [[ -n "$VOLUME_FILES_PATH" ]]; then
        current_files="custom: $VOLUME_FILES_PATH"
    else
        current_files="default Docker volume"
    fi
    read -p "Enter custom path for files volume [current: ${current_files}]: " input
    if [[ "$input" == "default" ]]; then
        _VOLUME_FILES_PATH=""
    else
        _VOLUME_FILES_PATH="${input:-${VOLUME_FILES_PATH}}"
    fi

if [ ! -f .huly.secret ] || [ "$SECRET" == true ]; then
  openssl rand -hex 32 > .huly.secret
  echo "Secret generated and stored in .huly.secret"
else
  echo -e "\033[33m.huly.secret already exists, not overwriting."
  echo "Run this script with --secret to generate a new secret."
fi

# Ask for the domain name
read -p "Enter the domain name: " DOMAIN_NAME
if [ -z "$DOMAIN_NAME" ]; then
  echo "DOMAIN_NAME is required"
  exit 1
fi

# Ask for the email address
read -p "Enter the email address: " LETSENCRYPT_EMAIL
if [ -z "$LETSENCRYPT_EMAIL" ]; then
  echo "LETSENCRYPT_EMAIL address is required"
  exit 1
fi

# Write configuration to .env file
cat > "$ENV_FILE" << EOF
HULY_VERSION="v0.6.501"
HULY_SECRET="secret"
SERVER_ADDRESS=$DOMAIN_NAME
LETSENCRYPT_EMAIL=$LETSENCRYPT_EMAIL
EOF

echo "Configuration written to $ENV_FILE"

# Export variables for envsubst to work with template generation
export HULY_VERSION="v0.6.501"
export HULY_SECRET="secret"
export SERVER_ADDRESS=$DOMAIN_NAME
export LETSENCRYPT_EMAIL=$LETSENCRYPT_EMAIL

# replace the domain name and email address in the docker-compose file
envsubst < template-compose.yaml > docker-compose.yaml

echo -e "\033[1;32mSetup is complete. Run 'docker compose up -d' to start the services.\033[0m"
