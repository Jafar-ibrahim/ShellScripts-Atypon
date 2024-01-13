#!/bin/bash

# Function to display help message
 show_help() {
  echo "Backup Utility"
  echo ""
  echo "Usage: $0 [OPTIONS] DIRECTORY..."
  echo ""
  echo "Options:"
  echo "  -h,  --help      	         Show this help message and exit"
  echo "  -m,  --mode      	         Choose backup mode (1 for full, 2 for incremental)"
  echo "  -dd, --destination-directory PATH   Set the destination directory to back up to "
  echo "  -a,  --auto ARGUMENT     	 Enable automatic backups (daily, weekly, or monthly)"
  echo ""
  echo "Examples:"
  echo "  $0 documents pictures"
  echo "  $0 -m 1 --directory /backup home"
  echo "  $0 -a weekly"
  echo ""
  exit 0
 }
# Function to print directory size in human-readable format
 print_dir_size() {
    local dir_path="$1"
    local dir_size=$(du -sh "$dir_path" | awk '{print $1}')  # Get size using du and extract first field
    echo "Size of $dir_path before compression : $dir_size"
 }
 
 initialize_dirs() {
    backup_dir=$1
    echo "Checking and initializing the backup directory structure , this requires creating new directories in the destination directory if not created before"
    mkdir -p ${backup_dir}/Manual_backups/Full_backups ${backup_dir}/Manual_backups/Incremental_backups ${backup_dir}/Auto_backups/Daily ${backup_dir}/Auto_backups/Weekly ${backup_dir}/Auto_backups/Monthly
 }
 
 
 #dirs=()  # Initialize the array of directories
# Parse options
while getopts ":hm:d:s:a:" opt; do
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
    \?)
      echo "Invalid option: -$OPTARG" >&2
      exit 1
      ;;
  esac
done

# Welcome message
echo "Welcome to the Backup Utility!"

# -- Auto-backup setup --
if [[ -n "$auto_backup" ]]; then
  case "$auto_backup" in
    daily)
      cron_schedule="0 0 * * *"  # Daily at midnight

      # Add cron job for daily backup
      (crontab -l 2>/dev/null; echo "$cron_schedule $0 -m 2 --directory $backup_dir ${dirs[@]} >> $log_file 2>&1") | crontab -

      # Add cron job for daily backup deletion (after completion)
      (crontab -l 2>/dev/null; echo "0 5 * * * find $backup_dir -name 'backup-*daily-*.tar.gz' -mtime +7 -delete") | crontab -
      ;;

    weekly)
      cron_schedule="0 0 * * 0"  # Every Sunday at midnight

      # Add cron job for weekly backup
      (crontab -l 2>/dev/null; echo "$cron_schedule $0 -m 1 --directory $backup_dir ${dirs[@]} >> $log_file 2>&1") | crontab -

      # Add cron job for weekly backup deletion (after completion)
      (crontab -l 2>/dev/null; echo "0 5 * * 1 find $backup_dir -name 'backup-*weekly-*.tar.gz' -mtime +31 -delete") | crontab -
      ;;

    monthly)
      cron_schedule="0 0 1 * *"  # First day of every month at midnight

      # Add cron job for monthly backup
      (crontab -l 2>/dev/null; echo "$cron_schedule $0 -m 1 --directory $backup_dir ${dirs[@]} >> $log_file 2>&1") | crontab -

      # Add cron job for monthly backup deletion (after completion)
      (crontab -l 2>/dev/null; echo "0 5 2 * * find $backup_dir -name 'backup-*monthly-*.tar.gz' -mtime +365 -delete") | crontab -
      ;;

    *)
      # ... (error handling for invalid auto-backup frequency)
  esac
fi
#-----------------------

