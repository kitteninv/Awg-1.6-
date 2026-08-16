#!/bin/bash

set -euo pipefail

REPO_RAW="https://raw.githubusercontent.com/kitteninv/Awg-1.6-/main/files"

BOT_SRC="${REPO_RAW}/awg-telegram-bot"
SERVICE_SRC="${REPO_RAW}/awg-telegram-bot.service"

BOT_DST="/usr/local/bin/awg-telegram-bot"
SERVICE_DST="/etc/systemd/system/awg-telegram-bot.service"
CONFIG_DST="/etc/awg-monitor.conf"

echo "======================================"
echo " Amnezia AWG Telegram Bot Installer"
echo " Version 1.6"
echo "======================================"
echo

if [ "$(id -u)" -ne 0 ]; then
    echo "ERROR: запускать установщик нужно от root."
    exit 1
fi

echo "[1/7] Проверка зависимостей..."

for cmd in curl systemctl docker; do
    if ! command -v "$cmd" >/dev/null 2>&1; then
        echo "ERROR: не найдено: $cmd"
        exit 1
    fi
done

echo "OK"

echo
echo "[2/7] Проверка Amnezia AWG..."

if docker ps --format '{{.Names}}' 2>/dev/null | grep -qx "amnezia-awg2"; then
    echo "OK: контейнер amnezia-awg2 найден."
else
    echo "WARNING: контейнер amnezia-awg2 не найден среди запущенных."
    echo "Продолжаем установку."
fi

echo
echo "[3/7] Загрузка файлов..."

TMP_DIR="$(mktemp -d)"
trap 'rm -rf "$TMP_DIR"' EXIT

curl -fsSL "$BOT_SRC" -o "$TMP_DIR/awg-telegram-bot"
curl -fsSL "$SERVICE_SRC" -o "$TMP_DIR/awg-telegram-bot.service"

echo "OK"

echo
echo "[4/7] Установка файлов..."

install -m 0755 "$TMP_DIR/awg-telegram-bot" "$BOT_DST"
install -m 0644 "$TMP_DIR/awg-telegram-bot.service" "$SERVICE_DST"

echo "OK"

echo
echo "[5/7] Настройка Telegram..."

echo
echo "Введите данные Telegram-бота."
echo

read -r -p "Введите новый Telegram BOT_TOKEN: " BOT_TOKEN

if [ -z "$BOT_TOKEN" ]; then
    echo "ERROR: BOT_TOKEN не может быть пустым."
    exit 1
fi

read -r -p "Введите Telegram CHAT_ID: " CHAT_ID

if [ -z "$CHAT_ID" ]; then
    echo "ERROR: CHAT_ID не может быть пустым."
    exit 1
fi

cat > "$CONFIG_DST" <<EOF
BOT_TOKEN='$BOT_TOKEN'
CHAT_ID='$CHAT_ID'
OFF_TIMEOUT=1800
EOF

chmod 600 "$CONFIG_DST"

unset BOT_TOKEN
unset CHAT_ID

echo "Конфигурация сохранена."

echo
echo "[6/7] Настройка systemd..."

systemctl daemon-reload
systemctl enable awg-telegram-bot.service

echo "OK"

echo
echo "[7/7] Запуск сервиса..."

systemctl restart awg-telegram-bot.service

sleep 2

if systemctl is-active --quiet awg-telegram-bot.service; then
    echo
    echo "======================================"
    echo " УСТАНОВКА УСПЕШНО ЗАВЕРШЕНА"
    echo "======================================"
    echo
    echo "Сервис: awg-telegram-bot.service"
    echo "Статус: active (running)"
    echo
    echo "Проверка:"
    echo "systemctl status awg-telegram-bot.service --no-pager"
else
    echo
    echo "======================================"
    echo " ОШИБКА ЗАПУСКА СЕРВИСА"
    echo "======================================"
    echo
    systemctl --no-pager --full status awg-telegram-bot.service || true
    echo
    echo "Последние логи:"
    journalctl -u awg-telegram-bot.service -n 50 --no-pager || true
    exit 1
fi
