using CarIdle.Core;
using UnityEngine;
using UnityEngine.Rendering;

namespace CarIdle.Drive
{
    /// <summary>
    /// Construit le monde de la balade à partir de <see cref="WorldLayout"/> : terrain (relief,
    /// sols texturés par des photos), immeubles de la ville, rochers, mer animée, ciel photographié
    /// de fin de journée, soleil rasant, brume et reflets. Tout est fait en code : aucun asset à préparer.
    /// </summary>
    public static class WorldBuilder
    {
        private const int HeightmapResolution = 1025;
        private const int AlphamapResolution = 512;

        // Couleurs des sols (calques du terrain), dans l'ordre de l'énumération Surface.
        private static readonly Color[] GroundColors =
        {
            new Color(0.20f, 0.20f, 0.21f), // bitume
            new Color(0.45f, 0.33f, 0.23f), // terre
            new Color(0.86f, 0.68f, 0.47f), // sable
            new Color(0.58f, 0.47f, 0.34f), // sable mouillé
        };

        // Taille d'une répétition de texture, en mètres.
        private static readonly float[] TileSizes = { 4f, 3.5f, 3f, 3.5f };
        // Textures photographiées (Poly Haven, CC0) dans Resources/Ground, par sol.
        private static readonly string[] GroundNames = { "asphalt", "dirt", "sand", "wet_sand" };
        // Brillance maximale de chaque sol (la texture module dans son alpha).
        private static readonly float[] Smoothness = { 0.25f, 0.08f, 0.05f, 0.35f };

        // Ciel photographié de fin d'après-midi (HDR). Le soleil y est à u = 0,6003, 19° de hauteur ;
        // on tourne le ciel pour le placer au sud-ouest : lumière rasante de côté sur les dunes
        // (crêtes nord-sud), contre-jour doré quand on roule vers l'ouest.
        private const string SkyTexture = "Ground/sky_late_afternoon";
        private const float SkySunU = 0.6003f;
        private const float SkySunElevation = 19.07f;
        // Le shader du ciel tourne d'un angle opposé à Quaternion.Euler : -261° = soleil au sud-ouest.
        private const float SkyRotation = 261f;
        public static readonly Color SunColor = new Color(1f, 0.84f, 0.66f);
        // Couleur de l'horizon du ciel : la brume s'y fond.
        public static readonly Color HazeColor = new Color(0.80f, 0.75f, 0.67f);

        private static Texture2D _sandAlbedo;

        public static GameObject Build()
        {
            var root = new GameObject("Monde");
            float[,] heights = BuildTerrain(root.transform);
            BuildFarGround(root.transform);
            BuildWalls(root.transform);
            BuildCity(root.transform);
            BuildRocks(root.transform);
            BuildSea(root.transform);
            BuildSky(root.transform);
            return root;
        }

        // ------------------------------------------------------------------ terrain

        private static float[,] BuildTerrain(Transform parent)
        {
            float size = WorldLayout.Size;
            var data = new TerrainData();
            data.heightmapResolution = HeightmapResolution;
            data.size = new Vector3(size, WorldLayout.MaxHeight, size);

            int n = data.heightmapResolution;
            var heights = new float[n, n];
            for (int zi = 0; zi < n; zi++)
            {
                float z = zi / (float)(n - 1) * size - size / 2f;
                for (int xi = 0; xi < n; xi++)
                {
                    float x = xi / (float)(n - 1) * size - size / 2f;
                    heights[zi, xi] = WorldLayout.Height(x, z) / WorldLayout.MaxHeight;
                }
            }
            data.SetHeights(0, 0, heights);

            var layers = new TerrainLayer[GroundColors.Length];
            for (int i = 0; i < layers.Length; i++)
            {
                var albedo = Resources.Load<Texture2D>("Ground/" + GroundNames[i] + "_albedo");
                var normal = Resources.Load<Texture2D>("Ground/" + GroundNames[i] + "_normal");
                if (albedo == null || normal == null)
                    Materials.Ground((Surface)i, GroundColors[i], 100 + i, out albedo, out normal);
                if (i == (int)Surface.Sand)
                    _sandAlbedo = albedo;
                layers[i] = new TerrainLayer
                {
                    diffuseTexture = albedo,
                    normalMapTexture = normal,
                    normalScale = i == (int)Surface.Sand ? 0.7f : 1f,
                    tileSize = new Vector2(TileSizes[i], TileSizes[i]),
                    smoothness = Smoothness[i],
                    metallic = 0f,
                };
            }
            data.terrainLayers = layers;

            data.alphamapResolution = AlphamapResolution;
            data.SetAlphamaps(0, 0, Splat(heights, n, layers.Length));

            var go = Terrain.CreateTerrainGameObject(data);
            go.name = "Terrain";
            go.transform.SetParent(parent, false);
            go.transform.position = new Vector3(-size / 2f, 0f, -size / 2f);
            var terrain = go.GetComponent<Terrain>();
            terrain.heightmapPixelError = 3f;
            terrain.basemapDistance = 450f;
            terrain.drawInstanced = true;
            terrain.shadowCastingMode = ShadowCastingMode.On;
            // Avec URP, le terrain prend le matériau du pipeline ; sinon, Standard.
            if (!Materials.IsUrp)
            {
                var shader = Shader.Find("Nature/Terrain/Standard");
                if (shader != null)
                    terrain.materialTemplate = new Material(shader);
            }
            return heights;
        }

