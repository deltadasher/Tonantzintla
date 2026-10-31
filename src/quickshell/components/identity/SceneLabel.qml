import QtQuick
import "LockStyles.js" as Styles

// Text in one of an identity's typographic roles (see LockStyles.js).
// Set size rather than font.pixelSize; tracking is proportional to it.
Text {
    property var type: Styles.style("wabi-sabi").label
    property real size: 14
    font.pixelSize: size
    font.family: Styles.family(type.families)
    font.styleName: Styles.styleName(type)
    font.weight: type.weight || Font.Normal
    font.italic: type.italic === true
    font.letterSpacing: (type.tracking || 0) * size
    font.capitalization: type.caps === "upper" ? Font.AllUppercase
        : type.caps === "lower" ? Font.AllLowercase : Font.MixedCase
}
