# Fatcat - OpenShift Container Resource Monitor

## Overview
Fatcat is a bash script designed to monitor and collect resource usage metrics from OpenShift containers. It queries Prometheus metrics and generates a comprehensive CSV report containing CPU, memory, and network usage statistics for specified namespaces.

## Features
- Collects maximum CPU usage over time
- Monitors memory consumption
- Tracks network transmission and reception rates
- Compares actual usage against resource requests and limits
- Outputs data in an easy-to-analyze CSV format

## Prerequisites
- OpenShift CLI (oc) installed and configured
- Cluster-monitoring-view permission or higher
- Active login session to the OpenShift cluster
- `kubectl` access to the cluster
- `curl` and `jq` installed on the system

## Configuration
The script uses several configurable parameters:
```bash
readonly TIME_RANGE="7d"        # Time range for metrics collection
readonly NAMESPACES="openshift-apiserver openshift-monitoring"  # Target namespaces
```

## Output Format
The script generates a CSV file with the following columns:
1. Namespace
2. Pod
3. Max CPU Usage (mCores)
4. Total CPU Request (mCores)
5. Total CPU Limit (mCores)
6. Max Memory Usage
7. Total Memory Request
8. Total Memory Limit
9. Max Network Receive
10. Max Network Transmit

## Metrics Details

### CPU Metrics
- Usage is measured in millicores (m)
- Calculated using container_cpu_usage_seconds_total
- Shows maximum rate over the specified time range

### Memory Metrics
- Measured in MiB (Mebibytes)
- Uses container_memory_working_set_bytes
- Includes all container memory usage

### Network Metrics
- Measured in B/s, KB/s, or MB/s
- Uses container_network_receive_bytes_total and container_network_transmit_bytes_total
- Values are rounded to integers before unit conversion
- Shows maximum transmission/reception rates

## Usage

1. Ensure you're logged into OpenShift:
   ```bash
   oc login <cluster-url>
   ```

2. Make the script executable:
   ```bash
   chmod +x fatcat.sh
   ```

3. Run the script:
   ```bash
   ./fatcat.sh
   ```

4. Check the output file:
   ```bash
   cat max_cpu_usage_7_days.csv
   ```

## Customization

### Modifying Target Namespaces
To monitor different namespaces, modify the NAMESPACES variable:
```bash
readonly NAMESPACES="namespace1 namespace2 namespace3"
```

To monitor all namespaces, uncomment the following line:
```bash
readonly NAMESPACES=$(oc get namespaces -o jsonpath='{.items[*].metadata.name}')
```

### Adjusting Time Range
Modify the TIME_RANGE variable to change the monitoring period:
```bash
readonly TIME_RANGE="24h"  # For last 24 hours
readonly TIME_RANGE="7d"   # For last 7 days
readonly TIME_RANGE="30d"  # For last 30 days
```

## Error Handling
The script includes error handling that will:
- Log errors with timestamp and line number
- Exit on any error (set -e)
- Handle null or empty values in metrics
- Validate Prometheus query responses

## Logging
The script provides detailed logging during execution:
- Start and completion timestamps
- Processing status for each namespace and pod
- Resource usage values as they're collected
- Error messages if any issues occur

## Limitations
- Requires active OpenShift session
- Prometheus must be accessible
- May take longer to run with many namespaces/pods
- Large time ranges may impact performance
- Network metrics might not be available for all pod types

## Troubleshooting
1. If the script fails to run:
   - Verify OpenShift login status
   - Check permissions
   - Ensure Prometheus route is accessible

2. If metrics show "No Data":
   - Verify pod existence during the time range
   - Check if metrics are being collected for the namespace
   - Ensure proper monitoring configuration

3. For permission errors:
   - Verify cluster-monitoring-view access
   - Check namespace access permissions
   - Validate token authentication


# Analyze the csv file

## Usage

```
python3 analyze_usage.py --input <result_from_fatcat.csv> --output <output.csv>
```