using UnityEngine;

namespace CarIdle.Drive
{
    /// <summary>
    /// Fabrique une voiture jouable à partir d'un modèle du Car Kit de Kenney (CC0), rangé dans
    /// Resources/CarKit : remet le modèle dans le bon sens (avant vers +Z) d'après la position
    /// des roues, l'agrandit à la taille d'une vraie voiture, puis ajoute le corps physique
    /// (Rigidbody, boîte de collision) et les quatre WheelCollider.
    /// Les noms des nœuds attendus sont ceux du kit : body, wheel-front-left, wheel-front-right,
    /// wheel-back-left, wheel-back-right (la roue de secours « wheel-back » du SUV reste décor).
    /// </summary>
    public static class VehicleFactory
    {
        public static readonly string[] Models = { "hatchback-sports", "sedan", "suv", "police", "taxi", "van" };

        /// <summary>Transmission de chaque modèle : propulsion pour les sportives, 4x4 pour le SUV, traction pour les utilitaires.</summary>
        public static Drivetrain DrivetrainOf(string model)
        {
            switch (model)
            {
                case "suv": return Drivetrain.AllWheel;
                case "taxi":
                case "van": return Drivetrain.FrontWheel;
                default: return Drivetrain.RearWheel;
            }
        }

        private static readonly string[] WheelNames =
        {
            "wheel-front-left", "wheel-front-right", "wheel-back-left", "wheel-back-right",
        };

        private const float CarLength = 4.4f;
        private const float Mass = 1400f;
        private const float SuspensionDistance = 0.28f;

        private static Material _paint;

        public static CarController Create(string model, Vector3 position, float yaw, DriveInput input)
        {
            var prefab = Resources.Load<GameObject>("CarKit/" + model);
            if (prefab == null)
            {
                Debug.LogError("Modèle introuvable : Resources/CarKit/" + model);
                return null;
            }

            var root = new GameObject("Voiture (" + model + ")");
            var visual = Object.Instantiate(prefab);
            visual.name = "Modele";
            visual.transform.SetPositionAndRotation(Vector3.zero, Quaternion.identity);

            var wheels = new Transform[4];
            for (int i = 0; i < 4; i++)
            {
                wheels[i] = FindDeep(visual.transform, WheelNames[i]);
                if (wheels[i] == null)
                {
                    Debug.LogError("Roue « " + WheelNames[i] + " » introuvable dans " + model);
                    Object.Destroy(root);
                    Object.Destroy(visual);
                    return null;
                }
            }

            // 1. Sens : l'avant de la voiture est du côté des roues avant.
            Vector3 front = (Center(wheels[0]) + Center(wheels[1])) / 2f;
            Vector3 back = (Center(wheels[2]) + Center(wheels[3])) / 2f;
            Vector3 forward = Vector3.ProjectOnPlane(front - back, Vector3.up);
            float angle = Vector3.SignedAngle(forward, Vector3.forward, Vector3.up);
            visual.transform.RotateAround(Vector3.zero, Vector3.up, angle);

            // 2. Taille : longueur réelle d'une voiture.
            Bounds b = BoundsOf(visual);
            float scale = CarLength / Mathf.Max(0.01f, b.size.z);
            visual.transform.localScale *= scale;
            visual.transform.position *= scale;

            // 3. Position : centré sur l'origine, le bas des roues à y = 0.
            b = BoundsOf(visual);
            visual.transform.position -= new Vector3(b.center.x, b.min.y, b.center.z);
            b = BoundsOf(visual);

            // Si le modèle est en miroir, la roue « gauche » est à droite : on échange.
            if (Center(wheels[0]).x > Center(wheels[1]).x)
            {
                (wheels[0], wheels[1]) = (wheels[1], wheels[0]);
                (wheels[2], wheels[3]) = (wheels[3], wheels[2]);
            }

            visual.transform.SetParent(root.transform, false);
            Paint(visual);

            // Corps physique.
            var rb = root.AddComponent<Rigidbody>();
            rb.mass = Mass;
            rb.interpolation = RigidbodyInterpolation.Interpolate;
            rb.collisionDetectionMode = CollisionDetectionMode.ContinuousDynamic;

            float wheelRadius = 0f;
            for (int i = 0; i < 4; i++)
                wheelRadius += WheelBounds(wheels[i]).extents.y / 4f;
            float axleY = wheelRadius;

            // Boîte de collision : la carrosserie, sans le bas des roues (les WheelCollider s'en chargent).
            var box = root.AddComponent<BoxCollider>();
            float bottom = axleY + 0.05f;
            box.center = new Vector3(b.center.x, (bottom + b.max.y) / 2f, b.center.z);
            box.size = new Vector3(b.size.x * 0.92f, b.max.y - bottom, b.size.z * 0.96f);
            box.sharedMaterial = BodyMaterial.Create();

            // Centre de gravité bas : la voiture se renverse moins dans les virages.
            rb.centerOfMass = new Vector3(0f, axleY * 0.9f, 0.1f);

            // Roues : un pivot par roue pour l'affichage, un WheelCollider au-dessus.
            var colliders = new WheelCollider[4];
            var pivots = new Transform[4];
            for (int i = 0; i < 4; i++)
            {
                Vector3 c = Center(wheels[i]);
                var pivot = new GameObject("Roue " + WheelNames[i]).transform;
                pivot.SetParent(root.transform, false);
                pivot.localPosition = c;
                wheels[i].SetParent(pivot, true);
                pivots[i] = pivot;

                var wcGo = new GameObject("Collider " + WheelNames[i]);
                wcGo.transform.SetParent(root.transform, false);
                // Au repos, la suspension est à mi-course : la roue tombe juste sous le modèle.
                wcGo.transform.localPosition = c + Vector3.up * SuspensionDistance * 0.5f;
                var wc = wcGo.AddComponent<WheelCollider>();
                wc.radius = wheelRadius;
                wc.mass = 25f;
                wc.wheelDampingRate = 0.6f;
                wc.suspensionDistance = SuspensionDistance;
                wc.forceAppPointDistance = 0.15f;
                wc.suspensionSpring = new JointSpring { spring = 38000f, damper = 4200f, targetPosition = 0.5f };
                wc.forwardFriction = Friction(0.35f, 1f, 0.8f, 0.75f);
                wc.sidewaysFriction = Friction(0.22f, 1f, 0.55f, 0.7f);
                colliders[i] = wc;
            }
            // Plus de calculs par pas de physique à basse vitesse : roues plus stables.
            colliders[0].ConfigureVehicleSubsteps(5f, 12, 15);

            var car = root.AddComponent<CarController>();
            car.Wheels = colliders;
            car.WheelVisuals = pivots;
            car.Controls = input;
            car.Drive = DrivetrainOf(model);
            if (model == "van" || model == "suv")
                car.Drift = 0.4f;
            root.AddComponent<CarEffects>();

            root.transform.SetPositionAndRotation(position, Quaternion.Euler(0f, yaw, 0f));
            return car;
        }

