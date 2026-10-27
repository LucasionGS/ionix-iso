/* "Software" installer page: optional bundles fetched from the internet.
 *
 * A notesqml instance (see settings.conf and modules/ionix-software.conf).
 * None of these bundles is on the installation medium. The page only records the
 * choice — `ionixExtras` in GlobalStorage, a comma-separated list or "none" — and
 * /usr/bin/ionix-extras installs it at the end of the install. The bundle
 * ids here must match the ones that script knows.
 */
import io.calamares.core 1.0
import io.calamares.ui 1.0

import QtQuick
import QtQuick.Layouts

Item {
    id: page

    readonly property color bgDeep:     "#0f0a18"
    readonly property color card:       "#2d2d3f"
    readonly property color border:     "#4a3d60"
    readonly property color muted:      "#6b5f80"
    readonly property color text:       "#c4b5fd"
    readonly property color bright:     "#e2d9f3"
    readonly property color accent:     "#9b59b6"
    readonly property color accentHi:   "#a855f7"
    readonly property color accentLite: "#c084fc"
    readonly property color green:      "#2ecc71"
    readonly property color orange:     "#f39c12"
    readonly property string mono:      "JetBrainsMono Nerd Font"
    readonly property string sans:      "Noto Sans"

    readonly property var bundles: [
        { id: "gaming", icon: "", name: "Gaming",
          blurb: "Steam with Proton, Lutris and Wine for everything else, plus the tuning tools that make games run well.",
          pkgs: "steam · lutris · wine · protonup-qt · gamescope · mangohud · gamemode · antimicrox" },
        { id: "obs", icon: "", name: "OBS Studio",
          blurb: "Screen recording and live streaming, with PipeWire capture for Wayland.",
          pkgs: "obs-studio" },
        { id: "tabby", icon: "", name: "Tabby terminal",
          blurb: "A modern terminal with tabs, SSH and serial profiles. Opens with Ctrl + Alt + T.",
          pkgs: "tabby-bin" }
    ]

    property var selected: ({})
    readonly property int selectedCount: Object.keys(selected).filter(k => selected[k]).length

    // "checking" | "online" | "offline"
    property string network: "checking"

    function toggle(id) {
        var next = Object.assign({}, selected);
        next[id] = !next[id];
        selected = next;
    }

    function publish() {
        var ids = bundles.map(b => b.id).filter(id => selected[id]);
        var value = ids.length ? ids.join(",") : "none";
        if (Global.value("ionixExtras") !== value)
            Global.insert("ionixExtras", value);
    }

    // Same host as the welcome page's internet requirement. Any HTTP answer at
    // all means the network is up; only a transport failure counts as offline.
    function checkNetwork() {
        network = "checking";
        var xhr = new XMLHttpRequest();
        xhr.onreadystatechange = function() {
            if (xhr.readyState === XMLHttpRequest.DONE)
                page.network = xhr.status > 0 ? "online" : "offline";
        };
        xhr.open("HEAD", "https://archlinux.org/");
        xhr.send();
    }

    onSelectedChanged: publish()
    Component.onCompleted: { publish(); checkNetwork(); }
    function onActivate() { publish(); checkNetwork(); }
    function onLeave() { publish(); }

    // Same flat colour as #mainApp in stylesheet.qss. Calamares clears a QML page
    // to white, so it must paint something, and anything but an exact match
    // shows the page's inset as a box.
    Rectangle {
        anchors.fill: parent
        color: "#150d20"
    }

    component Toggle: Rectangle {
        id: sw
        property bool on: false
        implicitWidth: 46
        implicitHeight: 26
        radius: 13
        color: on ? page.accentHi : page.card
        border.width: 1
        border.color: on ? page.accentLite : page.border
        Behavior on color { ColorAnimation { duration: 150 } }
        Rectangle {
            width: 20; height: 20; radius: 10
            y: 3
            x: sw.on ? sw.width - width - 3 : 3
            color: sw.on ? "white" : page.muted
            Behavior on x { NumberAnimation { duration: 170; easing.type: Easing.OutCubic } }
        }
    }

    ColumnLayout {
        anchors.fill: parent
        anchors.leftMargin: 44
        anchors.rightMargin: 44
        anchors.topMargin: 34
        anchors.bottomMargin: 24
        spacing: 0

        RowLayout {
            Layout.fillWidth: true
            Text {
                text: "SOFTWARE"
                color: page.accentLite
                font.family: page.mono
                font.pixelSize: 12
                font.letterSpacing: 3
            }
            Item { Layout.fillWidth: true }

            // Network status pill; click to re-check.
            Rectangle {
                Layout.preferredHeight: 26
                Layout.preferredWidth: netLabel.implicitWidth + 30
                radius: 13
                color: Qt.rgba(0.10, 0.06, 0.15, 0.7)
                border.width: 1
                border.color: page.network === "online" ? Qt.rgba(0.18, 0.8, 0.44, 0.5)
                            : page.network === "offline" ? Qt.rgba(0.95, 0.61, 0.07, 0.6)
                            : page.border
                Row {
                    anchors.centerIn: parent
                    spacing: 7
                    Rectangle {
                        anchors.verticalCenter: parent.verticalCenter
                        width: 8; height: 8; radius: 4
                        color: page.network === "online" ? page.green
                             : page.network === "offline" ? page.orange : page.muted
                    }
                    Text {
                        id: netLabel
                        text: page.network === "online" ? "Connected"
                            : page.network === "offline" ? "Offline — click to retry" : "Checking connection…"
                        color: page.text
                        font.family: page.sans
                        font.pixelSize: 12
                    }
                }
                MouseArea {
                    anchors.fill: parent
                    cursorShape: Qt.PointingHandCursor
                    onClicked: page.checkNetwork()
                }
            }
        }
        Text {
            Layout.topMargin: 6
            text: "Add extras"
            color: page.bright
            font.family: page.sans
            font.pixelSize: 30
            font.weight: Font.Bold
        }
        Text {
            Layout.topMargin: 6
            Layout.fillWidth: true
            text: "None of this is on the installation medium. Whatever you switch on is downloaded and installed at the end of setup, so you get current versions and keep only what you use."
            color: page.text
            wrapMode: Text.WordWrap
            font.family: page.sans
            font.pixelSize: 14
        }

        GridLayout {
            Layout.fillWidth: true
            Layout.topMargin: 22
            columns: 2
            columnSpacing: 14
            rowSpacing: 14

            Repeater {
                model: page.bundles
                delegate: Rectangle {
                    id: bundle
                    required property var modelData
                    readonly property bool on: !!page.selected[modelData.id]

                    Layout.fillWidth: true
                    Layout.preferredHeight: 150
                    radius: 14
                    color: on ? Qt.rgba(0.66, 0.33, 0.97, 0.12)
                         : ma.containsMouse ? Qt.rgba(0.23, 0.18, 0.31, 0.75)
                         : Qt.rgba(0.10, 0.06, 0.15, 0.65)
                    border.width: on ? 2 : 1
                    border.color: on ? page.accentHi : ma.containsMouse ? page.accent : page.border
                    Behavior on color { ColorAnimation { duration: 150 } }

                    Rectangle {
                        anchors.fill: parent
                        anchors.margins: -5
                        radius: parent.radius + 5
                        color: "transparent"
                        border.width: 4
                        border.color: page.accentHi
                        opacity: bundle.on ? 0.22 : 0
                        Behavior on opacity { NumberAnimation { duration: 150 } }
                    }

                    Rectangle {
                        id: iconTile
                        x: 18; y: 18
                        width: 44; height: 44; radius: 12
                        color: bundle.on ? page.accentHi : page.card
                        border.width: 1
                        border.color: bundle.on ? page.accentLite : page.border
                        Behavior on color { ColorAnimation { duration: 150 } }
                        Text {
                            anchors.centerIn: parent
                            text: bundle.modelData.icon
                            color: bundle.on ? "white" : page.accentLite
                            font.family: page.mono
                            font.pixelSize: 20
                        }
                    }

                    Text {
                        anchors { left: iconTile.right; leftMargin: 14; verticalCenter: iconTile.verticalCenter; right: toggle.left; rightMargin: 10 }
                        text: bundle.modelData.name
                        color: page.bright
                        elide: Text.ElideRight
                        font.family: page.sans
                        font.pixelSize: 16
                        font.weight: Font.DemiBold
                    }

                    Toggle {
                        id: toggle
                        anchors { right: parent.right; rightMargin: 18; verticalCenter: iconTile.verticalCenter }
                        on: bundle.on
                    }

                    Text {
                        id: blurb
                        anchors { left: parent.left; right: parent.right; top: iconTile.bottom; leftMargin: 18; rightMargin: 18; topMargin: 12 }
                        text: bundle.modelData.blurb
                        color: page.text
                        wrapMode: Text.WordWrap
                        maximumLineCount: 2
                        elide: Text.ElideRight
                        font.family: page.sans
                        font.pixelSize: 13
                    }

                    Text {
                        anchors { left: parent.left; right: parent.right; bottom: parent.bottom; leftMargin: 18; rightMargin: 18; bottomMargin: 12 }
                        text: bundle.modelData.pkgs
                        color: page.muted
                        elide: Text.ElideRight
                        font.family: page.mono
                        font.pixelSize: 11
                    }

                    MouseArea {
                        id: ma
                        anchors.fill: parent
                        hoverEnabled: true
                        cursorShape: Qt.PointingHandCursor
                        onClicked: page.toggle(bundle.modelData.id)
                    }
                }
            }
        }

        Item { Layout.fillHeight: true; Layout.minimumHeight: 16 }

        // ── Footer: what will happen ──
        Rectangle {
            Layout.fillWidth: true
            Layout.preferredHeight: footer.implicitHeight + 22
            radius: 10
            readonly property bool warn: page.network === "offline" && page.selectedCount > 0
            color: warn ? Qt.rgba(0.95, 0.61, 0.07, 0.10) : Qt.rgba(0.10, 0.06, 0.15, 0.6)
            border.width: 1
            border.color: warn ? Qt.rgba(0.95, 0.61, 0.07, 0.5) : Qt.rgba(0.29, 0.24, 0.38, 0.6)
            RowLayout {
                id: footer
                anchors.fill: parent
                anchors.margins: 11
                anchors.leftMargin: 14
                spacing: 10
                Text {
                    text: parent.parent.warn ? "" : ""
                    color: parent.parent.warn ? page.orange : page.accentLite
                    font.family: page.mono
                    font.pixelSize: 14
                }
                Text {
                    Layout.fillWidth: true
                    wrapMode: Text.WordWrap
                    textFormat: Text.StyledText
                    color: page.text
                    font.family: page.sans
                    font.pixelSize: 13
                    text: parent.parent.warn
                        ? "You're offline, so these can't be downloaded now. Setup will finish without them and remind you on first login — then <b>sudo ionix-extras install</b> picks up where it left off."
                        : page.selectedCount === 0
                        ? "Nothing selected — you get the lean Ionix desktop. Any of these can be added later with <b>sudo ionix-extras install</b> and a bundle name."
                        : page.selectedCount + (page.selectedCount === 1 ? " bundle" : " bundles")
                          + " will be installed after the base system. The system is brought fully up to date at the same time, so this step takes a few extra minutes."
                }
            }
        }
    }
}
