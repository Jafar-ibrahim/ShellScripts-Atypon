#!/bin/bash


REPORT_FILE="system_health_report.txt"

show_system_info_header() {
    echo -e "
========================================================================
                        Health Check Report 
========================================================================
 
Hostname         : `hostname`
Kernel Version   : `uname -r`
Uptime           : `uptime | sed 's/.*up \([^,]*\), .*/\1/'`
Last Reboot Time : `who -b | awk '{print $3,$4}'` " >> $REPORT_FILE
}

check_disk() {
    echo -e "
========================================================================
                            Disk Usage  
========================================================================
        ( <90% healthy , >=90% Needs Caution , >=95% Unhealthy )
" >> $REPORT_FILE
    df -h >> $REPORT_FILE
    echo >> $REPORT_FILE # empty line
    # Check if any partition is more than 90% full
    if df -h | awk '{sub(/%/, "", $5); if ($5 > 90) exit 1}'; then
        echo "[WARNING] Disk usage is over 90% on one or more partitions." >> $REPORT_FILE
        echo "Recommendation: Consider cleaning up unnecessary files or expanding your storage." >> $REPORT_FILE
    else
        echo "[INFO] Disk usage is healthy." >> $REPORT_FILE
    fi
}


check_memory() {
    echo -e "
========================================================================
                          Memory Usage
========================================================================
" >> $REPORT_FILE

    free -h >> $REPORT_FILE
    echo >> $REPORT_FILE # empty line
    
    local warning_threshold=80
    local total_mem=$(free -m | awk '/Mem:/{print $2}')
    local used_mem=$(free -m | awk '/Mem:/{print $3}')
    local used_percent=$((used_mem * 100 / total_mem))
    if [[ $used_percent -gt $warning_threshold ]]; then
        echo "[WARNING]: High memory usage ($used_percent%)" >> $REPORT_FILE
    else
        echo "[INFO] Memory usage is healthy." >> $REPORT_FILE
    fi
}


check_processes() {
    echo -e "
========================================================================
                   Top 10 Processes by RAM Usage 
========================================================================
" >> $REPORT_FILE
    ps aux --sort=-%mem | head -n 11 >> $REPORT_FILE
    
    echo -e "
========================================================================
                   Top 10 Processes by CPU Usage 
========================================================================
" >> $REPORT_FILE
    ps aux --sort=-%cpu | head -n 11 >> $REPORT_FILE
}


check_services() {
    echo -e "
========================================================================
                        Running Services 
========================================================================
" >> $REPORT_FILE

    systemctl | head -n 1 >> $REPORT_FILE
    systemctl | grep running >> $REPORT_FILE
}


check_updates() {
echo -e "
========================================================================
                 Recent System Installation Commands 
========================================================================
" >> $REPORT_FILE
    cat /var/log/apt/history.log | grep Commandline | tail -n 10 >> $REPORT_FILE
    echo -e "
========================================================================
                   Recent System Changes/Updates
========================================================================
" >> $REPORT_FILE
    tail /var/log/dpkg.log >> $REPORT_FILE
    echo >> $REPORT_FILE # empty line
    
    UPDATE_THRESHOLD=14;
    
    local last_update=$(awk '/Upgrade:/ {getline; print}' /var/log/apt/history.log | tail -1 | awk '{print $2, $3}')
    local days_since_update=$((($(date +%s) - $(date -d "$last_update" +%s)) / 86400))
    if [[ $days_since_update -gt $UPDATE_THRESHOLD ]]; then
        echo "[WARNING]: System hasn't been updated in $days_since_update days" >> $REPORT_FILE
        echo "Recommendation: Consider updating your system using the command specific for your distribution (ex. \"sudo apt update\" for ubuntu)." >> $REPORT_FILE
    fi
    echo "[INFO]: System updates frequency is normal and healthy ." >> $REPORT_FILE
}

# Function to provide recommendations
provide_recommendations() {
echo -e "
========================================================================
                           Recommendations 
========================================================================
" >> $REPORT_FILE
    echo "If any of the checks above are concerning, consider the following actions:" >> $REPORT_FILE
    echo "- Disk Usage: Consider cleaning up unnecessary files or expanding your storage." >> $REPORT_FILE
    echo "- Memory Usage: Consider closing unnecessary applications or expanding your memory." >> $REPORT_FILE
    echo "- Processes: Consider investigating any unfamiliar processes using a large amount of resources." >> $REPORT_FILE
    echo "- Services: Consider disabling unnecessary services." >> $REPORT_FILE
    echo "- Updates: Consider updating your system if it has not been updated recently." >> $REPORT_FILE
}
report_end_footer() {
echo -e "
========================================================================
                           End Of The Report 
========================================================================

" >> $REPORT_FILE
}

show_system_info_header
check_disk
check_memory
check_processes
check_services
check_updates
provide_recommendations
report_end_footer

echo "System health report has been generated in your current directory (system_health_report.txt) ."

