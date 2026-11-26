# Scrolling-Fenstermanager (wie niri) auf macOS: Bewertung auf Basis von yabai

Stand: yabai `main` bei Commit `477e859` (24.11.2026), etwa 16 200 Zeilen C/Objective-C, MIT-Lizenz.
Nur Quellcode gelesen, nichts gebaut oder ausprobiert.

## Kurzfazit

- **Technisch möglich, ja.** yabais Grundgerüst (Fenster finden, Ereignisse von Apps und Spaces empfangen,
  Fenster per Accessibility verschieben) passt auch für ein Scrolling-Layout.
- **Aber kein kleiner Umbau:** yabais Layout-Kern ist durchgehend auf einen Binärbaum (BSP) gebaut. Ein
  Scrolling-Layout braucht eine andere Datenstruktur und einen eigenen Satz Befehle. Ich schätze
  **1 500–2 500 Zeilen C**, verteilt über die fünf größten Dateien, plus dauerhafte Pflege eines Forks.
- **Die eigentlichen Grenzen setzt macOS, nicht yabai:** Fenster dürfen nicht ganz aus dem Bild, flüssige
  Animationen gibt es nur mit deaktiviertem SIP, und Spaces lassen sich ohne SIP nicht per Befehl steuern.
  Diese Grenzen gelten für jede Lösung gleich.
- **Empfehlung:** Erst **Paneru** ausprobieren. Das ist genau das, was du suchst (von niri und PaperWM
  inspiriert, Architektur laut eigener Aussage an yabai angelehnt), in Rust, MIT-Lizenz. Fehlt dort etwas,
  ist ein Beitrag zu Paneru deutlich billiger als ein yabai-Fork.

## Was „wie niri“ heißt

1. Fenster liegen als **Spalten auf einem endlosen horizontalen Streifen**, pro Monitor (und Arbeitsbereich).
   Neue Fenster werden neben dem fokussierten eingefügt, nichts wird gequetscht.
2. Der **Fokus zieht den Streifen mit**: Die fokussierte Spalte wird ins Bild gescrollt.
3. **Spaltenbreiten** als Voreinstellungen (z. B. 1/3, 1/2, 2/3, volle Breite), pro Spalte umschaltbar.
4. **Mehrere Fenster pro Spalte** übereinander, Fenster in eine Spalte holen oder herauslösen.
5. **Arbeitsbereiche vertikal** gestapelt, dynamisch.
6. **Flüssige Animationen und Gesten** (Trackpad-Wischen scrollt den Streifen).

## Wie yabai aufgebaut ist (relevant für ein neues Layout)

| Teil | Datei | Was dort passiert |
|---|---|---|
| Layout-Datenstruktur | `src/view.h`, `src/view.c` (1 042 Zeilen) | `struct view` pro Space mit `root`, einem Binärbaum aus `struct window_node` (`left`/`right`, `split`, `ratio`). Layouts: `bsp`, `stack`, `float`. Ein Blatt fasst höchstens 32 Fenster (`NODE_MAX_WINDOW_COUNT`). |
| Flächen berechnen | `view_update` → `window_node_update` | Startet mit den Bildschirmgrenzen minus Ränder und teilt rekursiv auf. Alles bleibt **innerhalb des Bildschirms**. |
| Fenster anwenden | `window_node_flush` → `window_manager_animate_window_list` | Setzt Position und Größe per Accessibility (`kAXPositionAttribute`, `kAXSizeAttribute`). |
| Animationen | `window_manager_animate_window_list_async` | Tauscht Fenster gegen Bild-Proxies (`scripting_addition_swap_window_proxy_in/out`). **Braucht die Scripting Addition, also SIP teilweise aus.** Ohne sie springen Fenster direkt an die Zielposition. |
| Befehle | `src/message.c` (3 045 Zeilen) | Fast alle Layout-Befehle sind BSP-Begriffe: `--warp`, `--swap`, `--insert`, `--ratio`, `--balance`, `--rotate`, `--mirror`. |
| BSP-Abhängigkeiten | `window_manager.c`, `space_manager.c`, `message.c`, `mouse_handler.c`, `view.c` | 17 Stellen prüfen ausdrücklich `layout == VIEW_BSP` und lehnen sonst ab. |
| Fenster/Apps/Spaces | `event_loop.c`, `window_manager.c`, `application.c`, `space_manager.c`, `display_manager.c` | Fenster finden, AX-Beobachter, Space- und Monitorwechsel. **Dieser Teil ist layoutunabhängig und wiederverwendbar.** |

## Option A: Scrolling-Layout in einen yabai-Fork einbauen

**Was nötig wäre:**

1. **Neue Datenstruktur** pro Space, z. B. `struct column { uint32_t windows[]; float width_ratio; }`,
   eine Spaltenliste und ein Scroll-Versatz `scroll_x`. Der Binärbaum passt nicht: Er teilt eine feste Fläche
   auf, ein Streifen ist dagegen breiter als der Bildschirm.
2. **Eigenes `view_update`** für `VIEW_SCROLL`: Spalten nebeneinander auslegen, Versatz abziehen, Fenster
   außerhalb des Bildschirms an den Rand legen (siehe macOS-Grenzen).
