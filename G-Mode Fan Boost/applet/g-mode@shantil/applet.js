// G-Mode Fan Boost — Cinnamon applet for Dell G-series laptops.
//
// Fan speed = Dell's automatic fan curve + boost (0-100). Boost 0 = automatic only.
// Reads fan speeds, temperatures and the boost from the alienware_wmi hwmon device,
// and changes the boost through `sudo -n /usr/local/bin/g-fan-boost set N`
// (the same command the G key uses, so the two always agree).

const Applet = imports.ui.applet;
const PopupMenu = imports.ui.popupMenu;
const Settings = imports.ui.settings;
const Mainloop = imports.mainloop;
const Util = imports.misc.util;
const GLib = imports.gi.GLib;
const Gio = imports.gi.Gio;
const St = imports.gi.St;
const Clutter = imports.gi.Clutter;

const BOOST_CMD = '/usr/local/bin/g-fan-boost';
const MAX = 100;
const DEFAULT_LEVELS = '0 33 66 100';
const CONF = GLib.get_home_dir() + '/.config/g-mode.conf';
const CONF_TEMPLATE =
    '# G key fan boost levels, cycled in this order on each press.\n' +
    '# Fan speed = Dell\'s automatic curve + level. 0 = automatic only, 100 = maximum.\n' +
    '# Out-of-range values are clamped to 0-100; entries with no number are skipped.\n' +
    'LEVELS="' + DEFAULT_LEVELS + '"\n';

const decoder = new TextDecoder();

function readFile(path) {
    try {
        const [ok, data] = GLib.file_get_contents(path);
        return ok ? decoder.decode(data).trim() : null;
    } catch (e) {
        return null;
    }
}

function readInt(path) {
    const t = readFile(path);
    const n = t === null ? NaN : parseInt(t, 10);
    return isNaN(n) ? null : n;
}

function findHwmon() {
    for (let i = 0; i < 64; i++) {
        const dir = `/sys/class/hwmon/hwmon${i}`;
        if (readFile(dir + '/name') === 'alienware_wmi')
            return dir;
    }
    return null;
}

function clamp(n) {
    return Math.max(0, Math.min(MAX, n));
}

// Same rules as the G key: clamp to 0-100, round, skip entries without a number, drop repeats.
function cleanLevels(text) {
    const out = [];
    for (let tok of (text || '').split(/\s+/)) {
        const s = tok.replace(/%/g, '').replace(',', '.');
        if (!/^[-+]?(\d+(\.\d*)?|\.\d+)([eE][-+]?\d+)?$/.test(s))
            continue;
        const n = clamp(Math.round(parseFloat(s)));
        if (!out.includes(n))
            out.push(n);
    }
    return out.length ? out : DEFAULT_LEVELS.split(' ').map(Number);
}

function readLevels() {
    const t = readFile(CONF);
    const m = t && t.match(/^\s*LEVELS\s*=\s*["']?([^"'\n]*)["']?/m);
    return cleanLevels(m ? m[1] : DEFAULT_LEVELS);
}

function levelName(n) {
    return n === 0 ? 'Automatic' : `Auto + ${n}`;
}

class GModeApplet extends Applet.TextIconApplet {
    constructor(metadata, orientation, panelHeight, instanceId) {
        super(orientation, panelHeight, instanceId);
        this.metadata = metadata;
        this.hwmon = findHwmon();
        this.boost = null;
        this.error = null;
        this.lastUserChange = 0;
        this.applyTimer = 0;
        this.pollTimer = 0;

        this.set_applet_icon_symbolic_path(metadata.path + '/icons/fan-symbolic.svg');

        this.settings = new Settings.AppletSettings(this, metadata.uuid, instanceId);
        this.settings.bind('label-style', 'labelStyle', () => this.update());
        this.settings.bind('scroll-step', 'scrollStep');
        this.settings.bind('interval', 'interval', () => this.startPolling());

        this.menuManager = new PopupMenu.PopupMenuManager(this);
        this.menu = new Applet.AppletPopupMenu(this, orientation);
        this.menuManager.addMenu(this.menu);
        this.buildMenu();

        this.actor.connect('scroll-event', (actor, event) => this.onScroll(event));

        this.update();
        this.startPolling();
    }