        /// <summary>
        /// Peinture des sols : un sol par point d'après WorldLayout, puis un flou pour des
        /// transitions douces. Les creux des dunes reçoivent un peu de sable plus sombre et
        /// plus compact, qui casse la répétition.
        /// </summary>
        private static float[,,] Splat(float[,] heights, int hn, int layerCount)
        {
            int a = AlphamapResolution;
            float size = WorldLayout.Size;
            var raw = new float[a, a, layerCount];
            for (int zi = 0; zi < a; zi++)
            {
                for (int xi = 0; xi < a; xi++)
                {
                    float x = (xi + 0.5f) / a * size - size / 2f;
                    float z = (zi + 0.5f) / a * size - size / 2f;
                    int hx = Mathf.Min(hn - 1, Mathf.RoundToInt((xi + 0.5f) / a * (hn - 1)));
                    int hz = Mathf.Min(hn - 1, Mathf.RoundToInt((zi + 0.5f) / a * (hn - 1)));
                    float h = heights[hz, hx] * WorldLayout.MaxHeight;
                    var s = WorldLayout.SurfaceAt(x, z, h);
                    // L'eau recouvre du sable mouillé.
                    int layer = s == Surface.Water ? (int)Surface.WetSand : (int)s;
                    if (s == Surface.Sand)
                    {
                        // Creux des dunes : sable plus sombre ; ailleurs, légères taches.
                        float trough = Mathf.Clamp01((WorldLayout.GroundLevel + 3f - h) / 3f);
                        float patch = WorldLayout.Fbm(x / 60f + 2f, z / 60f - 5f);
                        float wet = Mathf.Clamp01(trough * 0.35f + (patch - 0.55f) * 0.5f);
                        raw[zi, xi, (int)Surface.Sand] = 1f - wet;
                        raw[zi, xi, (int)Surface.WetSand] = wet;
                    }
                    else
                    {
                        raw[zi, xi, layer] = 1f;
                    }
                }
            }

            // Flou 5 × 5 (≈ 10 m) : les zones se fondent les unes dans les autres.
            var alpha = new float[a, a, layerCount];
            for (int zi = 0; zi < a; zi++)
            {
                for (int xi = 0; xi < a; xi++)
                {
                    float total = 0f;
                    for (int l = 0; l < layerCount; l++)
                    {
                        float sum = 0f;
                        int count = 0;
                        for (int dz = -2; dz <= 2; dz++)
                        {
                            int z2 = Mathf.Clamp(zi + dz, 0, a - 1);
                            for (int dx = -2; dx <= 2; dx++)
                            {
                                sum += raw[z2, Mathf.Clamp(xi + dx, 0, a - 1), l];
                                count++;
                            }
                        }
                        alpha[zi, xi, l] = sum / count;
                        total += alpha[zi, xi, l];
                    }
                    for (int l = 0; l < layerCount; l++)
                        alpha[zi, xi, l] /= total;
                }
            }
            return alpha;
        }

