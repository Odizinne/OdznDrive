pragma Singleton
import QtQuick

QtObject {
    function formatStorage(bytes) {
        let mb = bytes / (1024 * 1024)
        if (mb >= 1000) {
            let gb = mb / 1024
            return gb.toFixed(1) + " GB"
        }
        return Math.round(mb) + " MB"
    }
}
