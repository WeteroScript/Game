using UnityEngine;

namespace ScooterGame
{
    /// <summary>Smooth third-person chase camera with a speed-based field of view.</summary>
    public class CameraRig : MonoBehaviour
    {
        public ScooterController Scooter;

        Camera _camera;
        Vector3 _velocity;
        float _yaw;

        public float Distance = 4.3f;
        public float Height = 1.65f;
        public float LookAhead = 1.6f;
        public float PositionSmoothTime = 0.11f;
        public float RotationSpeed = 7f;
        public float BaseFov = 60f;
        public float MaxFov = 74f;

        void Awake()
        {
            _camera = GetComponent<Camera>();
        }

        public void SetTarget(ScooterController scooter)
        {
            Scooter = scooter;
            if (scooter != null)
            {
                _yaw = scooter.transform.eulerAngles.y;
                SnapBehind();
            }
        }

        public void SnapBehind()
        {
            if (Scooter == null) return;
            Quaternion yawRotation = Quaternion.Euler(0f, _yaw, 0f);
            transform.position = Scooter.transform.position - yawRotation * Vector3.forward * Distance
                                 + Vector3.up * Height;
            Vector3 lookPoint = Scooter.transform.position + Vector3.up * 0.9f;
            transform.rotation = Quaternion.LookRotation(lookPoint - transform.position);
            _velocity = Vector3.zero;
        }

        void LateUpdate()
        {
            if (Scooter == null || Scooter.transform == null) return;
            float dt = Time.deltaTime;
            if (dt <= 0f) return;

            Transform target = Scooter.transform;

            // Smoothly follow the heading, but keep the camera stable while airborne or crashed.
            float targetYaw = target.eulerAngles.y;
            float yawLerp = Scooter.IsCrashed ? 1.5f : 3.2f;
            _yaw = Mathf.LerpAngle(_yaw, targetYaw, Mathf.Clamp01(dt * yawLerp));

            float speedFactor = Mathf.Clamp01(Scooter.SpeedKmh / 65f);
            float distance = Distance + speedFactor * 0.9f;

            Quaternion yawRotation = Quaternion.Euler(0f, _yaw, 0f);
            Vector3 desired = target.position
                              - yawRotation * Vector3.forward * distance
                              + Vector3.up * (Height + speedFactor * 0.25f);

            if (desired.y < 0.55f) desired.y = 0.55f;

            transform.position = Vector3.SmoothDamp(transform.position, desired, ref _velocity, PositionSmoothTime);

            Vector3 lookPoint = target.position
                                + Vector3.up * 0.85f
                                + target.forward * (LookAhead + speedFactor * 1.4f);
            Quaternion lookRotation = Quaternion.LookRotation(lookPoint - transform.position, Vector3.up);
            transform.rotation = Quaternion.Slerp(transform.rotation, lookRotation,
                Mathf.Clamp01(dt * RotationSpeed * (Scooter.IsCrashed ? 1.6f : 1f)));

            if (_camera != null)
            {
                float targetFov = Mathf.Lerp(BaseFov, MaxFov, speedFactor);
                _camera.fieldOfView = Mathf.Lerp(_camera.fieldOfView, targetFov, Mathf.Clamp01(dt * 3f));
            }
        }
    }
}
