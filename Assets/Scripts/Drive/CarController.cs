using CarIdle.Core;
using UnityEngine;

namespace CarIdle.Drive
{
    /// <summary>
    /// Conduite arcade sur les WheelCollider de Unity : 4 roues motrices, propulsion ou traction, braquage qui se
    /// réduit avec la vitesse, adhérence selon le sol (bitume, terre, sable, eau), frein à
    /// main et gaz qui font déraper l'arrière, contre-braquage automatique, aides discrètes (barres antiroulis, appui, stabilité)
    /// et retour sur la route quand la voiture est sur le toit ou à la mer.
    /// Ordre des roues : avant gauche, avant droite, arrière gauche, arrière droite.
    /// </summary>
    /// <summary>Roues motrices : 4 roues, propulsion (arrière) ou traction (avant).</summary>
    public enum Drivetrain
    {
        AllWheel,
        RearWheel,
        FrontWheel,
    }

    [RequireComponent(typeof(Rigidbody))]
    public class CarController : MonoBehaviour
    {
        [Header("Transmission")]
        public Drivetrain Drive = Drivetrain.AllWheel;
        /// <summary>Part du couple envoyée à l'arrière en 4 roues motrices (sportive : plus d'arrière).</summary>
        [Range(0f, 1f)] public float AwdRearShare = 0.65f;

        [Header("Moteur et freins")]
        public float MotorTorque = 900f;
        public float BrakeTorque = 2600f;
        public float HandbrakeTorque = 1800f;
        public float TopSpeedKmh = 150f;
        public float ReverseSpeedKmh = 35f;

        [Header("Direction")]
        public float MaxSteerAngle = 34f;
        public float MinSteerAngle = 9f;
        public float SteerFadeSpeedKmh = 120f;

        [Header("Aides")]
        public float AntiRoll = 9000f;
        public float Downforce = 2.5f;
        /// <summary>Force qui gomme le glissement latéral hors dérapage (plus haut = plus collé).</summary>
        public float LateralGrip = 1.1f;
        public float DriftYawAssist = 1.6f;

        [Header("Dérapage")]
        /// <summary>0 = sage, 1 = très joueur : perte d'adhérence de l'arrière sous les gaz et au frein à main.</summary>
        [Range(0f, 1f)] public float Drift = 0.6f;
        /// <summary>Contre-braquage automatique (les roues avant suivent la glisse) : dérapages rattrapables au doigt.</summary>
        [Range(0f, 1f)] public float CounterSteer = 0.55f;
        /// <summary>Angle de glisse au-delà duquel la voiture est retenue pour ne pas partir en tête-à-queue.</summary>
        public float MaxDriftAngle = 55f;

        public WheelCollider[] Wheels = new WheelCollider[4];
        public Transform[] WheelVisuals = new Transform[4];
        public DriveInput Controls;

        // État lu par les effets et l'affichage.
        public float SpeedKmh { get; private set; }
        public float ForwardSpeed { get; private set; }
        public readonly bool[] Grounded = new bool[4];
        public readonly Surface[] WheelSurface = new Surface[4];
        public readonly float[] WheelSlip = new float[4];
        public readonly Vector3[] ContactPoint = new Vector3[4];
        public readonly Vector3[] ContactNormal = new Vector3[4];
        public bool InWater { get; private set; }
        /// <summary>Angle entre le nez de la voiture et sa trajectoire, en degrés (signe = côté).</summary>
        public float SlipAngle { get; private set; }

        private Rigidbody _rb;
        private Quaternion[] _visualOffset;
        private float _upsideDownTime;
        private Vector3 _safePosition;
        private float _safeYaw;
        private float _safeTimer;

        private void Awake()
        {
            _rb = GetComponent<Rigidbody>();
        }

        private void Start()
        {
            _visualOffset = new Quaternion[4];
            for (int i = 0; i < 4; i++)
            {
                if (WheelVisuals[i] != null)
                    _visualOffset[i] = Quaternion.Inverse(transform.rotation) * WheelVisuals[i].rotation;
            }
            _safePosition = transform.position;
            _safeYaw = transform.eulerAngles.y;
        }

