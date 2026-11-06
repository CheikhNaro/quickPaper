import QtQuick
import Quickshell
import Quickshell.Io
import Quickshell.Wayland

ShellRoot {
    id: root
    readonly property int hauteur: 300; readonly property real pente: 0.25
    readonly property int largeurActive: 550    // current card
    readonly property int largeurTranche: 250    // inactive cards: the knob to move
    readonly property int sautRapide: 3; readonly property int introSaut: 6
    readonly property string mono: "JetBrainsMono Nerd Font"; readonly property string sans: "Noto Sans"
    // largeurTranche is also the ListView step: `largeurSlot`, neighbour offset and
    // recentering all derive from it. Free value as long as it stays < largeurActive.
    readonly property int largeurSlot: largeurTranche

    // ── launcher entries ───────────────────────────────────────────
    readonly property string fichierListe: Quickshell.env("QUICKPAPER_LISTE")  // "name<TAB>path<TAB>thumbnail"
    readonly property string depart: Quickshell.env("QUICKPAPER_CURRENT") || ""
    readonly property color accent: Quickshell.env("QUICKPAPER_ACCENT").length ? Quickshell.env("QUICKPAPER_ACCENT") : "#58d6f7"
    property var tous: []
    property bool pret: false; property bool confirme: false; property bool introJoue: false

    function estAnime(p) { return /\.(mp4|webm|mkv|mov|gif)$/i.test(p) }
    function cheminCourant() {
        return liste.currentIndex >= 0 && liste.currentIndex < images.count ? images.get(liste.currentIndex).chemin : ""
    }
    // ⏎ applies here (the overlay stays open, no relay file) then confirms.
    // Escape closes without restoring: the visible wallpaper is already the last applied one.
    // Backend is detected by the launcher; add a branch here for other wallpaper daemons
    // (e.g. kanso: ["kanso", "set", c]).
    readonly property string backend: Quickshell.env("QUICKPAPER_BACKEND") || "noctalia"
    function setWallpaper(c) {
        if (backend === "noctalia") {
            Quickshell.execDetached(["noctalia", "msg", "wallpaper-set", c])
        } else if (backend === "hyprpaper") {
            Quickshell.execDetached(["sh", "-c", 'hyprpaper -l "' + c + ', " && for m in $(hyprctl monitors -j | jq -r ".[].name"); do hyprpaper -s "$m,' + c + '"; done'])
        } else if (backend === "swaybg") {
            Quickshell.execDetached(["sh", "-c", 'for o in $(swaymsg -t get_outputs -r | jq -r ".[].name"); do pkill -f "swaybg -o $o"; swaybg -i "' + c + '" -o "$o" & done'])
        }
        // optional: mirror the choice to the SDDM login screen
        Quickshell.execDetached(["sh", "-c", 'test -x "$HOME/.local/bin/sync-sddm-wallpaper" && sync-sddm-wallpaper "' + c + '"'])
    }
    function valider() {
        const c = cheminCourant()
        if (!c) return
        setWallpaper(c)
        confirme = true; confirmer.restart()
    }
    function annuler() { fin.start() }

    Timer { id: fin; interval: 200; onTriggered: Qt.quit() }
    Timer { id: confirmer; interval: 2000; onTriggered: root.confirme = false }

    // ── data: launcher list + fzf fuzzy filter ─────────────────
    ListModel { id: images }
    function lignesVersEntrees(texte) {
        return texte.split("\n").filter(l => l).map(l => { const c = l.split("\t"); return { nom: c[0], chemin: c[1], mini: c[2] } })
    }
    function remplir(entrees) {
        const garde = cheminCourant()
        images.clear()
        for (const e of entrees) images.append(e)
        const i = entrees.findIndex(e => e.chemin === (pret ? garde : depart))
        if (i > 0 && !introJoue) {
            // Intro "scroll": NoHighlightRange during the manual contentX
            // animation, otherwise StrictlyEnforceRange would recenter mid-flight.
            introJoue = true
            liste.highlightRangeMode = ListView.NoHighlightRange
            liste.currentIndex = i
            Qt.callLater(() => {
                const pas = root.largeurSlot + liste.spacing
                const cible = Math.max(0, i * pas + root.largeurSlot / 2 - liste.width / 2)
                const departAnim = Math.max(0, cible - root.introSaut * pas)
                liste.contentX = departAnim
                introAnim.from = departAnim; introAnim.to = cible; introAnim.start()
            })
        } else {
            liste.currentIndex = i >= 0 ? i : 0
            // Explicit recentering after fill: a bare currentIndex \"drifts\" on a
            // long jump (StrictlyEnforceRange stops recentering ~12 cards early).
            if (i > 0) Qt.callLater(() => liste.positionViewAtIndex(i, ListView.Center))
        }
        pret = true
    }
    Process {
        running: true
        command: ["cat", root.fichierListe]
        stdout: StdioCollector { onStreamFinished: { root.tous = root.lignesVersEntrees(this.text); root.remplir(root.tous) } }
    }
    Process {
        id: fzf
        property string requete: ""
        command: ["sh", "-c", 'exec fzf --filter "$1" --delimiter "\t" --nth 1 < "$2"', "sh", requete, root.fichierListe]
        stdout: StdioCollector { onStreamFinished: root.remplir(root.lignesVersEntrees(this.text)) }
    }
    Timer { id: rechercher; interval: 70; onTriggered: {
        const q = recherche.text.trim()
        if (!q) { root.remplir(root.tous); return }
        fzf.running = false; fzf.requete = q; fzf.running = true
    } }

    PanelWindow {
        anchors { top: true; bottom: true; left: true; right: true }
        screen: Quickshell.screens.find(s => s.name === Quickshell.env("QUICKPAPER_ECRAN")) ?? Quickshell.screens[0]
        color: "transparent"
        exclusionMode: ExclusionMode.Ignore
        WlrLayershell.layer: WlrLayer.Overlay
        WlrLayershell.namespace: "quickPaper"
        WlrLayershell.keyboardFocus: WlrKeyboardFocus.Exclusive

        // ── search, just above the wallpaper name ────────────────
        Rectangle {
            id: barre
            anchors.horizontalCenter: parent.horizontalCenter
            anchors.bottom: nom.top
            anchors.bottomMargin: 18
            width: 380; height: 40; radius: 12
            color: "#e6000000"
            border.color: recherche.text ? root.accent : "#40ffffff"
            border.width: 1.5
            Text {
                id: loupe
                anchors.verticalCenter: parent.verticalCenter
                x: 14; text: "󰍉"; color: root.accent
                font.family: root.mono; font.pixelSize: 18
            }
            TextInput {
                id: recherche
                anchors { left: loupe.right; leftMargin: 10; right: compte.left; rightMargin: 8; verticalCenter: parent.verticalCenter }
                color: "white"; font.family: root.sans; font.pixelSize: 15
                selectionColor: root.accent
                focus: true; clip: true
                onTextChanged: rechercher.restart()
                Text { visible: !recherche.text; text: "Search…"; color: "#80ffffff"; font: recherche.font }
                Keys.onPressed: e => {
                    const k = e.key, last = images.count - 1, saut = root.sautRapide
                    if (k === Qt.Key_Escape) root.annuler()
                    else if (k === Qt.Key_Return || k === Qt.Key_Enter) root.valider()
                    else if (k === Qt.Key_Right || k === Qt.Key_Tab) liste.incrementCurrentIndex()
                    else if (k === Qt.Key_Left || k === Qt.Key_Backtab) liste.decrementCurrentIndex()
                    else if (k === Qt.Key_PageDown) { if (images.count) liste.currentIndex = Math.min(last, liste.currentIndex + saut) }
                    else if (k === Qt.Key_PageUp) { if (images.count) liste.currentIndex = Math.max(0, liste.currentIndex - saut) }
                    else if (k === Qt.Key_Home) liste.currentIndex = 0
                    else if (k === Qt.Key_End) liste.currentIndex = last
                    else return
                    e.accepted = true
                }
            }
            Text {
                id: compte
                anchors { right: parent.right; rightMargin: 14; verticalCenter: parent.verticalCenter }
                text: images.count ? (liste.currentIndex + 1) + " / " + images.count : "aucun"
                color: "#99ffffff"; font.family: root.mono; font.pixelSize: 12
            }
        }

        // ── carousel, row anchored above the help bar ────
        ListView {
            id: liste
            anchors.horizontalCenter: parent.horizontalCenter
            anchors.bottom: barreau.top
            anchors.bottomMargin: 30
            width: parent.width; height: root.hauteur + 20
            orientation: ListView.Horizontal
            model: images
            spacing: 8
            clip: false
            keyNavigationWraps: false
            cacheBuffer: 2000
            highlightRangeMode: ListView.StrictlyEnforceRange
            // Range bounded on the SLOT (constant width), not the enlarged card:
            // scroll position then depends only on currentIndex.
            preferredHighlightBegin: width / 2 - root.largeurSlot / 2
            preferredHighlightEnd: width / 2 + root.largeurSlot / 2
            highlightMoveDuration: 260

            WheelHandler {
                acceptedDevices: PointerDevice.Mouse | PointerDevice.TouchPad
                onWheel: e => {
                    const d = e.angleDelta.y !== 0 ? e.angleDelta.y : e.angleDelta.x
                    if (d < 0) liste.incrementCurrentIndex(); else if (d > 0) liste.decrementCurrentIndex()
                }
            }
            // At the end of the intro StrictlyEnforceRange comes back: the current item
            // is already centered in the preferred range, so nothing recenters.
            NumberAnimation {
                id: introAnim
                target: liste
                property: "contentX"
                duration: 800
                easing.type: Easing.OutQuint
                onFinished: liste.highlightRangeMode = ListView.StrictlyEnforceRange
            }

            delegate: Item {
                id: carte
                required property int index
                required property string chemin
                required property string mini
                required property string nom
                readonly property bool active: ListView.isCurrentItem
                // CONSTANT width: the ListView never recomputes positions, so no
                // spurious recentering when currentIndex changes. Only the content widens.
                width: root.largeurSlot
                height: root.hauteur
                y: 10
                z: active ? 2 : 1
                // Neighbours step aside to restore the original spacing around the
                // enlarged card: active/2 + spacing + slice/2 - ListView step.
                readonly property int ecart: root.largeurActive / 2 + 8 + root.largeurTranche / 2 - (root.largeurSlot + 8)
                readonly property real decalage: active ? 0 : (index - liste.currentIndex > 0 ? ecart : -ecart)

                Item {
                    anchors { horizontalCenter: parent.horizontalCenter; horizontalCenterOffset: carte.decalage; verticalCenter: parent.verticalCenter }
                    width: carte.active ? root.largeurActive : root.largeurTranche
                    height: root.hauteur
                    opacity: carte.active ? 1 : 0.82
                    // root.pret : pas d'animation avant le premier remplissage, sinon le
                    // carousel "breathes" on startup.
                    Behavior on width { enabled: root.pret; NumberAnimation { duration: 260; easing.type: Easing.OutCubic } }
                    Behavior on opacity { enabled: root.pret; NumberAnimation { duration: 200 } }
                    Behavior on anchors.horizontalCenterOffset { enabled: root.pret; NumberAnimation { duration: 260; easing.type: Easing.OutCubic } }

                    // Slanted frame: the image is straightened inside by the inverse matrix.
                    Item {
                        anchors.fill: parent
                        clip: true
                        transform: Matrix4x4 {
                            matrix: Qt.matrix4x4(1, -root.pente, 0, root.pente * parent.height / 2, 0, 1, 0, 0, 0, 0, 1, 0, 0, 0, 0, 1)
                        }
                        Rectangle { anchors.fill: parent; color: "#000" }
                        Image {
                            x: -root.pente * parent.height
                            width: parent.width + root.pente * parent.height
                            height: parent.height
                            transform: Matrix4x4 { matrix: Qt.matrix4x4(1, root.pente, 0, 0, 0, 1, 0, 0, 0, 0, 1, 0, 0, 0, 0, 1) }
                            source: "file://" + carte.mini    // cached 720px thumbnail, never the full-size image
                            fillMode: Image.PreserveAspectCrop
                            asynchronous: true
                            cache: true
                            smooth: true
                        }
                        Rectangle {
                            visible: root.estAnime(carte.chemin)
                            x: carte.active ? parent.width - width - 18 : (parent.width - width) / 2
                            y: 12
                            width: carte.active ? 86 : 26; height: 24; radius: 6
                            color: "#cc000000"; border.color: root.accent; border.width: 1
                            Text {
                                anchors.centerIn: parent
                                text: carte.active ? "▶  LIVE" : "▶"
                                color: root.accent; font.family: root.mono; font.pixelSize: 11; font.bold: true
                            }
                        }
                        Rectangle {
                            anchors.fill: parent
                            color: "transparent"
                            border.width: carte.active ? 2.5 : 1
                            border.color: carte.active ? root.accent : "#55ffffff"
                        }
                        // Inside the frame: the click area inherits the shear and follows the
                        // rendered slanted card (otherwise ~75px of offset).
                        MouseArea {
                            anchors.fill: parent
                            hoverEnabled: true
                            cursorShape: Qt.PointingHandCursor
                            onEntered: liste.currentIndex = carte.index
                            onClicked: { liste.currentIndex = carte.index; root.valider() }
                        }
                    }
                }
            }
        }

        // selected wallpaper name, just above the carousel
        Text {
            id: nom
            anchors.horizontalCenter: parent.horizontalCenter
            anchors.bottom: liste.top
            anchors.bottomMargin: 6
            text: liste.currentIndex >= 0 && liste.currentIndex < images.count ? images.get(liste.currentIndex).nom : ""
            color: "white"; font.family: root.sans; font.pixelSize: 20; font.weight: Font.Light
            font.letterSpacing: 2; font.capitalization: Font.AllUppercase
        }
        Text {
            id: barreau
            anchors { horizontalCenter: parent.horizontalCenter; bottom: parent.bottom; bottomMargin: 34 }
            text: root.confirme ? "✓  applied  —  Esc to close" : "← →   browse      ⇞ ⇟  jump      ⏎  apply      Esc  close"
            color: root.confirme ? root.accent : "#88ffffff"
            font.family: root.mono; font.pixelSize: 12
            Behavior on color { ColorAnimation { duration: 200 } }
        }
    }
}