        /// <summary>Sable à perte de vue autour du monde (sauf côté mer) : plus de bord visible.</summary>
        private static void BuildFarGround(Transform parent)
        {
            var mat = Materials.Lit(Color.white, _sandAlbedo, 0.05f);
            mat.mainTextureScale = new Vector2(400f, 400f);
            if (mat.HasProperty("_BaseMap"))
                mat.SetTextureScale("_BaseMap", new Vector2(400f, 400f));
            float half = WorldLayout.Size / 2f;
            float far = 2500f;
            float east = WorldLayout.BeachEnd - 15f;
            // Nord, sud et ouest, à la hauteur des bords aplatis du terrain.
            AddGroundQuad(parent, mat, new Rect(-far, half - 1f, east + far, far), WorldLayout.GroundLevel - 0.05f);
            AddGroundQuad(parent, mat, new Rect(-far, -half - far + 1f, east + far, far), WorldLayout.GroundLevel - 0.05f);
            AddGroundQuad(parent, mat, new Rect(-far, -half, far - half + 1f, WorldLayout.Size), WorldLayout.GroundLevel - 0.05f);
        }

        private static void AddGroundQuad(Transform parent, Material mat, Rect r, float y)
        {
            var go = GameObject.CreatePrimitive(PrimitiveType.Quad);
            go.name = "Sol lointain";
            Object.Destroy(go.GetComponent<Collider>());
            go.transform.SetParent(parent, false);
            go.transform.position = new Vector3(r.center.x, y, r.center.y);
            go.transform.rotation = Quaternion.Euler(90f, 0f, 0f);
            go.transform.localScale = new Vector3(r.width, r.height, 1f);
            var renderer = go.GetComponent<Renderer>();
            renderer.sharedMaterial = mat;
            renderer.shadowCastingMode = ShadowCastingMode.Off;
        }

        /// <summary>Murs invisibles au nord, au sud et à l'ouest (la mer, à l'est, ramène au sec).</summary>
        private static void BuildWalls(Transform parent)
        {
            float half = WorldLayout.Size / 2f;
            var walls = new GameObject("Limites").transform;
            walls.SetParent(parent, false);
            AddWall(walls, new Vector3(0f, 30f, half - 6f), new Vector3(WorldLayout.Size * 2f, 80f, 2f));
            AddWall(walls, new Vector3(0f, 30f, -half + 6f), new Vector3(WorldLayout.Size * 2f, 80f, 2f));
            AddWall(walls, new Vector3(-half + 6f, 30f, 0f), new Vector3(2f, 80f, WorldLayout.Size * 2f));
        }

        private static void AddWall(Transform parent, Vector3 center, Vector3 size)
        {
            var go = new GameObject("Mur");
            go.transform.SetParent(parent, false);
            go.transform.position = center;
            go.AddComponent<BoxCollider>().size = size;
        }

