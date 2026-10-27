/* Ionix install slideshow, shown while the system is being written.
 *
 * Slideshow API 2 (branding.desc `slideshowAPI: 2`): Calamares calls onActivate()
 * when the install page opens and onLeave() when it closes, and
 * `activatedInCalamares` gates the timer so nothing runs before then.
 *
 * `calamares.slideshow` provides Presentation and Slide; without that import the
 * whole file fails to load and Calamares shows a blank page.
 */
import QtQuick
import QtQuick.Layouts
import QtQuick.Effects
import calamares.slideshow 1.0

Presentation {
    id: presentation

    readonly property color bgDeep:     "#0f0a18"
    readonly property color bgWindow:   "#1a1025"
    readonly property color card:       "#2d2d3f"
    readonly property color border:     "#4a3d60"
    readonly property color muted:      "#6b5f80"
    readonly property color text:       "#c4b5fd"
    readonly property color bright:     "#e2d9f3"
    readonly property color accent:     "#9b59b6"
    readonly property color accentHi:   "#a855f7"
    readonly property color accentLite: "#c084fc"
    readonly property color cyan:       "#48dbfb"
    readonly property string mono:      "JetBrainsMono Nerd Font"
    readonly property string sans:      "Noto Sans"

    readonly property int slideSeconds: 9

    function onActivate() {
        presentation.currentSlide = 0;
        progress.restart();
    }
    function onLeave() {}

    Timer {
        interval: presentation.slideSeconds * 1000
        running: presentation.activatedInCalamares
        repeat: true
        onTriggered: {
            presentation.goToNextSlide();
            progress.restart();
        }
    }

    // ── Shared backdrop ─────────────────────────────────────────────────────
    Rectangle {
        anchors.fill: parent
        z: -10
        gradient: Gradient {
            orientation: Gradient.Vertical
            GradientStop { position: 0.0; color: "#1d1229" }
            GradientStop { position: 1.0; color: presentation.bgDeep }
        }

        // Two slow-drifting glows so the page never looks frozen during a long step.
        Repeater {
            model: [
                { c: "#a855f7", s: 420, x0: 0.62, y0: 0.10, dx: 0.10, dy: 0.12, t: 17000 },
                { c: "#48dbfb", s: 300, x0: 0.05, y0: 0.55, dx: 0.12, dy: -0.10, t: 23000 }
            ]
            delegate: Rectangle {
                id: orb
                required property var modelData
                property real phase: 0
                width: modelData.s; height: width; radius: width / 2
                color: modelData.c
                opacity: 0.13
                x: parent.width * (modelData.x0 + modelData.dx * Math.sin(phase))
                y: parent.height * (modelData.y0 + modelData.dy * Math.cos(phase))
                layer.enabled: true
                layer.effect: MultiEffect { blurEnabled: true; blur: 1.0; blurMax: 64 }
                NumberAnimation on phase {
                    from: 0; to: Math.PI * 2
                    duration: orb.modelData.t
                    loops: Animation.Infinite
                    running: presentation.activatedInCalamares
                }
            }
        }
    }

    // ── Building blocks ─────────────────────────────────────────────────────

    // Eyebrow + headline + body, fading in each time its slide is shown.
    component Copy: ColumnLayout {
        id: copy
        property string eyebrow
        property string title
        property string body
        spacing: 14

        opacity: 0
        property real shift: 18
        transform: Translate { y: copy.shift }
        onVisibleChanged: if (visible) enter.restart()
        Component.onCompleted: if (visible) enter.restart()
        ParallelAnimation {
            id: enter
            NumberAnimation { target: copy; property: "opacity"; from: 0; to: 1; duration: 520; easing.type: Easing.OutCubic }
            NumberAnimation { target: copy; property: "shift"; from: 18; to: 0; duration: 620; easing.type: Easing.OutCubic }
        }

        Text {
            text: copy.eyebrow
            color: presentation.accentLite
            font.family: presentation.mono
            font.pixelSize: 13
            font.letterSpacing: 3
        }
        Text {
            Layout.fillWidth: true
            text: copy.title
            color: presentation.bright
            wrapMode: Text.WordWrap
            font.family: presentation.sans
            font.pixelSize: 34
            font.weight: Font.Bold
            lineHeight: 1.1
        }
        Text {
            Layout.fillWidth: true
            Layout.topMargin: 4
            text: copy.body
            color: presentation.text
            wrapMode: Text.WordWrap
            font.family: presentation.sans
            font.pixelSize: 16
            lineHeight: 1.35
            textFormat: Text.StyledText
        }
    }

    // A glass card used by the right-hand visuals.
    component Glass: Rectangle {
        radius: 16
        color: Qt.rgba(0.10, 0.06, 0.15, 0.72)
        border.width: 1
        border.color: Qt.rgba(0.29, 0.24, 0.38, 0.9)
    }

    component Keycap: Rectangle {
        property alias label: capText.text
        implicitWidth: Math.max(34, capText.implicitWidth + 18)
        implicitHeight: 30
        radius: 7
        color: presentation.card
        border.width: 1
        border.color: presentation.border
        Rectangle {   // bottom lip
            anchors { left: parent.left; right: parent.right; bottom: parent.bottom }
            height: 3; radius: 7
            color: Qt.rgba(0, 0, 0, 0.35)
        }
        Text {
            id: capText
            anchors.centerIn: parent
            anchors.verticalCenterOffset: -1
            color: presentation.bright
            font.family: presentation.mono
            font.pixelSize: 12
            font.weight: Font.Bold
        }
    }

    // Calamares' Slide insets itself (5% / 20%, 90% x 70%) for bullet-point decks;
    // these slides lay themselves out edge to edge instead.
    component FullSlide: Slide {
        x: 0; y: 0
        width: presentation.width
        height: presentation.height
    }

    // Two-column slide: copy on the left, a visual on the right.
    component Split: Item {
        id: split
        anchors.fill: parent
        default property alias visual: visualSlot.data
        property string eyebrow
        property string title
        property string body
        Copy {
            id: copyItem
            eyebrow: split.eyebrow
            title: split.title
            body: split.body
            anchors.left: parent.left
            anchors.leftMargin: 64
            anchors.verticalCenter: parent.verticalCenter
            anchors.verticalCenterOffset: -16
            width: parent.width * 0.44
        }
        Item {
            id: visualSlot
            anchors.right: parent.right
            anchors.rightMargin: 56
            anchors.verticalCenter: parent.verticalCenter
            anchors.verticalCenterOffset: -16
            width: parent.width * 0.40
            height: parent.height * 0.70
        }
    }

    // ── 1. Welcome ──────────────────────────────────────────────────────────
    FullSlide {
        Split {
            eyebrow: "WELCOME TO IONIX"
            title: "Sit back — your new desktop is on its way."
            body: "Arch Linux underneath, Hyprland on top, and one deep-violet look across every surface in between. This takes a few minutes; here is what to expect when it's done."

            Image {
                // Wider than its slot: the hero's outer orbits are faint and
                // may run into the right margin.
                anchors.centerIn: parent
                anchors.horizontalCenterOffset: 36
                width: parent.width * 1.45
                height: parent.height
                source: "welcome.png"
                sourceSize.width: 1200
                fillMode: Image.PreserveAspectFit
                smooth: true
                mipmap: true
            }
        }
    }

    // ── 2. The bar ──────────────────────────────────────────────────────────
    FullSlide {
        Split {
            eyebrow: "THE SHELL"
            title: "A bar that goes where you want it."
            body: "The Ionix shell is built on Quickshell: workspaces, media, network, calendar and notifications, each one a click from a popout. Dock it to <b>any edge</b> of the screen — you choose that during setup, and can change it any time from the start menu."

            Glass {
                anchors.centerIn: parent
                width: parent.width
                height: width * 0.68
                // A miniature screen with the bar along the top.
                Rectangle {
                    id: screen
                    anchors.fill: parent
                    anchors.margins: 18
                    radius: 10
                    gradient: Gradient {
                        GradientStop { position: 0.0; color: "#2a1845" }
                        GradientStop { position: 1.0; color: "#120b1c" }
                    }
                    Rectangle {
                        anchors { left: parent.left; right: parent.right; top: parent.top; margins: 8 }
                        height: 26; radius: 8
                        color: Qt.rgba(0.10, 0.06, 0.15, 0.9)
                        border.width: 1; border.color: presentation.border
                        Row {
                            anchors.verticalCenter: parent.verticalCenter
                            x: 10; spacing: 6
                            Repeater {
                                model: 5
                                Rectangle {
                                    width: index === 1 ? 22 : 10; height: 10; radius: 5
                                    color: index === 1 ? presentation.accentHi : presentation.border
                                }
                            }
                        }
                        Rectangle {
                            anchors.centerIn: parent
                            width: 64; height: 14; radius: 7
                            color: presentation.card
                            Text { anchors.centerIn: parent; text: "21:04"; color: presentation.bright; font.family: presentation.mono; font.pixelSize: 9 }
                        }
                        Row {
                            anchors.verticalCenter: parent.verticalCenter
                            anchors.right: parent.right; anchors.rightMargin: 10
                            spacing: 8
                            Repeater {
                                model: ["", "", ""]
                                Text { text: modelData; color: presentation.accentLite; font.family: presentation.mono; font.pixelSize: 10 }
                            }
                        }
                    }
                    // A popout hanging off the clock.
                    Glass {
                        anchors.horizontalCenter: parent.horizontalCenter
                        y: 44
                        width: parent.width * 0.52; height: parent.height * 0.52
                        radius: 10
                        Column {
                            anchors.fill: parent; anchors.margins: 12; spacing: 8
                            Text { text: "SEPTEMBER"; color: presentation.accentLite; font.family: presentation.mono; font.pixelSize: 9; font.letterSpacing: 2 }
                            Grid {
                                columns: 7; spacing: 5
                                Repeater {
                                    model: 28
                                    Rectangle {
                                        width: 13; height: 11; radius: 3
                                        color: index === 17 ? presentation.accentHi : Qt.rgba(0.29, 0.24, 0.38, index % 6 === 0 ? 0.9 : 0.45)
                                    }
                                }
                            }
                        }
                    }
                }
            }
        }
    }

    // ── 3. Themes ───────────────────────────────────────────────────────────
    FullSlide {
        Split {
            eyebrow: "THEMES"
            title: "One command restyles everything."
            body: "Bar, borders, terminal and file manager switch together. Try <b>ionixtheme --list</b> in a terminal, or pick one from the start menu's settings. <b>Ionix Adaptive</b> goes further and derives its whole palette from your wallpaper."

            Grid {
                anchors.centerIn: parent
                columns: 2
                spacing: 16
                Repeater {
                    model: [
                        { n: "Ionix",          a: "#9b59b6", b: "#a855f7", bg: "#1a1025", c: "#2d2d3f" },
                        { n: "Ionix Adaptive", a: "#48dbfb", b: "#a855f7", bg: "#141826", c: "#26304a" },
                        { n: "Ionix Pro",      a: "#b026ff", b: "#00f0ff", bg: "#0d0620", c: "#1a0d33" },
                        { n: "Winix",          a: "#0078d4", b: "#4cc2ff", bg: "#202020", c: "#2b2b2b" }
                    ]
                    Glass {
                        required property var modelData
                        width: 170; height: 124
                        Rectangle {
                            anchors { left: parent.left; right: parent.right; top: parent.top; margins: 10 }
                            height: 72; radius: 8
                            color: modelData.bg
                            border.width: 1; border.color: Qt.rgba(1, 1, 1, 0.06)
                            Rectangle { x: 8; y: 8; width: parent.width - 16; height: 8; radius: 4; color: modelData.c }
                            Rectangle { x: 8; y: 8; width: 18; height: 8; radius: 4; color: modelData.a }
                            Rectangle {
                                x: 16; y: 24; width: parent.width - 32; height: 38; radius: 6
                                color: modelData.c
                                border.width: 1; border.color: modelData.b
                            }
                        }
                        Text {
                            anchors { left: parent.left; bottom: parent.bottom; margins: 12 }
                            text: modelData.n
                            color: presentation.bright
                            font.family: presentation.sans
                            font.pixelSize: 13
                            font.weight: Font.DemiBold
                        }
                    }
                }
            }
        }
    }

    // ── 4. Keys ─────────────────────────────────────────────────────────────
    FullSlide {
        Split {
            eyebrow: "KEYS WORTH KNOWING"
            title: "Everything is a shortcut away."
            body: "Ionix is keyboard-first, but never keyboard-only — every one of these is also reachable from the bar. <b>Super</b> is the Windows key."

            Glass {
                anchors.centerIn: parent
                width: parent.width
                height: keys.implicitHeight + 36
                GridLayout {
                    id: keys
                    anchors.fill: parent
                    anchors.margins: 18
                    columns: 2
                    rowSpacing: 11
                    columnSpacing: 18
                    Repeater {
                        model: [
                            { k: ["Super"],          d: "Start menu" },
                            { k: ["Super", "T"],     d: "Terminal" },
                            { k: ["Super", "E"],     d: "Files" },
                            { k: ["Super", "W"],     d: "Web browser" },
                            { k: ["Alt", "Space"],   d: "Search anything" },
                            { k: ["Super", "V"],     d: "Clipboard history" },
                            { k: ["Super", "L"],     d: "Lock the screen" },
                            { k: ["Super", "Q"],     d: "Close a window" }
                        ]
                        delegate: RowLayout {
                            required property var modelData
                            Layout.columnSpan: 2
                            Layout.fillWidth: true
                            spacing: 6
                            Repeater {
                                model: modelData.k
                                Keycap { label: modelData }
                            }
                            Item { Layout.fillWidth: true }
                            Text {
                                text: modelData.d
                                color: presentation.text
                                font.family: presentation.sans
                                font.pixelSize: 14
                            }
                        }
                    }
                }
            }
        }
    }

    // ── 5. Arch ─────────────────────────────────────────────────────────────
    FullSlide {
        Split {
            eyebrow: "ARCH UNDERNEATH"
            title: "Rolling release. Nothing to reinstall, ever."
            body: "Updates arrive continuously through pacman and yay, and <b>yay -Syu</b> brings everything current — including the Ionix shell itself, which is published to the AUR. The whole Arch Wiki applies to you."

            Glass {
                anchors.centerIn: parent
                width: parent.width
                height: 230
                Column {
                    anchors.fill: parent
                    anchors.margins: 20
                    spacing: 8
                    Row {
                        spacing: 7
                        Repeater {
                            model: ["#e74c3c", "#f39c12", "#2ecc71"]
                            Rectangle { width: 10; height: 10; radius: 5; color: modelData; opacity: 0.8 }
                        }
                    }
                    Item { width: 1; height: 6 }
                    Repeater {
                        model: [
                            { t: "❯ yay -Syu", c: "#e2d9f3" },
                            { t: ":: Synchronizing package databases...", c: "#6b5f80" },
                            { t: "   core    extra    multilib", c: "#6b5f80" },
                            { t: ":: Searching AUR for updates...", c: "#6b5f80" },
                            { t: "   ionix-quickshell-git  r33 → r34", c: "#c084fc" },
                            { t: ":: Proceed with installation? [Y/n]", c: "#48dbfb" }
                        ]
                        Text {
                            text: modelData.t
                            color: modelData.c
                            font.family: presentation.mono
                            font.pixelSize: 13
                        }
                    }
                }
            }
        }
    }

    // ── Slide indicator and per-slide progress ──────────────────────────────
    Row {
        anchors.horizontalCenter: parent.horizontalCenter
        anchors.bottom: parent.bottom
        anchors.bottomMargin: 26
        spacing: 8
        z: 10
        Repeater {
            model: presentation.slides.length
            Rectangle {
                width: index === presentation.currentSlide ? 36 : 8
                height: 8; radius: 4
                color: index < presentation.currentSlide ? presentation.accent : presentation.border
                clip: true
                Behavior on width { NumberAnimation { duration: 260; easing.type: Easing.OutCubic } }
                Rectangle {
                    visible: index === presentation.currentSlide
                    height: parent.height; radius: 4
                    width: parent.width * progress.value
                    color: presentation.accentLite
                }
            }
        }
    }

    // Fills the current slide's pill over slideSeconds.
    QtObject {
        id: progress
        property real value: 0
        property var anim: NumberAnimation {
            target: progress; property: "value"
            from: 0; to: 1
            duration: presentation.slideSeconds * 1000
        }
        function restart() { anim.restart(); }
    }
}
