using CarIdle.Core;
using UnityEngine;

namespace CarIdle.Drive
{
    /// <summary>
    /// Construit le monde de la balade à partir de <see cref="WorldLayout"/> : terrain
    /// (relief et sols peints), immeubles de la ville, mer, soleil, ciel et brume.
    /// Tout est fait en code pour le prototype : aucun asset à préparer.
    /// </summary>
    public static class WorldBuilder
    {
        private const int HeightmapResolution = 513;
        private const int AlphamapResolution = 512;

        // Couleurs des sols (calques du terrain), dans l'ordre de l'énumération Surface.
        private static readonly Color[] GroundColors =
        {
            new Color(0.23f, 0.23f, 0.24f), // bitume
            new Color(0.42f, 0.30f, 0.20f), // terre
            new Color(0.86f, 0.74f, 0.52f), // sable
            new Color(0.62f, 0.52f, 0.38f), // sable mouillé
        };

        public static GameObject Build()
        {
            var root = new GameObject("Monde");
            BuildTerrain(root.transform);
            BuildCity(root.transform);
            BuildSea(root.transform);
            BuildSky();
            return root;
        }

        private static void BuildTerrain(Transform parent)
        {
            float size = WorldLayout.Size;
            var data = new TerrainData();
            data.heightmapResolution = HeightmapResolution;
            data.size = new Vector3(size, WorldLayout.MaxHeight, size);

            int n = data.heightmapResolution;
            var heights = new float[n, n];
            for (int zi = 0; zi < n; zi++)
            {
                for (int xi = 0; xi < n; xi++)
                {
                    float x = xi / (float)(n - 1) * size - size / 2f;
                    float z = zi / (float)(n - 1) * size - size / 2f;
                    heights[zi, xi] = WorldLayout.Height(x, z) / WorldLayout.MaxHeight;
                }
            }
            data.SetHeights(0, 0, heights);

            var layers = new TerrainLayer[GroundColors.Length];
            for (int i = 0; i < layers.Length; i++)
            {
                layers[i] = new TerrainLayer
                {
                    diffuseTexture = Materials.Noise(GroundColors[i], i == 2 ? 0.08f : 0.18f, 100 + i),
                    tileSize = new Vector2(4f, 4f),
                    smoothness = i == 0 ? 0.25f : 0.05f,
                };
            }
            data.terrainLayers = layers;

            data.alphamapResolution = AlphamapResolution;
            int a = data.alphamapResolution;
            var alpha = new float[a, a, layers.Length];
            for (int zi = 0; zi < a; zi++)
            {
                for (int xi = 0; xi < a; xi++)
                {
                    float x = (xi + 0.5f) / a * size - size / 2f;
                    float z = (zi + 0.5f) / a * size - size / 2f;
                    var s = WorldLayout.SurfaceAt(x, z, WorldLayout.Height(x, z));
                    // L'eau recouvre du sable mouillé.
                    int layer = s == Surface.Water ? (int)Surface.WetSand : (int)s;
                    alpha[zi, xi, layer] = 1f;
                }
            }
            data.SetAlphamaps(0, 0, alpha);

            var go = Terrain.CreateTerrainGameObject(data);
            go.name = "Terrain";
            go.transform.SetParent(parent, false);
            go.transform.position = new Vector3(-size / 2f, 0f, -size / 2f);
            var terrain = go.GetComponent<Terrain>();
            terrain.heightmapPixelError = 4f;
            terrain.basemapDistance = 300f;
            // Avec le rendu URP, le terrain prend le matériau par défaut du pipeline ; sinon, Standard.
            if (!Materials.IsUrp)
            {
                var shader = Shader.Find("Nature/Terrain/Standard");
                if (shader != null)
                    terrain.materialTemplate = new Material(shader);
            }
        }

