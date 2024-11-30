#!/bin/bash

loading_step() {
    echo "Mengunduh dan menjalankan skrip display..."
    curl -s https://raw.githubusercontent.com/Wawanahayy/JawaPride-all.sh/refs/heads/main/display.sh | bash
    echo
}

# Function to update system and install dependencies
update_system() {
    echo "Updating system..."
    sudo apt update && sudo apt upgrade -y

    dependencies=("curl" "jq")
    for dependency in "${dependencies[@]}"; do
        if ! dpkg -l | grep -q "$dependency"; then
            echo "$dependency is not installed. Installing..."
            sudo apt install "$dependency" -y
        else
            echo "$dependency is already installed."
        fi
    done
}

# Function to handle user login and store token
login_user() {
    echo "Please enter your email:"
    read -r email

    echo "Please enter your password:"
    read -s password

    response=$(curl -s -X POST "https://pipe-network-backend.pipecanary.workers.dev/api/login" \
        -H "Content-Type: application/json" \
        -d "{\"email\":\"$email\", \"password\":\"$password\"}")

    echo "Login response: $response"
    echo "$(echo $response | jq -r .token)" > token.txt
}

# Function to fetch the public IP address
fetch_ip_address() {
    ip_response=$(curl -s "https://api64.ipify.org?format=json")
    echo "$(echo $ip_response | jq -r .ip)"
}

# Function to fetch geolocation of IP
fetch_geo_location() {
    ip=$1
    geo_response=$(curl -s "https://ipapi.co/${ip}/json/")
    echo "$geo_response"
}

# Function to send heartbeat to server
send_heartbeat() {
    token=$(cat token.txt)
    username="your_username"
    ip=$(fetch_ip_address)
    geo_info=$(fetch_geo_location "$ip")

    heartbeat_data=$(jq -n --arg username "$username" --arg ip "$ip" --argjson geo_info "$geo_info" '{username: $username, ip: $ip, geo: $geo_info}')
    heartbeat_response=$(curl -s -X POST "https://pipe-network-backend.pipecanary.workers.dev/api/heartbeat" \
        -H "Authorization: Bearer $token" \
        -H "Content-Type: application/json" \
        -d "$heartbeat_data")

    echo "Heartbeat response: $heartbeat_response" >> node_operations.log
}

# Function to fetch user points
fetch_points() {
    token=$(cat token.txt)
    points_response=$(curl -s -X GET "https://pipe-network-backend.pipecanary.workers.dev/api/points" \
        -H "Authorization: Bearer $token")

    if echo "$points_response" | jq -e . >/dev/null 2>&1; then
        echo "User Points Response: $points_response" >> node_operations.log
    else
        echo "Error fetching points: $points_response" >> node_operations.log
    fi
}

# Function to test node latency and report results
test_nodes() {
    token=$(cat token.txt)
    nodes_response=$(curl -s -X GET "https://pipe-network-backend.pipecanary.workers.dev/api/nodes" \
        -H "Authorization: Bearer $token")

    if [ -z "$nodes_response" ]; then
        echo "Error: No nodes found or failed to fetch nodes." >> node_operations.log
        return
    fi

    for node in $(echo "$nodes_response" | jq -c '.[]'); do
        node_id=$(echo "$node" | jq -r .node_id)
        node_ip=$(echo "$node" | jq -r .ip)

        latency=$(test_node_latency "$node_ip")

        if [[ "$latency" =~ ^[0-9]+(\.[0-9]+)?$ ]]; then
            echo "Node ID: $node_id, IP: $node_ip, Latency: ${latency}ms" >> node_operations.log
        else
            echo "Node ID: $node_id, IP: $node_ip, Latency: Timeout/Error" >> node_operations.log
        fi

        report_test_result "$node_id" "$node_ip" "$latency"
    done
}

# Function to test node latency
test_node_latency() {
    node_ip=$1
    start=$(date +%s%3N)

    latency=$(curl -o /dev/null -s -w "%{time_total}\n" "http://$node_ip")

    if [ -z "$latency" ]; then
        return -1
    else
        echo $latency
    fi
}

# Function to report the node test result
report_test_result() {
    node_id=$1
    node_ip=$2
    latency=$3

    token=$(cat token.txt)

    if [ -z "$token" ]; then
        echo "Error: No token found. Skipping result reporting." >> node_operations.log
        return
    fi

    if [[ "$latency" =~ ^[0-9]+(\.[0-9]+)?$ ]] && (( $(echo "$latency > 0" | bc -l) )); then
        status="online"
    else
        status="offline"
        latency=-1
    fi

    report_response=$(curl -s -X POST "https://pipe-network-backend.pipecanary.workers.dev/api/test" \
        -H "Authorization: Bearer $token" \
        -H "Content-Type : application/json" \
        -d "{\"node_id\": \"$node_id\", \"ip\": \"$node_ip\", \"latency\": $latency, \"status\": \"$status\"}")

    if echo "$report_response" | jq -e . >/dev/null 2>&1; then
        echo "Reported result for node $node_id ($node_ip), status: $status" >> node_operations.log
    else
        echo "Failed to report result for node $node_id ($node_ip)." >> node_operations.log
    fi
}

# Main loop to run the operations every 5 minutes
while true; do
    fetch_points
    test_nodes
    send_heartbeat
    fetch_points
    sleep 300
done