        // ------------------------------------------------------------------ ville et rochers

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
            foreach (var m in palette)
                m.enableInstancing = true;
            float half = WorldLayout.Size / 2f;
            float block = WorldLayout.BlockSize;
            float street = WorldLayout.StreetWidth;
            float ground = WorldLayout.GroundLevel;
            // Pâtés de maisons : de l'ouest du monde jusqu'à 40 m avant la fin de la ville.
            for (float bx = Mathf.Ceil(-half / block) * block; bx + block < WorldLayout.CityEnd - 40f; bx += block)
            {
                for (float bz = Mathf.Ceil(-half / block) * block; bz + block < half; bz += block)
                {
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

        /// <summary>Rochers dans la terre, quelques-uns au pied des dunes. Les gros arrêtent la voiture.</summary>
        private static void BuildRocks(Transform parent)
        {
            var rocks = new GameObject("Rochers").transform;
            rocks.SetParent(parent, false);
            var meshes = new Mesh[4];
            for (int i = 0; i < meshes.Length; i++)
                meshes[i] = RockMesh(500 + i);
            var mats = new[]
            {
                Materials.Lit(new Color(0.42f, 0.34f, 0.28f), null, 0.12f),
                Materials.Lit(new Color(0.55f, 0.45f, 0.36f), null, 0.10f),
            };
            foreach (var m in mats)
                m.enableInstancing = true;

            var rng = new System.Random(7);
            float half = WorldLayout.Size / 2f - 20f;
            int placed = 0;
            for (int attempt = 0; attempt < 4000 && placed < 320; attempt++)
            {
                float x = Mathf.Lerp(WorldLayout.CityEnd + 20f, WorldLayout.DunesEnd - 30f, (float)rng.NextDouble());
                float z = Mathf.Lerp(-half, half, (float)rng.NextDouble());
                float h = WorldLayout.Height(x, z);
                var s = WorldLayout.SurfaceAt(x, z, h);
                // Beaucoup dans la terre, rares dans le sable, groupés par endroits.
                float cluster = WorldLayout.Fbm(x / 45f + 30f, z / 45f - 12f);
                float chance = s == Surface.Dirt ? cluster * 1.4f - 0.35f : s == Surface.Sand ? (cluster - 0.62f) * 0.6f : 0f;
                if (rng.NextDouble() > chance)
                    continue;
                // Le spawn reste dégagé.
                if (Mathf.Abs(x - WorldLayout.SpawnX) < 40f && Mathf.Abs(z - WorldLayout.SpawnZ) < 40f)
                    continue;

                float scale = 0.4f + Mathf.Pow((float)rng.NextDouble(), 3f) * 3.2f;
                var go = new GameObject("Rocher");
                go.transform.SetParent(rocks, false);
                go.transform.position = new Vector3(x, h - scale * 0.25f, z);
                go.transform.rotation = Quaternion.Euler((float)rng.NextDouble() * 20f - 10f, (float)rng.NextDouble() * 360f, (float)rng.NextDouble() * 20f - 10f);
                go.transform.localScale = new Vector3(scale * (0.8f + (float)rng.NextDouble() * 0.6f), scale * (0.5f + (float)rng.NextDouble() * 0.4f), scale * (0.8f + (float)rng.NextDouble() * 0.6f));
                var mesh = meshes[rng.Next(meshes.Length)];
                go.AddComponent<MeshFilter>().sharedMesh = mesh;
                go.AddComponent<MeshRenderer>().sharedMaterial = mats[rng.Next(mats.Length)];
                if (scale > 1.1f)
                {
                    var mc = go.AddComponent<MeshCollider>();
                    mc.sharedMesh = mesh;
                    mc.convex = true;
                }
                placed++;
            }
        }

        /// <summary>Rocher : sphère facettée déformée par du bruit, aplatie à la base.</summary>
        private static Mesh RockMesh(int seed)
        {
            var mesh = new Mesh { name = "Rocher" };
            var rng = new System.Random(seed);
            float ox = (float)rng.NextDouble() * 100f, oz = (float)rng.NextDouble() * 100f;
            // Sphère grossière (8 × 12), puis facettes : chaque triangle a ses propres sommets
            // (ombrage anguleux de pierre).
            const int rings = 8, segments = 12;
            var sv = new Vector3[(rings + 1) * (segments + 1)];
            for (int r = 0; r <= rings; r++)
            {
                float lat = Mathf.PI * r / rings;
                for (int g = 0; g <= segments; g++)
                {
                    float lon = 2f * Mathf.PI * g / segments;
                    sv[r * (segments + 1) + g] = new Vector3(Mathf.Sin(lat) * Mathf.Cos(lon), Mathf.Cos(lat), Mathf.Sin(lat) * Mathf.Sin(lon)) * 0.5f;
                }
            }
            var st = new int[rings * segments * 6];
            int q = 0;
            for (int r = 0; r < rings; r++)
            {
                for (int g = 0; g < segments; g++)
                {
                    int a0 = r * (segments + 1) + g, b0 = a0 + segments + 1;
                    st[q++] = a0; st[q++] = a0 + 1; st[q++] = b0;
                    st[q++] = a0 + 1; st[q++] = b0 + 1; st[q++] = b0;
                }
            }
            var verts = new Vector3[st.Length];
            var tris = new int[st.Length];
            for (int i = 0; i < st.Length; i++)
            {
                Vector3 v = sv[st[i]];
                float d = 0.75f + 0.5f * WorldLayout.Fbm(v.x * 4.4f + ox, v.z * 4.4f + v.y * 3.4f + oz);
                v *= d;
                if (v.y < -0.08f)
                    v.y = -0.08f + (v.y + 0.08f) * 0.3f;
                verts[i] = v;
                tris[i] = i;
            }
            mesh.vertices = verts;
            mesh.triangles = tris;
            mesh.RecalculateNormals();
            mesh.RecalculateBounds();
            return mesh;
        }

        // ------------------------------------------------------------------ mer

        /// <summary>
        /// Mer : un maillage fin le long de la côte (houle visible, vagues qui lèchent le sable)
        /// entouré de grands panneaux jusqu'à l'horizon. Avec URP, shader CarIdle/Sea.
        /// </summary>
        private static void BuildSea(Transform parent)
        {
            var sea = new GameObject("Mer").transform;
            sea.SetParent(parent, false);
            var shader = Materials.IsUrp ? Shader.Find("CarIdle/Sea") : null;

            // Zone détaillée : de l'arrière de la plage au large, sur toute la côte du monde.
            var near = new Rect(WorldLayout.DunesEnd - 40f, -WorldLayout.Size / 2f - 40f, 420f, WorldLayout.Size + 80f);
            Material nearMat, farMat;
            if (shader != null)
            {
                var depth = DepthMap(near, 256, 512);
                nearMat = new Material(shader);
                nearMat.SetTexture("_DepthMap", depth);
                nearMat.SetVector("_DepthRect", new Vector4(near.x, near.y, near.width, near.height));
                farMat = new Material(nearMat);
                farMat.SetFloat("_WaveHeight", 0f);
            }
            else
            {
                nearMat = farMat = Materials.Lit(new Color(0.10f, 0.38f, 0.40f), null, 0.92f);
            }

            AddSeaMesh(sea, nearMat, near, 2f, 4f, "Mer côte");
            // Large : quatre panneaux autour de la zone détaillée.
            float far = 4000f;
            AddSeaMesh(sea, farMat, new Rect(near.xMax, -far, far, far * 2f), 200f, 200f, "Mer large");
            AddSeaMesh(sea, farMat, new Rect(near.x, near.yMax, near.width, far - near.yMax), 50f, 200f, "Mer nord");
            AddSeaMesh(sea, farMat, new Rect(near.x, -far, near.width, near.y + far), 50f, 200f, "Mer sud");
        }

        /// <summary>Profondeur d'eau (R = mètres / 8) sous la zone détaillée de la mer.</summary>
        private static Texture2D DepthMap(Rect r, int w, int h)
        {
            var t = new Texture2D(w, h, TextureFormat.RGBA32, false, true);
            t.wrapMode = TextureWrapMode.Clamp;
            var px = new Color[w * h];
            for (int j = 0; j < h; j++)
            {
                float z = r.y + (j + 0.5f) / h * r.height;
                for (int i = 0; i < w; i++)
                {
                    float x = r.x + (i + 0.5f) / w * r.width;
                    float d = Mathf.Clamp01((WorldLayout.SeaLevel - WorldLayout.Height(x, z)) / 8f);
                    px[j * w + i] = new Color(d, d, d, 1f);
                }
            }
            t.SetPixels(px);
            t.Apply(false);
            return t;
        }

        private static void AddSeaMesh(Transform parent, Material mat, Rect r, float stepX, float stepZ, string name)
        {
            int nx = Mathf.Max(1, Mathf.CeilToInt(r.width / stepX));
            int nz = Mathf.Max(1, Mathf.CeilToInt(r.height / stepZ));
            var verts = new Vector3[(nx + 1) * (nz + 1)];
            for (int j = 0; j <= nz; j++)
                for (int i = 0; i <= nx; i++)
                    verts[j * (nx + 1) + i] = new Vector3(r.x + r.width * i / nx, 0f, r.y + r.height * j / nz);
            var tris = new int[nx * nz * 6];
            int k = 0;
            for (int j = 0; j < nz; j++)
            {
                for (int i = 0; i < nx; i++)
                {
                    int a = j * (nx + 1) + i;
                    tris[k++] = a; tris[k++] = a + nx + 1; tris[k++] = a + 1;
                    tris[k++] = a + 1; tris[k++] = a + nx + 1; tris[k++] = a + nx + 2;
                }
            }
            var mesh = new Mesh { name = name, indexFormat = verts.Length > 65000 ? IndexFormat.UInt32 : IndexFormat.UInt16 };
            mesh.vertices = verts;
            mesh.triangles = tris;
            mesh.RecalculateNormals();
            mesh.RecalculateBounds();
            // La houle déplace les sommets : on élargit la boîte englobante.
            var b = mesh.bounds;
            b.Expand(new Vector3(0f, 2f, 0f));
            mesh.bounds = b;

            var go = new GameObject(name);
            go.transform.SetParent(parent, false);
            go.transform.position = new Vector3(0f, WorldLayout.SeaLevel, 0f);
            go.AddComponent<MeshFilter>().sharedMesh = mesh;
            var mr = go.AddComponent<MeshRenderer>();
            mr.sharedMaterial = mat;
            mr.shadowCastingMode = ShadowCastingMode.Off;
        }

        // ------------------------------------------------------------------ ciel et lumière

        private static void BuildSky(Transform parent)
        {
            // Direction du soleil dans le ciel photographié (repère du shader Skybox/Panoramic),
            // puis la même rotation que le ciel.
            float lon = (0.5f - SkySunU) * 2f * Mathf.PI;
            float el = SkySunElevation * Mathf.Deg2Rad;
            var toSun = new Vector3(Mathf.Cos(el) * Mathf.Cos(lon), Mathf.Sin(el), Mathf.Cos(el) * Mathf.Sin(lon));
            toSun = Quaternion.Euler(0f, -SkyRotation, 0f) * toSun;

            var sunGo = new GameObject("Soleil");
            sunGo.transform.SetParent(parent, false);
            var sun = sunGo.AddComponent<Light>();
            sun.type = LightType.Directional;
            sun.color = SunColor;
            sun.intensity = 2.4f;
            sun.shadows = LightShadows.Soft;
            sun.shadowStrength = 0.85f;
            sun.shadowBias = 0.05f;
            sun.shadowNormalBias = 0.4f;
            sunGo.transform.rotation = Quaternion.LookRotation(-toSun);
            RenderSettings.sun = sun;

            var skyTex = Resources.Load<Texture2D>(SkyTexture);
            var panoShader = Shader.Find("Skybox/Panoramic");
            var skyShader = Shader.Find("Skybox/Procedural");
            if (skyTex != null && panoShader != null)
            {
                var sky = new Material(panoShader);
                sky.SetTexture("_MainTex", skyTex);
                sky.SetFloat("_Rotation", SkyRotation);
                sky.SetFloat("_Exposure", 1f);
                sky.SetFloat("_Mapping", 1f); // équirectangulaire
                sky.SetFloat("_ImageType", 0f); // 360°
                RenderSettings.skybox = sky;
                RenderSettings.ambientMode = AmbientMode.Skybox;
                RenderSettings.ambientIntensity = 1f;
            }
            else if (skyShader != null)
            {
                var sky = new Material(skyShader);
                sky.SetFloat("_SunDisk", 2f);
                sky.SetFloat("_SunSize", 0.045f);
                sky.SetFloat("_SunSizeConvergence", 4f);
                sky.SetFloat("_AtmosphereThickness", 1.2f);
                sky.SetColor("_SkyTint", new Color(0.55f, 0.58f, 0.62f));
                sky.SetColor("_GroundColor", new Color(0.55f, 0.47f, 0.40f));
                sky.SetFloat("_Exposure", 1.1f);
                RenderSettings.skybox = sky;
                RenderSettings.ambientMode = AmbientMode.Skybox;
                RenderSettings.ambientIntensity = 1f;
            }
            else
            {
                RenderSettings.ambientMode = AmbientMode.Trilight;
                RenderSettings.ambientSkyColor = new Color(0.55f, 0.62f, 0.72f);
                RenderSettings.ambientEquatorColor = new Color(0.66f, 0.60f, 0.52f);
                RenderSettings.ambientGroundColor = new Color(0.36f, 0.30f, 0.25f);
            }

            // Brume de chaleur : profondeur, et fin du monde invisible.
            RenderSettings.fog = true;
            RenderSettings.fogMode = FogMode.ExponentialSquared;
            RenderSettings.fogColor = HazeColor;
            RenderSettings.fogDensity = 0.0017f;

            // Lumière ambiante et reflets calculés depuis le ciel (pas de précalcul).
            DynamicGI.UpdateEnvironment();
            var probeGo = new GameObject("Reflets du ciel");
            probeGo.transform.SetParent(parent, false);
            probeGo.transform.position = new Vector3(0f, 60f, 0f);
            var probe = probeGo.AddComponent<ReflectionProbe>();
            probe.mode = ReflectionProbeMode.Realtime;
            probe.refreshMode = ReflectionProbeRefreshMode.ViaScripting;
            probe.timeSlicingMode = ReflectionProbeTimeSlicingMode.NoTimeSlicing;
            probe.size = new Vector3(6000f, 2000f, 6000f);
            probe.resolution = 128;
            probe.cullingMask = 0; // le ciel seul
            probe.clearFlags = ReflectionProbeClearFlags.Skybox;
            probe.hdr = true;
            probe.importance = 0;
            probe.RenderProbe();
        }
    }
}
