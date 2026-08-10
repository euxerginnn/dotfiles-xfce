#!/usr/bin/env python3
"""
plank-padding.py - Cria spacers transparentes nas bordas da tela para:
  - Gap entre o painel do topo e as janelas (TOP_PADDING)
  - Gap entre o Plank e a borda inferior da tela (BOTTOM_PADDING)

Funciona dinamicamente com múltiplos monitores.
Inicia o Plank automaticamente após os spacers estarem prontos.

Uso:
  plank-padding.py           # Foreground
  plank-padding.py --daemon  # Background (fork)
"""

import gi
gi.require_version('Gtk', '3.0')
gi.require_version('Gdk', '3.0')
from gi.repository import Gtk, Gdk, GLib
import subprocess
import signal
import sys
import os
import time

TOP_PADDING = 40     # pixels de gap no topo (strut total, se sobrepõe ao painel de 30px = 10px de gap real)
BOTTOM_PADDING = 5   # pixels de gap entre o Plank e a borda da tela
BOTTOM_WINDOW_GAP = 5  # pixels de gap entre janelas e o topo do Plank


class SpacerWindow(Gtk.Window):
    """Janela dock transparente que reserva espaço numa borda da tela"""

    def __init__(self, monitor_geom, index, position):
        super().__init__()
        self.monitor_geom = monitor_geom
        self.position = position  # "top" ou "bottom"

        self.set_title(f"plank-spacer-{position}-{index}")
        self.set_decorated(False)
        self.set_skip_taskbar_hint(True)
        self.set_skip_pager_hint(True)
        self.set_type_hint(Gdk.WindowTypeHint.DOCK)
        self.stick()
        self.set_keep_below(True)

        width = monitor_geom.width

        if position == "bottom":
            height = BOTTOM_PADDING
            x = monitor_geom.x
            y = monitor_geom.y + monitor_geom.height - BOTTOM_PADDING
        else:  # top
            height = TOP_PADDING
            x = monitor_geom.x
            # Posiciona logo abaixo do painel (o painel já tem seu próprio strut)
            # O spacer fica no topo do monitor; o strut se soma ao do painel
            y = monitor_geom.y

        self.set_default_size(width, height)
        self.set_size_request(width, height)
        self.move(x, y)

        # Transparência total
        screen = self.get_screen()
        visual = screen.get_rgba_visual()
        if visual:
            self.set_visual(visual)
        self.set_app_paintable(True)
        self.connect("draw", self.on_draw)
        self.connect("realize", self.on_realize)

        self.show_all()
        log(f"  Monitor {index} [{position}]: spacer {width}x{height} @ ({x}, {y})")

    def on_draw(self, widget, cr):
        cr.set_source_rgba(0, 0, 0, 0)
        cr.set_operator(0)  # CAIRO_OPERATOR_CLEAR
        cr.paint()
        return True

    def on_realize(self, widget):
        window = self.get_window()
        if not window:
            return
        xid = window.get_xid()
        geom = self.monitor_geom

        start_x = geom.x
        end_x = geom.x + geom.width - 1

        if self.position == "bottom":
            strut = f"0,0,0,{BOTTOM_PADDING}"
            strut_partial = f"0,0,0,{BOTTOM_PADDING},0,0,0,0,0,0,{start_x},{end_x}"
        else:  # top
            strut = f"0,0,{TOP_PADDING},0"
            strut_partial = f"0,0,{TOP_PADDING},0,0,0,0,0,{start_x},{end_x},0,0"

        subprocess.run([
            "xprop", "-id", str(xid),
            "-f", "_NET_WM_STRUT", "32c",
            "-set", "_NET_WM_STRUT", strut
        ], capture_output=True)
        subprocess.run([
            "xprop", "-id", str(xid),
            "-f", "_NET_WM_STRUT_PARTIAL", "32c",
            "-set", "_NET_WM_STRUT_PARTIAL", strut_partial
        ], capture_output=True)


