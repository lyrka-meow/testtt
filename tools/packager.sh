#!/bin/bash

# Packager for Nemac DE (PhantomForge Edition)
CONFIG=".phantom-forge.json"

if [ ! -f "$CONFIG" ]; then
    echo "Ошибка: .phantom-forge.json не найден."
    exit 1
fi

PROJECT_NAME=$(jq -r '.project' "$CONFIG")
VERSION=$(grep "Version=" tools/installer.sh | cut -d'=' -f2 || echo "1.0")

echo "=== Сборщик Пакета: $PROJECT_NAME ==="
echo "Версия: $VERSION"
echo "-------------------"

# Create a temporary staging directory
STAGING_DIR=$(mktemp -d)
mkdir -p "$STAGING_DIR/$PROJECT_NAME"

# Copy all groups to staging
groups=$(jq -r '.groups[].name' "$CONFIG")
for g in $groups; do
    echo "Копирование группы: $g..."
    mkdir -p "$STAGING_DIR/$PROJECT_NAME/$g"
    # Get items in this group
    items=$(jq -r ".groups[] | select(.name == \"$g\") | .items[].path" "$CONFIG")
    for item in $items; do
        if [ -e "$item" ]; then
            cp -r "$item" "$STAGING_DIR/$PROJECT_NAME/$g/"
        fi
    done
done

# Also copy root files
cp LICENSE README.md forge.json "$STAGING_DIR/$PROJECT_NAME/" 2>/dev/null || true

PACKAGE_NAME="${PROJECT_NAME}-${VERSION}.tar.gz"

echo "-------------------"
read -e -p "Куда сохранить пакет? (по умолчанию ~/): " DEST_PATH
DEST_PATH="${DEST_PATH/#\~/$HOME}"
[ -z "$DEST_PATH" ] && DEST_PATH="$HOME"
mkdir -p "$DEST_PATH"

echo "Создание архива: $PACKAGE_NAME..."
tar -czf "$DEST_PATH/$PACKAGE_NAME" -C "$STAGING_DIR" "$PROJECT_NAME"

rm -rf "$STAGING_DIR"

echo "-------------------"
echo "Пакет успешно создан: $DEST_PATH/$PACKAGE_NAME"
