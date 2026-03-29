/*
 * Copyright (C) 2021 NemacDE Team.
 *
 * Author:     Reion Wong <reion@nemacde.com>
 *
 * This program is free software: you can redistribute it and/or modify
 * it under the terms of the GNU General Public License as published by
 * the Free Software Foundation, either version 3 of the License, or
 * any later version.
 *
 * This program is distributed in the hope that it will be useful,
 * but WITHOUT ANY WARRANTY; without even the implied warranty of
 * MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
 * GNU General Public License for more details.
 *
 * You should have received a copy of the GNU General Public License
 * along with this program.  If not, see <http://www.gnu.org/licenses/>.
 */

#include "keyboardsearchmanager.h"

KeyboardSearchManager *KEYBORDSRARCH_MANAGER_SELF = nullptr;

KeyboardSearchManager *KeyboardSearchManager::self()
{
    if (!KEYBORDSRARCH_MANAGER_SELF)
        KEYBORDSRARCH_MANAGER_SELF = new KeyboardSearchManager;

    return KEYBORDSRARCH_MANAGER_SELF;
}

KeyboardSearchManager::KeyboardSearchManager(QObject *parent)
    : QObject(parent)
    , m_timeout(500)
{
}

void KeyboardSearchManager::addKeys(const QString &keys)
{
    if (!keys.isEmpty()) {
        emit searchTextChanged(keys, false);
    }
}
