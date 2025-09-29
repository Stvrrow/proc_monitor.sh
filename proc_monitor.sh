#!/bin/bash

proc_dir="/proc"
output_file="proc_info.txt"
log_file="proc_monitor.log"

# Проверка на вводимые аргументы для скрипта
if [ $# -eq 0 ]; then
    echo "Используйте: $0 param1 param2 ..."
    echo "Доступные параметры: cmdline, environ, limits, mounts, status, cwd, fd, fdinfo, root"
    exit 1
fi

params=("$@")

# Ширины столбцов
pid_width=5
name_width=20
param_width=50

# Заголовок таблицы
header=$(printf "%-${pid_width}s | %-${name_width}s" "PID" "Name")
for param in "${params[@]}"; do
    header+=" | $(printf "%-${param_width}s" "$param")"
done
echo "$header" > "$output_file"

# Разделительная линия для таблицы
total_width=$((pid_width + name_width + param_width*${#params[@]} + 3*(${#params[@]})))
printf '%*s\n' "$total_width" '' | tr ' ' '-' >> "$output_file"

# Получаем уже зафиксированные PID из лог-файла
if [[ -f "$log_file" ]]; then
    existing_pids=$(awk '{print $NF}' "$log_file")
else
    existing_pids=""
fi

current_time=$(date '+%Y-%m-%d %H:%M:%S')

for entry in "$proc_dir"/*; do
    if [[ -d "$entry" && $(basename "$entry") =~ ^[0-9]+$ ]]; then
        pid=$(basename "$entry")
        process_name=$(readlink "$entry/exe" 2>/dev/null)
        process_name=${process_name##*/}  
        [ -z "$process_name" ] && process_name="N/A"

        # Логирование новых процессов
        if ! grep -qw "$pid" <<< "$existing_pids"; then
            echo "$current_time Обнаружен новый процесс: PID=$pid Name=$process_name" >> "$log_file"
        fi

        row=$(printf "%-${pid_width}s | %-${name_width}s" "$pid" "$process_name")

        for param in "${params[@]}"; do
            src="$entry/$param"
            value="N/A"

            if [[ -e $src ]]; then
                if [[ -d $src ]]; then
                    files=($(ls -1 "$src" 2>/dev/null))
                    if [ ${#files[@]} -gt 3 ]; then
                        value="${files[0]},${files[1]},${files[2]}…"
                    else
                        value=$(IFS=,; echo "${files[*]}")
                    fi
                else
                    value=$(head -c 1024 "$src" 2>/dev/null | tr '\0\n' '  ' | tr -s ' ')
                    [ ${#value} -gt $param_width ] && value="${value:0:$param_width-1}…"
                    if [ "$param" == "mounts" ]; then
                        value=$(head -n 3 "$src" 2>/dev/null | tr '\0\n' '  ' | tr -s ' ')
                        [ ${#value} -gt $param_width ] && value="${value:0:$param_width-1}…"
                    fi
                fi
            fi

            row+=" | $(printf "%-${param_width}s" "$value")"
        done

        echo "$row" >> "$output_file"
    fi
done

echo "Таблица с информацией по параметрам (${params[*]}) сохранена в файл $output_file"
echo "Лог обновлён: $log_file"

