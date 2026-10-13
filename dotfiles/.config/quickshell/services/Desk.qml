pragma Singleton

import QtQuick
import Quickshell

// The desk: the record cards (and, through archive-desk, the terminal) as
// laid out at login. Cards can be dragged anywhere and filed away with a
// right click; restore() puts every card back in its place. The bar's desk
// button and Super+D run archive-desk, which calls it over IPC.
Singleton {
    id: root

    // card name -> true once filed away
    property var closed: ({})

    // every card listens, and snaps back to its place
    signal restored()

    function isClosed(name: string): bool {
        return closed[name] === true;
    }

    function close(name: string): void {
        const next = Object.assign({}, closed);
        next[name] = true;
        closed = next;
    }

    function restore(): void {
        closed = ({});
        restored();
    }
}
