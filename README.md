# JortsMacOS
## 🔥 V2 - MAJOR UPDATE

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
- Clipboard drawer global:
  - capture texte, URL, images, fichiers et couleurs hex
  - historique persistant dans le dossier de stockage
  - pictogrammes de l'application source pour chaque item
  - recherche instantanée + filtres par type
  - filtres par source, favoris et récent
  - pins, lock, suppression item par item
  - navigation clavier complète
  - `Enter` colle dans l'app précédente
  - `Cmd+Enter` convertit l'item en note
  - aperçu image complet sans crop + lightbox
  - aperçu URL enrichi (titre, favicon, description, thumbnail)
  - QuickLook pour les fichiers
  - aperçu couleur intelligent avec Hex/RGB/HSL/OKLCH
  - position du drawer configurable: haut, bas, gauche, droite
  - clic hors drawer: fermeture automatique
  - `Esc` en 2 temps:
    - 1er `Esc`: reset contexte (catégorie/filtres/recherche/sélection) vers la carte la plus récente
    - 2e `Esc`: fermeture du drawer
 - Fenêtre standard PKClipboard:
  - taille par défaut: 1200x1000
  - raccourcis visuels limités aux 9 premières tuiles (`⌘1` ... `⌘9`)
  - navigation clavier activée (flèches + Entrée)
  - `Esc` ferme la fenêtre standard
  - pagination fonctionnelle avec pages cliquables
  - nombre d'items par page dynamique selon la taille visible de la grille
  - layout renforcé au resize (haut/bas non tronqués)
  - anti-chevauchement fenêtres: masquage des notes lors de l'ouverture du drawer/PKClipboard
  - focus clavier renforcé du drawer pour éviter saisie partagée note/clipboard
- Persistance et stockage:
  - stockage Markdown par note
  - métadonnées note en fin de fichier (`<!-- JORTS_META ... -->`)
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
  - entrée dédiée: afficher le tiroir presse-papiers
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
- Raccourcis globaux (par défaut, configurables):
  - `Cmd+Shift+Space` : rouvrir / focus la dernière note
  - `Ctrl+Shift+Space` : créer une nouvelle note
- Intégration Spotlight / Raycast / Alfred (URLs):
  - Nouvelle note: `jortsmacos://new`
  - Rouvrir la dernière note: `jortsmacos://last`
  - Afficher la liste des notes: `jortsmacos://list`
  - Ouvrir le clipboard: `jortsmacos://clipboard`
- Dossier de stockage par défaut: `~/Documents/JortsMacOS/`

### Clipboard drawer
- Toggle: `Cmd+Shift+V`
- Ouvrir `PKClipboard` (fenêtre standard): `Cmd+Option+V`
- Navigation: flèches gauche/droite
- `Enter`: colle (best-effort) dans l'app précédente + ferme le drawer
- `Cmd+C`: copie la carte sélectionnée vers le presse-papier système
- Clic hors drawer: ferme le drawer
- `Cmd+Enter`: convertir en note
- Filtres: texte, URL, image, fichier, couleur, source, épinglé, récent
- Couleurs: copier `#2C3861` crée une carte couleur avec:
  - Hex: `#2C3861`
  - RGB: `44, 56, 97`
  - HSL: `226, 38, 28`
  - OKLCH: aperçu calculé automatiquement

## ⚙️ Réglages
- Préférences générales (langue, stockage, import/export).
- Préférences raccourcis (modificateurs + touche).
- Activation/désactivation du calcul inline.
- Position du clipboard drawer.

## 🧾 Commandes
- `./JortsMacOS/run-dev.sh` : build + package + run
- `swift build` : build SwiftPM

## 📦 Build & Package
- Le script `JortsMacOS/script/build_and_run.sh` reconstruit le bundle `.app` local.
- Le bundle de test est généré dans `releases/JortsMacOS.app`.
- `JortsMacOS/dist` pointe vers `../releases`.
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