class PlankPadding:
    def __init__(self):
        self.spacers = []
        self.plank_restarted = False
        self.setup_spacers()

        # Monitora mudanças de monitor
        screen = Gdk.Screen.get_default()
        screen.connect("monitors-changed", self.on_monitors_changed)
        screen.connect("size-changed", self.on_monitors_changed)

        # Restart Plank após spacers estarem prontos
        GLib.timeout_add(500, self.ensure_plank)

    def setup_spacers(self):
        """Cria spacers para todos os monitores ativos"""
        for spacer in self.spacers:
            spacer.destroy()
        self.spacers = []

        display = Gdk.Display.get_default()
        n_monitors = display.get_n_monitors()

        log(f"Configurando spacers para {n_monitors} monitor(es):")
        log(f"  TOP_PADDING={TOP_PADDING}px, BOTTOM_PADDING={BOTTOM_PADDING}px")

        for i in range(n_monitors):
            monitor = display.get_monitor(i)
            geom = monitor.get_geometry()
            # Spacer inferior (pra empurrar o Plank)
            self.spacers.append(SpacerWindow(geom, i, "bottom"))
            # Spacer superior (gap entre painel e janelas)
            self.spacers.append(SpacerWindow(geom, i, "top"))

    def ensure_plank(self):
        """Garante que o Plank reinicie após os spacers estarem ativos"""
        if self.plank_restarted:
            return False

        # Verifica se o Plank está rodando
        try:
            result = subprocess.run(["pgrep", "-x", "plank"], capture_output=True)
            plank_running = result.returncode == 0
        except Exception:
            plank_running = False

        if plank_running:
            log("Reiniciando Plank para aplicar padding...")
            subprocess.run(["killall", "plank"], capture_output=True)
            time.sleep(1)

        # Inicia o Plank
        subprocess.Popen(["plank"], stdout=subprocess.DEVNULL, stderr=subprocess.DEVNULL)
        log("Plank iniciado com padding ativo!")

        # Aguarda Plank criar a janela e sobrescreve o strut pra incluir gap
        GLib.timeout_add(2000, self.override_plank_strut)

        # Timer periódico pra manter o strut correto (caso picom reinicie, etc)
        GLib.timeout_add(5000, self.watch_plank_strut)

        self.plank_restarted = True
        return False

    def override_plank_strut(self):
        """Sobrescreve o strut do Plank para incluir o gap entre janelas e o dock"""
        try:
            output = subprocess.check_output(["wmctrl", "-l"], text=True)
            plank_id = None
            for line in output.splitlines():
                if "plank" in line.lower() and "spacer" not in line.lower():
                    plank_id = line.split()[0]
                    break

            if not plank_id:
                return False

            # Pega o strut atual do Plank
            strut_out = subprocess.check_output(
                ["xprop", "-id", plank_id, "_NET_WM_STRUT_PARTIAL"], text=True)
            # Formato: _NET_WM_STRUT_PARTIAL(CARDINAL) = 0, 0, 0, 71, 0, 0, 0, 0, 0, 0, 0, 1919
            values = [int(v.strip()) for v in strut_out.split("=")[1].split(",")]
            current_bottom = values[3]
            start_x = values[10]
            end_x = values[11]

            # Adiciona o gap extra ao strut do Plank
            new_bottom = current_bottom + BOTTOM_WINDOW_GAP

            subprocess.run([
                "xprop", "-id", plank_id,
                "-f", "_NET_WM_STRUT", "32c",
                "-set", "_NET_WM_STRUT", f"0,0,0,{new_bottom}"
            ], capture_output=True)
            subprocess.run([
                "xprop", "-id", plank_id,
                "-f", "_NET_WM_STRUT_PARTIAL", "32c",
                "-set", "_NET_WM_STRUT_PARTIAL",
                f"0,0,0,{new_bottom},0,0,0,0,0,0,{start_x},{end_x}"
            ], capture_output=True)

            log(f"Strut do Plank ajustado: {current_bottom} -> {new_bottom} (+{BOTTOM_WINDOW_GAP}px gap)")
        except Exception as e:
            log(f"Erro ao ajustar strut do Plank: {e}")
        return False

    def watch_plank_strut(self):
        """Verifica periodicamente se o strut do Plank ainda inclui o gap"""
        try:
            output = subprocess.check_output(["wmctrl", "-l"], text=True)
            plank_id = None
            for line in output.splitlines():
                if "plank" in line.lower() and "spacer" not in line.lower():
                    plank_id = line.split()[0]
                    break

            if not plank_id:
                return True  # Continua tentando

            strut_out = subprocess.check_output(
                ["xprop", "-id", plank_id, "_NET_WM_STRUT_PARTIAL"], text=True)
            values = [int(v.strip()) for v in strut_out.split("=")[1].split(",")]
            current_bottom = values[3]

            # Se o strut não inclui o gap (Plank resetou), reaplica
            # O strut original do Plank é ~66-71, com gap deveria ser ~71-76+
            if current_bottom <= 71:
                self.override_plank_strut()
        except Exception:
            pass
        return True  # Repete a cada 5s

    def on_monitors_changed(self, *args):
        """Reconfigura spacers quando monitores mudam"""
        log("\nMudança de monitores detectada!")
        self.plank_restarted = False
        GLib.timeout_add(2000, self._delayed_reconfig)

    def _delayed_reconfig(self):
        self.setup_spacers()
        GLib.timeout_add(1000, self.ensure_plank)
        return False


def log(msg):
    print(msg, flush=True)


def main():
    log(f"=== Plank Padding Spacer ===")
    log(f"    Top: {TOP_PADDING}px | Bottom: {BOTTOM_PADDING}px")

    if "--daemon" in sys.argv:
        pid = os.fork()
        if pid > 0:
            print(f"Daemon iniciado (PID: {pid})")
            sys.exit(0)
        os.setsid()
        log_path = os.path.expanduser("~/.local/share/plank-padding.log")
        sys.stdout = open(log_path, "a")
        sys.stderr = sys.stdout

    signal.signal(signal.SIGINT, lambda *_: Gtk.main_quit())
    signal.signal(signal.SIGTERM, lambda *_: Gtk.main_quit())

    app = PlankPadding()
    Gtk.main()


if __name__ == "__main__":
    main()
