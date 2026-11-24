# WindowSwitcher

Minimaler Fensterwechsler für macOS, als Menüleisten-App (Symbol ⇥) ohne Einstellungsfenster. Die gesamte
Konfiguration steht in einer JSON-Datei.

- Getrennte Shortcuts für vorwärts und rückwärts, beliebig viele Tasten pro Richtung
- Pro Gruppe nur der aktuelle Space oder alle Spaces, mehrere Gruppen mit eigenen Tasten möglich
- Wechsel sofort beim Drücken (`instant`) oder erst beim Loslassen
- Reihenfolge „zuletzt benutzt“ (ändert sich beim Wechseln) oder fest (Erstellung, alphabetisch)
- Solange die Haltetaste gedrückt ist, bleibt die Reihenfolge eingefroren: wiederholtes Drücken läuft durch
  alle Fenster, statt zwischen zweien hin und her zu springen

## Bauen

Braucht die Xcode Command Line Tools (`xcode-select --install`), kein Xcode-Projekt.

```bash
./build.sh
```

Das Skript erzeugt `build/WindowSwitcher.app` und signiert es mit dem Zertifikat „Local Self-Signed“, falls
vorhanden (sonst ad hoc). Mit stabiler Signatur behält macOS die Berechtigung über Neubauten hinweg.

```bash
cp -R build/WindowSwitcher.app /Applications/ && open /Applications/WindowSwitcher.app
```

Beim ersten Start fragt macOS nach **Bedienungshilfen** (Systemeinstellungen → Datenschutz & Sicherheit). Nach
dem Erlauben startet die App von selbst durch, ein Neustart ist nicht nötig.

Tests der Logik (Konfiguration, Sortierung, Durchlauf):

```bash
swift test
```

## Konfiguration

`~/.config/window-switcher/config.json`, wird beim ersten Start mit den Standardwerten angelegt. Nach dem
Bearbeiten: Menüleiste → ⇥ → „Konfiguration neu laden“.

```json
{
  "groups" : [
    {
      "hold" : ["option"],
      "forward" : [{ "modifiers" : ["option"], "key" : "tab" }],
      "backward" : [{ "modifiers" : ["option", "shift"], "key" : "tab" }],
      "spaces" : "all",
      "order" : "recent",
      "instant" : true
    },
    {
      "hold" : ["option"],
      "forward" : [{ "modifiers" : ["option"], "key" : "^" }],
      "backward" : [{ "modifiers" : ["option", "shift"], "key" : "^" }],
      "spaces" : "current",
      "order" : "recent",
      "instant" : true
    }
  ]
}
```

| Feld | Werte |
|---|---|
| `hold` | Haltetasten der Gruppe. Loslassen beendet den Durchlauf. `command`, `option`, `control`, `shift` (auch `cmd`, `alt`, `ctrl`) |
| `forward`, `backward` | Liste von Tasten. Jede muss alle `hold`-Modifier enthalten |
| `key` | `tab`, `space`, `^` bzw. `` ` `` (Taste links neben der 1), `<` (Taste neben links-Shift), `a`–`z`, `0`–`9`, `f1`–`f12`, Pfeile `left` … oder ein Keycode als Zahl |
| `spaces` | `current` = nur aktueller Space, `all` = alle Spaces |
| `order` | `recent` = zuletzt benutzt zuerst, `created` = feste Reihenfolge nach Erstellung, `alphabetical` = nach App und Titel |
| `instant` | `true` = jeder Druck wechselt sofort, `false` = Auswahl mit Titel-Einblendung, Wechsel beim Loslassen |

Keycode einer Taste herausfinden (das Terminal braucht dafür Bedienungshilfen):

```bash
/Applications/WindowSwitcher.app/Contents/MacOS/WindowSwitcher --keycodes
```

## Grenzen

- **Andere Spaces:** Ein Fenster auf einem anderen Space holt macOS nur dann heran, wenn unter
  Systemeinstellungen → Schreibtisch & Dock „Beim Wechseln zu einem Programm, zu einem Space mit geöffneten
  Fenstern des Programms wechseln“ an ist. Manche Apps melden ihre Fenster auf anderen Spaces gar nicht.
- **Reihenfolge `recent`:** Die App merkt sich Fokuswechsel zwischen Apps. Wechsel innerhalb einer App (⌘\`)
  sieht sie nicht direkt; auf dem aktuellen Space hilft die Stapelreihenfolge der Fenster aus.
- **Minimierte Fenster, Panels und Dialoge** werden übersprungen.
- **Gleiche Tasten wie AltTab:** Läuft AltTab mit denselben Tasten, meldet die App „schon belegt“. Dann AltTab
  beenden oder andere Tasten wählen.
- Fenster-IDs kommen über die private, aber seit Jahren stabile Funktion `_AXUIElementGetWindow`.
