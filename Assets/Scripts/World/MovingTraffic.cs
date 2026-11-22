using UnityEngine;

namespace ScooterGame
{
    /// <summary>Simple ping-pong traffic car. The headlights are real spot lights, so the city gets moving light.</summary>
    public class MovingTraffic : MonoBehaviour
    {
        public Vector3 PointA;
        public Vector3 PointB;
        public float Speed = 9f;
        [Range(0f, 1f)] public float Phase = 0f;

        float _t;

        void Start()
        {
            _t = Mathf.Clamp01(Phase);
        }

        void Update()
        {
            float distance = Vector3.Distance(PointA, PointB);
            if (distance < 0.01f) return;

            _t += Time.deltaTime * Speed / distance;
            float pingPong = Mathf.PingPong(_t, 1f);
            Vector3 direction = (PointB - PointA).normalized;
            bool forward = _t % 2f < 1f;

            transform.position = Vector3.Lerp(PointA, PointB, pingPong);
            if (!forward) direction = -direction;
            if (direction.sqrMagnitude > 0.001f)
            {
                transform.rotation = Quaternion.LookRotation(direction, Vector3.up);
            }
        }
    }
}
