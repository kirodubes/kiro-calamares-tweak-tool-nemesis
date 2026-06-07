import QtCore
import QtQuick
import QtQuick.Window
import QtQuick.Controls
import QtQuick.Layouts

Window {
    id: win
    visible: true
    title: "Calamares Tweak Tool — NEMESIS"
    width: 720
    height: 670
    color: win.t.bgBottom

    // ── Themes (day/night + swatches, ported from kiro-keybindings) ─────
    readonly property var themes: ({
        "kiro":      { bgTop: "#111C33", bgBottom: "#020617", cardBg: "#0C1B33", cardBorder: "#1E293B", title: "#ffffff", subtext: "#94A3B8", desc: "#E2E8F0", accentA: "#0195F7", accentB: "#2FC328" },
        "arcdark":   { bgTop: "#404552", bgBottom: "#2F343F", cardBg: "#3B3F4C", cardBorder: "#2B2E39", title: "#D3DAE3", subtext: "#8B9BB4", desc: "#CFD6E6", accentA: "#5294E2", accentB: "#7FB0EA" },
        "nord":      { bgTop: "#3B4252", bgBottom: "#2E3440", cardBg: "#39404E", cardBorder: "#4C566A", title: "#ECEFF4", subtext: "#81A1C1", desc: "#D8DEE9", accentA: "#88C0D0", accentB: "#5E81AC" },
        "dracula":   { bgTop: "#343746", bgBottom: "#282A36", cardBg: "#2E303E", cardBorder: "#44475A", title: "#F8F8F2", subtext: "#6272A4", desc: "#E6E6E6", accentA: "#BD93F9", accentB: "#FF79C6" },
        "gruvbox":   { bgTop: "#3C3836", bgBottom: "#282828", cardBg: "#32302F", cardBorder: "#504945", title: "#EBDBB2", subtext: "#A89984", desc: "#EBDBB2", accentA: "#FABD2F", accentB: "#FE8019" },
        "catppuccin":{ bgTop: "#1E1E2E", bgBottom: "#181825", cardBg: "#28283B", cardBorder: "#45475A", title: "#CDD6F4", subtext: "#A6ADC8", desc: "#CDD6F4", accentA: "#89B4FA", accentB: "#CBA6F7" },
        "neon":      { bgTop: "#0A0A14", bgBottom: "#050507", cardBg: "#12101F", cardBorder: "#2B2350", title: "#EAFEFF", subtext: "#67E8F9", desc: "#C7F7FF", accentA: "#22D3EE", accentB: "#FF2BD6" },
        "kirolight": { bgTop: "#F8FAFF", bgBottom: "#E9F0FB", cardBg: "#FFFFFF", cardBorder: "#E2E8F0", title: "#0F172A", subtext: "#64748B", desc: "#1E293B", accentA: "#0195F7", accentB: "#2FC328" },
        "arclight":  { bgTop: "#FBFCFD", bgBottom: "#EFF1F3", cardBg: "#FFFFFF", cardBorder: "#DCDFE3", title: "#2E3436", subtext: "#7A828E", desc: "#3B4045", accentA: "#5294E2", accentB: "#3B82C4" },
        "nordlight": { bgTop: "#ECEFF4", bgBottom: "#E5E9F0", cardBg: "#FFFFFF", cardBorder: "#D8DEE9", title: "#2E3440", subtext: "#4C566A", desc: "#3B4252", accentA: "#5E81AC", accentB: "#4C7E8E" },
        "draculalight": { bgTop: "#FBF8F1", bgBottom: "#F2ECDD", cardBg: "#FFFFFF", cardBorder: "#E6DEC9", title: "#22212C", subtext: "#7A7560", desc: "#34324A", accentA: "#644AC9", accentB: "#A3144D" },
        "gruvboxlight": { bgTop: "#FBF1C7", bgBottom: "#F2E5BC", cardBg: "#F9F5D7", cardBorder: "#D5C4A1", title: "#3C3836", subtext: "#7C6F64", desc: "#3C3836", accentA: "#B57614", accentB: "#AF3A03" },
        "catppuccinlatte": { bgTop: "#EFF1F5", bgBottom: "#E6E9EF", cardBg: "#FFFFFF", cardBorder: "#CCD0DA", title: "#4C4F69", subtext: "#6C6F85", desc: "#4C4F69", accentA: "#1E66F5", accentB: "#8839EF" },
        "solarizedlight": { bgTop: "#FDF6E3", bgBottom: "#EEE8D5", cardBg: "#FFFEF7", cardBorder: "#E0DAC4", title: "#586E75", subtext: "#93A1A1", desc: "#657B83", accentA: "#268BD2", accentB: "#2AA198" }
    })
    readonly property var darkThemes: [
        { key: "kiro", label: "Kiro", color: "#0195F7" },
        { key: "arcdark", label: "Arc-Dark", color: "#5294E2" },
        { key: "nord", label: "Nord", color: "#88C0D0" },
        { key: "dracula", label: "Dracula", color: "#BD93F9" },
        { key: "gruvbox", label: "Gruvbox", color: "#FABD2F" },
        { key: "catppuccin", label: "Catppuccin", color: "#89B4FA" },
        { key: "neon", label: "Neon", color: "#22D3EE" }
    ]
    readonly property var lightThemes: [
        { key: "kirolight", label: "Kiro Light", color: "#0276D6" },
        { key: "arclight", label: "Arc-Light", color: "#5294E2" },
        { key: "nordlight", label: "Nord Light", color: "#5E81AC" },
        { key: "draculalight", label: "Dracula Light", color: "#644AC9" },
        { key: "gruvboxlight", label: "Gruvbox Light", color: "#B57614" },
        { key: "catppuccinlatte", label: "Catppuccin Latte", color: "#1E66F5" },
        { key: "solarizedlight", label: "Solarized Light", color: "#268BD2" }
    ]
    readonly property var activeThemeList: appSettings.mode === "dark" ? win.darkThemes : win.lightThemes
    property string themeName: appSettings.mode === "dark" ? appSettings.themeDark : appSettings.themeLight
    readonly property var t: themes[themeName] !== undefined ? themes[themeName] : themes["kiro"]

    // Semantic colours are mode-derived (not per-theme): amber warning, red danger.
    readonly property color warn: appSettings.mode === "dark" ? "#F59E0B" : "#B45309"
    readonly property color danger: appSettings.mode === "dark" ? "#F87171" : "#DC2626"
    readonly property bool savedNow: backend.status.indexOf("Saved:") === 0

    // Translucent tint of a colour over the card — works on light and dark.
    function tint(c, a) { return Qt.rgba(c.r, c.g, c.b, a) }

    Settings {
        id: appSettings
        category: "ui"
        property string mode: "dark"
        property string themeDark: "kiro"
        property string themeLight: "kirolight"
    }

    Component.onCompleted: {
        x = Math.round(Screen.width / 2 - width / 2)
        y = Math.round(Screen.height / 2 - height / 2)
    }

    Rectangle {
        anchors.fill: parent
        gradient: Gradient {
            GradientStop { position: 0.0; color: win.t.bgTop }
            GradientStop { position: 1.0; color: win.t.bgBottom }
        }

        ColumnLayout {
            anchors.fill: parent
            anchors.margins: 28
            spacing: 18

            // ── Header ──────────────────────────────────────────────────
            RowLayout {
                Layout.fillWidth: true
                spacing: 14
                Image { source: logoPath; sourceSize.height: 40; fillMode: Image.PreserveAspectFit }
                ColumnLayout {
                    spacing: 1
                    Text { text: "Calamares Tweak Tool"; color: win.t.title; font.pixelSize: 22; font.bold: true }
                    Text {
                        text: "dev · filesystem · bootloader · encryption"
                        color: win.t.subtext; font.pixelSize: 12
                    }
                }
                Item { Layout.fillWidth: true }

                // theme switcher: day/night toggle + swatch row
                Row {
                    spacing: 10
                    Rectangle {
                        width: 22; height: 22; radius: 11
                        anchors.verticalCenter: parent.verticalCenter
                        color: "transparent"; border.width: 1; border.color: win.t.subtext
                        Text {
                            anchors.centerIn: parent
                            text: appSettings.mode === "dark" ? "☾" : "☀"
                            color: win.t.subtext; font.pixelSize: 13
                        }
                        MouseArea {
                            anchors.fill: parent; hoverEnabled: true; cursorShape: Qt.PointingHandCursor
                            onClicked: appSettings.mode = (appSettings.mode === "dark" ? "light" : "dark")
                            ToolTip.visible: containsMouse
                            ToolTip.text: appSettings.mode === "dark" ? "Switch to light themes" : "Switch to dark themes"
                        }
                    }
                    Repeater {
                        model: win.activeThemeList
                        delegate: Rectangle {
                            width: 20; height: 20; radius: 10
                            anchors.verticalCenter: parent.verticalCenter
                            color: modelData.color
                            border.width: win.themeName === modelData.key ? 2 : 0
                            border.color: win.t.title
                            opacity: win.themeName === modelData.key ? 1.0 : 0.6
                            Behavior on opacity { NumberAnimation { duration: 120 } }
                            MouseArea {
                                anchors.fill: parent; hoverEnabled: true; cursorShape: Qt.PointingHandCursor
                                onClicked: {
                                    if (appSettings.mode === "dark")
                                        appSettings.themeDark = modelData.key
                                    else
                                        appSettings.themeLight = modelData.key
                                }
                                ToolTip.visible: containsMouse
                                ToolTip.text: modelData.label
                            }
                        }
                    }
                }
            }

            Rectangle {
                Layout.fillWidth: true; height: 2
                gradient: Gradient {
                    orientation: Gradient.Horizontal
                    GradientStop { position: 0.0; color: win.t.accentA }
                    GradientStop { position: 1.0; color: win.t.accentB }
                }
            }

            // ── Missing-config banner ───────────────────────────────────
            Rectangle {
                Layout.fillWidth: true
                visible: !backend.configExists
                color: win.tint(win.danger, 0.12); border.color: win.danger; border.width: 1; radius: 10
                implicitHeight: 44
                Text {
                    anchors.centerIn: parent
                    text: "No Calamares config found at " + backend.configDir + "  —  try --sample for the bundled sample"
                    color: win.danger; font.pixelSize: 13
                }
            }

            // ── Filesystem ──────────────────────────────────────────────
            Rectangle {
                Layout.fillWidth: true
                color: win.t.cardBg; border.color: win.t.cardBorder; border.width: 1; radius: 14
                implicitHeight: 64
                enabled: backend.configExists
                RowLayout {
                    anchors { left: parent.left; right: parent.right; verticalCenter: parent.verticalCenter; margins: 16 }
                    ColumnLayout {
                        spacing: 1
                        Text { text: "FILESYSTEM"; color: win.t.accentA; font.pixelSize: 12; font.bold: true; font.letterSpacing: 1.4 }
                        Text { text: "root partition · defaultFileSystemType"; color: win.t.subtext; font.pixelSize: 12 }
                    }
                    Item { Layout.fillWidth: true }
                    ComboBox {
                        id: fsCombo
                        Layout.preferredWidth: 160
                        model: backend.filesystems
                        currentIndex: Math.max(0, backend.filesystems.indexOf(backend.filesystem))
                        onActivated: backend.setFilesystem(currentText)
                        contentItem: Text {
                            text: fsCombo.displayText
                            color: win.t.desc; font.pixelSize: 15
                            leftPadding: 12; verticalAlignment: Text.AlignVCenter
                        }
                    }
                }
            }

            // ── Bootloader ──────────────────────────────────────────────
            Rectangle {
                Layout.fillWidth: true
                color: win.t.cardBg; border.color: win.t.cardBorder; border.width: 1; radius: 14
                implicitHeight: blCol.implicitHeight + 32
                enabled: backend.configExists
                ColumnLayout {
                    id: blCol
                    anchors { left: parent.left; right: parent.right; top: parent.top; margins: 16 }
                    spacing: 10
                    Text { text: "BOOTLOADER"; color: win.t.accentA; font.pixelSize: 12; font.bold: true; font.letterSpacing: 1.4 }
                    RowLayout {
                        spacing: 10
                        Repeater {
                            model: backend.bootloaders
                            delegate: RadioButton {
                                text: modelData
                                checked: backend.bootloader === modelData
                                onClicked: backend.setBootloader(modelData)
                                contentItem: Text {
                                    text: parent.text; color: win.t.desc; font.pixelSize: 15
                                    leftPadding: parent.indicator.width + 8; verticalAlignment: Text.AlignVCenter
                                }
                            }
                        }
                    }
                }
            }

            // ── Encryption ──────────────────────────────────────────────
            Rectangle {
                Layout.fillWidth: true
                color: win.t.cardBg; border.color: win.t.cardBorder; border.width: 1; radius: 14
                implicitHeight: 64
                enabled: backend.configExists
                RowLayout {
                    anchors { left: parent.left; right: parent.right; verticalCenter: parent.verticalCenter; margins: 16 }
                    ColumnLayout {
                        spacing: 1
                        Text { text: "ENCRYPTION"; color: win.t.accentA; font.pixelSize: 12; font.bold: true; font.letterSpacing: 1.4 }
                        Text { text: "show the “Encrypt system” option in the installer"; color: win.t.subtext; font.pixelSize: 12 }
                    }
                    Item { Layout.fillWidth: true }
                    Switch {
                        checked: backend.encryption
                        onToggled: backend.setEncryption(checked)
                    }
                }
            }

            // ── LUKS readout ────────────────────────────────────────────
            Rectangle {
                Layout.fillWidth: true
                radius: 14; border.width: 1
                color: win.tint(win.t.accentB, 0.13)
                border.color: win.t.accentB
                implicitHeight: 70
                opacity: backend.encryption ? 1.0 : 0.5
                RowLayout {
                    anchors { left: parent.left; right: parent.right; verticalCenter: parent.verticalCenter; margins: 16 }
                    spacing: 14
                    Text {
                        text: backend.luksGeneration.toUpperCase()
                        color: win.t.accentB
                        font.pixelSize: 24; font.bold: true
                    }
                    Text {
                        Layout.fillWidth: true
                        wrapMode: Text.WordWrap
                        color: win.t.desc; font.pixelSize: 13
                        text: "Both GRUB (2.14+) and systemd-boot unlock LUKS2/Argon2id at boot — the stronger KDF."
                    }
                }
            }

            Item { Layout.fillHeight: true }

            // ── Status ──────────────────────────────────────────────────
            // Prominent green "saved" pill — centered, pulses on every Apply.
            Rectangle {
                id: savedPill
                Layout.alignment: Qt.AlignHCenter
                Layout.maximumWidth: parent.width
                visible: win.savedNow
                radius: height / 2
                color: win.tint(win.t.accentB, 0.15)
                border.width: 2
                border.color: win.t.accentB
                implicitWidth: savedRow.implicitWidth + 40
                implicitHeight: savedRow.implicitHeight + 18

                transform: Scale {
                    id: pillScale
                    origin.x: savedPill.width / 2
                    origin.y: savedPill.height / 2
                }

                // Flash overlay (sits under the text); opacity is pulsed on save.
                Rectangle {
                    id: savedFlash
                    anchors.fill: parent
                    radius: parent.radius
                    color: win.tint(win.t.accentB, 0.55)
                    opacity: 0
                }
                Row {
                    id: savedRow
                    anchors.centerIn: parent
                    spacing: 9
                    Text {
                        text: "✓"
                        color: win.t.accentB
                        font.pixelSize: 19; font.bold: true
                        anchors.verticalCenter: parent.verticalCenter
                    }
                    Text {
                        text: backend.status
                        color: win.t.accentB
                        font.pixelSize: 15; font.bold: true
                        anchors.verticalCenter: parent.verticalCenter
                    }
                }

                SequentialAnimation {
                    id: savedPulse
                    ParallelAnimation {
                        NumberAnimation { target: pillScale; properties: "xScale,yScale"; to: 1.09; duration: 140; easing.type: Easing.OutQuad }
                        NumberAnimation { target: savedFlash; property: "opacity"; from: 0.6; to: 0.0; duration: 650; easing.type: Easing.OutCubic }
                    }
                    NumberAnimation { target: pillScale; properties: "xScale,yScale"; to: 1.0; duration: 260; easing.type: Easing.OutBounce }
                }
                Connections {
                    target: backend
                    function onSaveTickChanged() { savedPulse.restart() }
                }
            }
            // Plain subtle status for every non-saved message.
            Text {
                Layout.fillWidth: true
                visible: !win.savedNow
                text: backend.status
                color: win.t.subtext; font.pixelSize: 12
                elide: Text.ElideRight
            }
            Text {
                Layout.fillWidth: true
                visible: backend.configExists && !backend.writable
                text: "Read-only: relaunch as root (e.g. sudo -E calamares-tweak-tool) to save changes."
                color: win.warn; font.pixelSize: 12
            }

            // ── Encryption reminder (visually apparent) ─────────────────
            Rectangle {
                Layout.fillWidth: true
                visible: backend.configExists
                radius: 12
                border.width: 2
                color: win.tint(backend.encryption ? win.t.accentB : win.warn, 0.13)
                border.color: backend.encryption ? win.t.accentB : win.warn
                implicitHeight: reminderText.implicitHeight + 26
                Text {
                    id: reminderText
                    anchors { left: parent.left; right: parent.right; verticalCenter: parent.verticalCenter; margins: 16 }
                    wrapMode: Text.WordWrap
                    horizontalAlignment: Text.AlignHCenter
                    font.pixelSize: 14
                    font.bold: true
                    color: backend.encryption ? win.t.accentB : win.warn
                    text: backend.encryption
                          ? "Encryption ON — don't forget to tick “Encrypt system”\nand set a passphrase in the installer."
                          : "⚠  Encryption is OFF — turn the switch on, or the installer won't offer to encrypt."
                }
            }

            // ── Actions ─────────────────────────────────────────────────
            RowLayout {
                Layout.fillWidth: true
                spacing: 12
                Button {
                    text: "Apply"
                    enabled: backend.configExists && backend.writable
                    onClicked: backend.apply()
                    Layout.preferredWidth: 120; Layout.preferredHeight: 42
                    contentItem: Text { text: parent.text; color: "#ffffff"; font.pixelSize: 15; font.bold: true
                                        horizontalAlignment: Text.AlignHCenter; verticalAlignment: Text.AlignVCenter }
                    background: Rectangle {
                        radius: 10
                        color: parent.enabled ? (parent.down ? Qt.darker(win.t.accentA, 1.2) : win.t.accentA) : win.t.cardBorder
                    }
                }
                Item { Layout.fillWidth: true }
                Button {
                    text: "Launch installer"
                    onClicked: backend.launchInstaller()
                    Layout.preferredWidth: 170; Layout.preferredHeight: 42
                    contentItem: Text { text: parent.text; color: win.t.desc; font.pixelSize: 15
                                        horizontalAlignment: Text.AlignHCenter; verticalAlignment: Text.AlignVCenter }
                    background: Rectangle { radius: 10; color: "transparent"; border.color: win.t.cardBorder; border.width: 1 }
                }
            }
        }
    }

    Shortcut { sequence: "Escape"; onActivated: Qt.quit() }
}