        private static void BuildCity(Transform parent)
        {
            var city = new GameObject("Ville").transform;
            city.SetParent(parent, false);
            var rng = new System.Random(42);
            var palette = new[]
            {
                Materials.Lit(new Color(0.20f, 0.19f, 0.21f)),
                Materials.Lit(new Color(0.30f, 0.27f, 0.25f)),
                Materials.Lit(new Color(0.42f, 0.38f, 0.34f)),
                Materials.Lit(new Color(0.16f, 0.17f, 0.20f), null, 0.6f),
                Materials.Lit(new Color(0.50f, 0.30f, 0.22f)),
            };
            float half = WorldLayout.Size / 2f;
            float block = WorldLayout.BlockSize;
            float street = WorldLayout.StreetWidth;
            float ground = WorldLayout.GroundLevel;
            // Pâtés de maisons : de l'ouest du monde jusqu'à 40 m avant la fin de la ville.
            for (float bx = Mathf.Ceil(-half / block) * block; bx + block < WorldLayout.CityEnd - 40f; bx += block)
            {
                for (float bz = Mathf.Ceil(-half / block) * block; bz + block < half; bz += block)
                {
                    // Chaque pâté (entre deux rues) reçoit 1 à 4 immeubles.
                    float x0 = bx + street, z0 = bz + street, w = block - street;
                    int split = rng.Next(1, 3);
                    float cell = w / split;
                    for (int i = 0; i < split; i++)
                    {
                        for (int j = 0; j < split; j++)
                        {
                            float margin = 2f;
                            float sx = cell - margin * 2f, sz = cell - margin * 2f;
                            float height = 8f + (float)rng.NextDouble() * (rng.NextDouble() < 0.15 ? 55f : 22f);
                            var b = GameObject.CreatePrimitive(PrimitiveType.Cube);
                            b.name = "Immeuble";
                            b.transform.SetParent(city, false);
                            b.transform.position = new Vector3(x0 + cell * (i + 0.5f), ground + height / 2f, z0 + cell * (j + 0.5f));
                            b.transform.localScale = new Vector3(sx, height, sz);
                            b.GetComponent<Renderer>().sharedMaterial = palette[rng.Next(palette.Length)];
                        }
                    }
                }
            }
        }

        private static void BuildSea(Transform parent)
        {
            var sea = GameObject.CreatePrimitive(PrimitiveType.Plane);
            sea.name = "Mer";
            Object.Destroy(sea.GetComponent<Collider>());
            sea.transform.SetParent(parent, false);
            // Un plan Unity fait 10 m : on couvre le monde et au-delà, pour l'horizon.
            float s = WorldLayout.Size * 3f / 10f;
            sea.transform.position = new Vector3(WorldLayout.Size, WorldLayout.SeaLevel, 0f);
            sea.transform.localScale = new Vector3(s, 1f, s);
            sea.GetComponent<Renderer>().sharedMaterial = Materials.Lit(new Color(0.10f, 0.38f, 0.40f), null, 0.92f);
        }

        private static void BuildSky()
        {
            var sunGo = new GameObject("Soleil");
            var sun = sunGo.AddComponent<Light>();
            sun.type = LightType.Directional;
            sun.color = new Color(1f, 0.93f, 0.82f);
            sun.intensity = 1.25f;
            sun.shadows = LightShadows.Soft;
            sunGo.transform.rotation = Quaternion.Euler(38f, -35f, 0f);
            RenderSettings.sun = sun;

            RenderSettings.ambientMode = UnityEngine.Rendering.AmbientMode.Trilight;
            RenderSettings.ambientSkyColor = new Color(0.55f, 0.62f, 0.70f);
            RenderSettings.ambientEquatorColor = new Color(0.55f, 0.50f, 0.42f);
            RenderSettings.ambientGroundColor = new Color(0.30f, 0.25f, 0.20f);

            // Brume de chaleur : donne de la profondeur et masque la fin du monde.
            RenderSettings.fog = true;
            RenderSettings.fogMode = FogMode.Linear;
            RenderSettings.fogColor = new Color(0.80f, 0.76f, 0.68f);
            RenderSettings.fogStartDistance = 160f;
            RenderSettings.fogEndDistance = 650f;
        }
    }
}
