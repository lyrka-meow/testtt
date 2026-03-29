// Отображает иконку по имени из темы или по url. Поддерживает колоризацию через color/keyColor.
import QtQuick 2.4

Item {
    id: icon

    property string name        // имя иконки из темы
    property alias color: colorizedImage.keyColorOut
    property alias keyColor: colorizedImage.keyColorIn
    property alias source: image.source
    property alias asynchronous: image.asynchronous

    implicitWidth: image.implicitWidth
    implicitHeight: image.implicitHeight

    Component.onCompleted: image.completed = true

    Image {
        id: image
        objectName: "image"
        anchors.fill: parent
        fillMode: Image.PreserveAspectFit

        sourceSize {
            width: icon.width
            height: icon.height
        }

        property bool completed: false
        source: completed && icon.name ? "image://theme/%1".arg(icon.name) : ""

        cache: true
        visible: !colorizedImage.visible
        asynchronous: false
    }

    ShaderEffect {
        id: colorizedImage
        objectName: "shader"

        anchors.fill: parent

        // Whether or not a color has been set.
        visible: image.status == Image.Ready && keyColorOut != Qt.rgba(0.0, 0.0, 0.0, 0.0)

        property Image source: image
        property color keyColorOut: Qt.rgba(0.0, 0.0, 0.0, 0.0)
        property color keyColorIn: "#808080"
        property real threshold: 0.1

        fragmentShader: "
            varying highp vec2 qt_TexCoord0;
            uniform sampler2D source;
            uniform highp vec4 keyColorOut;
            uniform highp vec4 keyColorIn;
            uniform lowp float threshold;
            uniform lowp float qt_Opacity;
            void main() {
                lowp vec4 sourceColor = texture2D(source, qt_TexCoord0);
                gl_FragColor = mix(keyColorOut * vec4(sourceColor.a), sourceColor, step(threshold, distance(sourceColor.rgb / sourceColor.a, keyColorIn.rgb))) * qt_Opacity;
            }"
    }
}