# Car Idle

Idle game mobile de garage au rendu 3D réaliste : on fait tourner son garage dans une ville vivante, on améliore ses voitures pièce par pièce, et l'on part en balade en 3D, filmée comme par un drone, pour spotter les voitures rares qui complètent la collection.
Le document de game design (GDD) fait foi : https://claude.ai/artifact/WgkvZZaTt9JrZg6hYERz9r (onglets « GDD » et « Courses & balade »).
Le prototype 2D (dépôt lulu4660/garage-spotter) sert de référence : formules, simulations, map, catalogue. L'essai sous Unity est gardé sur la branche `unity` (abandonné : trop lourd à installer et à construire pour le web).

## Stack
- Godot 4.7 (GDScript), 3D. Rendu Forward+ sur PC, Mobile sur iPhone natif, Compatibility (WebGL 2) pour la version web. Dev sur PC Windows ; essais sur iPhone par la version web (GitHub Pages), puis TestFlight (export iOS depuis un Mac ou un service en ligne).
- Physique : Jolt ; voiture = VehicleBody3D + couche arcade.
- Serveur (plus tard) : Supabase (Auth, Postgres + RLS, Edge Functions). Pubs : AdMob. Achats : RevenueCat.
- Voitures : pour l'instant seulement les voitures low poly « toon » (même style que le décor) ; les vraies viendront de boutiques d'assets, licence commerciale vérifiée pour chacune. Le dépôt est public : un asset dont la licence interdit la republication va dans `assets/store/`, ignoré par Git, et le code passe par un catalogue, jamais par un chemin en dur.

## Règles non négociables
- L'appli affiche, le serveur décide : tout calcul d'argent qui fait foi se fera côté serveur.
- Revenus idle calculés depuis l'heure de la dernière récolte, jamais en continu.
- Aucune clé d'API dans l'appli.
- Aucune marque réelle : logos, badges, textes et plaques retirés de chaque modèle 3D ; noms de voitures modifiés (base de noms du GDD), le nom réel n'est jamais affiché.
- Économie : coût ×1,10 par niveau, revenu linéaire, ×2 aux paliers 25/50/100/150/200 ; les échelles s'additionnent, jamais ne se multiplient. Tout changement d'équilibrage passe par une simulation.
- Les voitures spottées arrivent neuves (plus de mise à neuf) ; le rythme vient du déblocage des voitures au fil du temps.
- DA : rendu réaliste ; garage et ville : course de rue de nuit, noir charbon + orange/rouge/or, pas de bleu dominant ; balade : style low poly épuré (couleurs unies, relief légèrement facetté, voitures « toon »), désert et plage l'après-midi, filmés comme une vidéo de drone.

## Code
- `scripts/core/` : règles pures (aucun nœud), à porter telles quelles côté serveur.
  - `economy.gd` : coûts, revenus, paliers, places, hors ligne, spot, SERVIR, formatage des nombres.
  - `progression.gd` : réputation (prestige), arbre de compétences (4 × 6), collections, missions du jour (graine FNV-1a de la date), succès ; récompenses en minutes de revenus.
  - `catalog.gd` : 32 modèles provisoires (noms modifiés).
  - `world_layout.gd` : plan de la balade (relief, sols, adhérence : ville, terre, dunes, plage, mer).
  - Aucune règle d'économie ailleurs que dans ce dossier.
