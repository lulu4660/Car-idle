using System;

namespace CarIdle.Core
{
    /// <summary>Nature du sol sous une roue : règle l'adhérence, les traces et la poussière.</summary>
    public enum Surface
    {
        Asphalt,
        Dirt,
        Sand,
        WetSand,
        Water,
    }

    /// <summary>
    /// Plan du monde de la balade (prototype) : une bande d'ouest en est,
    /// ville → terre et collines → dunes → plage → mer. Les coordonnées sont en mètres,
    /// x vers l'est, z vers le nord, origine au centre ; la hauteur est absolue.
    /// Fonctions pures et déterministes : le même relief sert au terrain, à la caméra
    /// et aux tests, sans Unity.
    /// </summary>
    public static class WorldLayout
    {
        /// <summary>Côté du monde carré, en mètres.</summary>
        public const float Size = 1024f;
        /// <summary>Hauteur maximale que peut prendre le relief.</summary>
        public const float MaxHeight = 60f;
        public const float SeaLevel = 10f;
        /// <summary>Hauteur du sol de la ville (et de la base des autres zones).</summary>
        public const float GroundLevel = 13f;

        // Limites des zones le long de x (la plage ondule un peu le long de z).
        public const float CityEnd = -180f;
        public const float DirtEnd = 110f;
        public const float DunesEnd = 330f;
        public const float BeachEnd = 395f;

        // Rues de la ville : un pâté de maisons tous les 60 m, rues de 16 m.
        public const float BlockSize = 60f;
        public const float StreetWidth = 16f;

        /// <summary>Point de départ de la voiture : dans les dunes, face à la côte.</summary>
        public const float SpawnX = 240f;
        public const float SpawnZ = 0f;

        public static float Height(float x, float z)
        {
            float city = GroundLevel;
            // Terre : collines douces (±4 m).
            float dirt = GroundLevel + 8f * (Fbm(x / 110f + 3.1f, z / 110f - 7.3f) - 0.5f);
            // Dunes : crêtes perpendiculaires au vent, déformées par du bruit, jusqu'à 8 m.
            float warp = 1.6f * Fbm(x / 70f, z / 70f) + 0.5f * (float)Math.Sin(z * 0.013f);
            float ridge = (float)Math.Abs(Math.Sin(x * 0.034f + warp));
            float dunes = GroundLevel + 8f * (float)Math.Pow(ridge, 1.6) + 2.5f * (Fbm(x / 40f + 11f, z / 40f) - 0.5f);

            float h = Lerp(city, dirt, SmoothStep(CityEnd - 25f, CityEnd + 25f, x));
            h = Lerp(h, dunes, SmoothStep(DirtEnd - 45f, DirtEnd + 45f, x));

            // Plage puis fond marin : la côte ondule le long de z.
            float coast = ShoreOffset(z);
            float shoreStart = DunesEnd - 20f + coast;
            float beachEnd = BeachEnd + coast;
            float shore = GroundLevel - (x - shoreStart) * (GroundLevel - (SeaLevel - 0.4f)) / (beachEnd - shoreStart);
            if (x > beachEnd)
                shore = SeaLevel - 0.4f - (x - beachEnd) * 0.06f;
            h = Lerp(h, shore, SmoothStep(shoreStart - 10f, shoreStart + 25f, x));
            return Math.Max(0.5f, Math.Min(MaxHeight - 0.5f, h));
        }

        /// <summary>Décalage de la côte vers l'est ou l'ouest selon z (±15 m).</summary>
        public static float ShoreOffset(float z)
        {
            return 15f * (float)Math.Sin(z * 0.01f) + 6f * (float)Math.Sin(z * 0.031f + 1.3f);
        }

        public static Surface SurfaceAt(float x, float z, float height)
        {
            if (height < SeaLevel - 0.05f)
                return Surface.Water;
            if (x > DunesEnd + ShoreOffset(z) && height < SeaLevel + 0.7f)
                return Surface.WetSand;
            // Frontières un peu irrégulières entre les zones.
            float jitter = 20f * (Fbm(x / 35f + 5f, z / 35f + 9f) - 0.5f);
            if (x < CityEnd + jitter * 0.3f)
                return Surface.Asphalt;
            if (x < DirtEnd + jitter)
                return Surface.Dirt;
            return Surface.Sand;
        }

        /// <summary>Adhérence relative du sol (1 = bitume sec).</summary>
        public static float Grip(Surface s)
        {
            switch (s)
            {
                case Surface.Asphalt: return 1.0f;
                case Surface.Dirt: return 0.8f;
                case Surface.WetSand: return 0.7f;
                case Surface.Sand: return 0.6f;
                default: return 0.35f;
            }
        }

        /// <summary>Le sol laisse-t-il des traces et soulève-t-il de la poussière même sans dérapage ?</summary>
        public static bool IsSoft(Surface s)
        {
            return s == Surface.Dirt || s == Surface.Sand || s == Surface.WetSand;
        }

        /// <summary>Ce point de la ville est-il une rue (et non un pâté de maisons) ?</summary>
        public static bool IsStreet(float x, float z)
        {
            return Mod(x, BlockSize) < StreetWidth || Mod(z, BlockSize) < StreetWidth;
        }

        // --- Bruit déterministe ---------------------------------------------------------

        /// <summary>Bruit fractal dans [0, 1], lisse.</summary>
        public static float Fbm(float x, float y)
        {
            return 0.55f * ValueNoise(x, y) + 0.3f * ValueNoise(x * 2.03f + 17f, y * 2.03f - 5f) + 0.15f * ValueNoise(x * 4.1f - 3f, y * 4.1f + 11f);
        }

        private static float ValueNoise(float x, float y)
        {
            int xi = (int)Math.Floor(x);
            int yi = (int)Math.Floor(y);
            float fx = x - xi;
            float fy = y - yi;
            fx = fx * fx * (3f - 2f * fx);
            fy = fy * fy * (3f - 2f * fy);
            float a = Hash(xi, yi), b = Hash(xi + 1, yi), c = Hash(xi, yi + 1), d = Hash(xi + 1, yi + 1);
            return Lerp(Lerp(a, b, fx), Lerp(c, d, fx), fy);
        }

        private static float Hash(int x, int y)
        {
            unchecked
            {
                uint h = (uint)x * 374761393u + (uint)y * 668265263u;
                h = (h ^ (h >> 13)) * 1274126177u;
                h ^= h >> 16;
                return (h & 0xFFFFFF) / 16777215f;
            }
        }

        public static float Lerp(float a, float b, float t)
        {
            return a + (b - a) * t;
        }

        public static float SmoothStep(float edge0, float edge1, float x)
        {
            float t = Math.Max(0f, Math.Min(1f, (x - edge0) / (edge1 - edge0)));
            return t * t * (3f - 2f * t);
        }

        private static float Mod(float a, float m)
        {
            float r = a % m;
            return r < 0f ? r + m : r;
        }
    }
}