    buildMenu() {
        this.statusItem = new PopupMenu.PopupMenuItem('', { reactive: false });
        this.fansItem = new PopupMenu.PopupMenuItem('', { reactive: false });
        this.tempsItem = new PopupMenu.PopupMenuItem('', { reactive: false });
        this.statusItem.label.add_style_class_name('popup-subtitle-menu-item');
        this.menu.addMenuItem(this.statusItem);
        this.menu.addMenuItem(this.fansItem);
        this.menu.addMenuItem(this.tempsItem);

        this.menu.addMenuItem(new PopupMenu.PopupSeparatorMenuItem());
        this.levelSection = new PopupMenu.PopupMenuSection();
        this.menu.addMenuItem(this.levelSection);

        this.menu.addMenuItem(new PopupMenu.PopupSeparatorMenuItem());
        this.sliderLabel = new PopupMenu.PopupMenuItem('', { reactive: false });
        this.menu.addMenuItem(this.sliderLabel);
        this.slider = new PopupMenu.PopupSliderMenuItem(0);
        this.slider.connect('value-changed', (item, value) => {
            const n = clamp(Math.round(value * MAX));
            this.sliderLabel.label.set_text(`Custom: ${levelName(n)}`);
            this.lastUserChange = Date.now();
            this.scheduleApply(n, 400);
        });
        this.slider.connect('drag-end', () => {
            this.scheduleApply(clamp(Math.round(this.slider.value * MAX)), 0);
        });
        this.menu.addMenuItem(this.slider);

        this.menu.addMenuItem(new PopupMenu.PopupSeparatorMenuItem());
        const edit = new PopupMenu.PopupMenuItem('Edit G key levels…');
        edit.connect('activate', () => this.editLevels());
        this.menu.addMenuItem(edit);

        this.menu.connect('open-state-changed', (menu, open) => {
            if (open) {
                this.rebuildLevels();
                this.update(true);
            }
        });
    }

    rebuildLevels() {
        this.levelSection.removeAll();
        this.levelItems = [];
        for (const n of readLevels()) {
            const item = new PopupMenu.PopupMenuItem(levelName(n));
            item.setOrnament(PopupMenu.OrnamentType.DOT, n === this.boost);
            item.connect('activate', () => this.setBoost(n));
            this.levelSection.addMenuItem(item);
            this.levelItems.push([n, item]);
        }
    }

    editLevels() {
        if (!GLib.file_test(CONF, GLib.FileTest.EXISTS)) {
            GLib.mkdir_with_parents(GLib.path_get_dirname(CONF), 0o755);
            GLib.file_set_contents(CONF, CONF_TEMPLATE);
        }
        Util.spawn(['xdg-open', CONF]);
    }

    onScroll(event) {
        const dir = event.get_scroll_direction();
        let delta = 0;
        if (dir === Clutter.ScrollDirection.UP) delta = this.scrollStep;
        else if (dir === Clutter.ScrollDirection.DOWN) delta = -this.scrollStep;
        else return Clutter.EVENT_PROPAGATE;
        const base = this.pending !== undefined && this.applyTimer ? this.pending : (this.boost || 0);
        const n = clamp(base + delta);
        this.lastUserChange = Date.now();
        this.showBoost(n);
        this.scheduleApply(n, 350);
        return Clutter.EVENT_STOP;
    }

    scheduleApply(n, delayMs) {
        this.pending = n;
        if (this.applyTimer) {
            Mainloop.source_remove(this.applyTimer);
            this.applyTimer = 0;
        }
        const run = () => {
            this.applyTimer = 0;
            this.setBoost(this.pending);
            return false;
        };
        if (delayMs > 0) this.applyTimer = Mainloop.timeout_add(delayMs, run);
        else run();
    }

