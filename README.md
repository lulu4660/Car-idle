# Car Idle

Idle game mobile de garage au rendu 3D réaliste, avec balade en vue de drone et chasse aux voitures rares.
Game design : https://claude.ai/artifact/WgkvZZaTt9JrZg6hYERz9r

## Ouvrir le projet (PC Windows)

1. **Installer** [Unity Hub](https://unity.com/download), puis dans Hub > Installs : **Unity 6 (6000.0 LTS)**, avec les modules **WebGL Build Support** et **iOS Build Support**.
2. **Récupérer le dépôt** avec [GitHub Desktop](https://desktop.github.com/) : File > Clone repository > `lulu4660/Car-idle`.
3. **Ouvrir** : Unity Hub > Projects > Add > Add project from disk > choisir le dossier `Car-idle`.
   Si Hub propose une autre version de Unity 6 que celle du projet, accepter celle qui est installée.
   La première ouverture prend quelques minutes (Unity télécharge les paquets et crée ses fichiers).
4. **Activer le rendu URP** (une seule fois) :
   - Assets > Create > Rendering > **URP Asset (with Universal Renderer)**, nommé `URP-Mobile`, dans `Assets/Settings`.
   - Edit > Project Settings > **Graphics** : Default Render Pipeline = `URP-Mobile`.
   - Edit > Project Settings > **Quality** : pour chaque niveau, Render Pipeline Asset = `URP-Mobile`.
5. **Lancer les tests** : Window > General > Test Runner > EditMode > **Run All**. Tout doit être vert.
6. **Enregistrer** : GitHub Desktop montre les fichiers créés par Unity (`.meta`, `ProjectSettings/`, `Packages/packages-lock.json`) : les envoyer (Commit, puis Push).

## Essayer la balade (prototype de conduite)

À la première ouverture, Unity crée tout seul la scène **`Assets/Scenes/Balade.unity`** et l'ouvre (sinon : menu **Car Idle > Recréer la scène Balade**). Appuyer sur **Play**.

- Monde de 1 km : ville à l'ouest, chemins de terre et collines, dunes, plage et mer à l'est. Départ sur le sable, face à la ville.
- Clavier : flèches ou ZQSD/WASD, **Espace** = frein à main (dérapage), **R** = replacer la voiture, **C** = voiture suivante.
- Tactile (ou souris) : boutons à l'écran. La voiture revient toute seule au sec si elle est sur le toit ou trop loin dans la mer.
- Voitures provisoires : [Car Kit de Kenney](https://kenney.nl/assets/car-kit) (CC0, libre de droits), dans `Assets/Resources/CarKit/`. Elles servent à régler la physique ; les belles voitures viendront ensuite.
- Réglages de conduite : sélectionner la voiture pendant le Play, composant **CarController** (couple, freins, braquage, aides). Les valeurs changées pendant le Play sont perdues à l'arrêt : noter celles qui plaisent.

## Assets de boutique (voitures, décors)

La licence de l'Asset Store interdit de republier ses fichiers dans un dépôt public. Tout ce qui vient d'une boutique va dans **`Assets/Store/`**, que Git ignore :

1. Sur la page de l'asset, **Add to My Assets** (compte Unity gratuit).
2. Dans Unity : Window > **Package Manager** > My Assets > l'asset > **Download**, puis **Import**.
3. Dans la fenêtre Project, **glisser le dossier importé dans `Assets/Store/`** (créer le dossier la première fois).

Première voiture du prototype : [Realistic Mobile Car #26 (Demo)](https://assetstore.unity.com/packages/3d/vehicles/land/realistic-mobile-car-26-demo-305319) (gratuite, design sans marque réelle).

## Tests sans Unity

```
dotnet test tools/CoreTests/CoreTests.csproj
```

Ils tournent aussi sur GitHub à chaque envoi (onglet Actions).
