using UnityEngine;

namespace ScooterGame
{
    /// <summary>Map 1: long straight road with ramps, shoulders, guardrails and daylight.</summary>
    public static class TrackMap
    {
        const float RoadWidth = 12f;
        const float RoadLength = 520f;
        const float ShoulderWidth = 5f;

        public static void Build(WorldContext context)
        {
            Transform root = context.Root;

            // ---- ground ----
            GameObject grass = MeshUtil.SolidBox(root, "Grass", new Vector3(0f, -0.6f, RoadLength * 0.5f),
                new Vector3(420f, 1.2f, RoadLength + 240f),
                MaterialLibrary.Tiled(MaterialLibrary.Grass, "grass_field", 42f, 76f));
            grass.AddComponent<SurfaceMarker>().Configure(0.45f);

            // ---- road ----
            GameObject road = MeshUtil.SolidBox(root, "Road", new Vector3(0f, -0.5f, RoadLength * 0.5f),
                new Vector3(RoadWidth, 1f, RoadLength),
                MaterialLibrary.Tiled(MaterialLibrary.Asphalt, "asphalt_road", 3f, 90f));
            road.AddComponent<SurfaceMarker>().Configure(0f);

            // shoulders
            float shoulderX = RoadWidth * 0.5f + ShoulderWidth * 0.5f;
            GameObject shoulderR = MeshUtil.SolidBox(root, "ShoulderR", new Vector3(shoulderX, -0.52f, RoadLength * 0.5f),
                new Vector3(ShoulderWidth, 1f, RoadLength),
                MaterialLibrary.Tiled(MaterialLibrary.Dirt, "dirt_shoulder", 2f, 100f));
            shoulderR.AddComponent<SurfaceMarker>().Configure(0.85f);
            GameObject shoulderL = MeshUtil.SolidBox(root, "ShoulderL", new Vector3(-shoulderX, -0.52f, RoadLength * 0.5f),
                new Vector3(ShoulderWidth, 1f, RoadLength),
                MaterialLibrary.Tiled(MaterialLibrary.Dirt, "dirt_shoulder", 2f, 100f));
            shoulderL.AddComponent<SurfaceMarker>().Configure(0.85f);

            // ---- markings ----
            Material paint = MaterialLibrary.RoadPaint;
            Transform markings = MeshUtil.Empty(root, "Markings", Vector3.zero).transform;
            for (float z = 6f; z < RoadLength; z += 12f)
            {
                MeshUtil.Box(markings, "Dash", new Vector3(0f, 0.012f, z), new Vector3(0.18f, 0.02f, 5f), paint);
            }
            MeshUtil.Box(markings, "LineR", new Vector3(RoadWidth * 0.5f - 0.35f, 0.012f, RoadLength * 0.5f),
                new Vector3(0.16f, 0.02f, RoadLength), paint);
            MeshUtil.Box(markings, "LineL", new Vector3(-RoadWidth * 0.5f + 0.35f, 0.012f, RoadLength * 0.5f),
                new Vector3(0.16f, 0.02f, RoadLength), paint);

            // ---- guardrails ----
            Transform rails = MeshUtil.Empty(root, "Guardrails", Vector3.zero).transform;
            Material railMat = MaterialLibrary.Guardrail;
            Material postMat = MaterialLibrary.Steel;
            for (int side = -1; side <= 1; side += 2)
            {
                if (side == 0) continue;
                float x = side * (RoadWidth * 0.5f + ShoulderWidth + 0.35f);
                MeshUtil.SolidBox(rails, "Rail", new Vector3(x, 0.62f, RoadLength * 0.5f),
                    new Vector3(0.1f, 0.3f, RoadLength), railMat);
                for (float z = 0f; z <= RoadLength; z += 10f)
                {
                    MeshUtil.SolidBox(rails, "Post", new Vector3(x, 0.4f, z), new Vector3(0.1f, 0.8f, 0.1f), postMat);
                }
            }

            // ---- ramps ----
            Material rampMat = MaterialLibrary.Get("ramp", new Color(0.55f, 0.42f, 0.2f), 0f, 0.2f);
            Material rampStripe = MaterialLibrary.Hazard;
            float[][] ramps =
            {
                new float[] { -2.2f, 80f, 1.4f, 12f },
                new float[] { 2.4f, 165f, 1.8f, 14f },
                new float[] { 0f, 255f, 1.2f, 10f },
                new float[] { -2.6f, 340f, 2.0f, 15f },
                new float[] { 2.2f, 430f, 1.5f, 12f }
            };

            for (int i = 0; i < ramps.Length; i++)
            {
                float x = ramps[i][0];
                float z = ramps[i][1];
                float height = ramps[i][2];
                float length = ramps[i][3];

                GameObject ramp = MeshUtil.Ramp(root, "Ramp" + i, new Vector3(x, 0f, z), 6.5f, length, height, rampMat);
                ramp.AddComponent<SurfaceMarker>().Configure(0.15f);

                // hazard stripe at the lip so the ramp reads clearly
                MeshUtil.Box(root, "RampLip" + i, new Vector3(x, height - 0.03f, z + length - 0.15f),
                    new Vector3(6.5f, 0.08f, 0.3f), rampStripe);
                MeshUtil.Box(root, "RampBase" + i, new Vector3(x, 0.02f, z - 0.05f),
                    new Vector3(6.5f, 0.04f, 0.12f), rampStripe);
            }

            // ---- props ----
            Transform props = MeshUtil.Empty(root, "Props", Vector3.zero).transform;

            // cones near the ramps
            Material coneMat = MaterialLibrary.ConeMaterial;
            Material coneStripe = MaterialLibrary.RoadPaint;
            for (int i = 0; i < ramps.Length; i++)
            {
                float x = ramps[i][0];
                float z = ramps[i][1];
                for (int side = -1; side <= 1; side += 2)
                {
                    Vector3 p = new Vector3(x + side * 4.2f, 0.25f, z + 1.5f);
                    MeshUtil.SolidCylinder(props, "Cone", p, 0.11f, 0.5f, coneMat);
                    MeshUtil.SolidCylinder(props, "ConeStripe", p + Vector3.up * 0.08f, 0.115f, 0.08f, coneStripe);
                }
            }

            // roadside barriers
            Material barrierMat = MaterialLibrary.Barrier;
            for (float z = 40f; z < RodLengthSafe(); z += 60f)
            {
                for (int side = -1; side <= 1; side += 2)
                {
                    Vector3 p = new Vector3(side * (RoadWidth * 0.5f + ShoulderWidth * 0.5f), 0.35f, z + 20f);
                    MeshUtil.SolidBox(props, "Barrier", p, new Vector3(1.6f, 0.7f, 0.35f), barrierMat,
                        Quaternion.Euler(0f, 18f * side, 0f));
                }
            }

            // start arch
            BuildStartArch(root);

            // ---- checkpoints ----
            BuildCheckpoints(context);

            context.SpawnPosition = new Vector3(0f, 0.25f, 4f);
            context.SpawnRotation = Quaternion.LookRotation(Vector3.forward);
        }

