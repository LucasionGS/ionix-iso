/* Ionix installer sidebar: logo, wordmark and a step rail.
 *
 * Loaded because branding.desc says `sidebar: qml`. ViewManager is the list of
 * pages (its `display` role is each step's name) and knows the current one;
 * Branding carries the colours from branding.desc's `style:` block.
 */
import io.calamares.ui 1.0
import io.calamares.core 1.0

import QtQuick
import QtQuick.Layouts
import QtQuick.Effects

Rectangle {
    id: sideBar

    readonly property color bgTop:      "#1d1229"
    readonly property color bgBottom:   "#0f0a18"
    readonly property color border:     "#4a3d60"
    readonly property color muted:      "#6b5f80"
    readonly property color text:       "#c4b5fd"
    readonly property color bright:     "#e2d9f3"
    readonly property color accent:     "#9b59b6"
    readonly property color accentHi:   "#a855f7"
    readonly property color accentLite: "#c084fc"
    readonly property string mono:      "JetBrainsMono Nerd Font"

    implicitWidth: 250
    anchors.fill: parent

    gradient: Gradient {
        GradientStop { position: 0.0; color: sideBar.bgTop }
        GradientStop { position: 1.0; color: sideBar.bgBottom }
    }

    // Soft purple bloom behind the logo.
    Rectangle {
        width: 260; height: 260; radius: 130
        x: (parent.width - width) / 2
        y: -70
        color: sideBar.accentHi
        opacity: 0.16
        layer.enabled: true
        layer.effect: MultiEffect { blurEnabled: true; blur: 1.0; blurMax: 64 }
    }

    // Hairline separating the rail from the page.
    Rectangle {
        anchors { top: parent.top; bottom: parent.bottom; right: parent.right }
        width: 1
        gradient: Gradient {
            GradientStop { position: 0.0; color: "transparent" }
            GradientStop { position: 0.3; color: sideBar.border }
            GradientStop { position: 1.0; color: "transparent" }
        }
    }

    ColumnLayout {
        anchors.fill: parent
        anchors.topMargin: 34
        anchors.bottomMargin: 18
        spacing: 0

        Image {
            id: logo
            Layout.alignment: Qt.AlignHCenter
            Layout.preferredWidth: 72
            Layout.preferredHeight: 72
            source: "file:/" + Branding.imagePath(Branding.ProductLogo)
            sourceSize.width: 144
            sourceSize.height: 144
            fillMode: Image.PreserveAspectFit
            smooth: true
            mipmap: true
            layer.enabled: true
            layer.effect: MultiEffect {
                shadowEnabled: true
                shadowColor: sideBar.accentHi
                shadowBlur: 0.9
                shadowOpacity: 0.7
                shadowHorizontalOffset: 0
                shadowVerticalOffset: 0
            }
        }

        Text {
            Layout.alignment: Qt.AlignHCenter
            Layout.topMargin: 16
            text: "IONIX"
            color: sideBar.bright
            font.family: sideBar.mono
            font.pixelSize: 24
            font.weight: Font.Bold
            font.letterSpacing: 7
        }

        Text {
            Layout.alignment: Qt.AlignHCenter
            Layout.topMargin: 4
            text: Branding.string(Branding.Version) + "  ·  installer"
            color: sideBar.muted
            font.family: sideBar.mono
            font.pixelSize: 11
            font.letterSpacing: 1
        }

        Item { Layout.preferredHeight: 34 }

        // ── Step rail ───────────────────────────────────────────────────────
        Repeater {
            id: steps
            model: ViewManager

            delegate: Item {
                id: step

                readonly property bool isCurrent: index === ViewManager.currentStepIndex
                readonly property bool isDone:    index < ViewManager.currentStepIndex
                readonly property bool isLast:    index === steps.count - 1

                Layout.fillWidth: true
                Layout.preferredHeight: 46

                // Current-step pill.
                Rectangle {
                    anchors.fill: parent
                    anchors.leftMargin: 14
                    anchors.rightMargin: 14
                    anchors.topMargin: 3
                    anchors.bottomMargin: 3
                    radius: 12
                    opacity: step.isCurrent ? 1 : 0
                    Behavior on opacity { NumberAnimation { duration: 220 } }
                    gradient: Gradient {
                        orientation: Gradient.Horizontal
                        GradientStop { position: 0.0; color: Qt.rgba(0.66, 0.33, 0.97, 0.30) }
                        GradientStop { position: 1.0; color: Qt.rgba(0.61, 0.35, 0.71, 0.06) }
                    }
                    border.width: 1
                    border.color: Qt.rgba(0.75, 0.52, 0.99, 0.35)
                }

                // Connector to the next step's dot.
                Rectangle {
                    visible: !step.isLast
                    x: 40
                    y: parent.height / 2 + 13
                    width: 2
                    height: parent.height - 26
                    radius: 1
                    color: step.isDone ? sideBar.accent : Qt.rgba(0.29, 0.24, 0.38, 0.8)
                }

                // Step dot: check when done, number otherwise.
                Rectangle {
                    id: dot
                    x: 28
                    anchors.verticalCenter: parent.verticalCenter
                    width: 26; height: 26; radius: 13
                    color: step.isCurrent ? sideBar.accentHi
                         : step.isDone    ? sideBar.accent
                         :                  "transparent"
                    border.width: step.isCurrent || step.isDone ? 0 : 2
                    border.color: sideBar.border
                    Behavior on color { ColorAnimation { duration: 220 } }

                    layer.enabled: step.isCurrent
                    layer.effect: MultiEffect {
                        shadowEnabled: true
                        shadowColor: sideBar.accentHi
                        shadowBlur: 0.8
                        shadowOpacity: 0.9
                        shadowHorizontalOffset: 0
                        shadowVerticalOffset: 0
                    }

                    Text {
                        anchors.centerIn: parent
                        text: step.isDone ? "" : (index + 1)
                        color: step.isCurrent || step.isDone ? "#ffffff" : sideBar.muted
                        font.family: sideBar.mono
                        font.pixelSize: step.isDone ? 12 : 12
                        font.weight: Font.Bold
                    }
                }

                Text {
                    anchors.verticalCenter: parent.verticalCenter
                    anchors.left: dot.right
                    anchors.leftMargin: 14
                    anchors.right: parent.right
                    anchors.rightMargin: 22
                    elide: Text.ElideRight
                    text: display
                    color: step.isCurrent ? "#ffffff" : step.isDone ? sideBar.text : sideBar.muted
                    font.family: "Noto Sans"
                    font.pixelSize: 14
                    font.weight: step.isCurrent ? Font.DemiBold : Font.Normal
                    Behavior on color { ColorAnimation { duration: 220 } }
                }
            }
        }

        Item { Layout.fillHeight: true }

        // Debug-log toggle. ionix-install always passes -d, so keep it quiet.
        Rectangle {
            id: debugButton
            visible: ViewManager.isDebugMode
            Layout.alignment: Qt.AlignHCenter
            Layout.preferredWidth: debugLabel.implicitWidth + 28
            Layout.preferredHeight: 28
            radius: 14
            color: debugMouse.containsMouse ? "#3a2d50" : "transparent"
            border.width: 1
            border.color: debugMouse.containsMouse ? sideBar.accent : Qt.rgba(0.29, 0.24, 0.38, 0.7)

            Text {
                id: debugLabel
                anchors.centerIn: parent
                text: "  debug log"
                color: debugMouse.containsMouse ? sideBar.bright : sideBar.muted
                font.family: sideBar.mono
                font.pixelSize: 11
            }

            MouseArea {
                id: debugMouse
                anchors.fill: parent
                hoverEnabled: true
                cursorShape: Qt.PointingHandCursor
                onClicked: debug.toggle()
            }
        }
    }
}
