/*
 * Copyright (C) 2021 NemacDE.
 *
 * Author:     Reoin Wong <reion@nemacde.com>
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

import QtQuick 2.12
import QtQuick.Window 2.12
import QtQuick.Controls 2.12
import QtQuick.Layouts 1.12
import QtGraphicalEffects 1.0

import Nemac.Launcher 1.0
import Nemac.System 1.0 as System
import NemacUI 1.0 as NemacUI

Item {
    id: root

    property bool showed: launcher.showed
    property int iconSize: 52

    readonly property int popupW: Math.min(460, root.width - 32)
    readonly property int popupH: Math.min(540, root.height - launcher.bottomMargin - 80)
    readonly property int popupX: (root.width - popupW) / 2
    readonly property int popupY: root.height - launcher.bottomMargin - popupH - 14

    property alias uninstallDialog: _uninstallDialog

    AppManager {
        id: appManager
    }

    Dialog {
        id: _uninstallDialog

        property var desktopPath: ""
        property var appName: ""

        width: _uninstallDialogLayout.implicitWidth + NemacUI.Units.largeSpacing * 2
        height: _uninstallDialogLayout.implicitHeight + NemacUI.Units.largeSpacing * 2

        modal: true

        x: (root.width - width) / 2
        y: (root.height - height) / 2

        ColumnLayout {
            id: _uninstallDialogLayout
            anchors.centerIn: parent
            anchors.margins: NemacUI.Units.largeSpacing
            spacing: NemacUI.Units.largeSpacing * 1.5

            Label {
                text: qsTr("Are you sure you want to uninstall %1 ?").arg(_uninstallDialog.appName)
                wrapMode: Text.WordWrap
            }

            RowLayout {
                spacing: NemacUI.Units.largeSpacing

                Button {
                    text: qsTr("Cancel")
                    onClicked: _uninstallDialog.close()
                    Layout.fillWidth: true
                }

                Button {
                    flat: true
                    text: qsTr("Uninstall")
                    Layout.fillWidth: true
                    onClicked: {
                        _uninstallDialog.close()
                        appManager.uninstall(_uninstallDialog.desktopPath)
                    }
                }
            }
        }
    }

    Connections {
        target: launcher

        function onVisibleChanged(visible) {
            if (!visible) {
                _uninstallDialog.close()
            }
        }
    }

    System.Wallpaper {
        id: backend
    }

    LauncherModel {
        id: launcherModel
    }

    Connections {
        target: launcherModel
        function onApplicationLaunched() {
            launcher.hideWindow()
        }
    }

    // Dim overlay — click outside to close
    Rectangle {
        anchors.fill: parent
        color: "#000000"
        opacity: showed ? 0.30 : 0
        Behavior on opacity { NumberAnimation { duration: 220 } }
    }

    MouseArea {
        anchors.fill: parent
        z: -1
        onClicked: launcher.hideWindow()
    }

    // ── POPUP PANEL ─────────────────────────────────────────────────
    Item {
        id: popupRoot
        x: popupX
        y: popupY
        width: popupW
        height: popupH

        opacity: showed ? 1.0 : 0.0
        scale:   showed ? 1.0 : 0.90
        transformOrigin: Item.Bottom

        Behavior on opacity { NumberAnimation { duration: 200; easing.type: Easing.OutQuad } }
        Behavior on scale   { NumberAnimation { duration: 220; easing.type: Easing.OutBack; easing.overshoot: 0.3 } }

        // Dark glass panel background
        Rectangle {
            anchors.fill: parent
            radius: 20
            color: Qt.rgba(0.07, 0.07, 0.13, 0.92)
            border.color: Qt.rgba(1, 1, 1, 0.09)
            border.width: 1
        }

        // Top highlight line
        Rectangle {
            x: 20; y: 0
            width: parent.width - 40
            height: 1
            color: Qt.rgba(1, 1, 1, 0.18)
        }

        ColumnLayout {
            anchors.fill: parent
            anchors.margins: 14
            spacing: 10

            // Search bar
            TextField {
                id: textField
                Layout.fillWidth: true
                height: 36
                leftPadding: _searchIcon.width + 14
                rightPadding: 10
                selectByMouse: true
                color: "white"
                font.pixelSize: 13

                Item {
                    id: placeHolderItem
                    height: parent.height
                    width: _phRow.implicitWidth
                    opacity: 0.5
                    x: textField.activeFocus ? 8 : (parent.width - width) / 2
                    y: 0
                    Behavior on x { NumberAnimation { duration: 180 } }

                    RowLayout {
                        id: _phRow
                        anchors.fill: parent
                        spacing: 6
                        Image {
                            id: _searchIcon
                            height: 16; width: 16
                            sourceSize: Qt.size(16, 16)
                            source: "qrc:/images/system-search-symbolic.svg"
                        }
                        Label {
                            color: "white"
                            font.pixelSize: 13
                            text: qsTr("Search")
                            visible: !textField.length && !textField.preeditText
                        }
                    }
                }

                background: Rectangle {
                    radius: 9
                    color: Qt.rgba(1, 1, 1, 0.11)
                    border.color: Qt.rgba(1, 1, 1, 0.07)
                    border.width: 1
                }

                Timer {
                    id: searchTimer
                    interval: 300
                    repeat: false
                    onTriggered: launcherModel.search(textField.text)
                }

                onTextChanged: {
                    if (text === "") launcherModel.search("")
                    else searchTimer.start()
                }
                Keys.onEscapePressed: launcher.hideWindow()
            }

            // App grid
            Item {
                id: gridItem
                Layout.fillWidth: true
                Layout.fillHeight: true

                Keys.enabled: true
                Keys.forwardTo: appView

                AllAppsView {
                    id: appView
                    anchors.fill: parent
                    searchMode: textField.text
                    focus: true

                    Keys.enabled: true
                    Keys.onPressed: {
                        if (event.key === Qt.Key_Escape)
                            launcher.hideWindow()
                        if ((event.key >= Qt.Key_A && event.key <= Qt.Key_Z) ||
                                event.key >= Qt.Key_0 && event.key <= Qt.Key_9) {
                            textField.forceActiveFocus()
                            textField.text = event.text
                        }
                    }

                    Label {
                        anchors.centerIn: parent
                        text: qsTr("Not found")
                        font.pixelSize: 15
                        color: Qt.rgba(1, 1, 1, 0.45)
                        visible: appView.count === 0
                    }
                }
            }

            // Page dots
            PageIndicator {
                id: pageIndicator
                count: appView.count
                currentIndex: appView.currentIndex
                onCurrentIndexChanged: appView.currentIndex = currentIndex
                interactive: true
                spacing: 7
                Layout.alignment: Qt.AlignHCenter
                visible: appView.count > 1

                delegate: Rectangle {
                    width: 6; height: 6
                    radius: 3
                    color: index === pageIndicator.currentIndex
                           ? "white" : Qt.rgba(1, 1, 1, 0.28)
                    Behavior on color { ColorAnimation { duration: 150 } }
                }
            }
        }
    }

    Timer {
        id: clearSearchTimer
        interval: 100
        onTriggered: textField.text = ""
    }

    Connections {
        target: launcher

        function onVisibleChanged(visible) {
            if (visible) {
                textField.focus = false
                appView.focus = true
                appView.forceActiveFocus()
            } else {
                clearSearchTimer.restart()
            }
        }
    }
}
