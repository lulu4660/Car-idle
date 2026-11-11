using CarIdle.Core;
using UnityEngine;

namespace CarIdle.Drive
{
    /// <summary>
    /// Caméra « drone », comme une vidéo filmée au-dessus des dunes. Trois plans (V ou bouton
    /// CAMÉRA) : poursuite haute de trois quarts arrière, travelling latéral qui longe la voiture,
    /// et vue plongeante de haut. Mouvements amortis, léger balancement de drone, recul avec la
    /// vitesse ; elle suit la direction réelle de la voiture (on voit venir le virage pendant un
    /// dérapage) et ne passe jamais sous le sol.
    /// </summary>
    public class DroneCamera : MonoBehaviour
    {
        public enum Mode
        {
            Chase,
            Side,
            Top,
        }

        [System.Serializable]
        public struct Shot
        {
            public float Distance, DistanceAtSpeed, Height, HeightAtSpeed, SideAngle, FieldOfView;
        }

        public CarController Target;
        public Mode Current = Mode.Chase;
        public float SpeedForMax = 140f;
        public float FollowTime = 0.35f;
        public float YawSharpness = 2f;
        public float Sway = 0.35f;

        // Réglages de chaque plan : recul (m), hauteur (m), angle autour de la voiture (°), champ (°).
        public Shot Chase = new Shot { Distance = 11f, DistanceAtSpeed = 17f, Height = 6.5f, HeightAtSpeed = 9f, SideAngle = 18f, FieldOfView = 52f };
        public Shot Side = new Shot { Distance = 13f, DistanceAtSpeed = 16f, Height = 4f, HeightAtSpeed = 5f, SideAngle = 95f, FieldOfView = 45f };
        public Shot Top = new Shot { Distance = 6f, DistanceAtSpeed = 10f, Height = 26f, HeightAtSpeed = 32f, SideAngle = 25f, FieldOfView = 50f };

        private Vector3 _velocity;
        private float _yaw;
        private bool _placed;
        private Camera _cam;
        private Rigidbody _targetBody;

        private void Awake()
        {
            _cam = GetComponent<Camera>();
        }

        public void NextMode()
        {
            Current = (Mode)(((int)Current + 1) % 3);
        }

        private void LateUpdate()
        {
            if (Target == null)
                return;
            if (_targetBody == null || _targetBody.gameObject != Target.gameObject)
                _targetBody = Target.GetComponent<Rigidbody>();
            var t = Target.transform;
            Vector3 carVel = _targetBody != null ? Physics2.GetVelocity(_targetBody) : Vector3.zero;
            Shot shot = Current == Mode.Chase ? Chase : Current == Mode.Side ? Side : Top;

            // Cap suivi : celui de la voiture, tiré vers sa direction de déplacement quand elle va vite.
            Vector3 heading = Vector3.ProjectOnPlane(t.forward, Vector3.up).normalized;
            Vector3 flatVel = Vector3.ProjectOnPlane(carVel, Vector3.up);
            if (flatVel.magnitude > 4f && Target.ForwardSpeed > 0f)
                heading = Vector3.Slerp(heading, flatVel.normalized, 0.6f);
            float targetYaw = Mathf.Atan2(heading.x, heading.z) * Mathf.Rad2Deg;

            float k = Mathf.Clamp01(Target.SpeedKmh / SpeedForMax);
            float dist = Mathf.Lerp(shot.Distance, shot.DistanceAtSpeed, k);
            float height = Mathf.Lerp(shot.Height, shot.HeightAtSpeed, k);

            if (!_placed)
            {
                _yaw = targetYaw;
                _placed = true;
                transform.position = Desired(t.position, dist, height, shot.SideAngle);
                _velocity = Vector3.zero;
            }
            _yaw = Mathf.LerpAngle(_yaw, targetYaw, 1f - Mathf.Exp(-YawSharpness * Time.deltaTime));

            Vector3 desired = Desired(t.position, dist, height, shot.SideAngle);
            // Balancement lent de drone (vent).
            float time = Time.time;
            desired += new Vector3(Mathf.Sin(time * 0.37f), Mathf.Sin(time * 0.53f + 1f) * 0.6f, Mathf.Sin(time * 0.29f + 2f)) * Sway;
            Vector3 pos = Vector3.SmoothDamp(transform.position, desired, ref _velocity, FollowTime);
            // Jamais sous le relief (dunes) ni sous l'eau.
            float floor = Mathf.Max(WorldLayout.Height(pos.x, pos.z), WorldLayout.SeaLevel) + 2.5f;
            if (pos.y < floor)
                pos.y = floor;
            transform.position = pos;

            // On vise un peu devant la voiture, dans le sens où elle va.
            Vector3 look = t.position + Vector3.up * 0.8f + flatVel * (Current == Mode.Top ? 0.25f : 0.18f);
            var rot = Quaternion.LookRotation(look - pos);
            transform.rotation = Quaternion.Slerp(transform.rotation, rot, 1f - Mathf.Exp(-8f * Time.deltaTime));

            if (_cam != null)
                _cam.fieldOfView = Mathf.Lerp(_cam.fieldOfView, shot.FieldOfView + k * 6f, 1f - Mathf.Exp(-3f * Time.deltaTime));
        }

        private Vector3 Desired(Vector3 carPos, float dist, float height, float sideAngle)
        {
            Quaternion yaw = Quaternion.Euler(0f, _yaw + sideAngle, 0f);
            return carPos + yaw * new Vector3(0f, height, -dist);
        }

        /// <summary>À appeler quand la voiture est téléportée : la caméra se replace aussitôt.</summary>
        public void Snap()
        {
            _placed = false;
            _velocity = Vector3.zero;
        }
    }
}
