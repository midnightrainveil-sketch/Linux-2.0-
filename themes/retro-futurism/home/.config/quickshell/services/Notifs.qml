pragma Singleton

import QtQuick
import Quickshell
import Quickshell.Io
import Quickshell.Services.Notifications

// The notifications: this shell is the notification daemon. Every one that
// arrives goes on the history (newest first, at most 60, kept across
// restarts in ~/.local/state/ultra/retro-futurism/notifications.json) and
// the pager (modules/Pager.qml) shows it.
//
//   entries          [{ key, app, icon, summary, body, time, urgent }]
//   open(key)        what it is about: its own action, else its app
//   remove(key)      off the history (and the app told it was dismissed)
//   clearAll()       all of them
//   arrived(key)     a new one (not while Do Not Disturb, unless urgent)
//
// An app may change one it sent (the same id: it moves up, changed) or take
// it back (it goes from the history). Do Not Disturb keeps them, quietly.
Singleton {
    id: root

    property var entries: []
    property bool dnd: false
    readonly property int count: entries.length
    signal arrived(int key)
    function toggleDnd(): void { dnd = !dnd; }

    // the live notification of each entry (gone after a restart: then its
    // app is opened instead of its action)
    property var live: ({})
    property int nextKey: 1

    function find(key: int): var { return entries.find(e => e.key === key) ?? null; }
    function indexOfKey(key: int): int { return entries.findIndex(e => e.key === key); }

    function open(key: int): void {
        const e = find(key);
        if (!e) return;
        const n = live[key];
        let done = false;
        try {
            const acts = n?.actions ?? [];
            const def = acts.find(a => a.identifier === "default") ?? (acts.length === 1 ? acts[0] : null);
            if (def) { def.invoke(); done = true; }
        } catch (err) {}
        if (!done) {
            const app = (e.desktop ? DesktopEntries.byId(e.desktop) : null)
                ?? DesktopEntries.applications.values.find(a => a.name.toLowerCase() === (e.app || "").toLowerCase());
            if (app) app.execute();
        }
        remove(key);
    }
    function remove(key: int): void {
        const n = live[key];
        delete live[key];
        entries = entries.filter(e => e.key !== key);
        save.restart();
        try { if (n) n.dismiss(); } catch (err) {}
    }
    function clearAll(): void {
        for (const k in live) {
            try { live[k].dismiss(); } catch (err) {}
        }
        live = {};
        entries = [];
        save.restart();
    }

    // ---- an icon for it. A well-known app: its brand mark in one colour
    // (Simple Icons, CC0: assets/pager/marks); else its own (a name or a
    // file), its app's, or its name's
    readonly property var marks: ({
        discord: "discord", vesktop: "discord", webcord: "discord", armcord: "discord", discordapp: "discord",
        firefox: "firefoxbrowser", librewolf: "librewolf", chrome: "googlechrome", googlechrome: "googlechrome",
        brave: "brave", spotify: "spotify", telegram: "telegram", telegramdesktop: "telegram",
        slack: "slack", steam: "steam", thunderbird: "thunderbird", signal: "signal", whatsapp: "whatsapp",
        zapzap: "whatsapp", whatsie: "whatsapp", zoom: "zoom", obs: "obsstudio", obsstudio: "obsstudio",
        github: "github", githubdesktop: "github", gitlab: "gitlab", youtube: "youtube", freetube: "youtube",
        twitch: "twitch", reddit: "reddit", mastodon: "mastodon", tuba: "mastodon", element: "element",
        protonmail: "protonmail", proton: "protonmail", gmail: "gmail", calendar: "googlecalendar",
        pacman: "archlinux", archlinux: "archlinux", yay: "archlinux", paru: "archlinux",
        blender: "blender", gimp: "gimp", inkscape: "inkscape", krita: "krita", libreoffice: "libreoffice",
        obsidian: "obsidian", notion: "notion", vivaldi: "vivaldi", opera: "opera", torbrowser: "torbrowser",
        messenger: "messenger", instagram: "instagram", dropbox: "dropbox", nextcloud: "nextcloud",
        bitwarden: "bitwarden", "1password": "1password", keepassxc: "keepassxc", docker: "docker",
        vscodium: "vscodium", code: "vscodium", codeoss: "vscodium", neovim: "neovim", nvim: "neovim",
        alacritty: "alacritty"
    })
    function markFor(n: var): string {
        const names = [n.desktopEntry || "", n.appName || "", n.appIcon || ""];
        for (const name of names) {
            const low = String(name).toLowerCase();
            const whole = low.replace(/[^a-z0-9]/g, "");
            const tokens = [whole].concat(low.split(/[^a-z0-9]+/).filter(t => t.length > 1));
            for (const t of tokens)
                if (marks[t]) return Quickshell.shellPath("assets/pager/marks/" + marks[t] + ".svg");
        }
        return "";
    }
    function iconFor(n: var): string {
        const mark = markFor(n);
        if (mark) return mark;
        const ic = n.appIcon ?? "";
        if (ic.startsWith("file://")) return ic;
        if (ic.startsWith("/")) return "file://" + ic;
        const names = [];
        if (ic !== "") names.push(ic);
        const de = n.desktopEntry ? DesktopEntries.byId(n.desktopEntry) : null;
        if (de?.icon) names.push(de.icon);
        if (n.desktopEntry) names.push(n.desktopEntry);
        if (n.appName) names.push(n.appName.toLowerCase().replace(/\s+/g, "-"));
        for (const name of names) {
            // a one-colour (symbolic) one first: it suits the e-ink screen best
            const sym = Quickshell.iconPath(name + "-symbolic", true);
            if (sym) return sym;
            const p = Quickshell.iconPath(name, true);
            if (p) return p;
        }
        return "";
    }
    function entryOf(n: var, key: int): var {
        return {
            key: key,
            nid: n.id,
            app: n.appName || "",
            desktop: n.desktopEntry || "",
            icon: iconFor(n),
            summary: (n.summary || "").replace(/\s+/g, " ").trim(),
            body: (n.body || "").replace(/<[^>]*>/g, "").replace(/\s+/g, " ").trim(),
            time: Date.now(),
            urgent: n.urgency === NotificationUrgency.Critical
        };
    }

    NotificationServer {
        id: server
        keepOnReload: true
        bodySupported: true
        bodyMarkupSupported: false
        bodyHyperlinksSupported: false
        actionsSupported: true
        imageSupported: false
        persistenceSupported: true

        onNotification: n => {
            n.tracked = true;
            // the same id again: the one it had, changed and moved up
            let key = 0;
            for (const k in root.live)
                if (root.live[k] === n || root.live[k]?.id === n.id) key = Number(k);
            if (key === 0) key = root.nextKey++;
            const e = root.entryOf(n, key);
            const others = root.entries.filter(x => x.key !== key);
            root.entries = [e].concat(others).slice(0, 60);
            const lv = Object.assign({}, root.live); lv[key] = n; root.live = lv;
            // taken back by its app (read there, say): off the history
            n.closed.connect(reason => {
                if (root.live[key] !== n) return;
                if (reason === NotificationCloseReason.CloseRequested) {
                    const l2 = Object.assign({}, root.live); delete l2[key]; root.live = l2;
                    root.entries = root.entries.filter(x => x.key !== key);
                    save.restart();
                }
            });
            save.restart();
            if (!root.dnd || e.urgent) root.arrived(key);
        }
    }

    // ---- kept across restarts (what it said, not its actions)
    readonly property string file: (Quickshell.env("XDG_STATE_HOME") || (Quickshell.env("HOME") + "/.local/state"))
        + "/ultra/retro-futurism/notifications.json"
    FileView {
        id: store
        path: root.file
        printErrors: false
        onLoaded: {
            try {
                const old = JSON.parse(text());
                if (Array.isArray(old)) {
                    const keys = new Set(root.entries.map(e => e.key));
                    let k = root.nextKey;
                    const back = old.filter(e => e && e.summary !== undefined).map(e => Object.assign({}, e, { key: k++ }));
                    root.nextKey = k;
                    root.entries = root.entries.concat(back).slice(0, 60);
                }
            } catch (err) {}
        }
    }
    Timer {
        id: save
        interval: 600
        onTriggered: store.setText(JSON.stringify(root.entries.map(e => ({
            app: e.app, desktop: e.desktop, icon: e.icon, summary: e.summary, body: e.body, time: e.time, urgent: e.urgent
        }))))
    }
    Component.onCompleted: Quickshell.execDetached(["mkdir", "-p", root.file.replace(/\/[^/]*$/, "")])
}
