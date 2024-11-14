#!/bin/bash

# Function to create a horizontal line
create_line() {
    local width=$1
    printf '%*s\n' "$width" '' | tr ' ' '-'
}

# Function to create table header
create_header() {
    local width=$1
    local text=$2
    local padding=$(( (width - ${#text}) / 2 ))
    printf '\n%*s%s%*s\n' $padding '' "$text" $padding ''
    create_line "$width"
}

# Get all namespaces excluding those that start with numbers
NAMESPACES=$(kubectl get namespaces -o jsonpath='{.items[*].metadata.name}' | tr ' ' '\n' | grep -v '^[0-9]')

# Set table width
TABLE_WIDTH=100

# Print main header
create_header $TABLE_WIDTH "KUBERNETES CLUSTER HEALTH CHECK REPORT"

# Iterate through each namespace
for ns in $NAMESPACES; do
    # Print namespace header
    create_header $TABLE_WIDTH "NAMESPACE: $ns"
    
    # Helm Releases Section
    echo -e "\n📦 HELM RELEASES"
    printf "%-30s %-30s %-30s\n" "RELEASE NAME" "CHART" "VERSION"
    create_line $TABLE_WIDTH
    
    releases=$(helm list -n "$ns" -q)
    if [ ! -z "$releases" ]; then
        while read -r release; do
            if [ ! -z "$release" ]; then
                helm_info=$(helm list -n "$ns" | grep "^${release}")
                chart_name=$(echo "$helm_info" | awk '{print $8}')
                chart_version=$(echo "$helm_info" | awk '{print $9}')
                printf "%-30s %-30s %-30s\n" "$release" "$chart_name" "$chart_version"
            fi
        done <<< "$releases"
    else
        printf "%-30s\n" "No Helm releases found"
    fi

    # Pod Health Section
    echo -e "\n🔍 POD HEALTH STATUS"
    printf "%-40s %-20s %-30s\n" "POD NAME" "STATUS" "REASON"
    create_line $TABLE_WIDTH
    
    unhealthy_pods=$(kubectl get pods -n "$ns" -o json | jq -r '.items[] | 
        select(.status.phase != "Running" or 
        (.status.containerStatuses != null and 
        (.status.containerStatuses[] | 
        select(.ready == false or .state.waiting != null or .state.terminated != null)))) | 
        "\(.metadata.name)|\(.status.phase)|\(.status.containerStatuses[]?.state.waiting.reason // .status.containerStatuses[]?.state.terminated.reason // "Not Ready")"')
    
    if [ ! -z "$unhealthy_pods" ]; then
        while IFS='|' read -r pod_name pod_status pod_reason; do
            printf "%-40s %-20s %-30s\n" "$pod_name" "$pod_status" "$pod_reason"
        done <<< "$unhealthy_pods"
    else
        printf "%-40s\n" "✅ All pods are healthy"
    fi
    
    # Add spacing between namespaces
    echo -e "\n"
done

# Print footer
create_line $TABLE_WIDTH
echo "Report generated on $(date)"
create_line $TABLE_WIDTH