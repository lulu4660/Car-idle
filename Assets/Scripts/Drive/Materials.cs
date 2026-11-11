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

        /// <summary>Matériau transparent non éclairé pour traces et particules (couleur par sommet).</summary>
        public static Material Fx(Texture texture = null)
        {
            if (_fx == null)
                _fx = Shader.Find("Sprites/Default");
            var m = new Material(_fx);
            if (texture != null)
                m.mainTexture = texture;
            return m;
        }

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