# Get user-specified directories to back up (if not provided via options)
if [[ ${#dirs[@]} -eq 0 ]]; then
  read -rp  "Enter directories to back up, separated by spaces: " dirs
fi

# Get user-specified target directory to back up to (if not provided via options)
while [[ -z "$backup_dir"  || ! -d "$backup_dir" ]] ; do
  read -rp  "Enter destination directory( full path from /home )
   If performing an incremental backup , it must contain the last full backup in its sub directories : " backup_dir
  if [[ ! -d "$backup_dir" ]]; then
    echo "Error: Directory does not exist."
  fi
done

if [[ -z "$mode" ]]; then
# -- Informative prompt about backup modes --
read -rp "Choose how you want to back up:

  1. Full backup (creates a complete copy of all selected directories)
  2. Incremental backup (only backs up files changed since the last backup)

Which option do you want? (1/2): " mode
fi

while [[ ! "$mode" == "1" || "$mode" == "2" ]] ; do
      echo "wrong mode value , choose 1 or 2"
      read -rp "Which option do you want? (1/2): " mode
done

# -- Detailed description of the chosen mode --

if [[ "$mode" == "1" ]]; then
  echo "Creating a full backup, please be patient this may take some time..."
elif [[ "$mode" == "2" ]]; then
  echo "Performing an incremental backup, this will be faster than a full backup."
fi


timestamp=$(date +%Y.%m.%d-%H:%M:%S)
initialize_dirs ${backup_dir}
general_log_file="${backup_dir}"/general_log.log
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
    
    print_dir_size "$dir"  # Print size before creating the backup
    # Extract the path and the base name
    path=$(dirname "$dir")
    dirname=$(basename "$dir")
     
    # Build backup file name
	if [[ "$mode" == "1" ]]; then
	   if [[ -n "$auto_backup" ]]; then
	      backup_type="Auto_backups"
	      echo "Started auto full backup for ${dir}" | tee -a "${general_log_file}"
	   else 
	      backup_type="Manual_backups"
	      echo "Started manual full backup for ${dir}" | tee -a "${general_log_file}"
	   fi
	   echo "Creating a new directory with new timestamp for ${dirname} in the backup directory" | tee -a "${general_log_file}"
	   mkdir -p "${backup_dir}/${backup_type}/Full_backups/${dirname}/${dirname}-${timestamp}"
	   specific_backup_dir="${backup_dir}/${backup_type}/Full_backups/${dirname}/${dirname}-${timestamp}"
	   # Full backup 
	   backup_file="$specific_backup_dir/backup-$dirname-$timestamp.tar.gz"
	   
	else
	   echo "Started manual incremental backup for ${dir}" | tee -a "${general_log_file}" 
	   echo "Creating a specific directory for ${dirname} in the backup directory"| tee -a "${general_log_file}"
	   mkdir -p "${backup_dir}/Manual_backups/Incremental_backups/${dirname}/${dirname}-${timestamp}"
	   specific_backup_dir="${backup_dir}/Manual_backups/Incremental_backups/${dirname}/${dirname}-${timestamp}"																																		
	   # Incremental backup
	   backup_file="$specific_backup_dir/incremental-backup-$dirname-$timestamp.tar.gz"
	fi
	
    # Set default log file path if not specified
    log_file="${log_file:-"$specific_backup_dir/backup-$dirname-$timestamp.log"}"
    
    # Create the backup
    echo "Backing up $dir to $backup_file..." | tee -a "${general_log_file}"
    if [[ "$mode" == "1" ]]; then
       tar -cvvz --listed-incremental="${specific_backup_dir}"/data.snar -f "${backup_file}" -C "${path}" "${dirname}" >> "$log_file" 2>&1
    else
       # Use most recent full backup as reference
       echo "Fetching the snapshot file of the last backup" | tee -a "${log_file}"
       last_full_backup_snapshot=$(ls -t ${backup_dir}/*/*/${dirname}/*/*.snar | head -n1)
       echo "last backup for ${dirname} was $(dirname "$last_full_backup_snapshot")" | tee -a "${log_file}"
       cp $last_full_backup_snapshot $specific_backup_dir/data.snar
       SNAR=${specific_backup_dir}/data.snar
       tar -cvz --listed-incremental="${SNAR}" -f "${backup_file}" -C "${path}" "${dirname}" >> "$log_file" 2>&1
    fi

    # Check backup status
    if [[ $? -eq 0 ]]; then
      echo "Backup of $dir completed successfully!" | tee -a "${log_file}" "${general_log_file}"
      echo "Size of backup files : $(du -sh "$backup_file" | awk '{print $1}')"
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
