using UnityEngine;

namespace ScooterGame
{
    /// <summary>Gate that registers progress, stores the respawn point and drives the Time Attack route.</summary>
    public class Checkpoint : MonoBehaviour
    {
        public int Index;
        public bool IsFinal;
        public Vector3 RespawnPosition;
        public Quaternion RespawnRotation = Quaternion.identity;
        public bool Reached { get; private set; }

        public static Checkpoint Create(Transform parent, Vector3 position, float yaw, int index, bool isFinal, Color color)
        {
            GameObject root = new GameObject("Checkpoint_" + index);
            root.transform.SetParent(parent, false);
            root.transform.position = position;
            root.transform.rotation = Quaternion.Euler(0f, yaw, 0f);

            Checkpoint checkpoint = root.AddComponent<Checkpoint>();
            checkpoint.Index = index;
            checkpoint.IsFinal = isFinal;
            checkpoint.RespawnPosition = position + Vector3.up * 0.25f + root.transform.forward * 1.5f;
            checkpoint.RespawnRotation = Quaternion.Euler(0f, yaw, 0f);

            Material post = MaterialLibrary.Get("cp_post_" + index, new Color(0.12f, 0.13f, 0.15f), 0.6f, 0.4f);
            Material glow = MaterialLibrary.Emissive("cp_glow_" + index, color, 2.4f);
            Material banner = MaterialLibrary.Get("cp_banner", new Color(0.08f, 0.09f, 0.11f), 0.2f, 0.3f);

            float half = 5.5f;
            MeshUtil.Box(root.transform, "PostL", new Vector3(-half, 2.1f, 0f), new Vector3(0.28f, 4.2f, 0.28f), post);
            MeshUtil.Box(root.transform, "PostR", new Vector3(half, 2.1f, 0f), new Vector3(0.28f, 4.2f, 0.28f), post);
            MeshUtil.Box(root.transform, "Banner", new Vector3(0f, 4.35f, 0f), new Vector3(half * 2f + 0.3f, 0.7f, 0.3f), banner);
            MeshUtil.Box(root.transform, "GlowLine", new Vector3(0f, 3.95f, 0.17f), new Vector3(half * 2f, 0.08f, 0.03f), glow);
            MeshUtil.Box(root.transform, "PostGlowL", new Vector3(-half, 3.8f, 0f), new Vector3(0.3f, 0.1f, 0.3f), glow);
            MeshUtil.Box(root.transform, "PostGlowR", new Vector3(half, 3.8f, 0f), new Vector3(0.3f, 0.1f, 0.3f), glow);

            BoxCollider trigger = root.AddComponent<BoxCollider>();
            trigger.isTrigger = true;
            trigger.center = new Vector3(0f, 2.2f, 0f);
            trigger.size = new Vector3(half * 2f, 4.4f, 2.6f);

            return checkpoint;
        }

        void OnTriggerEnter(Collider other)
        {
            if (Reached) return;
            ScooterController scooter = other.GetComponentInParent<ScooterController>();
            if (scooter == null) return;

            if (GameRoot.Instance == null) return;

            // The session decides whether the gate counts (Time Attack requires the order),
            // otherwise driving through a later gate first would lock out the route.
            if (GameRoot.Instance.OnCheckpointReached(this, scooter))
            {
                Reached = true;
            }
        }

        public void ResetProgress()
        {
            Reached = false;
        }
    }
}
