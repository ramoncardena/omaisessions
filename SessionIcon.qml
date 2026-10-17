import QtQuick
import QtQuick.Shapes
import qs.Commons

// The omAiSessions mark (assets/icon.svg): a robot head whose antenna is a
// return arrow. The SVG's paths, drawn on its 16-unit grid and scaled, so
// the mark takes the bar's color and stays sharp at any size.
Item {
  id: root

  property real size: 16
  property color color: Color.foreground

  implicitWidth: size
  implicitHeight: size

  Shape {
    width: 16
    height: 16
    anchors.centerIn: parent
    scale: Math.min(root.width, root.height) / 16
    preferredRendererType: Shape.CurveRenderer

    // Head and antenna-arrow.
    ShapePath {
      fillColor: "transparent"
      strokeColor: root.color
      strokeWidth: 1.5
      capStyle: ShapePath.RoundCap
      joinStyle: ShapePath.RoundJoin
      PathSvg {
        path: "M4.5 7H11.5A2 2 0 0 1 13.5 9V12A2 2 0 0 1 11.5 14H4.5A2 2 0 0 1 2.5 12V9A2 2 0 0 1 4.5 7Z"
          + "M8 7V4.5A2.5 2.5 0 0 0 5.5 2H3M5 0.8L3 2L5 3.8"
      }
    }

    // Eyes.
    ShapePath {
      fillColor: root.color
      strokeWidth: -1
      PathSvg {
        path: "M5 10.25A0.75 0.75 0 0 1 6.5 10.25V11.25A0.75 0.75 0 0 1 5 11.25Z"
          + "M9.5 10.25A0.75 0.75 0 0 1 11 10.25V11.25A0.75 0.75 0 0 1 9.5 11.25Z"
      }
    }
  }
}
