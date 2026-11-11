using CarIdle.Core;
using UnityEngine;

namespace CarIdle.Drive
{
    /// <summary>
    /// Effets de roue : traces au sol (gomme sur le bitume quand ça glisse, sillons dans la
    /// terre et le sable dès qu'on roule) et nuages de poussière, de sable ou d'éclaboussures.
    /// Les traces s'effacent avec le temps ; une trace s'arrête quand la roue décolle ou
    /// change de sol, et une nouvelle commence.
    /// </summary>
    [RequireComponent(typeof(CarController))]
    public class CarEffects : MonoBehaviour
    {
        public float MarkWidth = 0.38f;
        public float SlipForMarks = 0.35f;

        private CarController _car;
        private readonly TrailRenderer[] _trails = new TrailRenderer[4];
        private readonly Surface[] _trailSurface = new Surface[4];
        private ParticleSystem _dust;
        private Material _markMaterial;

        // Couleur des traces, par sol (alpha = force de la marque).
        private static readonly Color[] MarkColors =
        {
            new Color(0.05f, 0.05f, 0.05f, 0.55f), // bitume
            new Color(0.22f, 0.15f, 0.10f, 0.55f), // terre
            new Color(0.55f, 0.45f, 0.30f, 0.60f), // sable
            new Color(0.35f, 0.28f, 0.20f, 0.55f), // sable mouillé
            new Color(0.80f, 0.90f, 0.90f, 0.00f), // eau : pas de trace
        };

        // Poussière soulevée, par sol (alpha = densité).
        private static readonly Color[] DustColors =
        {
            new Color(0.75f, 0.75f, 0.75f, 0.35f), // fumée de pneus
            new Color(0.62f, 0.48f, 0.34f, 0.50f),
            new Color(0.95f, 0.80f, 0.60f, 0.42f),
            new Color(0.70f, 0.62f, 0.50f, 0.25f),
            new Color(0.92f, 0.97f, 1.00f, 0.70f), // éclaboussures
        };

        private static readonly float[] MarkLife = { 6f, 18f, 25f, 12f, 0f };

        private void Start()
        {
            _car = GetComponent<CarController>();
            _markMaterial = Materials.Fx(Materials.TrackTexture());
            BuildDust();
        }

        private void BuildDust()
        {
            var go = new GameObject("Poussiere");
            go.transform.SetParent(transform, false);
            _dust = go.AddComponent<ParticleSystem>();
            _dust.Stop(true, ParticleSystemStopBehavior.StopEmittingAndClear);

            var main = _dust.main;
            main.simulationSpace = ParticleSystemSimulationSpace.World;
            main.maxParticles = 2500;
            main.playOnAwake = false;
            main.gravityModifier = -0.03f;
            var emission = _dust.emission;
            emission.enabled = false;
            var shape = _dust.shape;
            shape.enabled = false;

            var size = _dust.sizeOverLifetime;
            size.enabled = true;
            size.size = new ParticleSystem.MinMaxCurve(1f, new AnimationCurve(new Keyframe(0f, 0.35f), new Keyframe(0.3f, 1f), new Keyframe(1f, 2.2f)));

            var color = _dust.colorOverLifetime;
            color.enabled = true;
            var fade = new Gradient();
            fade.SetKeys(
                new[] { new GradientColorKey(Color.white, 0f), new GradientColorKey(Color.white, 1f) },
                new[] { new GradientAlphaKey(0f, 0f), new GradientAlphaKey(1f, 0.1f), new GradientAlphaKey(0f, 1f) });
            color.color = fade;

            var limit = _dust.limitVelocityOverLifetime;
            limit.enabled = true;
            limit.drag = 1.5f;

            var r = go.GetComponent<ParticleSystemRenderer>();
            // Contre-jour : le nuage de sable s'illumine quand on filme face au soleil.
            r.material = Materials.Fx(Materials.SoftDot(), 1.6f);
            r.renderMode = ParticleSystemRenderMode.Billboard;
            r.sortingFudge = 10f;
            _dust.Play();
        }

        private void Update()
        {
            if (_car == null)
                return;
            float speed = _car.SpeedKmh;
            for (int i = 0; i < 4; i++)
            {
                UpdateMark(i, speed);
                EmitDust(i, speed);
            }
        }

        private void UpdateMark(int i, float speed)
        {
            bool grounded = _car.Grounded[i];
            Surface s = _car.WheelSurface[i];
            bool soft = WorldLayout.IsSoft(s);
            bool marking = grounded && s != Surface.Water && speed > 2f
                && (soft || _car.WheelSlip[i] > SlipForMarks);

            if (_trails[i] != null && (!marking || _trailSurface[i] != s))
                Release(i);
            if (!marking)
                return;
            if (_trails[i] == null)
                _trails[i] = NewTrail(s);
            _trailSurface[i] = s;

            var t = _trails[i].transform;
            Vector3 n = _car.ContactNormal[i];
            t.SetPositionAndRotation(_car.ContactPoint[i] + n * 0.04f, Quaternion.LookRotation(-n));
        }