3. **Fokus-Ereignis → Scrollen:** Im Ereignis-Handler für Fokuswechsel (`event_loop.c`) den Versatz so
   setzen, dass die fokussierte Spalte sichtbar ist, dann neu auslegen.
4. **Einfügen und Entfernen** (`view_add_window_node*`, `view_remove_window_node`) für Spalten.
5. **Neue Befehle** in `message.c`: Spalte links/rechts fokussieren und verschieben, Fenster in Spalte
   holen/herauslösen, Breite umschalten, Spalte zentrieren. Abfrage-Ausgabe (`view_serialize`) erweitern.
6. **Bestehende BSP-Befehle** für das neue Layout abfangen oder sinnvoll umdeuten (17 Stellen).
7. **Maus:** Ziehen und Größe ändern in `mouse_handler.c` für Spalten.

**Aufwand:** etwa 1 500–2 500 Zeilen C, mehrere Wochen Abendarbeit inklusive Testen auf echten Macs mit
mehreren Monitoren und Spaces.

**Dagegen spricht:**

- Der Fork muss dauerhaft mit yabai-Upstream abgeglichen werden; der Layout-Code ist mitten in den am meisten
  geänderten Dateien (`message.c`, `window_manager.c`).
- Ob Upstream so ein Layout übernehmen würde, ist offen.
- C, ohne Tests für die Layout-Logik.

## Option B: eigenen Manager von yabai ableiten

Den layoutunabhängigen Teil (Ereignisse, Fenster, Spaces, Monitore) übernehmen und den Layout- und
Befehlsteil neu schreiben. Das ist im Kern Option A ohne Rücksicht auf BSP-Kompatibilität: weniger
Verrenkungen, aber dafür eine eigene Codebasis, die man komplett selbst pflegt. Aufwand ähnlich wie A,
plus Aufräumen dessen, was man nicht braucht.

## Option C: auf bestehenden Scrolling-Managern aufbauen

| Projekt | Sprache | Stand (laut README) | Bemerkung |
|---|---|---|---|
| **Paneru** (`karinushka/paneru`) | Rust, MIT | ca. 2 500 Sterne, ~1 100 Commits, über Homebrew installierbar | „Sliding, tiling window manager“, von niri und PaperWM.spoon inspiriert, Architektur an yabai angelehnt. Streifen pro Monitor und pro Space, Trackpad-Scrollen, Spaltenbreiten, Stapeln, Abfrage-Schnittstelle, Lua-Konfiguration. Kein Hinweis auf SIP-Pflicht. |
| **PaperWM.spoon** (`mogenson/PaperWM.spoon`) | Lua (Hammerspoon) | ca. 1 800 Sterne | Scrollbares Tiling, Spaltenbreiten, Stapel, Trackpad-Wischen. Passt zu deiner Hammerspoon-Konfiguration. |
| **Nehir** (`Guria/Nehir`) | – | nicht geprüft | Von Paneru als weiteres „scrollable tiling for macOS“ genannt. |

**Empfehlung:** Paneru ausprobieren. Es löst genau die Probleme, die ein yabai-Fork erst lösen müsste, und
ist wegen der yabai-ähnlichen Architektur leicht zu verstehen. Fehlende niri-Funktionen als Beitrag dort
einzubauen ist um ein Vielfaches günstiger als Option A oder B.

## Grenzen, die macOS für jede Lösung setzt

1. **Fenster dürfen nicht ganz aus dem Bild.** macOS schiebt Fenster zurück, die vollständig außerhalb liegen.
   Paneru und PaperWM.spoon lassen deshalb einen schmalen Streifen jedes Fensters am Bildschirmrand stehen.
   Bei Monitoren **nebeneinander** ragen diese Fenster auf den Nachbarmonitor; beide Projekte empfehlen, die
   Monitore übereinander anzuordnen.
2. **Keine flüssigen Animationen ohne SIP.** Ohne Zugriff auf den Compositor bleibt nur, Fenster pro Bild per
   Accessibility zu verschieben. Jeder Aufruf geht an die jeweilige App; bei vielen Fenstern ruckelt das.
   yabai animiert deshalb nur mit Scripting Addition, die SIP teilweise deaktiviert voraussetzt.
3. **Spaces lassen sich ohne SIP nicht per Befehl anlegen, verschieben oder wechseln.** niris dynamische
   vertikale Arbeitsbereiche lassen sich nur nachbilden (z. B. virtuelle Arbeitsbereiche innerhalb eines
   Spaces, wie bei Paneru experimentell).
4. **Apps mit Mindestgrößen, Vollbild-Spaces, Dialoge und Fenster, die sich selbst verschieben**, brechen das
   Layout immer wieder; das braucht Ausnahmeregeln pro App.
5. **Gesten:** Trackpad-Wischen lässt sich abfangen, kollidiert aber mit den Systemgesten für Spaces und
   Mission Control, wenn dieselbe Fingerzahl genutzt wird.

## Vorschlag für die nächsten Schritte

1. Paneru per `brew install paneru` installieren und eine Woche nutzen.
2. Notieren, was gegenüber niri fehlt oder stört.
3. Je nach Liste: Konfiguration anpassen, Issue oder Beitrag bei Paneru, oder, falls Paneru grundsätzlich
   nicht passt, Option B mit einem Prototyp für einen Space und einen Monitor beginnen.