- `scripts/balade/` : la balade 3D.
  - `balade.gd` (point d'entrée, scène `scenes/balade.tscn` : décor, voiture, caméra, effets de roues, réception de saut, affichage), `world_data.gd` (monde précalculé), `terrain.gd` (16 × 16 morceaux à deux niveaux de détail (2 m et 4 m entre sommets) déformés par la carte graphique, collision HeightMapShape3D, sable qui se creuse), `world_builder.gd` (ciel HDR et soleil calé dessus, brume, post-traitement, mer, sable lointain, limites, ville, rochers), `car.gd` (VehicleBody3D : 4x4/propulsion/traction, adhérence par sol, dérapage réglable avec contre-braquage automatique, garde-fou, flottaison (12 sondes sous la caisse : poussée d'Archimède sous la vraie surface, résistance de l'eau selon le sens et par rapport à l'eau qui bouge, prend l'eau puis coule), roues dessinées posées sur le sol ou au fond de leur ornière, résistance au roulement par sol, roues freinées par l'eau peu profonde ; retour au sec ; fabrique la voiture depuis un modèle du kit), `drone_camera.gd` (poursuite, travelling, plongée), `effects.gd` (traces de gomme sur le bitume ; particules en MultiMesh animées par shader, volontairement simples : poussière qui reste où la roue l'a soulevée et monte doucement, deux nappes de gouttes à l'avant dans l'eau, anneau au sol à la réception d'un saut), `ruts.gd` (ornières : pièce de terrain (30 cm entre sommets, calée sur une grille fixe, carte de 51 m qui s'efface en fondu sur les bords) qui suit la voiture et se creuse sous les roues et sous la caisse dans le sable et la terre ; `balade._body_contact` creuse aussi la collision quand la caisse frotte longtemps), `decor.gd` (herbe low poly par cases, mouettes, campements et objets), `prop_body.gd` (objets destructibles : figés, réveillés par la voiture, projetés ou brisés en morceaux), `waves.gd` (houle commune à l'image et à la flottaison, vitesse de l'eau), `water_sim.gd` (vraies vagues autour de la voiture : équation des ondes en eau peu profonde sur 64 m (cases de 50 cm), calculée par la carte graphique dans deux SubViewports qui se passent le relais, compatible WebGL 2 ; la caisse et les roues poussent l'eau), `controls.gd` (clavier + boutons tactiles multi-doigts).
- `shaders/` : `terrain` (hauteurs lues en texelFetch, couleurs unies par sol, facettes, ornières en mode « pièce fine »), `sea` (mer low poly opaque : facettes à plat, couleurs unies selon la profondeur, écume en bandes ; grille fine de 128 m qui suit la voiture avec la houle (les 4 vagues de `waves.gd`, mêmes que la flottaison) et les vagues simulées, mer plate et grossière au-delà), `water_sim` (simulation des vagues), `stamps` (traces), `dust` (poussière à contre-jour).
- `assets/balade/world.bin` : monde précalculé par `tools/bake_world.gd` (relief 1025² en facettes de 2 m : image, collision et physique voient les mêmes triangles ; sols 512², profondeur de la mer). À relancer après tout changement de `world_layout.gd`.
- `assets/ground/` : textures de sol et ciel HDR (Poly Haven, CC0 ; brillance rangée dans l'alpha des couleurs). Le soleil suit la position du soleil dans la photo (`world_builder.SKY_SUN_U`).
- `assets/cars/toon/` : les seules voitures du jeu pour l'instant, low poly en couleurs unies (CC-BY 4.0, crédits dans le dossier) ; `car.TOON` dit quel fichier, quelle voiture d'un pack et quelle longueur.
- Pas de `class_name` : les scripts se chargent avec `preload`/`load`. Les nombres d'argent sont des `float` (double).

## Vérifier un changement
- `godot --headless --path . -s tests/run_tests.gd` doit passer (aussi lancé par GitHub Actions à chaque envoi).
- Performance : `tools/bench.gd` (coût d'une image, appels de dessin, triangles ; `-- low` = réglages iPhone) ; à comparer entre versions (rendu logiciel ici). Réglages iPhone/web dans `balade._apply_quality` (pleine résolution, FXAA, ombres 70 m au filtre le plus simple, ombres de l'herbe à 30 m, pas de halo, terrain sans ombre portée ; eau opaque, pas de transparence en grand) ; le compteur d'images/s est affiché en haut de l'écran.
- Capture rapide d'un plan : `tools/pose.gd -- sortie.png [plan] [x z cap°] [low]`.
- Changement visible : `xvfb-run -a -s "-screen 0 1280x720x24" godot --path . --rendering-method gl_compatibility --resolution 1280x720 -s tools/shot.gd -- dossier [secondes_de_gaz] [plan_caméra]`, puis relire les captures (rendu logiciel : lent, compter quelques minutes).
- Version web : `.github/workflows/web.yml` exporte et met en ligne sur https://lulu4660.github.io/Car-idle/ à chaque envoi sur `main` (aucune licence à fournir).

## Roadmap (GDD)
1. Socle : règles du jeu et tests. (fait)
2. Prototype de balade 3D : dunes et plage, caméra de drone, dérapages, traces, sable qui se creuse ; beau et fluide sur iPhone. (en cours)
3. Voitures : 3 à 5 vrais modèles nettoyés, matériaux, lumières, présentation sur plateau, révélation.
4. Ville et garage. 5. Balade complète et spotting. 6. Progression et rythme. 7. Serveur et monétisation. 8. Plus tard : drag race, clubs, saisons.

## Agents (.claude/agents/)
godot-dev (code Godot), vehicle-physics (ressenti de conduite, caméra drone), economy-balancer (simulation avant tout équilibrage), asset-scout (modèles 3D et licences), mobile-perf (60 i/s sur iPhone), build-release (version web, plus tard TestFlight), art-director (relecture DA), playtester-qa (tests sur la version web), supabase-backend (serveur, étape 7), store-compliance (conformité).

## graphify

This project has a knowledge graph at graphify-out/ with god nodes, community structure, and cross-file relationships.

Rules:
- When graphify-out/graph.json exists, run `graphify query "<question>"` before your first grep, search or source-file read for a codebase question, and put this rule in every subagent prompt that explores code. Read raw files only for lines the graph or an earlier read already located. Use `graphify path "<A>" "<B>"` for relationships and `graphify explain "<concept>"` for focused concepts. These return a scoped subgraph, usually much smaller than GRAPH_REPORT.md or raw grep output.
- If graphify-out/wiki/index.md exists, use it for broad navigation instead of raw source browsing.
- Read graphify-out/GRAPH_REPORT.md only for broad architecture review or when query/path/explain do not surface enough context.
- After modifying code, run `graphify update .` to keep the graph current (AST-only, no API cost).
- A committed graphify-out/graph.json is rewritten whole on every build, so a large diff to it in a pull request is expected. Do not flag it as churn or suggest skipping the graph rebuild or its hooks.

## Skills (.claude/skills/)
- `ui-ux-pro-max` (MIT, nextlevelbuilder) : règles et données d'interface (accessibilité, tactile, couleurs, typo). Pensé pour le web : en garder les règles mobiles pour l'interface du jeu, en respectant la DA ci-dessus.
- `graphify` (Apache-2.0) : graphe du code dans `graphify-out/` ; il faut la commande `graphify` (`uv tool install graphifyy`), sinon ses hooks ne font rien. `.graphifyignore` limite le graphe au jeu.
