#!/bin/bash

# Uploader for GitHub Releases (PhantomForge Edition)
CONFIG=".phantom-forge.json"

if [ ! -f "$CONFIG" ]; then
    echo "Ошибка: .phantom-forge.json не найден."
    exit 1
fi

# Check for gh CLI or use curl with token
if ! command -v gh &> /dev/null; then
    echo "Ошибка: GitHub CLI (gh) не установлен. Установите его: sudo pacman -S github-cli"
    exit 1
fi

echo "=== Загрузчик в GitHub Releases ==="
echo "-------------------"

read -e -p "Путь к файлу пакета: " FILE_PATH
FILE_PATH="${FILE_PATH/#\~/$HOME}"

if [ ! -f "$FILE_PATH" ]; then
    echo "Ошибка: Файл не найден: $FILE_PATH"
    exit 1
fi

read -p "Введите тег релиза (например, v3.6): " TAG
[ -z "$TAG" ] && TAG="v$(date +'%Y.%m.%d')"

echo "-------------------"
echo "Загрузка $FILE_PATH как релиз $TAG..."

# Create release if it doesn't exist and upload
gh release create "$TAG" "$FILE_PATH" --title "Release $TAG" --notes "Автоматическая сборка через PhantomForge" || \
gh release upload "$TAG" "$FILE_PATH" --clobber

echo "-------------------"
echo "Готово! Пакет загружен в релизы."
