import QtQuick 2.15
import QtQuick.Layouts 1.15

Presentation {
    id: presentation

    Timer {
        interval: 5000
        running: true
        repeat: true
        onTriggered: presentation.goToNextSlide()
    }

    Slide {
        Rectangle {
            anchors.fill: parent
            color: "#1a1025"

            ColumnLayout {
                anchors.centerIn: parent
                spacing: 20

                Text {
                    Layout.alignment: Qt.AlignHCenter
                    text: "Welcome to Ionix"
                    font.pixelSize: 32
                    font.bold: true
                    color: "#e2d9f3"
                }

                Text {
                    Layout.alignment: Qt.AlignHCenter
                    text: "A modern Arch-based operating system"
                    font.pixelSize: 18
                    color: "#c4b5fd"
                }
            }
        }
    }

    Slide {
        Rectangle {
            anchors.fill: parent
            color: "#1a1025"

            ColumnLayout {
                anchors.centerIn: parent
                spacing: 20

                Text {
                    Layout.alignment: Qt.AlignHCenter
                    text: "Powered by Hyprland"
                    font.pixelSize: 28
                    font.bold: true
                    color: "#e2d9f3"
                }

                Text {
                    Layout.alignment: Qt.AlignHCenter
                    text: "A dynamic tiling Wayland compositor\nwith smooth animations and modern design"
                    font.pixelSize: 16
                    color: "#c4b5fd"
                    horizontalAlignment: Text.AlignHCenter
                }
            }
        }
    }

    Slide {
        Rectangle {
            anchors.fill: parent
            color: "#1a1025"

            ColumnLayout {
                anchors.centerIn: parent
                spacing: 20

                Text {
                    Layout.alignment: Qt.AlignHCenter
                    text: "Your System, Your Way"
                    font.pixelSize: 28
                    font.bold: true
                    color: "#e2d9f3"
                }

                Text {
                    Layout.alignment: Qt.AlignHCenter
                    text: "Pre-configured with sensible defaults\nFully customizable through simple config files"
                    font.pixelSize: 16
                    color: "#c4b5fd"
                    horizontalAlignment: Text.AlignHCenter
                }
            }
        }
    }
}