        private static WheelFrictionCurve Friction(float extremumSlip, float extremumValue, float asymptoteSlip, float asymptoteValue)
        {
            return new WheelFrictionCurve
            {
                extremumSlip = extremumSlip,
                extremumValue = extremumValue,
                asymptoteSlip = asymptoteSlip,
                asymptoteValue = asymptoteValue,
                stiffness = 1f,
            };
        }

        /// <summary>Un seul matériau éclairé avec la palette du kit (colormap.png).</summary>
        private static void Paint(GameObject model)
        {
            if (_paint == null)
            {
                var tex = Resources.Load<Texture2D>("CarKit/Textures/colormap");
                // Peinture vernie : reflète le ciel et le soleil couchant.
                _paint = Materials.Lit(Color.white, tex, 0.78f, 0.2f);
            }
            foreach (var r in model.GetComponentsInChildren<Renderer>())
            {
                var mats = new Material[r.sharedMaterials.Length];
                for (int i = 0; i < mats.Length; i++)
                    mats[i] = _paint;
                r.sharedMaterials = mats;
            }
        }

        private static Transform FindDeep(Transform t, string name)
        {
            if (t.name == name)
                return t;
            foreach (Transform child in t)
            {
                var found = FindDeep(child, name);
                if (found != null)
                    return found;
            }
            return null;
        }

        private static Bounds WheelBounds(Transform wheel)
        {
            var renderers = wheel.GetComponentsInChildren<Renderer>();
            if (renderers.Length == 0)
                return new Bounds(wheel.position, Vector3.one * 0.6f);
            var b = renderers[0].bounds;
            foreach (var r in renderers)
                b.Encapsulate(r.bounds);
            return b;
        }

        private static Vector3 Center(Transform wheel) => WheelBounds(wheel).center;

        private static Bounds BoundsOf(GameObject go)
        {
            var renderers = go.GetComponentsInChildren<Renderer>();
            var b = renderers.Length > 0 ? renderers[0].bounds : new Bounds(go.transform.position, Vector3.one);
            foreach (var r in renderers)
                b.Encapsulate(r.bounds);
            return b;
        }
    }

    /// <summary>Matériau physique de la carrosserie : glisse un peu sur les murs au lieu de s'y coller.</summary>
    internal static class BodyMaterial
    {
#if UNITY_6000_0_OR_NEWER
        public static PhysicsMaterial Create()
        {
            return new PhysicsMaterial("Carrosserie")
            {
                dynamicFriction = 0.25f,
                staticFriction = 0.3f,
                bounciness = 0.05f,
                frictionCombine = PhysicsMaterialCombine.Minimum,
            };
        }
#else
        public static PhysicMaterial Create()
        {
            return new PhysicMaterial("Carrosserie")
            {
                dynamicFriction = 0.25f,
                staticFriction = 0.3f,
                bounciness = 0.05f,
                frictionCombine = PhysicMaterialCombine.Minimum,
            };
        }
#endif
    }
}
