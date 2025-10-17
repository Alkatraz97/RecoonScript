#!/bin/bash
# Nome: scan_hosts.sh
# Descrizione: Scansiona tutte le porte degli host elencati nel file 'hosts'

DATE_FORMATTED=$(date +"%d:%m:%Y %H:%M")
echo "Inizio sansione PTAC8k $DATE_FORMATTED" >> log_recoonscan.log
echo " " >> log_recoonscan.log

# 2. Check if 'hosts.txt' already exist
if [ ! -f hosts.txt ]; then
    echo "Error: 'hosts.txt' file not found."
    echo "Create 'hosts.txt' file and add IP o Host, one for row."
    exit 1
fi

# 3. Start Scan Loop
for i in $(cat hosts.txt); do

    echo "--- START check of $i ---" >> log_recoonscan.log
    check_ip="Scan_of_$i""_completed"
    echo $check_ip

    if grep -qF "$check_ip" "log_recoonscan.log"; then

    echo "$i SCAN ALERADY DONE"

    else
        # IP not scanned, scan started
        echo "--- Start scan of $i ---" >> log_recoonscan.log
        mkdir -p $i
        mkdir -p $i/nmap
        # Scans and saves output to nmap/$i.nmap
        nmap -T4 --max-retries 1 -sS -p- $i -vv -oN "$i/nmap/$i.nmap"
        
        # Array whith open ports
        declare -a all_ports=()

        FILE_NMAP="$i/nmap/$i.nmap"

        # mapfile used to build the array
        mapfile -t all_ports < <(
            awk '/\/tcp/ && !/Nmap scan report/ && !/PORT/ {
                # Stampa il primo campo (la porta) e sostituisce "/tcp" con una stringa vuota
                gsub("/tcp", "", $1);
                print $1
            }' "$FILE_NMAP"
        )

        echo "--- Nmap scan of $i ended ---" >> log_recoonscan.log
        
        https_ports=$(grep "https" $i/nmap/$i.nmap | cut -d'/' -f1)
        if [ -n "$https_ports" ]; then
            echo "--- START nuclei https scan of $i ---" >> log_recoonscan.log
            #echo "trovate porte http: $https_ports"
            echo "$https_ports" >> general_https_ports.txt
            echo "$https_ports" > $i/https_ports.txt
            for port in $https_ports; do
                mkdir -p $i/nuclei
                nuclei -target $i:$port -o "$i/nuclei/$port""_http_nuclei.txt"
            done
            echo "--- END nuclei https can of $i ---" >> log_recoonscan.log
        fi
        
        http_ports=$(grep "http" $i/nmap/$i.nmap | cut -d'/' -f1)
        if [ -n "$http_ports" ]; then
            echo "--- START nuclei http scan of $i ---" >> log_recoonscan.log
            #echo "trovate porte http: $http_ports"
            echo "$http_ports" >> general_http_ports.txt
            echo "$http_ports" > $i/http_ports.txt
            for port in $http_ports; do
                mkdir -p $i/nuclei
                nuclei -target $i:$port -o "$i/nuclei/$port""_http_nuclei.txt"
            done
            echo "--- END nuclei http scan of $i ---" >> log_recoonscan.log
        fi	
        
        OLD_IFS=$IFS
        IFS=','
        ports_string=${all_ports[*]}
        IFS=$OLD_IFS 

        if [ -n "$ports_string" ]; then
            echo "--- START Advanced nmap scan $i ---" >> log_recoonscan.log
            nmap -sC -sV -p $ports_string $i -vv -oN "$i/nmap/$i.nmap"
            echo "--- END Advanced nmap scan  $i ---" >> log_recoonscan.log
            
            echo "--- START Eyewitness scan $i ---" >> log_recoonscan.log
            echo $i > temp_$i
            eyewitness -f temp_$i -d $i/eyewitness --only-ports $ports_string --timeout 1 --no-prompt
            rm temp_$i
            echo "--- END Eyewitness scan $i ---" >> log_recoonscan.log
            
        fi

        

    fi

    DATE_FORMATTED=$(date +"%d:%m:%Y %H:%M")
    echo "--- Scan_of_$i"_completed" --- $DATE_FORMATTED" >> log_recoonscan.log
    notify-send "Scan of $i completed"
    		
done

echo "----------- END SCAN, happy hack! -----------"


