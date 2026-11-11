# Car Idle

Idle game mobile de garage au rendu 3D réaliste : on fait tourner son garage dans une ville vivante, on améliore ses voitures pièce par pièce, et l'on part en balade en 3D, filmée comme par un drone, pour spotter les voitures rares qui complètent la collection.
Le document de game design (GDD) fait foi : https://claude.ai/artifact/WgkvZZaTt9JrZg6hYERz9r (onglets « GDD » et « Courses & balade »).
Le prototype Godot (dépôt lulu4660/garage-spotter) sert de référence : formules, simulations, map, catalogue. Il n'est plus développé.

## Stack
- Unity 6 (C#), rendu URP 3D, pour iPhone d'abord. Dev sur PC Windows ; essais sur iPhone par une build web, puis TestFlight (build iOS depuis un Mac ou un service de build en ligne).
- Balade : terrain Unity, physique de véhicule, Cinemachine (caméra de drone), VFX Graph.
- Serveur (plus tard) : Supabase (Auth, Postgres + RLS, Edge Functions). Pubs : AdMob pour Unity. Achats : RevenueCat (SDK Unity).
- Voitures : modèles 3D de boutiques d'assets (Unity Asset Store, Sketchfab, CGTrader), licence commerciale vérifiée pour chacun.
- Le dépôt est public : tout contenu de boutique va dans `Assets/Store/`, ignoré par Git (la licence de l'Asset Store interdit de le republier). Le code ne doit jamais dépendre d'un chemin précis dans ce dossier : il passe par des références sérialisées ou un catalogue.

## Règles non négociables
- L'appli affiche, le serveur décide : tout calcul d'argent qui fait foi se fera côté serveur.
- Revenus idle calculés depuis l'heure de la dernière récolte, jamais en continu.
- Aucune clé d'API dans l'appli.
- Aucune marque réelle : logos, badges, textes et plaques retirés de chaque modèle 3D ; noms de voitures modifiés (base de noms du GDD), le nom réel n'est jamais affiché.
- Économie : coût ×1,10 par niveau, revenu linéaire, ×2 aux paliers 25/50/100/150/200 ; les échelles s'additionnent, jamais ne se multiplient. Tout changement d'équilibrage passe par une simulation.
- Les voitures spottées arrivent neuves (plus de mise à neuf) ; le rythme vient du déblocage des voitures au fil du temps.
- DA : rendu réaliste et sombre, course de rue de nuit, noir charbon + orange/rouge/or, pas de bleu dominant.

## Code
- `Assets/Scripts/Core/` (assemblage `CarIdle.Core`, sans Unity) : règles pures, portées du prototype.
  - `Economy.cs` : coûts, revenus, paliers, places, hors ligne, spot, SERVIR, formatage des nombres.
  - `Progression.cs` : réputation (prestige), arbre de compétences (4 × 6), collections, missions du jour, succès.
  - `Catalog.cs` : 32 modèles provisoires (noms modifiés).
  - `WorldLayout.cs` : plan de la balade (relief, sols et adhérence : ville, terre, dunes, plage, mer), testé sans Unity.
  - Aucune règle d'économie ailleurs que dans ce dossier ; il sera porté tel quel côté serveur.
- `Assets/Scripts/Drive/` (assemblage `CarIdle.Drive`) : prototype de balade, tout construit en code au lancement.
  - `BaladeBootstrap.cs` (point d'entrée + affichage), `WorldBuilder.cs` (terrain, ville, mer, ciel), `VehicleFactory.cs` (voiture du Car Kit : orientation, taille, Rigidbody, WheelCollider), `CarController.cs` (conduite arcade 4 roues motrices, adhérence par sol, frein à main, aides, retour au sec), `DroneCamera.cs`, `CarEffects.cs` (traces, poussière, éclaboussures), `DriveInput.cs` (clavier + boutons tactiles, ancien et nouveau système d'entrées), `Materials.cs` (URP Lit ou Standard).
  - API renommées dans Unity 6 (`linearVelocity`, `linearDamping`, `PhysicsMaterial`) : passer par `Physics2` ou `#if UNITY_6000_0_OR_NEWER`.
- `Assets/Scripts/Editor/BaladeSceneMenu.cs` : crée `Assets/Scenes/Balade.unity` (menu Car Idle).
- `Assets/Scripts/Editor/WebBuild.cs` + `.github/workflows/web.yml` : build web (GameCI) mise en ligne sur GitHub Pages (https://lulu4660.github.io/Car-idle/) pour jouer sur iPhone. Secrets UNITY_LICENSE/EMAIL/PASSWORD réglés par l'auteur sur GitHub. Un shader trouvé par `Shader.Find` doit figurer dans `WebBuild.CodeShaders`.
- `Assets/Resources/CarKit/` : voitures low poly du Car Kit de Kenney (CC0), provisoires pour régler la physique.
- `Assets/Tests/EditMode/` : tests NUnit. `ReferenceValuesTests.cs` vérifie que le portage redonne les valeurs du prototype Godot (seule différence voulue : 9,96 s'affiche « 10 »).
- `tools/CoreTests/` : fait tourner les mêmes tests sans Unity (`dotnet test tools/CoreTests/CoreTests.csproj`, C# 9 comme Unity).
- Les nombres sont des `double` : le plus gros revenu possible reste très loin de 1e308.

## Vérifier un changement
- `dotnet test tools/CoreTests/CoreTests.csproj` doit passer (aussi lancé par GitHub Actions à chaque envoi).
- Dans Unity : Window > General > Test Runner > EditMode > Run All.

## Roadmap (GDD)
1. Socle : projet Unity, économie et progression en C# avec tests. (fait)
2. Prototype de balade 3D : une voiture achetée, dunes et plage, caméra de drone, dérapages, traces et sable ; beau et fluide sur iPhone.
3. Voitures : 3 à 5 modèles nettoyés, matériaux, lumières, présentation sur plateau, révélation.
4. Ville et garage. 5. Balade complète et spotting. 6. Progression et rythme. 7. Serveur et monétisation. 8. Plus tard : drag race, clubs, saisons.

## Agents (.claude/agents/)
unity-dev (code Unity), vehicle-physics (ressenti de conduite, caméra drone), economy-balancer (simulation avant tout équilibrage), asset-scout (modèles 3D et licences), mobile-perf (60 i/s sur iPhone), build-release (build web, plus tard TestFlight), art-director (relecture DA), playtester-qa (tests sur la version web), supabase-backend (serveur, étape 7), store-compliance (conformité).

## graphify

This project has a knowledge graph at graphify-out/ with god nodes, community structure, and cross-file relationships.

Rules:
- When graphify-out/graph.json exists, run `graphify query "<question>"` before your first grep, search or source-file read for a codebase question, and put this rule in every subagent prompt that explores code. Read raw files only for lines the graph or an earlier read already located. Use `graphify path "<A>" "<B>"` for relationships and `graphify explain "<concept>"` for focused concepts. These return a scoped subgraph, usually much smaller than GRAPH_REPORT.md or raw grep output.
- If graphify-out/wiki/index.md exists, use it for broad navigation instead of raw source browsing.
- Read graphify-out/GRAPH_REPORT.md only for broad architecture review or when query/path/explain do not surface enough context.
- After modifying code, run `graphify update .` to keep the graph current (AST-only, no API cost).
- A committed graphify-out/graph.json is rewritten whole on every build, so a large diff to it in a pull request is expected. Do not flag it as churn or suggest skipping the graph rebuild or its hooks.

## Skills (.claude/skills/)
- `ui-ux-pro-max` (MIT, nextlevelbuilder) : règles et données d'interface (accessibilité, tactile, couleurs, typo). Pensé pour le web : en garder les règles mobiles pour l'interface Unity, en respectant la DA ci-dessus.
- `design-taste-frontend` (taste-skill, MIT, Leonxlnx) : pages web soignées (site vitrine, page de présentation du jeu). Son hook de fin ne fait rien hors d'une page en cours ; il demande Node 22+.
- `graphify` (Apache-2.0) : graphe du code dans `graphify-out/` ; il faut la commande `graphify` (`uv tool install graphifyy`), sinon ses hooks ne font rien. `.graphifyignore` limite le graphe au jeu.
