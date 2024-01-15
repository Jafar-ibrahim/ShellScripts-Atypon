#!/bin/bash

# Function to display help message
 show_help() {
  echo "Backup Utility Help Menu"
  echo "Options:"
  echo "  -h, usage : -h      	                      Show this help message and exit"
  echo "  -m, usage : -m [1,2]     	              Choose backup mode (1 for full, 2 for incremental)"
  echo "  -s, usage : -s [DIR1 DIR2 ...]              Set the source directories to back up"
  echo "  -d, usage : -d PATH                         Set the destination directory to back up to "
  echo "  -a, usage : -auto [daily,weekly,monthly]    Enable automatic backups (daily, weekly, or monthly all at midnight(00:00))"
  echo ""
  exit 0
 }
# Function to print directory size in human-readable format
 print_dir_size() {
    local dir_path="$1"
    local dir_size=$(du -sh "$dir_path" | awk '{print $1}')  # Get size using du and extract first field
    echo "Size of $dir_path before compression : $dir_size" | tee -a "${log_file}" "${general_log_file}"
 }
 
 initialize_dirs() {
    local backup_dir=$1
    echo "Checking and initializing the backup directory structure , this requires creating new directories in the destination directory if not created before"
    mkdir -p ${backup_dir}/Manual_backups/Full_backups ${backup_dir}/Manual_backups/Incremental_backups ${backup_dir}/Auto_backups/daily ${backup_dir}/Auto_backups/weekly ${backup_dir}/Auto_backups/monthly
 }
 read_dirs() {
    # Get user-specified directories to back up (if not provided via options)
    if [[ ${#dirs[@]} -eq 0 ]]; then
         read -rp  "-> Enter directories to back up, separated by spaces: " -a dirs
    fi
 }
 read_backup_dir() {
    # Get user-specified target directory to back up to (if not provided via options)
    while [[ -z "$backup_dir"  || ! -d "$backup_dir" ]] ; do
          read -rp  "-> Enter destination directory( full path from /home )
   If performing an incremental backup , it must contain the last full backup in its sub directories : " backup_dir
          if [[ ! -d "$backup_dir" ]]; then
               echo "Error: Directory does not exist."
          fi
    done
 }
 read_mode() {
    if [[ -z "$mode" ]]; then
    # -- Informative prompt about backup modes --
    read -rp "-> Choose how you want to back up:

  1. Full backup (creates a complete copy of all selected directories)
  2. Incremental backup (only backs up files changed since the last backup)

Which option do you want? (1/2): " mode
    fi

    while [[ ! ("$mode" == "1" || "$mode" == "2") ]] ; do
         echo "wrong mode value , choose 1 or 2"
         read -rp "Which option do you want? (1/2): " mode
    done
 }
 
 fetch_last_snapshot_file() {
    echo "Fetching the snapshot file of the last backup" | tee -a "${log_file}"
    last_full_backup_snapshot=$(ls -t ${backup_dir}/*/*/${dirname}/*/*.snar | head -n1)
    echo "last backup for ${dirname} was $(dirname "$last_full_backup_snapshot")" | tee -a "${log_file}"
    cp $last_full_backup_snapshot $specific_backup_dir/data.snar
 }
 
 check_auto_config() {
 # check if the $auto_backup has some value
if [[ -n "$auto_backup" ]]; then
  case "$auto_backup" in
    daily)
      cron_schedule="0 0 * * *"  # Daily at midnight

      # Add cron job for daily backup
      (crontab -l 2>/dev/null; echo "$cron_schedule $(readlink -f $0) -m 1 -d $backup_dir -s ${dirs[@]} -f daily" ) | crontab -

      # Add cron job for daily backup deletion (after completion) for any backup older than 7 days
      (crontab -l 2>/dev/null; echo "0 5 * * * find ${backup_dir}/Auto_backups/Full_backups/${dirname} -name 'backup*' -mtime +7 -exec rm -r {} + >> $general_log_file 2>&1") | crontab -
      ;;

    weekly)
      cron_schedule="0 0 * * 0"  # Every Sunday at midnight

      # Add cron job for daily backup
      (crontab -l 2>/dev/null; echo "$cron_schedule $(readlink -f $0) -m 1 -d $backup_dir -s ${dirs[@]} -f weekly") | crontab -

      # Add cron job for weekly backup deletion (after completion) for any backup older than 4 weeks (31 days)
      (crontab -l 2>/dev/null; echo "0 5 * * 1 find ${backup_dir}/Auto_backups/Full_backups/${dirname} -name 'backup*' -mtime +31 -exec rm -r {} + >> $general_log_file 2>&1") | crontab -
      ;;

    monthly)
      cron_schedule="0 0 1 * *"  # First day of every month at midnight

      # Add cron job for daily backup
      (crontab -l 2>/dev/null; echo "$cron_schedule $(readlink -f $0) -m 1 -d $backup_dir -s ${dirs[@]} -f monthly") | crontab -

      # Add cron job for monthly backup deletion (after completion) for any backup older than 12 months (365 days)
      (crontab -l 2>/dev/null; echo "0 5 2 * * find ${backup_dir}/Auto_backups/Full_backups/${dirname} -name 'backup*' -mtime +356 -exec rm -r {} + >> $general_log_file 2>&1") | crontab -
      ;;

    *)
      echo "Invalid option argument: $auto_backup , must be [daily,weekly,monthly]." >&2
      exit 1
      ;;
  esac
  exit 1
fi

 }
 
 #dirs=()  # Initialize the array of directories
# Parse options
while getopts ":hm:d:s:a:f:" opt; do
  case $opt in
    h)
      show_help
      ;;
    m)
      mode="$OPTARG"
      ;;
    s)
      #keep adding directories until another dashed option is met
      dirs=("$OPTARG")
            until [[ $(eval "echo \${$OPTIND}") =~ ^-.* ]] || [ -z $(eval "echo \${$OPTIND}") ]; do
                dirs+=($(eval "echo \${$OPTIND}"))
                OPTIND=$((OPTIND + 1))
            done
      ;;
    d)
      backup_dir="$OPTARG"
      ;;
    a)
      auto_backup="$OPTARG"
      ;;
    f)
      freq="$OPTARG"
      ;;
    \?)
      echo "Invalid option: -$OPTARG" >&2
      show_help
      ;;
  esac
done



read_dirs

read_backup_dir

# Initialize the log file for all backups in the backup directory
general_log_file="${backup_dir}/general_log.log"

check_auto_config

read_mode




# Welcome message
echo "Welcome to the Backup Utility!"
if [[ "$mode" == "1" ]]; then
  echo "Creating a full backup, please be patient this may take some time..."
elif [[ "$mode" == "2" ]]; then
  echo "Performing an incremental backup, this will be faster than a full backup."
fi


timestamp=$(date +%Y.%m.%d-%H:%M:%S)
initialize_dirs ${backup_dir}


# Start logging
echo "Backup started at $timestamp" >> $general_log_file
echo "Backing up : ${dirs[@]} " >> $general_log_file


echo "**********************************************************"
# Loop through each directory
for dir in "${dirs[@]}"; do
  # Ensure the directory exists
  if [[ -d "$dir" ]]; then
    
    # assign a timestamp
    timestamp=$(date +%Y.%m.%d-%H:%M:%S)
    
    
    # Extract the path and the base name
    path=$(dirname "$dir")
    dirname=$(basename "$dir")
     
    
	if [[ "$mode" == "1" ]]; then # Full backup 
	   if [[ -n "$freq" ]]; then
	      backup_type="Auto_backups"
	      echo "Started an auto full backup for ${dir}" | tee -a "${general_log_file}"
	      echo "Creating a new directory with new timestamp for ${dirname} " | tee -a "${general_log_file}"
	      mkdir -p "${backup_dir}/Auto_backups/${freq}/${dirname}/${dirname}-${timestamp}"
	      specific_backup_dir="${backup_dir}/Auto_backups/${freq}/${dirname}/${dirname}-${timestamp}"
	      
	   else 
	      backup_type="Manual_backups"
	      echo "Started a manual full backup for ${dir}" | tee -a "${general_log_file}"
	      echo "Creating a new directory with new timestamp for ${dirname} " | tee -a "${general_log_file}"
	      mkdir -p "${backup_dir}/${backup_type}/Full_backups/${dirname}/${dirname}-${timestamp}"
	      specific_backup_dir="${backup_dir}/${backup_type}/Full_backups/${dirname}/${dirname}-${timestamp}"
	   fi
	   
	   # Build backup file name/path
	   backup_file="$specific_backup_dir/backup-$dirname-$timestamp.tar.gz"
	   
	else # Incremental backup
	   echo "Started manual incremental backup for ${dir}" | tee -a "${general_log_file}" 
	   echo "Creating a specific directory for ${dirname} "| tee -a "${general_log_file}"
	   mkdir -p "${backup_dir}/Manual_backups/Incremental_backups/${dirname}/${dirname}-${timestamp}"
	   specific_backup_dir="${backup_dir}/Manual_backups/Incremental_backups/${dirname}/${dirname}-${timestamp}"																																		
	   backup_file="$specific_backup_dir/incremental-backup-$dirname-$timestamp.tar.gz"
	fi
	
    # Set default log file path if not specified
    log_file="$specific_backup_dir/backup-$dirname-$timestamp.log"
    # Print size before creating the backup
    print_dir_size "$dir"  
    
    # Create the backup
    echo "Backing up $dir to $backup_file..." | tee -a "${general_log_file}"
    if [[ "$mode" == "1" ]]; then
       tar -cvvz --listed-incremental="${specific_backup_dir}"/data.snar -f "${backup_file}" -C "${path}" "${dirname}" >> "$log_file" 2>&1
    else
       # Use most recent full backup as reference
       fetch_last_snapshot_file 
       SNAR=${specific_backup_dir}/data.snar
       
       tar -cvz --listed-incremental="${SNAR}" -f "${backup_file}" -C "${path}" "${dirname}" >> "$log_file" 2>&1
    fi

    # Check backup status
    if [[ $? -eq 0 ]]; then
      echo "Backup of $dir completed successfully!" | tee -a "${log_file}" "${general_log_file}" 
      echo "Size of backup files : $(du -sh "$backup_file" | awk '{print $1}')" | tee -a "${log_file}" "${general_log_file}"
      echo "**********************************************************"
    else
      echo "Backup of $dir failed!" | tee -a "${log_file}" "${general_log_file}"
    fi
  else
    echo "Warning: Directory $dir does not exist, skipping." | tee -a "${log_file}" "${general_log_file}" 
  fi
  unset log_file
done

timestamp=$(date +%Y.%m.%d-%H:%M:%S)
# finish logging
echo "Finished Backup  at $timestamp" >> $general_log_file
      echo "**********************************************************" >> $general_log_file
echo "Backup finished!"