    setBoost(n) {
        n = clamp(Math.round(n));
        this.lastUserChange = Date.now();
        this.showBoost(n);
        try {
            const proc = new Gio.Subprocess({
                argv: ['sudo', '-n', BOOST_CMD, 'set', String(n)],
                flags: Gio.SubprocessFlags.STDOUT_PIPE | Gio.SubprocessFlags.STDERR_PIPE,
            });
            proc.init(null);
            proc.communicate_utf8_async(null, null, (p, res) => {
                try {
                    const [, out, err] = p.communicate_utf8_finish(res);
                    this.error = p.get_successful() ? null : ((err || out || 'g-fan-boost failed').trim());
                } catch (e) {
                    this.error = e.message;
                }
                this.update();
            });
        } catch (e) {
            this.error = `Can't run ${BOOST_CMD}: ${e.message}`;
            this.update();
        }
    }

    // Show a level right away while the firmware catches up.
    showBoost(n) {
        this.boost = n;
        this.updateLabel(null);
    }

    startPolling() {
        if (this.pollTimer)
            Mainloop.source_remove(this.pollTimer);
        this.pollTimer = Mainloop.timeout_add_seconds(Math.max(1, this.interval || 2), () => {
            this.update();
            return true;
        });
    }

    readState() {
        if (!this.hwmon || !GLib.file_test(this.hwmon + '/fan1_boost', GLib.FileTest.EXISTS))
            this.hwmon = findHwmon();
        if (!this.hwmon)
            return null;
        const h = this.hwmon;
        return {
            boost: readInt(h + '/fan1_boost'),
            cpuRpm: readInt(h + '/fan1_input'),
            gpuRpm: readInt(h + '/fan2_input'),
            cpuTemp: readInt(h + '/temp1_input'),
            gpuTemp: readInt(h + '/temp2_input'),
        };
    }

    updateLabel(st) {
        const b = this.boost;
        let text = '';
        if (this.labelStyle !== 'none' && b !== null) {
            text = b === 0 ? 'Auto' : `+${b}`;
            if (this.labelStyle === 'level-rpm' && st && st.cpuRpm !== null)
                text += ` · ${st.cpuRpm}`;
        }
        if (this.error)
            text = '!';
        this.set_applet_label(text);
    }

    update(force) {
        const st = this.readState();
        if (!st) {
            this.boost = null;
            this.error = 'alienware_wmi fan control not found (needs kernel 6.15 or newer)';
        } else if (force || Date.now() - this.lastUserChange > 1500) {
            this.boost = st.boost;
        }

        this.updateLabel(st);
        const temp = (v) => (v === null || v === undefined ? '?' : Math.round(v / 1000) + '°C');
        const rpm = (v) => (v === null || v === undefined ? '?' : v + ' RPM');
        const title = this.error ? 'G-Mode: error' : `G-Mode: ${levelName(this.boost || 0)}`;
        const fans = st ? `CPU fan ${rpm(st.cpuRpm)}  ·  GPU fan ${rpm(st.gpuRpm)}` : '';
        const temps = st ? `CPU ${temp(st.cpuTemp)}  ·  GPU ${temp(st.gpuTemp)}` : '';

        this.statusItem.label.set_text(this.error ? this.error : title);
        this.fansItem.label.set_text(fans);
        this.tempsItem.label.set_text(temps);
        this.set_applet_tooltip([title, fans, temps,
            'Scroll to adjust · G key cycles levels'].filter(Boolean).join('\n'));

        if (this.boost !== null && Date.now() - this.lastUserChange > 1500) {
            this.slider.setValue(this.boost / MAX);
            this.sliderLabel.label.set_text(`Custom: ${levelName(this.boost)}`);
        }
        for (const [n, item] of this.levelItems || [])
            item.setOrnament(PopupMenu.OrnamentType.DOT, n === this.boost);
    }

    on_applet_clicked() {
        this.menu.toggle();
    }

    on_applet_removed_from_panel() {
        if (this.pollTimer) Mainloop.source_remove(this.pollTimer);
        if (this.applyTimer) Mainloop.source_remove(this.applyTimer);
        this.pollTimer = this.applyTimer = 0;
        this.settings.finalize();
    }
}

function main(metadata, orientation, panelHeight, instanceId) {
    return new GModeApplet(metadata, orientation, panelHeight, instanceId);
}
