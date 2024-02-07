#! /bin/bash

set -e

# ********************
# Command-line arguments
# ********************

# Check if GETH_NAME and genesis file path are provided as arguments
if [ -z "$1" ] || [ -z "$2" ] || [ -z "$3" ] || [ -z "$3" ]; then
  echo "Usage: $0 <GETH_NAME> <CHAIN_ID> <PORT> <GETH_BINARY_PATH>"
  exit 1
fi

# Command-line arguments
GETH_NAME=$1
CHAIN_ID=$2
PORT=$3
GETH_BINARY=$4

# ********************
# Settings
# ********************

WS_PORT=$((PORT + 1))

GETH_BASE_DATA_DIR="${HOME}/.ethereum"
GETH_DATA_DIR="${GETH_BASE_DATA_DIR}/${GETH_NAME}-data"
GENESIS_FILE_PATH="${GETH_DATA_DIR}/genesis.json"

# ********************
# echo all the variables
# ********************

echo "GETH_NAME: $GETH_NAME"
echo "CHAIN_ID: $CHAIN_ID"
echo "PORT: $PORT"
echo "WS_PORT: $WS_PORT"

echo "GETH_BASE_DATA_DIR: $GETH_BASE_DATA_DIR"
echo "GETH_DATA_DIR: $GETH_DATA_DIR"
echo "GENESIS_FILE_PATH: $GENESIS_FILE_PATH"

# ********************
# Setup
# ********************

echo "Setting up Geth data directory to ${GETH_DATA_DIR}"
mkdir -p ${GETH_DATA_DIR}

# ********************
# Account Setup
# ********************

# Get the list of existing accounts
EXISTING_ACCOUNTS=$(geth --datadir $GETH_DATA_DIR account list | cut -d ' ' -f 3)

# Check if any account exists
if [ -z "$EXISTING_ACCOUNTS" ]; then
    echo "No existing account found. Creating a new one..."
    # Create a new account securely without echoing the password
    echo "Please enter a new password for the account creation:"
    read -s -p "Password: " ACCOUNT_PASSWORD
    echo # Move to a new line

    # Save password to a temporary file securely
    PASSWORD_FILE=$(mktemp)
    echo "$ACCOUNT_PASSWORD" > "$PASSWORD_FILE"

    NEW_ACCOUNT_OUTPUT=$(geth --datadir $GETH_DATA_DIR account new --password $PASSWORD_FILE 2>&1)

    # Parse the public address from the output
    PUBLIC_ADDRESS=$(echo "$NEW_ACCOUNT_OUTPUT" | grep "Public address of the key:" | awk '{print $NF}' | sed 's/^0x//')

    echo "New account created with address: $PUBLIC_ADDRESS"
else
    echo "An existing account was found. Using the first one found..."
    # Use the first account from the list
    PUBLIC_ADDRESS=$(echo "$EXISTING_ACCOUNTS" | head -n 1 | sed 's/[\{\}]//g; s/^0x//')
    echo "Using existing account: $PUBLIC_ADDRESS"
fi

# Confirm the public address to be used
echo "Public address set to: $PUBLIC_ADDRESS"
sleep 2
# ********************
# Generate genesis file
# ********************

# check if the genesis file already exists

if [ ! -f "$GENESIS_FILE_PATH" ]; then
    echo "Genesis file does not exist. Creating..."
    # Use the correct variable substitution syntax in the heredoc
    cat <<EOL > "${GENESIS_FILE_PATH}"
    {
      "config": {
        "chainId": ${CHAIN_ID},
        "homesteadBlock": 0,
        "eip150Block": 0,
        "eip155Block": 0,
        "eip158Block": 0,
        "byzantiumBlock": 0,
        "constantinopleBlock": 0,
        "petersburgBlock": 0,
        "istanbulBlock": 0,
        "muirGlacierBlock": 0,
        "berlinBlock": 0,
        "londonBlock": 0,
        "arrowGlacierBlock": 0,
        "grayGlacierBlock": 0,
        "clique": {
          "period": 5,
          "epoch": 30000
        }
      },
      "difficulty": "1",
      "gasLimit": "0x2fefdfff",
      "extradata": "0x0000000000000000000000000000000000000000000000000000000000000000${PUBLIC_ADDRESS}0000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000",
      "alloc": {
        "0x${PUBLIC_ADDRESS}": { "balance": "90000000000000000000" },
        "0xE5a9bD0fB9b24a4920301DD08815e35677111706": {"balance":"90000000000000000000"},
        "0xF6eD51E028DA056979d401565e9F9Ff6d1C49115": {"balance":"90000000000000000000"}

      }
    }
EOL
    echo "Genesis file created at ${GENESIS_FILE_PATH}"
    # Display the content of the genesis file
    cat "${GENESIS_FILE_PATH}"

    echo "Initializing Geth with the genesis file..."
    # Directly use the geth command with correct syntax
    geth init --datadir ${GETH_DATA_DIR} ${GENESIS_FILE_PATH}
fi

# ********************
# Start Geth
# ********************

echo "Starting Geth"

$GETH_BINARY --datadir "${GETH_DATA_DIR}" \
     --keystore "${GETH_DATA_DIR}/keystore" \
     --networkid ${CHAIN_ID} \
     --http \
     --http.addr=0.0.0.0 \
     --http.vhosts="*" \
     --http.corsdomain="*" \
     --http.port $PORT \
     --http.api=web3,debug,eth,txpool,net,engine,personal \
     --ws \
     --ws.addr=0.0.0.0 \
     --networkid=100 \
     --rpc.gascap=9900000000000 \
     --ws.port $WS_PORT \
     --ws.origins="*" \
     --ws.api=debug,eth,txpool,net,engine,web3,personal \
     --mine \
     --miner.etherbase "0x${PUBLIC_ADDRESS}" \
     --networkid=100 \
     --allow-insecure-unlock \
     --unlock "0x${PUBLIC_ADDRESS}"
