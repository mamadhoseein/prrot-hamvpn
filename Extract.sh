#!/bin/bash

clear  # پاک کردن صفحه قبل از شروع

# باز کردن پورت 8000 تو فایروال (بدون خطا اگر قبلا باز شده)
sudo ufw allow 8000/tcp 2>/dev/null || true

clear  # پاک کردن صفحه قبل از شروع

BRAND_NAME="HAM VPN"

print_header() {
    echo -e "\e[1;34m=========================================\e[0m"
    # وسط‌چین کردن نام برند با طول خط 41 کاراکتر
    printf "\e[1;33m%*s%*s\e[0m\n" $(((${#BRAND_NAME}+41)/2)) "$BRAND_NAME" $(((41 - ${#BRAND_NAME})/2)) ""
    echo -e "\e[1;34m=========================================\e[0m\n"
}

read -p "🌐 Panel URL (e.g. http://127.0.0.1:2053): " PANEL_URL
read -p "👤 Username: " USERNAME
read -s -p "🔑 Password: " PASSWORD
echo ""

COOKIE_FILE=$(mktemp)

LOGIN_RESPONSE=$(curl -s -c "$COOKIE_FILE" -d "username=$USERNAME&password=$PASSWORD" "$PANEL_URL/login")

if echo "$LOGIN_RESPONSE" | grep -q "Login Successful"; then
    echo -e "\e[32m✅ Login successful!\e[0m"
else
    echo -e "\e[31m❌ Login failed!\e[0m"
    rm -f "$COOKIE_FILE"
    exit 1
fi

start_http_server() {
    PID=$(lsof -ti:8000)
    if [ -n "$PID" ]; then
        kill -9 $PID
    fi
    nohup python3 -m http.server 8000 > /dev/null 2>&1 &
}

while true; do
    clear
    print_header
    echo -e "\e[35m==== 3x-ui Panel Menu ====\e[0m"
    echo -e "\e[33m1.\e[0m Extract ports"
    echo -e "\e[33m2.\e[0m Exit"
    echo ""
    read -p "🔷 Your choice: " CHOICE

    case "$CHOICE" in
        1)
            INBOUNDS_JSON=$(curl -s -b "$COOKIE_FILE" "$PANEL_URL/panel/api/inbounds/list")
            PORTS=$(echo "$INBOUNDS_JSON" | jq -r '.obj[].port' | grep -v null | paste -sd "," -)

            # استخراج پورت پنل از PANEL_URL
            PANEL_PORT=$(echo "$PANEL_URL" | sed -n 's#.*:\([0-9]\+\).*#\1#p')

            if [ -z "$PORTS" ]; then
                echo -e "\e[33m⚠️ No ports found.\e[0m"
            else
                echo -e "\e[36m✅ Ports extracted: $PORTS\e[0m"
                echo "$PORTS,$PANEL_PORT" > ports.txt
                echo -e "\e[32m✅ Ports and panel port saved to ports.txt\e[0m"

                start_http_server

                IP=$(hostname -I | awk '{print $1}')
                echo -e "\e[34mDownload the file here:\e[0m http://$IP:8000/ports.txt"

                echo -e "\e[33m📥 Please download the file and press Enter to continue...\e[0m"
                read  # منتظر می‌مونه تا کاربر Enter بزنه

                # بستن پورت 8000 و توقف سرور
                fuser -k 8000/tcp 2>/dev/null
                sudo ufw deny 8000/tcp 2>/dev/null || true
                echo -e "\e[31m⛔ Port 8000 closed.\e[0m"
            fi

            read -p "Press Enter to return to menu..."
            ;;
        2)
            echo -e "\e[34m👋 Goodbye!\e[0m"
            rm -f "$COOKIE_FILE"
            exit 0
            ;;
        *)
            echo -e "\e[31m❌ Invalid choice, please try again.\e[0m"
            read -p "Press Enter to return to menu..."
            ;;
    esac
done
