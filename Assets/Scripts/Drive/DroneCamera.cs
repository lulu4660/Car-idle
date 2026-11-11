using CarIdle.Core;
using UnityEngine;

namespace CarIdle.Drive
{
    /// <summary>
    /// Caméra « drone » : suit la voiture de haut et de trois quarts arrière, avec retard et
    /// douceur ; elle prend du recul avec la vitesse, suit la direction réelle de la voiture
    /// (on voit venir le virage pendant un dérapage) et ne passe jamais sous le sol.
    /// </summary>
    public class DroneCamera : MonoBehaviour
    {
        public CarController Target;
        public float Distance = 10f;
        public float DistanceAtSpeed = 15f;
        public float Height = 6f;
        public float HeightAtSpeed = 8f;
        public float SpeedForMax = 140f;
        public float FollowTime = 0.25f;
        public float YawSharpness = 2.5f;

        private Vector3 _velocity;
        private float _yaw;
        private bool _placed;

        private void LateUpdate()
        {
            if (Target == null)
                return;
            var t = Target.transform;
            Vector3 carVel = Target.GetComponent<Rigidbody>() is Rigidbody rb ? Physics2.GetVelocity(rb) : Vector3.zero;

            // Cap suivi : celui de la voiture, tiré vers sa direction de déplacement quand elle va vite.
            Vector3 heading = Vector3.ProjectOnPlane(t.forward, Vector3.up);
            Vector3 flatVel = Vector3.ProjectOnPlane(carVel, Vector3.up);
            if (flatVel.magnitude > 4f && Target.ForwardSpeed > 0f)
                heading = Vector3.Slerp(heading.normalized, flatVel.normalized, 0.5f);
            float targetYaw = Mathf.Atan2(heading.x, heading.z) * Mathf.Rad2Deg;

            float k = Mathf.Clamp01(Target.SpeedKmh / SpeedForMax);
            float dist = Mathf.Lerp(Distance, DistanceAtSpeed, k);
            float height = Mathf.Lerp(Height, HeightAtSpeed, k);

            if (!_placed)
            {
                _yaw = targetYaw;
                _placed = true;
                transform.position = Desired(t.position, dist, height);
            }
            _yaw = Mathf.LerpAngle(_yaw, targetYaw, 1f - Mathf.Exp(-YawSharpness * Time.deltaTime));

            Vector3 desired = Desired(t.position, dist, height);
            Vector3 pos = Vector3.SmoothDamp(transform.position, desired, ref _velocity, FollowTime);
            // Jamais sous le relief (dunes) ni sous l'eau.
            float floor = Mathf.Max(WorldLayout.Height(pos.x, pos.z), WorldLayout.SeaLevel) + 2f;
            if (pos.y < floor)
                pos.y = floor;
            transform.position = pos;

            // On vise un peu devant la voiture, dans le sens où elle va.
            Vector3 look = t.position + Vector3.up * 1f + flatVel * 0.15f;
            transform.rotation = Quaternion.Slerp(transform.rotation, Quaternion.LookRotation(look - pos), 1f - Mathf.Exp(-10f * Time.deltaTime));
        }

        private Vector3 Desired(Vector3 carPos, float dist, float height)
        {
            Quaternion yaw = Quaternion.Euler(0f, _yaw, 0f);
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
