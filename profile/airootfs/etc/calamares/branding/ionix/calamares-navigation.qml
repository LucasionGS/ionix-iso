/* Ionix installer button bar: progress on the left, Cancel / Back / Next on the right.
 *
 * Loaded because branding.desc says `navigation: qml`. Every label, icon and
 * enabled state comes from ViewManager, so translations and the "Install" /
 * "Done" relabelling on the last pages keep working.
 */
import io.calamares.ui 1.0
import io.calamares.core 1.0

import QtQuick
import QtQuick.Layouts
import QtQuick.Effects

Rectangle {
    id: navigationBar

    readonly property color border:     "#4a3d60"
    readonly property color card:       "#2d2d3f"
    readonly property color hover:      "#3a2d50"
    readonly property color muted:      "#6b5f80"
    readonly property color text:       "#c4b5fd"
    readonly property color bright:     "#e2d9f3"
    readonly property color accent:     "#9b59b6"
    readonly property color accentHi:   "#a855f7"
    readonly property color accentLite: "#c084fc"
    readonly property string mono:      "JetBrainsMono Nerd Font"

    // rowCount() is a plain call, evaluated once before the steps are loaded;
    // a Repeater's count follows the model.
    readonly property int stepCount: stepCounter.count
    readonly property int stepIndex: ViewManager.currentStepIndex

    Repeater { id: stepCounter; model: ViewManager; delegate: Item {} }

    height: 76
    color: "#120b1c"

    Rectangle {
        anchors { left: parent.left; right: parent.right; top: parent.top }
        height: 1
        color: navigationBar.border
        opacity: 0.7
    }

    // A pill button. `primary` is the accent-filled Next; the rest are outlines.
    component NavButton: Rectangle {
        id: btn

        property string label
        property bool primary: false
        property bool ghost: false
        signal activated()

        implicitWidth: Math.max(112, btnText.implicitWidth + 44)
        implicitHeight: 42
        radius: 21
        opacity: enabled ? 1 : 0.4

        color: ghost ? (mouse.containsMouse ? Qt.rgba(0.23, 0.18, 0.31, 0.6) : "transparent")
             : primary ? "transparent"
             : (mouse.containsMouse ? navigationBar.hover : navigationBar.card)
        border.width: primary ? 0 : ghost ? 0 : 1
        border.color: mouse.containsMouse && enabled ? navigationBar.accent : navigationBar.border
        Behavior on color { ColorAnimation { duration: 140 } }

        Rectangle {
            visible: btn.primary
            anchors.fill: parent
            radius: parent.radius
            gradient: Gradient {
                orientation: Gradient.Horizontal
                GradientStop { position: 0.0; color: mouse.containsMouse && btn.enabled ? "#a563c9" : navigationBar.accent }
                GradientStop { position: 1.0; color: mouse.containsMouse && btn.enabled ? "#b97bff" : navigationBar.accentHi }
            }
            layer.enabled: btn.enabled
            layer.effect: MultiEffect {
                shadowEnabled: true
                shadowColor: navigationBar.accentHi
                shadowBlur: 0.7
                shadowOpacity: mouse.containsMouse ? 0.8 : 0.45
                shadowHorizontalOffset: 0
                shadowVerticalOffset: 2
            }
        }

        Text {
            id: btnText
            anchors.centerIn: parent
            text: btn.label.replace("&", "")
            color: btn.primary ? "#ffffff" : btn.ghost ? (mouse.containsMouse ? navigationBar.bright : navigationBar.muted) : navigationBar.bright
            font.family: "Noto Sans"
            font.pixelSize: 14
            font.weight: btn.primary ? Font.DemiBold : Font.Medium
        }

        MouseArea {
            id: mouse
            anchors.fill: parent
            hoverEnabled: true
            enabled: btn.enabled
            cursorShape: btn.enabled ? Qt.PointingHandCursor : Qt.ArrowCursor
            onClicked: btn.activated()
        }
    }

    RowLayout {
        anchors.fill: parent
        anchors.leftMargin: 28
        anchors.rightMargin: 24
        spacing: 12

        // ── Progress ────────────────────────────────────────────────────────
        ColumnLayout {
            Layout.alignment: Qt.AlignVCenter
            spacing: 8

            Text {
                text: "STEP " + (navigationBar.stepIndex + 1) + " OF " + navigationBar.stepCount
                color: navigationBar.muted
                font.family: navigationBar.mono
                font.pixelSize: 11
                font.letterSpacing: 2
            }

            Row {
                spacing: 5
                Repeater {
                    model: navigationBar.stepCount
                    Rectangle {
                        width: index === navigationBar.stepIndex ? 26 : 12
                        height: 5
                        radius: 2.5
                        color: index < navigationBar.stepIndex ? navigationBar.accent
                             : index === navigationBar.stepIndex ? navigationBar.accentLite
                             : navigationBar.border
                        Behavior on width { NumberAnimation { duration: 220; easing.type: Easing.OutCubic } }
                        Behavior on color { ColorAnimation { duration: 220 } }
                    }
                }
            }
        }

        Item { Layout.fillWidth: true }

        NavButton {
            ghost: true
            label: ViewManager.quitLabel
            visible: ViewManager.quitVisible
            enabled: ViewManager.quitEnabled
            onActivated: ViewManager.quit()
        }

        NavButton {
            label: ViewManager.backLabel
            visible: ViewManager.backAndNextVisible
            enabled: ViewManager.backEnabled
            onActivated: ViewManager.back()
        }

        NavButton {
            primary: true
            label: ViewManager.nextLabel
            visible: ViewManager.backAndNextVisible
            enabled: ViewManager.nextEnabled
            onActivated: ViewManager.next()
        }
    }
}