        static float RodLengthSafe()
        {
            return RoadLength - 20f;
        }

        static void BuildStartArch(Transform root)
        {
            Material post = MaterialLibrary.Get("start_post", new Color(0.14f, 0.15f, 0.17f), 0.5f, 0.4f);
            Material banner = MaterialLibrary.Emissive("start_banner", new Color(1f, 0.5f, 0.1f), 1.6f);

            MeshUtil.SolidBox(root, "StartPostL", new Vector3(-5.7f, 2.4f, 1f), new Vector3(0.3f, 4.8f, 0.3f), post);
            MeshUtil.SolidBox(root, "StartPostR", new Vector3(5.7f, 2.4f, 1f), new Vector3(0.3f, 4.8f, 0.3f), post);
            MeshUtil.Box(root, "StartBanner", new Vector3(0f, 4.85f, 1f), new Vector3(11.7f, 0.75f, 0.3f), banner);
        }

        static void BuildCheckpoints(WorldContext context)
        {
            Color[] colors =
            {
                UiFactory.Hex("#3FA9F5"),
                UiFactory.Hex("#3FA9F5"),
                UiFactory.Hex("#3FA9F5"),
                UiFactory.Hex("#3FA9F5"),
                UiFactory.Hex("#8FE0A8")
            };

            float[] positions = { 100f, 200f, 300f, 400f, 500f };
            for (int i = 0; i < positions.Length; i++)
            {
                bool last = i == positions.Length - 1;
                Checkpoint checkpoint = Checkpoint.Create(context.Root, new Vector3(0f, 0f, positions[i]), 0f, i, last, colors[i]);
                context.Checkpoints.Add(checkpoint);
            }
        }
    }
}