        private void FixedUpdate()
        {
            Vector3 velocity = Physics2.GetVelocity(_rb);
            ForwardSpeed = Vector3.Dot(velocity, transform.forward);
            SpeedKmh = velocity.magnitude * 3.6f;
            float kmh = Mathf.Abs(ForwardSpeed) * 3.6f;

            float throttle = Controls != null ? Controls.Throttle : 0f;
            float brake = Controls != null ? Controls.Brake : 0f;
            float steer = Controls != null ? Controls.Steer : 0f;
            bool handbrake = Controls != null && Controls.Handbrake;

            // Le bouton frein freine en avançant, puis passe en marche arrière à l'arrêt.
            float drive = 0f, brakeInput = 0f;
            if (throttle > 0.01f)
            {
                if (ForwardSpeed < -1f) brakeInput = throttle;
                else drive = throttle;
            }
            if (brake > 0.01f)
            {
                if (ForwardSpeed > 1f) brakeInput = Mathf.Max(brakeInput, brake);
                else drive = -brake * 0.7f;
            }
            if (drive > 0f && kmh > TopSpeedKmh) drive = 0f;
            if (drive < 0f && kmh > ReverseSpeedKmh) drive = 0f;

            // Angle de glisse : la voiture va-t-elle là où pointe son nez ?
            Vector3 flatVel = Vector3.ProjectOnPlane(velocity, transform.up);
            SlipAngle = flatVel.magnitude > 3f && ForwardSpeed > 0f ? Vector3.SignedAngle(transform.forward, flatVel, transform.up) : 0f;
            float drifting = Mathf.Clamp01((Mathf.Abs(SlipAngle) - 6f) / 20f);

            // Braquage : réduit avec la vitesse, plus le contre-braquage automatique en glisse.
            float maxSteer = Mathf.Lerp(MaxSteerAngle, MinSteerAngle, kmh / SteerFadeSpeedKmh);
            float steerAngle = steer * Mathf.Lerp(maxSteer, MaxSteerAngle, drifting);
            steerAngle += SlipAngle * CounterSteer * drifting;
            steerAngle = Mathf.Clamp(steerAngle, -MaxSteerAngle - 10f, MaxSteerAngle + 10f);

            float rearShare = Drive == Drivetrain.RearWheel ? 1f : Drive == Drivetrain.FrontWheel ? 0f : AwdRearShare;
            // Sous les gaz, les roues arrière motrices décrochent (plus en propulsion).
            float powerOversteer = Drift * rearShare * drive * Mathf.Clamp01((kmh - 20f) / 30f);

            int groundedCount = 0;
            for (int i = 0; i < 4; i++)
            {
                var wc = Wheels[i];
                bool front = i < 2;
                if (front)
                    wc.steerAngle = steerAngle;

                Grounded[i] = wc.GetGroundHit(out WheelHit hit);
                float grip = 1f;
                if (Grounded[i])
                {
                    groundedCount++;
                    ContactPoint[i] = hit.point;
                    ContactNormal[i] = hit.normal;
                    // Le sol des immeubles et le bitume de la ville sont du bitume.
                    WheelSurface[i] = hit.collider is TerrainCollider
                        ? WorldLayout.SurfaceAt(hit.point.x, hit.point.z, hit.point.y)
                        : Surface.Asphalt;
                    grip = WorldLayout.Grip(WheelSurface[i]);
                    WheelSlip[i] = Mathf.Abs(hit.sidewaysSlip) + Mathf.Max(0f, Mathf.Abs(hit.forwardSlip) - 0.3f);
                }
                else
                {
                    WheelSlip[i] = 0f;
                }

                var fwd = wc.forwardFriction;
                fwd.stiffness = 1.3f * grip;
                wc.forwardFriction = fwd;
                var side = wc.sidewaysFriction;
                float rearLoss = 1f;
                if (!front)
                {
                    if (handbrake)
                        rearLoss = Mathf.Lerp(0.45f, 0.25f, Drift);
                    rearLoss *= 1f - 0.45f * powerOversteer;
                    // En glisse, l'arrière reste un peu glissant : le dérapage dure.
                    rearLoss *= 1f - 0.25f * Drift * drifting;
                }
                side.stiffness = 1.8f * grip * rearLoss;
                wc.sidewaysFriction = side;

                // Couple réparti selon la transmission ; sur sol mou, un peu moins de couple passe.
                float share = front ? 1f - rearShare : rearShare;
                wc.motorTorque = drive * MotorTorque * 2f * share * Mathf.Lerp(0.75f, 1f, grip);
                float b = brakeInput * BrakeTorque;
                if (!front && handbrake) b = Mathf.Max(b, HandbrakeTorque);
                wc.brakeTorque = b;
            }

            ApplyAntiRoll(0, 1);
            ApplyAntiRoll(2, 3);

            if (groundedCount > 0)
            {
                // Appui aérodynamique : la voiture colle au sol à haute vitesse.
                _rb.AddForce(-transform.up * Downforce * velocity.sqrMagnitude, ForceMode.Force);
                // Stabilité : on gomme une partie du glissement latéral, moins pendant un dérapage.
                float lateral = Vector3.Dot(velocity, transform.right);
                float assist = LateralGrip * (handbrake ? 0.1f : Mathf.Lerp(1f, 0.25f, drifting * Drift));
                _rb.AddForce(-transform.right * lateral * assist, ForceMode.Acceleration);
                // Dérapage : frein à main ou gaz en propulsion font pivoter la voiture.
                float kick = (handbrake ? 1f : 0f) + powerOversteer * 0.6f;
                if (kick > 0f && kmh > 15f)
                    _rb.AddTorque(transform.up * steer * DriftYawAssist * Mathf.Min(1f, kick), ForceMode.Acceleration);
                // Garde-fou : au-delà de l'angle maxi, on freine la rotation (pas de tête-à-queue involontaire).
                float over = Mathf.Abs(SlipAngle) - MaxDriftAngle;
                if (over > 0f)
                {
                    float yawRate = Vector3.Dot(_rb.angularVelocity, transform.up);
                    if (Mathf.Sign(yawRate) == -Mathf.Sign(SlipAngle))
                        _rb.AddTorque(-transform.up * yawRate * Mathf.Min(1f, over / 20f) * 6f, ForceMode.Acceleration);
                }
            }

            // Mer : la voiture freine fort dans l'eau.
            InWater = transform.position.y < WorldLayout.SeaLevel + 0.1f;
            Physics2.SetDrag(_rb, InWater ? 2.5f : 0.05f);
            Physics2.SetAngularDrag(_rb, InWater ? 3f : 0.5f);

            TrackSafePosition(groundedCount);
        }

