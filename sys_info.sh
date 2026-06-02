#!/bin/bash

# Прячем курсор
tput civis
# При выходе (Ctrl+C) возвращаем курсор и очищаем экран
trap "tput cnorm; clear; exit" INT TERM

# Функция отрисовки бар-графика
draw_bar() {
    local val=$1
    local name=$2
    local bar_size=15 
    local filled=$(echo "scale=0; ($val*$bar_size)/100" | bc -l)
    local empty=$(echo "scale=0; ($bar_size-$filled)" | bc -l)
    
    printf "%-6s: [" "$name"
    printf "%0.s#" $(seq 1 $filled 2>/dev/null)
    printf "%0.s." $(seq 1 $empty 2>/dev/null)
    printf "] %d%%" "$val"
}

# Функция отрисовки температур
draw_temp() {
    local temp=$1
    if [ -z "$temp" ] || [ "$temp" == "N/A" ]; then
        printf " | Temp: N/A"
    else
        printf " | Temp: +%.1f°C" "$temp"
    fi
}

clear

while true; do
    tput cup 0 0
    
    echo "=== SYSTEM MONITOR (Ultimate Edition) ==="
    echo "Time: $(date +%H:%M:%S)                     "
    echo "------------------------------------------------"

    # 1. НАГРУЗКА ПО ЯДРАМ CPU (Вместо одной общей строки)
    grep -E '^cpu[0-9]+' /proc/stat | while read -r line; do
        core_name=$(echo "$line" | awk '{print $1}')
        cpu_usage=$(echo "$line" | awk '{print int(($2+$3+$4)*100/($2+$3+$4+$5+$6+$7+$8))}')
        draw_bar "$cpu_usage" "$core_name"
        printf "                    \n" # Очистка хвоста строки
    done

    # Общая температура процессора
    CPU_TEMP=$(sensors 2>/dev/null | grep -E 'Package id 0|Core 0' | awk '{print $4}' | head -n 1 | tr -d '+°C')
    printf "CPU Total Temp: "
    draw_temp "$CPU_TEMP"
    printf "                    \n"
    echo "------------------------------------------------"

    # 2. SSD
    SSD_FREE=$(df -h / | awk 'NR==2 {print $4}')
    SSD_TEMP=$(sudo smartctl -A /dev/sda 2>/dev/null | grep "Temperature" | awk '{print $10}')
    [ -z "$SSD_TEMP" ] && SSD_TEMP="N/A"
    printf "SSD Free: %-6s" "$SSD_FREE"
    draw_temp "$SSD_TEMP"
    printf "                    \n"
    echo "------------------------------------------------"

    # 3. RAM
    free -h | awk '/Mem:/ { printf "RAM Used: %s / %s (%.1f%%)  ", $3, $2, $3/$2*100 }'
    printf "                    \n"
    echo "------------------------------------------------"

    # 4. GPU (Добавили sudo, чтобы правило Sudoers сработало!)
    if command -v nvidia-smi &> /dev/null; then
        GPU_DATA=$(sudo -n /usr/bin/nvidia-smi --query-gpu=utilization.gpu,temperature.gpu --format=csv,noheader,nounits 2>/dev/null)

        if [ $? -eq 0 ]; then
            GPU_LOAD=$(echo $GPU_DATA | cut -d',' -f1 | awk '{printf "%.0f\n", $1}')
            GPU_TEMP=$(echo $GPU_DATA | cut -d',' -f2 | awk '{printf "%.0f\n", $1}')
            draw_bar "$GPU_LOAD" "GPU"
            draw_temp "$GPU_TEMP"
            printf "                    \n" 
        else
            echo "GPU data: Error (N/A)                       "
        fi
    else
        echo "GPU: NVIDIA Driver not found                 "
    fi

    echo "------------------------------------------------"
    echo "Exit: Ctrl+C                                    "
    
    sleep 0.5 
done

