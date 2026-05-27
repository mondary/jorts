# JortsMacOS

![Project icon](icon.png)

[🇫🇷 FR](README.md) · [🇬🇧 EN](README_en.md)

✨ Application de notes native macOS inspirée de Jorts, avec calcul inline, palette de commandes et gestion avancée des raccourcis.

![Aperçu Jorts](https://github.com/elly-code/jorts/blob/main/data/screenshots/spread.png)
![Preferences Light](https://github.com/elly-code/jorts/blob/main/data/screenshots/preferences-light.png)
![Preferences Dark](https://github.com/elly-code/jorts/blob/main/data/screenshots/preferences-dark.png)
![Default Theme](https://github.com/elly-code/jorts/blob/main/data/screenshots/default.png)

## ✅ Fonctionnalités
- Port natif macOS (SwiftUI/AppKit) inspiré de Jorts.
- Palette de commandes (`Cmd+K`) avec:
  - recherche titre/contenu
  - navigation clavier
  - ouverture note
  - création note
  - ouverture Préférences / À propos
- Raccourcis clavier éditables dans les préférences (modificateurs + touche).
- Deux raccourcis globaux configurables:
  - focus dernière note
  - création nouvelle note
- Rechargement dynamique des raccourcis dans les menus.
- Calcul inline dans les notes:
  - évaluation en direct
  - variables par lignes
  - conversions d’unités
  - parsing d’expressions dans l’éditeur
- Icônes inline automatiques:
  - intégration du catalogue `developer-icons`
  - insertion d’icône à la fin d’un mot reconnu
  - plus de 300 icônes techniques disponibles
- Options de calcul inline activables/désactivables dans les réglages.
- Moteur de saisie texte enrichi:
  - toggle listes
  - toggle monospace
  - zoom in/out/reset
  - effets de frappe
- Fenêtre liste des notes (notes actives + corbeille).
- Restauration des notes depuis corbeille.
- Gestion couleurs/thèmes:
  - sélecteur couleur
  - contraste texte auto
  - prévisualisation des couleurs
- Persistance et stockage:
  - stockage Markdown par note
  - JSON d’historique de versions
  - migration JSON legacy -> Markdown
  - consolidation des doublons
  - canonicalisation/cleanup
- Opérations données:
  - import/export
  - archivage doublons/backups
  - ouverture dossier de stockage dans Finder
- Internationalisation:
  - ressources localisées
  - changement de langue via préférences
- Gestion fenêtres:
  - comportement natif palette flottante
  - restauration focus fenêtre après palette
- Menubar native:
  - actions rapides
  - accès settings/about/restart/quit
- Refactor repo:
  - `JortsMacOS/` pour le code app
  - `submodules/jorts` pour la source d’inspiration
  - `submodules/developer-icons` pour la source des icônes techniques
  - `releases/` dédié artefacts

## 🧠 Utilisation
- Lancement dev: `./JortsMacOS/run-dev.sh`
- Ouvrir la palette: `Cmd+K`
- Préférences: `Cmd+,`
- Dossier de stockage par défaut: `~/Documents/JortsMacOS/`

## ⚙️ Réglages
- Préférences générales (langue, stockage, import/export).
- Préférences raccourcis (modificateurs + touche).
- Activation/désactivation du calcul inline.

## 🧾 Commandes
- `./JortsMacOS/run-dev.sh` : build + package + run
- `swift build` : build SwiftPM

## 📦 Build & Package
- Le script `JortsMacOS/script/build_and_run.sh` reconstruit le bundle `.app` local.
- La cible SwiftPM pointe sur `JortsMacOS/macos/JortsMac`.

## 🧪 Installation (Antigravity)
- Non utilisé pour ce projet actuellement.

## 🧾 Changelog
- `182f57a` : ajout icônes inline dans les notes.
- `d06eea4` : refactor structure repo (`JortsMacOS/`, `submodules/jorts`, `releases`).
- `f9c95c5` : shortcuts globaux configurables + unification run dev + stockage par défaut.
- `45a7297` : nouveaux raccourcis + traduction.
- `8e97ab3` : ajout palette de commandes.
- `0aedc51` : ajouts calcul inline.

## 🔗 Liens
- Repo source d’inspiration (Jorts): https://github.com/elly-code/jorts
- Inspirations calcul:
  - https://github.com/bornova/numara-calculator
  - https://github.com/teamxenox/caligator
- README EN: [README_en.md](README_en.md)
