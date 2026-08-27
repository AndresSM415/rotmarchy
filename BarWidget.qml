import QtQuick
import Quickshell
import Quickshell.Io
import qs.Commons
import qs.Ui
import "Model.js" as Model

// Rotmarchy — click the face, get brainrot.
//
// One button, one behaviour. Every click opens another silent, phone-shaped
// video somewhere random on the screen. Press q on a window to close it, or
// call the stop IPC method to clear them all.
BarWidget {
  id: root
  moduleName: "io.github.andressm415.rotmarchy"

  // Normalized in Model.js before reaching an argv — shell.json is hand-edited.
  readonly property string activeCategory: Model.normalizeCategory(setting("category", "random"))
  readonly property int activeHeight: Model.normalizeHeight(setting("height", 720))

  property int cortisol: Model.rollCortisol()

  // The helper ships inside the plugin folder, so it is found relative to this
  // file rather than expected on PATH.
  function helperPath() {
    return Qt.resolvedUrl("bin/rotmarchy").toString().replace(/^file:\/\//, "")
  }

  // Util.execArgv runs `exec "$@"`, so every element stays a positional
  // parameter and is never re-tokenized by a shell.
  function launch() {
    Util.execArgv(Model.launchArgv(root.helperPath(), {
      category: root.activeCategory,
      height: root.activeHeight
    }))
  }

  function stopAll() {
    Util.execArgv(Model.stopArgv(root.helperPath()))
  }

  implicitWidth: button.implicitWidth
  implicitHeight: button.implicitHeight

  IpcHandler {
    target: "io.github.andressm415.rotmarchy"

    function play(): void { root.launch() }
    function stop(): void { root.stopAll() }
  }

  BarIconButton {
    id: button
    anchors.fill: parent
    bar: root.bar

    // Rerolled on each hover, so the number is different every time you look
    // at it. That is the entire feature.
    tooltipText: Model.cortisolLabel(root.cortisol)
    onTooltipHoveredChanged: if (tooltipHovered) root.cortisol = Model.rollCortisol()

    // The face, with a glyph fallback so the button is never invisible if the
    // asset is missing or fails to decode.
    iconComponent: Component {
      Item {
        Image {
          id: face
          anchors.centerIn: parent
          height: button.opticalSize
          width: height
          source: Qt.resolvedUrl("assets/icon.png")
          sourceSize.height: Math.round(button.opticalSize * 2)
          fillMode: Image.PreserveAspectFit
          smooth: true
          mipmap: true
          visible: status === Image.Ready
        }
        Text {
          anchors.centerIn: parent
          visible: face.status !== Image.Ready
          text: "󰧓"
          font.family: button.fontFamily
          font.pixelSize: button.fontSize
          color: button.foreground
        }
      }
    }

    onPressed: root.launch()
  }
}
