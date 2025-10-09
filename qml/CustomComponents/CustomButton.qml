pragma ComponentBehavior: Bound

import QtQuick
import QtQuick.Controls.Material
import QtQuick.Controls.Material.impl
import Odizinne.OdznDrive
Button {
    id: control
    Material.roundedScale: Material.ExtraSmallScale
    flat: true

    property color rippleHoverColor: Constants.rippleHoverColor
    background: Rectangle {
        implicitWidth: implicitHeight
        implicitHeight: control.Material.buttonHeight

        radius: control.Material.roundedScale === Material.FullScale ? height / 2 : control.Material.roundedScale
        color: control.Material.buttonColor(control.Material.theme, control.Material.background,
            control.Material.accent, control.enabled, control.flat, control.highlighted, control.checked)

        // The layer is disabled when the button color is transparent so you can do
        // Material.background: "transparent" and get a proper flat button without needing
        // to set Material.elevation as well
        layer.enabled: control.enabled && color.a > 0 && !control.flat
        layer.effect: RoundedElevationEffect {
            elevation: control.Material.elevation
            roundedScale: Material.ExtraSmallScale
        }

        Ripple {
            clip: true
            clipRadius: parent.radius
            width: parent.width
            height: parent.height
            pressed: control.pressed
            anchor: control
            active: enabled && (control.down || control.visualFocus || control.hovered)
            color: control.flat && control.hovered && UserSettings.darkMode
                   ? control.rippleHoverColor
                   : (control.flat && control.highlighted
                      ? control.Material.highlightedRippleColor
                      : control.Material.rippleColor)

        }
    }
}
