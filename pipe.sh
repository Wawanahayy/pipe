#!/bin/bash

import requests
import os

def loading_step():
    print("Mengunduh dan menjalankan skrip display...")
    

    url = "https://raw.githubusercontent.com/Wawanahayy/JawaPride-all.sh/refs/heads/main/display.sh"
    try:
        response = requests.get(url)
        response.raise_for_status()  
        script_content = response.text
        
        # Menyimpan skrip yang diunduh ke file sementara
        with open("display.sh", "w") as file:
            file.write(script_content)
        
   
        os.system("bash display.sh")
        
    except requests.exceptions.RequestException as e:
        print(f"Error saat mengunduh skrip: {e}")


loading_step()

glowing_text() {
    echo -e "\033[1;37m$logo\033[0m"
    sleep 0.5
}

perspective_shift() {
    echo -e "\033[1;37m$logo\033[0m"
    sleep 0.5
}

color_gradient() {
    echo -e "\033[1;37m$logo\033[0m"
    sleep 0.5
}


random_line_move() {
    echo -e "\033[1;37m$logo\033[0m"
    sleep 0.5
}

pixelated_glitch() {
    echo -e "\033[1;37m$logo\033[0m"
    sleep 0.5
}

machine_sounds() {
    for i in {1..3}; do
        echo -e "\a"
        sleep 0.3
        echo -e "\033[1;32m*Whirr* \033[0m"
        sleep 0.5
    done
}

progress_bar() {
    echo -e "Loading... \033[1;34m[##########]\033[0m"
    sleep 0.5
}

clear
glowing_text
perspective_shift
color_gradient
typewriter_effect
random_line_move
pixelated_glitch
machine_sounds
progress_bar

clear

# Update dan upgrade sistem
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

echo "Please enter your email:"
read -r email

echo "Please enter your password:"
read -s password

response=$(curl -s -X POST "https://pipe-network-backend.pipecanary.workers.dev/api/login" \
    -H "Content-Type: application/json" \
    -d "{\"email\":\"$email\", \"password\":\"$password\"}")

echo "Login response: $response"
echo "$(echo $response | jq -r .token)" > token.txt

log_file="node_operations.log"

fetch_ip_address() {
    ip_response=$(curl -s "https://api64.ipify.org?format=json")
    echo "$(echo $ip_response | jq -r .ip)"
}

fetch_geo_location() {
    ip=$1
    geo_response=$(curl -s "https://ipapi.co/${ip}/json/")
    echo "$geo_response"
}

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

    echo "Heartbeat response: $heartbeat_response" | tee -a "$log_file"
}

fetch_points() {
    token=$(cat token.txt)
    points_response=$(curl -s -X GET "https://pipe-network-backend.pipecanary.workers.dev/api/points" \
        -H "Authorization: Bearer $token")

    if echo "$points_response" | jq -e . >/dev/null 2>&1; then
        echo "User Points Response: $points_response" | tee -a "$log_file"
    else
        echo "Error fetching points: $points_response" | tee -a "$log_file"
    fi
}

test_nodes() {
    token=$(cat token.txt)
    nodes_response=$(curl -s -X GET "https://pipe-network-backend.pipecanary.workers.dev/api/nodes" \
        -H "Authorization: Bearer $token")

    if [ -z "$nodes_response" ]; then
        echo "Error: No nodes found or failed to fetch nodes." | tee -a "$log_file"
        return
    fi

    for node in $(echo "$nodes_response" | jq -c '.[]'); do
        node_id=$(echo "$node" | jq -r .node_id)
        node_ip=$(echo "$node" | jq -r .ip)

        latency=$(test_node_latency "$node_ip")

        if [[ "$latency" =~ ^[0-9]+(\.[0-9]+)?$ ]]; then
            echo "Node ID: $node_id, IP: $node_ip, Latency: ${latency}ms" | tee -a "$log_file"
        else
            echo "Node ID: $node_id, IP: $node_ip, Latency: Timeout/Error" | tee -a "$log_file"
        fi

        report_test_result "$node_id" "$node_ip" "$latency"
    done
}

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

report_test_result() {
    node_id=$1
    node_ip=$2
    latency=$3

    token=$(cat token.txt)

    if [ -z "$token" ]; then
        echo "Error: No token found. Skipping result reporting." | tee -a "$log_file"
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
        -H "Content-Type: application/json" \
        -d "{\"node_id\": \"$node_id\", \"ip\": \"$node_ip\", \"latency\": $latency, \"status\": \"$status\"}")

    if echo "$report_response" | jq -e . >/dev/null 2>&1; then
        echo "Reported result for node $node_id ($node_ip), status: $status" | tee -a "$log_file"
    else
        echo "Failed to report result for node $node_id ($node_ip)." | tee -a "$log_file"
    fi
}

while true; do
    fetch_points
    test_nodes
    send_heartbeat
    fetch_points
    sleep 300
done
