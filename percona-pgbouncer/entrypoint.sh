#!/bin/bash

# Function to update or add configuration in pgbouncer.ini under [databases] section
update_database_config() {
    local dbname="$1"
    local host="$2"
    local port="$3"
    local user="$4"
    local password="$5"
    local auth_type="$6"
    local file="/etc/pgbouncer/pgbouncer.ini"
    local temp_file=$(mktemp)

    if ! grep -q "\[databases\]" "$file"; then
        echo "[databases]" >> "$temp_file"
    fi

    local updated=false

    if [ "$auth_type" == "plain" ] || [ "$auth_type" == "scram-sha-256" ]; then
        password="$password"
    else
        password="md5$(echo -n "$password$user" | md5sum | cut -f 1 -d ' ')"
    fi
    echo "\"$user\" \"$password\"" >> /etc/pgbouncer/userlist.txt

    while IFS= read -r line; do
        if [[ $line == \[$dbname\] ]]; then
            echo "[$dbname]" >> "$temp_file"
            echo "host = $host" >> "$temp_file"
            echo "port = $port" >> "$temp_file"
            echo "user = $user" >> "$temp_file"
            updated=true
        elif [[ $line == \[databases\] && $updated == false ]]; then
            echo "$line" >> "$temp_file"
            echo "$dbname = host=$host port=$port user=$user" >> "$temp_file"
            updated=true
        else
            echo "$line" >> "$temp_file"
        fi
    done < "$file"

    # Move the updated temp file to replace the original file
    mv "$temp_file" "$file"
}

# Default values
: ${DATABASES_HOST:=localhost}
: ${DATABASES_PORT:=6432}
: ${DATABASES_USER:=test}
: ${DATABASES_PASSWORD:=testing}
: ${DATABASES_DBNAME:=testdb}
: ${AUTH_TYPE:-md5}

# Update or add database connection settings in pgbouncer.ini under [databases] section
update_database_config "$DATABASES_DBNAME" "$DATABASES_HOST" "$DATABASES_PORT" "$DATABASES_USER" "$DATABASES_PASSWORD" "$AUTH_TYPE"

# Start pgBouncer
exec /usr/bin/pgbouncer /etc/pgbouncer/pgbouncer.ini

