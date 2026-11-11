using CarIdle.Core;
using UnityEngine;

namespace CarIdle.Drive
{
    /// <summary>
    /// Réception de saut : quand la voiture retombe fort sur un sol meuble (sable, terre), le
    /// terrain se creuse sous chaque roue (cuvette avec un bourrelet autour, plus large et plus
    /// profonde selon la vitesse d'arrivée), une gerbe de sable jaillit et la caméra tremble.
    /// Les creux restent jusqu'à la fin de la balade.
    /// </summary>
    [RequireComponent(typeof(CarController))]
    public class TerrainImpacts : MonoBehaviour
    {
        /// <summary>Vitesse verticale (m/s) à partir de laquelle le sol se creuse.</summary>
        public float MinImpactSpeed = 4.5f;
        public float MaxDepth = 0.5f;
        /// <summary>Durée minimale en l'air (s) pour compter comme un saut.</summary>
        public float MinAirTime = 0.25f;

        private CarController _car;
        private Rigidbody _rb;
        private CarEffects _effects;
        private float _airTime;
        private float _fallSpeed;
        private bool _wasAirborne;

        public System.Action<float> Landed;

        private void Start()
        {
            _car = GetComponent<CarController>();
            _rb = GetComponent<Rigidbody>();
            _effects = GetComponent<CarEffects>();
        }

        private void FixedUpdate()
        {
            int grounded = 0;
            for (int i = 0; i < 4; i++)
                if (_car.Grounded[i])
                    grounded++;

            float vy = Physics2.GetVelocity(_rb).y;
            if (grounded == 0)
            {
                _airTime += Time.fixedDeltaTime;
                _fallSpeed = Mathf.Max(_fallSpeed, -vy);
                _wasAirborne = true;
                return;
            }

            if (_wasAirborne && _airTime >= MinAirTime && _fallSpeed >= MinImpactSpeed)
                Land(_fallSpeed);
            _wasAirborne = false;
            _airTime = 0f;
            _fallSpeed = 0f;
        }

        private void Land(float speed)
        {
            float k = Mathf.Clamp01((speed - MinImpactSpeed) / 10f);
            float depth = Mathf.Lerp(0.08f, MaxDepth, k);
            float radius = Mathf.Lerp(0.8f, 1.8f, k);
            var terrain = Terrain.activeTerrain;
            for (int i = 0; i < 4; i++)
            {
                if (!_car.Grounded[i])
                    continue;
                Vector3 p = _car.ContactPoint[i];
                Surface s = _car.WheelSurface[i];
                if (!WorldLayout.IsSoft(s))
                    continue;
                if (terrain != null)
                    Dent(terrain, p, radius, depth * (s == Surface.Dirt ? 0.5f : 1f));
                if (_effects != null)
                    _effects.Burst(p, s, 0.5f + k);
            }
            // Très gros choc : la caisse marque aussi le sable.
            if (k > 0.6f && terrain != null)
                Dent(terrain, transform.position, radius * 1.6f, depth * 0.5f);
            Landed?.Invoke(k);
        }

        /// <summary>Creuse une cuvette (profil en cloche) bordée d'un léger bourrelet.</summary>
        public static void Dent(Terrain terrain, Vector3 world, float radius, float depth)
        {
            var data = terrain.terrainData;
            int res = data.heightmapResolution;
            Vector3 size = data.size;
            Vector3 local = world - terrain.transform.position;
            float cell = size.x / (res - 1);
            float rimRadius = radius * 1.7f;
            int r = Mathf.CeilToInt(rimRadius / cell) + 1;
            int cx = Mathf.RoundToInt(local.x / cell);
            int cz = Mathf.RoundToInt(local.z / cell);
            int x0 = Mathf.Clamp(cx - r, 0, res - 1), z0 = Mathf.Clamp(cz - r, 0, res - 1);
            int x1 = Mathf.Clamp(cx + r, 0, res - 1), z1 = Mathf.Clamp(cz + r, 0, res - 1);
            int w = x1 - x0 + 1, h = z1 - z0 + 1;
            if (w <= 0 || h <= 0)
                return;

            float[,] heights = data.GetHeights(x0, z0, w, h);
            for (int j = 0; j < h; j++)
            {
                for (int i = 0; i < w; i++)
                {
                    float dx = (x0 + i) * cell - local.x;
                    float dz = (z0 + j) * cell - local.z;
                    float d = Mathf.Sqrt(dx * dx + dz * dz) / radius;
                    float delta;
                    if (d < 1f)
                    {
                        float t = 1f - d * d;
                        delta = -depth * t * t;
                    }
                    else if (d < 1.7f)
                    {
                        delta = depth * 0.22f * Mathf.Sin((d - 1f) / 0.7f * Mathf.PI);
                    }
                    else
                    {
                        continue;
                    }
                    heights[j, i] = Mathf.Clamp01(heights[j, i] + delta / size.y);
                }
            }
            data.SetHeights(x0, z0, heights);
        }
    }
}