        private void ApplyAntiRoll(int left, int right)
        {
            var wl = Wheels[left];
            var wr = Wheels[right];
            float travelL = 1f, travelR = 1f;
            bool gl = wl.GetGroundHit(out WheelHit hl);
            bool gr = wr.GetGroundHit(out WheelHit hr);
            if (gl)
                travelL = (-wl.transform.InverseTransformPoint(hl.point).y - wl.radius) / wl.suspensionDistance;
            if (gr)
                travelR = (-wr.transform.InverseTransformPoint(hr.point).y - wr.radius) / wr.suspensionDistance;
            float force = (travelL - travelR) * AntiRoll;
            if (gl)
                _rb.AddForceAtPosition(wl.transform.up * -force, wl.transform.position);
            if (gr)
                _rb.AddForceAtPosition(wr.transform.up * force, wr.transform.position);
        }

        private void TrackSafePosition(int groundedCount)
        {
            _safeTimer += Time.fixedDeltaTime;
            bool onLand = groundedCount >= 3 && !InWater && transform.up.y > 0.7f;
            if (onLand && _safeTimer > 1.5f)
            {
                _safeTimer = 0f;
                _safePosition = transform.position;
                _safeYaw = transform.eulerAngles.y;
            }
        }

        private void Update()
        {
            for (int i = 0; i < 4; i++)
            {
                if (WheelVisuals[i] == null)
                    continue;
                Wheels[i].GetWorldPose(out Vector3 pos, out Quaternion rot);
                WheelVisuals[i].SetPositionAndRotation(pos, rot * _visualOffset[i]);
            }

            // Sur le toit depuis 2 s, trop loin dans la mer, ou bouton « Replacer » : on revient au sec.
            _upsideDownTime = transform.up.y < 0.3f ? _upsideDownTime + Time.deltaTime : 0f;
            bool drowned = transform.position.y < WorldLayout.SeaLevel - 1.5f;
            bool requested = Controls != null && Controls.ResetRequested;
            if (_upsideDownTime > 2f || drowned || requested)
                Respawn(requested ? transform.position : _safePosition, requested ? transform.eulerAngles.y : _safeYaw);
        }

        public void Respawn(Vector3 position, float yaw)
        {
            float ground = WorldLayout.Height(position.x, position.z);
            Physics2.SetVelocity(_rb, Vector3.zero);
            _rb.angularVelocity = Vector3.zero;
            _rb.position = new Vector3(position.x, Mathf.Max(ground, WorldLayout.SeaLevel) + 1.5f, position.z);
            _rb.rotation = Quaternion.Euler(0f, yaw, 0f);
            transform.SetPositionAndRotation(_rb.position, _rb.rotation);
            _upsideDownTime = 0f;
        }
    }

    /// <summary>Unity 6 a renommé la vitesse et l'amortissement des Rigidbody : un seul endroit pour les deux versions.</summary>
    public static class Physics2
    {
        public static Vector3 GetVelocity(Rigidbody rb)
        {
#if UNITY_6000_0_OR_NEWER
            return rb.linearVelocity;
#else
            return rb.velocity;
#endif
        }

        public static void SetVelocity(Rigidbody rb, Vector3 v)
        {
#if UNITY_6000_0_OR_NEWER
            rb.linearVelocity = v;
#else
            rb.velocity = v;
#endif
        }

        public static void SetDrag(Rigidbody rb, float drag)
        {
#if UNITY_6000_0_OR_NEWER
            rb.linearDamping = drag;
#else
            rb.drag = drag;
#endif
        }

        public static void SetAngularDrag(Rigidbody rb, float drag)
        {
#if UNITY_6000_0_OR_NEWER
            rb.angularDamping = drag;
#else
            rb.angularDrag = drag;
#endif
        }
    }
}
