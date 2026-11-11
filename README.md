# Car Idle

Idle game mobile de garage au rendu 3D réaliste, avec balade en vue de drone et chasse aux voitures rares.
Game design : https://claude.ai/artifact/WgkvZZaTt9JrZg6hYERz9r

Moteur : **Godot 4.7** (gratuit, léger, version web sans licence). L'essai sous Unity est gardé sur la branche `unity`.

## Ouvrir le projet (PC Windows)

1. **Installer Godot 4.7.2** : https://godotengine.org/download/windows (version « Standard », pas .NET). C'est un simple fichier à dézipper, sans installation.
2. **Récupérer le dépôt** avec GitHub Desktop (Fetch puis Pull ; le dossier `Documents\Car-idle` existe déjà).
3. **Ouvrir** : lancer Godot > **Import** > choisir `Documents\Car-idle\project.godot` > Import & Edit. La première ouverture importe les textures (une minute).
4. **Jouer** : touche **F5** (ou le triangle en haut à droite). La balade démarre.

Les fichiers de Unity restés dans le dossier (`Assets`, `Library`, `Packages`, `ProjectSettings`…) peuvent être supprimés : ils ne servent plus et Git les ignore ou les a retirés.

## La balade

- Monde de 1 km : ville à l'ouest, chemins de terre et collines avec des rochers, grandes dunes, plage et mer à l'est. Départ dans les dunes, face à la ville.
- Clavier : flèches ou ZQSD/WASD, **Espace** = frein à main (dérapage), **R** = replacer la voiture, **C** = voiture suivante, **V** = plan de caméra (poursuite, travelling, plongée).
- Tactile (ou souris) : boutons à l'écran, plusieurs doigts en même temps.
- Transmissions : la sportive, la berline et la police sont des propulsions (elles dérapent sous les gaz), le SUV est un 4x4, le taxi et le van des tractions.
- Réceptions de saut : le sable se creuse sous les roues, gerbe de sable et secousse de caméra.
- Réglages de conduite : pendant le jeu, onglet **Remote** de l'arbre de scène > `Voiture` : `drift`, `counter_steer`, `tyre_grip`, `engine_force_total`… (les valeurs changées en jeu sont perdues à l'arrêt : noter celles qui plaisent).
- Voitures : « Free Low Poly Vehicles Pack » de RgsDev (CC-BY 4.0, [Sketchfab](https://sketchfab.com/3d-models/free-low-poly-vehicles-pack-cb7640039e7a40679a53be705ebff50e), crédits dans `assets/cars/rgs/CREDITS.txt`). Textures de sol et ciel : [Poly Haven](https://polyhaven.com) (CC0). Arbres, cactus, rochers : [Nature Kit de Kenney](https://kenney.nl/assets/nature-kit) (CC0).

## Jouer sur iPhone

À chaque envoi sur `main`, GitHub exporte la version web et la met en ligne sur **https://lulu4660.github.io/Car-idle/** (Safari ; Partager > « Sur l'écran d'accueil » pour le plein écran). Aucune licence ni secret à fournir. Il faut seulement, une fois : Settings > Pages > Source = **GitHub Actions** (déjà fait). Les secrets Unity enregistrés sur GitHub ne servent plus et peuvent être supprimés (Settings > Secrets and variables > Actions).

La version web utilise le rendu « Compatibility » de Godot (WebGL 2) : un peu moins riche que sur PC (pas d'ombres de contact, brume plus simple).

## Tests

```
godot --headless --path . -s tests/run_tests.gd      # règles du jeu
godot --headless --path . -s tests/test_drive.gd     # banc d'essai de la conduite
```

Les règles tournent aussi sur GitHub à chaque envoi (onglet Actions).

## Monde précalculé

`assets/balade/world.bin` contient le relief, les sols et la profondeur de la mer, calculés à partir de `scripts/core/world_layout.gd`. Après un changement de ce fichier :

```
godot --headless --path . -s tools/bake_world.gd
```

## Outils de Claude (facultatif)

Le projet contient des agents et des skills pour Claude Code (`.claude/`). Pour graphify (carte du code) sur le PC :

```
winget install astral-sh.uv
uv tool install graphifyy
```
