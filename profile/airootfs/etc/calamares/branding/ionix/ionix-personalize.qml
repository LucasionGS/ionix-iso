/* "Personalize" installer page: desktop theme and bar position.
 *
 * A notesqml instance (see settings.conf and modules/ionix-personalize.conf).
 * Choices go into Calamares' GlobalStorage, where shellprocess.conf hands them to
 * ionix-post-install as ${gs[ionixTheme]} and ${gs[ionixBar]}. A shellprocess
 * command with a key missing from GlobalStorage fails, so every key this page
 * owns is written as soon as the page exists, not only when something is clicked.
 *
 * It also mirrors the users page's "log in automatically" checkbox into
 * ionixAutologin: that page only sets `autoLoginUser` when the box is ticked and
 * removes it otherwise, and a removed key cannot be passed to a shellprocess.
 */
import io.calamares.core 1.0
import io.calamares.ui 1.0

import QtQuick
import QtQuick.Layouts

Item {
    id: page

    readonly property color bgDeep:     "#0f0a18"
    readonly property color card:       "#2d2d3f"
    readonly property color hover:      "#3a2d50"
    readonly property color border:     "#4a3d60"
    readonly property color muted:      "#6b5f80"
    readonly property color text:       "#c4b5fd"
    readonly property color bright:     "#e2d9f3"
    readonly property color accent:     "#9b59b6"
    readonly property color accentHi:   "#a855f7"
    readonly property color accentLite: "#c084fc"
    readonly property string mono:      "JetBrainsMono Nerd Font"
    readonly property string sans:      "Noto Sans"

    // Palettes from each theme's quickshell/theme.json, for the previews only.
    // `bar` is the theme's own bar.position, which "Theme default" resolves to.
    readonly property var themes: [
        { id: "ionix",          name: "Ionix",          blurb: "The signature deep violet.",
          bg: "#1a1025", deep: "#0f0a18", card: "#2d2d3f", accent: "#9b59b6", hi: "#a855f7", lite: "#c084fc", bar: "top" },
        { id: "ionix-adaptive", name: "Ionix Adaptive", blurb: "Colours drawn from your wallpaper.",
          bg: "#1a1025", deep: "#0f0a18", card: "#2d2d3f", accent: "#48dbfb", hi: "#a855f7", lite: "#f39c12", bar: "top", adaptive: true },
        { id: "ionix-pro",      name: "Ionix Pro",      blurb: "Neon violet and cyan, high contrast.",
          bg: "#0d0620", deep: "#070312", card: "#1a0d33", accent: "#b026ff", hi: "#00f0ff", lite: "#ff2bd6", bar: "top" },
        { id: "winix",          name: "Winix",          blurb: "Familiar blues, docked at the bottom.",
          bg: "#202020", deep: "#1b1b1b", card: "#2b2b2b", accent: "#0078d4", hi: "#4cc2ff", lite: "#60cdff", bar: "bottom" }
    ]
    readonly property var positions: ["default", "top", "bottom", "left", "right"]

    property string theme: "ionix"
    property string bar: "default"

    readonly property var currentTheme: themes.find(t => t.id === page.theme)
    readonly property string effectiveBar: bar === "default" ? currentTheme.bar : bar

    function store(key, value) {
        if (Global.value(key) !== value)
            Global.insert(key, value);
    }
    function publish() {
        store("ionixTheme", page.theme);
        store("ionixBar", page.bar);
        store("ionixAutologin", Global.value("autoLoginUser") ? "yes" : "no");
    }

    onThemeChanged: publish()
    onBarChanged: publish()
    Component.onCompleted: publish()
    function onActivate() { publish(); }
    function onLeave() { publish(); }

    // The users page writes autoLoginUser whenever its checkbox flips, possibly
    // after this page was last shown. store() only writes on a real change, so
    // reacting to our own insert does not loop.
    //
    // Deferred with callLater: GlobalStorage emits changed() while it still holds
    // its own lock, so touching Global from inside the handler deadlocks the
    // installer on startup.
    Connections {
        target: Global
        function onChanged() { Qt.callLater(page.publish); }
    }

    // Same flat colour as #mainApp in stylesheet.qss. Calamares clears a QML page
    // to white, so it must paint something, and anything but an exact match
    // shows the page's inset as a box.
    Rectangle {
        anchors.fill: parent
        color: "#150d20"
    }

    // ── Reusable pieces ──────────────────────────────────────────────────────

    component SectionTitle: RowLayout {
        property alias text: label.text
        property alias hint: hintLabel.text
        spacing: 12
        Text {
            id: label
            color: page.accentLite
            font.family: page.mono
            font.pixelSize: 12
            font.letterSpacing: 3
        }
        Rectangle { Layout.fillWidth: true; height: 1; color: page.border; opacity: 0.6 }
        Text {
            id: hintLabel
            color: page.muted
            font.family: page.sans
            font.pixelSize: 12
        }
    }

    // A selectable glass card with a check badge.
    component Choice: Rectangle {
        id: choice
        property bool selected: false
        signal picked()
        default property alias content: inner.data

        radius: 14
        color: selected ? Qt.rgba(0.66, 0.33, 0.97, 0.12)
             : ma.containsMouse ? Qt.rgba(0.23, 0.18, 0.31, 0.75)
             : Qt.rgba(0.10, 0.06, 0.15, 0.65)
        border.width: selected ? 2 : 1
        border.color: selected ? page.accentHi : ma.containsMouse ? page.accent : page.border
        Behavior on color { ColorAnimation { duration: 150 } }
        Behavior on border.color { ColorAnimation { duration: 150 } }

        // Halo around the selected card. A plain ring rather than a MultiEffect
        // layer: cheaper, and it cannot blank the card if a layer fails to render.
        Rectangle {
            anchors.fill: parent
            anchors.margins: -5
            radius: parent.radius + 5
            color: "transparent"
            border.width: 4
            border.color: page.accentHi
            opacity: choice.selected ? 0.22 : 0
            Behavior on opacity { NumberAnimation { duration: 150 } }
        }

        Item { id: inner; anchors.fill: parent }

        Rectangle {
            visible: choice.selected
            anchors { top: parent.top; right: parent.right; margins: 10 }
            width: 22; height: 22; radius: 11
            color: page.accentHi
            z: 5
            Text {
                anchors.centerIn: parent
                text: ""
                color: "white"
                font.family: page.mono
                font.pixelSize: 11
            }
        }

        MouseArea {
            id: ma
            anchors.fill: parent
            hoverEnabled: true
            cursorShape: Qt.PointingHandCursor
            onClicked: choice.picked()
        }
    }

    // A miniature desktop in a theme's colours, with the bar on `edge`.
    component MiniDesktop: Rectangle {
        id: mini
        property var t
        property string edge: "top"
        readonly property bool vertical: edge === "left" || edge === "right"
        radius: 8
        clip: true
        border.width: 1
        border.color: Qt.rgba(1, 1, 1, 0.07)
        gradient: Gradient {
            orientation: Gradient.Horizontal
            GradientStop { position: 0.0; color: mini.t.adaptive ? "#3b1f5c" : mini.t.bg }
            GradientStop { position: 0.5; color: mini.t.adaptive ? "#1f3a5f" : mini.t.deep }
            GradientStop { position: 1.0; color: mini.t.adaptive ? "#5c3a1f" : mini.t.bg }
        }

        // The bar.
        Rectangle {
            id: miniBar
            x: mini.edge === "right" ? parent.width - width - 4 : 4
            y: mini.edge === "bottom" ? parent.height - height - 4 : 4
            width: mini.vertical ? 10 : parent.width - 8
            height: mini.vertical ? parent.height - 8 : 10
            radius: 4
            color: Qt.rgba(0, 0, 0, 0.45)
            border.width: 1
            border.color: Qt.rgba(1, 1, 1, 0.08)
            Rectangle {
                x: mini.vertical ? 2 : 4
                y: mini.vertical ? 4 : 2
                width: mini.vertical ? 6 : 14
                height: mini.vertical ? 14 : 6
                radius: 3
                color: mini.t.accent
            }
            Rectangle {
                anchors.centerIn: parent
                width: mini.vertical ? 6 : 22
                height: mini.vertical ? 22 : 6
                radius: 3
                color: mini.t.card
            }
        }

        // Two windows, the focused one with an accent border.
        Rectangle {
            x: (mini.edge === "left" ? 18 : 8)
            y: (mini.edge === "top" ? 20 : 8)
            width: (parent.width - (mini.vertical ? 34 : 24)) * 0.58
            height: parent.height - (mini.vertical ? 16 : 30)
            radius: 4
            color: mini.t.card
            border.width: 1
            border.color: mini.t.hi
            Rectangle { x: 5; y: 5; width: parent.width * 0.5; height: 3; radius: 1.5; color: mini.t.lite; opacity: 0.8 }
            Rectangle { x: 5; y: 11; width: parent.width * 0.7; height: 3; radius: 1.5; color: Qt.rgba(1, 1, 1, 0.2) }
            Rectangle { x: 5; y: 17; width: parent.width * 0.4; height: 3; radius: 1.5; color: Qt.rgba(1, 1, 1, 0.2) }
        }
        Rectangle {
            x: (mini.edge === "left" ? 18 : 8) + (parent.width - (mini.vertical ? 34 : 24)) * 0.58 + 6
            y: (mini.edge === "top" ? 20 : 8)
            width: (parent.width - (mini.vertical ? 34 : 24)) * 0.42
            height: parent.height - (mini.vertical ? 16 : 30)
            radius: 4
            color: mini.t.card
            opacity: 0.8
        }
    }

    // ── Layout ───────────────────────────────────────────────────────────────

    ColumnLayout {
        anchors.fill: parent
        anchors.leftMargin: 44
        anchors.rightMargin: 44
        anchors.topMargin: 34
        anchors.bottomMargin: 24
        spacing: 0

        Text {
            text: "PERSONALIZE"
            color: page.accentLite
            font.family: page.mono
            font.pixelSize: 12
            font.letterSpacing: 3
        }
        Text {
            Layout.topMargin: 6
            text: "Make it yours"
            color: page.bright
            font.family: page.sans
            font.pixelSize: 30
            font.weight: Font.Bold
        }
        Text {
            Layout.topMargin: 6
            Layout.fillWidth: true
            text: "Choose how Ionix looks the first time you log in. Nothing here is permanent — both can be changed any time from the start menu's settings."
            color: page.text
            wrapMode: Text.WordWrap
            font.family: page.sans
            font.pixelSize: 14
        }

        // ── Theme ──
        SectionTitle {
            Layout.fillWidth: true
            Layout.topMargin: 22
            text: "DESKTOP THEME"
            hint: "ionixtheme " + page.theme
        }

        GridLayout {
            Layout.fillWidth: true
            Layout.topMargin: 14
            columns: 4
            columnSpacing: 14

            Repeater {
                model: page.themes
                delegate: Choice {
                    id: themeCard
                    required property var modelData
                    Layout.fillWidth: true
                    Layout.preferredHeight: 184
                    selected: page.theme === modelData.id
                    onPicked: page.theme = modelData.id

                    MiniDesktop {
                        id: preview
                        anchors { left: parent.left; right: parent.right; top: parent.top; margins: 12 }
                        height: 96
                        t: themeCard.modelData
                        edge: themeCard.modelData.bar
                    }
                    Text {
                        id: themeName
                        anchors { left: parent.left; top: preview.bottom; leftMargin: 14; topMargin: 12 }
                        text: themeCard.modelData.name
                        color: page.bright
                        font.family: page.sans
                        font.pixelSize: 15
                        font.weight: Font.DemiBold
                    }
                    Text {
                        anchors { left: parent.left; right: parent.right; top: themeName.bottom; leftMargin: 14; rightMargin: 14; topMargin: 3 }
                        text: themeCard.modelData.blurb
                        color: page.muted
                        wrapMode: Text.WordWrap
                        maximumLineCount: 2
                        font.family: page.sans
                        font.pixelSize: 12
                    }
                }
            }
        }

        // ── Bar position ──
        SectionTitle {
            Layout.fillWidth: true
            Layout.topMargin: 22
            text: "BAR POSITION"
            hint: page.bar === "default" ? currentTheme.name + " puts it at the " + currentTheme.bar : ""
        }

        RowLayout {
            Layout.fillWidth: true
            Layout.topMargin: 14
            spacing: 12

            Repeater {
                model: page.positions
                delegate: Choice {
                    id: posCard
                    required property string modelData
                    Layout.fillWidth: true
                    Layout.preferredHeight: 110
                    selected: page.bar === modelData
                    onPicked: page.bar = modelData

                    MiniDesktop {
                        anchors.horizontalCenter: parent.horizontalCenter
                        anchors.top: parent.top
                        anchors.topMargin: 14
                        width: 96; height: 58
                        t: page.currentTheme
                        edge: posCard.modelData === "default" ? page.currentTheme.bar : posCard.modelData
                        opacity: posCard.modelData === "default" ? 0.75 : 1
                    }
                    Text {
                        anchors.horizontalCenter: parent.horizontalCenter
                        anchors.bottom: parent.bottom
                        anchors.bottomMargin: 13
                        text: posCard.modelData === "default" ? "Theme default"
                            : posCard.modelData.charAt(0).toUpperCase() + posCard.modelData.slice(1)
                        color: posCard.selected ? page.bright : page.text
                        font.family: page.sans
                        font.pixelSize: 13
                        font.weight: posCard.selected ? Font.DemiBold : Font.Normal
                    }
                }
            }
        }

        Item { Layout.fillHeight: true; Layout.minimumHeight: 16 }

        // ── Footer ──
        Rectangle {
            Layout.fillWidth: true
            Layout.preferredHeight: footer.implicitHeight + 22
            radius: 10
            color: Qt.rgba(0.10, 0.06, 0.15, 0.6)
            border.width: 1
            border.color: Qt.rgba(0.29, 0.24, 0.38, 0.6)
            RowLayout {
                id: footer
                anchors.fill: parent
                anchors.margins: 11
                anchors.leftMargin: 14
                spacing: 10
                Text {
                    text: ""
                    color: page.accentLite
                    font.family: page.mono
                    font.pixelSize: 14
                }
                Text {
                    Layout.fillWidth: true
                    wrapMode: Text.WordWrap
                    textFormat: Text.StyledText
                    text: "Applied on your first login. Want to see them all first? Run <b>ionixtheme</b> with any theme name in the live session to try it right now."
                    color: page.text
                    font.family: page.sans
                    font.pixelSize: 13
                }
            }
        }
    }
}
