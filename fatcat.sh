#!/bin/bash

# Usage: 
# 1. Login to OpenShift before running this script.
# 2. Make sure you have cluster-monitoring-view or higer permission.

#!/bin/bash

set -euo pipefail

# Configuration
readonly PROMETHEUS_SERVER="https://$(oc get route prometheus-k8s -n openshift-monitoring -o jsonpath='{.spec.host}')"
readonly TOKEN=$(oc whoami -t)
readonly TIME_RANGE="7d"
readonly SAMPLE_RATE="5m"
readonly OUTPUT_FILE="max_cpu_usage_7_days.csv"
# For gather all namespaces 
#readonly NAMESPACES=$(oc get namespaces -o jsonpath='{.items[*].metadata.name}')
readonly NAMESPACES="openshift-apiserver openshift-monitoring"

# Log function
log() {
    echo "[$(date +'%Y-%m-%d %H:%M:%S')] $*"
}

# Error handling
error_handler() {
    local line_no=$1
    local error_code=$2
    log "Error occurred in script at line: ${line_no}, error code: ${error_code}"
    exit "${error_code}"
}
trap 'error_handler ${LINENO} $?' ERR

# CPU conversion functions
convert_to_cpu() {
    local input="$1"
    local result=""
    
    for item in $input; do
        case "$item" in
            *m)
                result+="${item} "
                ;;
            *cpu)
                local value=${item%cpu}
                result+="$((value * 1000))m "
                ;;
            *)
                result+="$((item * 1000))m "
                ;;
        esac
    done
    
    echo "${result%% }"
}

sum_cpu() {
    local input="$1"
    local total=0
    
    for item in $input; do
        case "$item" in
            *m)
                total=$((total + ${item//[^0-9]/}))
                ;;
            *cpu)
                local value=${item//[^0-9]/}
                total=$((total + value * 1000))
                ;;
            *)
                total=$((total + item * 1000))
                ;;
        esac
    done
    
    echo "${total}m"
}

# Memory conversion functions
convert_to_mi() {
    local input="$1"
    local result=""
    
    for item in $input; do
        case "$item" in
            *Gi)
                local value=${item%Gi}
                result+="$((value * 1024))Mi "
                ;;
            *Mi)
                result+="${item} "
                ;;
            *)
                result+="${item} "
                ;;
        esac
    done
    
    echo "${result%% }"
}

sum_memory() {
    local input="$1"
    local total=0
    
    for item in $input; do
        total=$((total + ${item//[^0-9]/}))
    done
    
    echo "${total}Mi"
}

convert_bytes_to_mi() {
    echo "$((${1:-0} / 1024 / 1024))Mi"
}

# Query Prometheus function
query_prometheus() {
    local query="$1"
    local result
    
    result=$(curl -k -H "Authorization: Bearer $TOKEN" -s -G \
        --data-urlencode "query=$query" \
        "$PROMETHEUS_SERVER/api/v1/query" | \
        jq -r '.data.result[-1].value[-1]' 2>/dev/null || echo "No Data")
    
    echo "$result"
}

# Get pod resources function
get_pod_resources() {
    local namespace="$1"
    local pod="$2"
    local resource="$3"
    local type="$4"
    
    kubectl get pod "$pod" -n "$namespace" \
        -o jsonpath="{.spec.containers[*].resources.${type}.${resource}}" 2>/dev/null || echo ""
}

# Initialize CSV
init_csv() {
    echo "Namespace,Pod,Max CPU Usage (mCores),Total CPU Request (mCores),Total CPU Limit (mCores),Max Mem Usage,Total Mem Request,Total Mem Limit" > "$OUTPUT_FILE"
    log "Initialized CSV file: $OUTPUT_FILE"
}

# Process single pod
process_pod() {
    local namespace="$1"
    local pod="$2"
    
    log "Processing pod: $namespace/$pod"
    
    # CPU metrics
    local cpu_query="max_over_time(rate(container_cpu_usage_seconds_total{namespace=\"$namespace\", pod=\"$pod\"}[5m])[$TIME_RANGE:])"
    local cpu_result=$(query_prometheus "$cpu_query")
    [[ "$cpu_result" != "No Data" ]] && cpu_result="$(awk "BEGIN {printf \"%.0f\", $cpu_result * 1000}")m"
    
    # Memory metrics
    local mem_query="max_over_time(sum(container_memory_working_set_bytes{job=\"kubelet\", metrics_path=\"/metrics/cadvisor\", cluster=\"\", namespace=\"$namespace\", container!=\"\", image!=\"\", pod=\"$pod\" }) [$TIME_RANGE:])"
    local mem_result=$(query_prometheus "$mem_query")
    [[ "$mem_result" != "No Data" ]] && mem_result=$(convert_bytes_to_mi "$mem_result")
    
    # Resource requests and limits
    local cpu_request=$(get_pod_resources "$namespace" "$pod" "cpu" "requests")
    local cpu_limit=$(get_pod_resources "$namespace" "$pod" "cpu" "limits")
    local mem_request=$(get_pod_resources "$namespace" "$pod" "memory" "requests")
    local mem_limit=$(get_pod_resources "$namespace" "$pod" "memory" "limits")
    
    # Convert and sum resources
    local sum_cpu_request=$(sum_cpu "$(convert_to_cpu "$cpu_request")")
    local sum_cpu_limit=$(sum_cpu "$(convert_to_cpu "$cpu_limit")")
    local sum_memory_request=$(sum_memory "$(convert_to_mi "$mem_request")")
    local sum_memory_limit=$(sum_memory "$(convert_to_mi "$mem_limit")")
    
    # Handle empty values
    : "${cpu_result:=No Data}"
    : "${sum_cpu_request:=No Data}"
    : "${sum_cpu_limit:=No Data}"
    : "${mem_result:=No Data}"
    : "${sum_memory_request:=No Data}"
    : "${sum_memory_limit:=No Data}"
    
    # Log results
    log "Max CPU Usage: $cpu_result"
    log "Pod CPU request: $sum_cpu_request"
    log "Pod CPU limit: $sum_cpu_limit"
    log "Max Mem Usage: $mem_result"
    log "Pod memory request: $sum_memory_request"
    log "Pod memory limit: $sum_memory_limit"
    
    # Write to CSV
    echo "$namespace,$pod,$cpu_result,$sum_cpu_request,$sum_cpu_limit,$mem_result,$sum_memory_request,$sum_memory_limit" >> "$OUTPUT_FILE"
}

main() {
    log "Starting resource monitoring script"
    init_csv
    
    for namespace in $NAMESPACES; do
        log "Processing namespace: $namespace"
        local pods
        pods=$(oc get pods -n "$namespace" -o jsonpath='{.items[*].metadata.name}')
        
        for pod in $pods; do
            process_pod "$namespace" "$pod"
        done
    done
    
    log "Completed. Results written to $OUTPUT_FILE"
}

main