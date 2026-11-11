using CarIdle.Core;
using UnityEngine;

namespace CarIdle.Drive
{
    /// <summary>
    /// Matériaux créés par le code pour le prototype : éclairés (URP Lit si le rendu URP est
    /// actif, sinon Standard) et transparents pour les effets (Sprites/Default, compatible URP).
    /// </summary>
    public static class Materials
    {
        private static Shader _lit;
        private static Shader _fx;
        private static Texture2D _softDot;

        /// <summary>Vrai si un pipeline URP est réglé dans Graphics (le paquet seul ne suffit pas).</summary>
        public static bool IsUrp => UnityEngine.Rendering.GraphicsSettings.currentRenderPipeline != null;

        private static Shader LitShader()
        {
            if (_lit == null && IsUrp)
                _lit = Shader.Find("Universal Render Pipeline/Lit");
            if (_lit == null)
                _lit = Shader.Find("Standard");
            return _lit;
        }

        /// <summary>Matériau éclairé d'une couleur, avec une texture facultative.</summary>
        public static Material Lit(Color color, Texture texture = null, float smoothness = 0.3f, float metallic = 0f)
        {
            var m = new Material(LitShader());
            m.color = color;
            if (m.HasProperty("_BaseColor"))
                m.SetColor("_BaseColor", color);
            if (texture != null)
            {
                m.mainTexture = texture;
                if (m.HasProperty("_BaseMap"))
                    m.SetTexture("_BaseMap", texture);
            }
            if (m.HasProperty("_Smoothness"))
                m.SetFloat("_Smoothness", smoothness);
            if (m.HasProperty("_Glossiness"))
                m.SetFloat("_Glossiness", smoothness);
            if (m.HasProperty("_Metallic"))
                m.SetFloat("_Metallic", metallic);
            return m;
        }

        /// <summary>
        /// Matériau transparent pour traces et particules (couleur par sommet). Avec URP,
        /// shader du jeu : brouillard, et contre-jour du soleil si <paramref name="scatter"/> &gt; 0.
        /// </summary>
        public static Material Fx(Texture texture = null, float scatter = 0f)
        {
            if (_fx == null && IsUrp)
                _fx = Shader.Find("CarIdle/Particle");
            if (_fx == null)
                _fx = Shader.Find("Sprites/Default");
            var m = new Material(_fx);
            if (texture != null)
                m.mainTexture = texture;
            if (m.HasProperty("_Scatter"))
                m.SetFloat("_Scatter", scatter);
            return m;
        }

        /// <summary>
        /// Normale encodée pour que les deux décodages d'Unity la lisent juste :
        /// RGB (mobile, web) et AG (PC). Texture linéaire.
        /// </summary>
        private static Color EncodeNormal(float nx, float ny, float nz)
        {
            float len = Mathf.Sqrt(nx * nx + ny * ny + nz * nz);
            nx /= len; ny /= len; nz /= len;
            return new Color(nx * 0.5f + 0.5f, ny * 0.5f + 0.5f, nz * 0.5f + 0.5f, 1f);
        }

        /// <summary>Hauteur périodique (la texture se répète sans couture) pour chaque sol.</summary>
        private delegate float HeightField(float u, float v);

