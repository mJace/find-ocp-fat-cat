import pandas as pd
import numpy as np
import argparse

def categorize_cpu_usage(row):
    # Convert CPU values from millicores to cores for calculation
    cpu_usage = float(row['Max CPU Usage (mCores)'].rstrip('m')) if isinstance(row['Max CPU Usage (mCores)'], str) else 0
    cpu_limit = float(row['Total CPU Limit (mCores)'].rstrip('m')) if isinstance(row['Total CPU Limit (mCores)'], str) else 0
    
    # Calculate usage percentage
    cpu_usage_pct = (cpu_usage / cpu_limit * 100) if cpu_limit > 0 else 0
    
    # Categorize based on CPU usage percentage
    if cpu_usage_pct < 40:
        return 'Most overcommit (< 40%)'
    elif cpu_usage_pct < 60:
        return 'Overcommit (40% - 60%)'
    else:
        return 'Normal (> 60%)'

def categorize_memory_usage(row):
    # Convert memory values from Mi to numbers for calculation
    mem_usage = float(row['Max Mem Usage'].rstrip('Mi')) if isinstance(row['Max Mem Usage'], str) and row['Max Mem Usage'] != 'No Data' else 0
    mem_limit = float(row['Total Mem Limit'].rstrip('Mi')) if isinstance(row['Total Mem Limit'], str) else 0
    
    # Calculate usage percentage
    mem_usage_pct = (mem_usage / mem_limit * 100) if mem_limit > 0 else 0
    
    # Categorize based on memory usage percentage
    if mem_usage_pct < 40:
        return 'Most overcommit (< 40%)'
    elif mem_usage_pct < 60:
        return 'Overcommit (40% - 60%)'
    else:
        return 'Normal (> 60%)'

def categorize_network_usage(row):
    # Convert network values to KB/s for standardization
    def convert_to_kbps(value):
        if isinstance(value, str):
            if value == 'No Data':
                return 0
            elif 'MB/s' in value:
                return float(value.rstrip('MB/s')) * 1024
            elif 'KB/s' in value:
                return float(value.rstrip('KB/s'))
            elif 'B/s' in value:
                return float(value.rstrip('B/s')) / 1024
        return 0

    receive = convert_to_kbps(row['Max Network Receive'])
    transmit = convert_to_kbps(row['Max Network Transmit'])
    
    # Use the maximum of receive and transmit
    max_network = max(receive, transmit)
    
    # Categorize based on network usage
    if max_network < 1000:  # Less than 1000 KB/s
        return 'Low (< 1 MB/s)'
    elif max_network < 50000:  # Less than 50000 KB/s
        return 'Medium (< 50 MB/s)'
    else:  # 51200 KB/s or more
        return 'High'

def main():
    # Set up argument parser
    parser = argparse.ArgumentParser(description='Analyze container resource usage from CSV file.')
    parser.add_argument('--input', required=True, help='Input CSV file path')
    parser.add_argument('--output', required=True, help='Output CSV file path')
    
    # Parse arguments
    args = parser.parse_args()

    try:
        # Read the CSV data
        df = pd.read_csv(args.input)

        # Add usage categories
        df['CPU Usage Category'] = df.apply(categorize_cpu_usage, axis=1)
        df['Memory Usage Category'] = df.apply(categorize_memory_usage, axis=1)
        df['Network Usage Category'] = df.apply(categorize_network_usage, axis=1)

        # Calculate and display usage percentages
        print("\nCPU Usage Categories Distribution:")
        print(df['CPU Usage Category'].value_counts())

        print("\nMemory Usage Categories Distribution:")
        print(df['Memory Usage Category'].value_counts())

        print("\nNetwork Usage Categories Distribution:")
        print(df['Network Usage Category'].value_counts())

        # Save the results to the output CSV file
        df.to_csv(args.output, index=False)
        print(f"\nResults have been saved to {args.output}")

    except FileNotFoundError:
        print(f"Error: Input file '{args.input}' not found")
        exit(1)
    except Exception as e:
        print(f"Error: An unexpected error occurred: {str(e)}")
        exit(1)

if __name__ == "__main__":
    main()