        private TrailRenderer NewTrail(Surface s)
        {
            var go = new GameObject("Trace");
            var trail = go.AddComponent<TrailRenderer>();
            trail.sharedMaterial = _markMaterial;
            trail.alignment = LineAlignment.TransformZ;
            trail.time = MarkLife[(int)s];
            trail.minVertexDistance = 0.25f;
            trail.widthMultiplier = MarkWidth;
            trail.textureMode = LineTextureMode.Tile;
            trail.shadowCastingMode = UnityEngine.Rendering.ShadowCastingMode.Off;
            trail.receiveShadows = false;
            trail.numCapVertices = 0;
            var c = MarkColors[(int)s];
            var g = new Gradient();
            g.SetKeys(
                new[] { new GradientColorKey(c, 0f), new GradientColorKey(c, 1f) },
                new[] { new GradientAlphaKey(c.a, 0f), new GradientAlphaKey(c.a, 0.7f), new GradientAlphaKey(0f, 1f) });
            trail.colorGradient = g;
            return trail;
        }

        /// <summary>La trace en cours reste au sol, s'efface, puis se détruit seule.</summary>
        private void Release(int i)
        {
            _trails[i].emitting = false;
            _trails[i].autodestruct = true;
            _trails[i] = null;
        }

        private void EmitDust(int i, float speed)
        {
            if (!_car.Grounded[i])
                return;
            Surface s = _car.WheelSurface[i];
            float slip = _car.WheelSlip[i];
            // Sur le bitume : seulement de la fumée quand les pneus glissent.
            float amount = s == Surface.Asphalt
                ? Mathf.Clamp01((slip - 0.5f) * 1.5f) * Mathf.Clamp01(speed / 30f)
                : Mathf.Clamp01(speed / 70f) * (i >= 2 ? 1f : 0.5f) + Mathf.Clamp01(slip - 0.3f);
            if (s == Surface.WetSand)
                amount *= 0.4f;
            if (amount <= 0.01f)
                return;

            // Nombre de particules par image, avec un tirage pour les fractions.
            // En dérapage sur le sable, un vrai panache.
            float drift = Mathf.Clamp01((Mathf.Abs(_car.SlipAngle) - 8f) / 25f);
            amount += drift * (s == Surface.Asphalt ? 0.6f : 1.5f) * (i >= 2 ? 1f : 0.3f);
            float rate = amount * 55f * Time.deltaTime;
            int count = Mathf.FloorToInt(rate) + (Random.value < rate % 1f ? 1 : 0);
            var c = DustColors[(int)s];
            var p = new ParticleSystem.EmitParams();
            for (int k = 0; k < count; k++)
            {
                Vector3 back = -transform.forward * Random.Range(0.5f, 2.5f) * Mathf.Clamp01(speed / 40f);
                p.position = _car.ContactPoint[i] + Vector3.up * 0.2f + Random.insideUnitSphere * 0.2f;
                p.velocity = back + Vector3.up * Random.Range(0.6f, s == Surface.Water ? 4f : 1.6f) + Random.insideUnitSphere * 0.6f;
                p.startColor = new Color(c.r, c.g, c.b, c.a * Random.Range(0.6f, 1f));
                p.startSize = Random.Range(1.0f, 2.0f) * (s == Surface.Sand ? 1.6f : 1f) * (1f + drift * 0.6f);
                p.startLifetime = Random.Range(1.6f, 3.4f) * (s == Surface.Water ? 0.45f : 1f);
                _dust.Emit(p, 1);
            }
        }

        /// <summary>Gerbe de sable à la réception d'un saut, projetée tout autour de la roue.</summary>
        public void Burst(Vector3 point, Surface s, float strength)
        {
            if (_dust == null)
                return;
            var c = DustColors[(int)s];
            int count = Mathf.RoundToInt(28f * strength);
            var p = new ParticleSystem.EmitParams();
            for (int k = 0; k < count; k++)
            {
                Vector2 dir = Random.insideUnitCircle.normalized * Random.Range(1.5f, 5f) * strength;
                p.position = point + Vector3.up * 0.15f;
                p.velocity = new Vector3(dir.x, Random.Range(1.5f, 4.5f) * strength, dir.y);
                p.startColor = new Color(c.r, c.g, c.b, Mathf.Min(1f, c.a * 1.4f) * Random.Range(0.7f, 1f));
                p.startSize = Random.Range(0.8f, 2.2f) * (0.8f + strength * 0.5f);
                p.startLifetime = Random.Range(1.2f, 2.8f);
                _dust.Emit(p, 1);
            }
        }

        private void OnDestroy()
        {
            for (int i = 0; i < 4; i++)
            {
                if (_trails[i] != null)
                    Release(i);
            }
        }
    }
}