        /// <summary>
        /// Texture de sol (couleur + reliefs) qui se répète : sable ridé par le vent, terre
        /// bosselée, bitume granuleux, sable mouillé lisse. La couleur est assombrie dans les
        /// creux, comme sous une lumière rasante.
        /// </summary>
        public static void Ground(Surface surface, Color baseColor, int seed, out Texture2D albedo, out Texture2D normal)
        {
            const int n = 256;
            var rng = new System.Random(seed);
            HeightField field;
            float strength, shade, grain;
            float p1 = (float)rng.NextDouble() * 6.28f, p2 = (float)rng.NextDouble() * 6.28f;
            switch (surface)
            {
                case Surface.Sand:
                    // Rides de sable : ~13 par tuile, un peu dissymétriques, ondulées.
                    field = (u, v) =>
                    {
                        float w = 0.05f * Mathf.Sin(6.2832f * (2f * v + u) + p1) + 0.03f * Mathf.Sin(6.2832f * (5f * v - 2f * u) + p2);
                        float ph = Frac(13f * u + 2f * v + w * 13f);
                        float ridge = ph < 0.7f ? ph / 0.7f : (1f - ph) / 0.3f;
                        return ridge * ridge * (3f - 2f * ridge);
                    };
                    strength = 2.2f; shade = 0.10f; grain = 0.06f;
                    break;
                case Surface.Dirt:
                    field = (u, v) => 0.5f * Mathf.Sin(6.2832f * (3f * u + 2f * v) + p1) * Mathf.Sin(6.2832f * (2f * u - 3f * v) + p2)
                        + 0.3f * Mathf.Sin(6.2832f * (7f * u + 5f * v) + p2) * Mathf.Sin(6.2832f * (6f * v - 4f * u) + p1);
                    strength = 2.5f; shade = 0.14f; grain = 0.22f;
                    break;
                case Surface.WetSand:
                    field = (u, v) => 0.5f * Mathf.Sin(6.2832f * (4f * u + v) + p1) * Mathf.Sin(6.2832f * (3f * v - u) + p2);
                    strength = 0.6f; shade = 0.04f; grain = 0.05f;
                    break;
                default:
                    field = (u, v) => 0f;
                    strength = 0f; shade = 0f; grain = 0.25f;
                    break;
            }

            var heights = new float[n * n];
            for (int y = 0; y < n; y++)
                for (int x = 0; x < n; x++)
                    heights[y * n + x] = field((float)x / n, (float)y / n);

            albedo = new Texture2D(n, n, TextureFormat.RGBA32, true);
            normal = new Texture2D(n, n, TextureFormat.RGBA32, true, true);
            albedo.wrapMode = normal.wrapMode = TextureWrapMode.Repeat;
            albedo.anisoLevel = normal.anisoLevel = 4;
            var a = new Color[n * n];
            var nm = new Color[n * n];
            for (int y = 0; y < n; y++)
            {
                for (int x = 0; x < n; x++)
                {
                    float h = heights[y * n + x];
                    float dx = heights[y * n + (x + 1) % n] - heights[y * n + (x + n - 1) % n];
                    float dy = heights[((y + 1) % n) * n + x] - heights[((y + n - 1) % n) * n + x];
                    nm[y * n + x] = EncodeNormal(-dx * strength, -dy * strength, 1f);
                    float k = 1f + (h - 0.5f) * shade + ((float)rng.NextDouble() - 0.5f) * grain;
                    // Alpha = brillance (lu par le terrain URP) : sol mat.
                    a[y * n + x] = new Color(baseColor.r * k, baseColor.g * k, baseColor.b * k, 0.08f);
                }
            }
            albedo.SetPixels(a);
            albedo.Apply(true);
            normal.SetPixels(nm);
            normal.Apply(true);
        }

        /// <summary>Bande de trace de pneu : bords doux, sculptures du pneu le long de la trace.</summary>
        public static Texture2D TrackTexture()
        {
            const int w = 64, h = 32;
            var t = new Texture2D(w, h, TextureFormat.RGBA32, true);
            t.wrapMode = TextureWrapMode.Repeat;
            for (int y = 0; y < h; y++)
            {
                float v = (y + 0.5f) / h * 2f - 1f;
                float band = Mathf.Clamp01((1f - Mathf.Abs(v)) * 3f);
                for (int x = 0; x < w; x++)
                {
                    float tread = 0.75f + 0.25f * Mathf.Sign(Mathf.Sin((x / (float)w) * 6.2832f * 4f + Mathf.Abs(v) * 3f));
                    t.SetPixel(x, y, new Color(1f, 1f, 1f, band * tread));
                }
            }
            t.Apply(true);
            return t;
        }

        private static float Frac(float x) => x - Mathf.Floor(x);

        /// <summary>Disque doux (blanc au centre, transparent au bord) pour la poussière et le sable.</summary>
        public static Texture2D SoftDot()
        {
            if (_softDot != null)
                return _softDot;
            const int n = 64;
            _softDot = new Texture2D(n, n, TextureFormat.RGBA32, false);
            _softDot.wrapMode = TextureWrapMode.Clamp;
            for (int y = 0; y < n; y++)
            {
                for (int x = 0; x < n; x++)
                {
                    float dx = (x + 0.5f) / n * 2f - 1f;
                    float dy = (y + 0.5f) / n * 2f - 1f;
                    float a = Mathf.Clamp01(1f - Mathf.Sqrt(dx * dx + dy * dy));
                    _softDot.SetPixel(x, y, new Color(1f, 1f, 1f, a * a));
                }
            }
            _softDot.Apply();
            return _softDot;
        }

        /// <summary>Texture de sol : une couleur de base avec un léger grain, qui se répète.</summary>
        public static Texture2D Noise(Color baseColor, float grain, int seed)
        {
            const int n = 64;
            var t = new Texture2D(n, n, TextureFormat.RGBA32, true);
            t.wrapMode = TextureWrapMode.Repeat;
            var rng = new System.Random(seed);
            for (int y = 0; y < n; y++)
            {
                for (int x = 0; x < n; x++)
                {
                    float v = 1f + ((float)rng.NextDouble() - 0.5f) * grain;
                    t.SetPixel(x, y, new Color(baseColor.r * v, baseColor.g * v, baseColor.b * v, 1f));
                }
            }
            t.Apply();
            return t;
        }
    }
}
