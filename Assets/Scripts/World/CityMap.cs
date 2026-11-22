using UnityEngine;

namespace ScooterGame
{
    /// <summary>
    /// Map 2: streets, houses, stairs, railings, a parking lot, a construction site and
    /// dynamic lighting (street lamps + moving traffic).
    /// </summary>
    public static class CityMap
    {
        const float RoadHalf = 7f;
        const float SidewalkHeight = 0.12f;
        const float CityHalf = 100f;

        public static void Build(WorldContext context)
        {
            Transform root = context.Root;

            BuildGround(root);
            BuildMarkings(root);
            BuildLeftBlock(root);
            BuildPlazaBlock(root);
            BuildEastBlock(root);
            BuildNorthBlock(root);
            BuildConstructionSite(root);
            BuildStreetLamps(root);
            BuildTraffic(root);
            BuildCheckpoints(context);

            context.SpawnPosition = new Vector3(0f, 0.25f, -30f);
            context.SpawnRotation = Quaternion.LookRotation(Vector3.forward);
        }

        // ------------------------------------------------------------------------
        static void BuildGround(Transform root)
        {
            GameObject ground = MeshUtil.SolidBox(root, "Asphalt", new Vector3(0f, -0.5f, 0f),
                new Vector3(CityHalf * 2f, 1f, CityHalf * 2f),
                MaterialLibrary.Tiled(MaterialLibrary.Asphalt, "asphalt_city", 20f, 20f));
            ground.AddComponent<SurfaceMarker>().Configure(0f);
        }

        static void BuildMarkings(Transform root)
        {
            Material paint = MaterialLibrary.RoadPaint;
            Transform markings = MeshUtil.Empty(root, "Markings", Vector3.zero).transform;

            // dashes along the two north-south streets
            for (float z = -CityHalf + 4f; z < CityHalf; z += 12f)
            {
                if (Mathf.Abs(z - 50f) < 8f || Mathf.Abs(z + 50f) < 8f) continue;
                MeshUtil.Box(markings, "DashZ0", new Vector3(0f, 0.012f, z), new Vector3(0.18f, 0.02f, 5f), paint);
                MeshUtil.Box(markings, "DashZ50", new Vector3(50f, 0.012f, z), new Vector3(0.18f, 0.02f, 5f), paint);
            }

            // dashes along the two east-west streets
            for (float x = -CityHalf + 4f; x < CityHalf; x += 12f)
            {
                if (Mathf.Abs(x) < 8f || Mathf.Abs(x - 50f) < 8f) continue;
                MeshUtil.Box(markings, "DashX50", new Vector3(x, 0.012f, 50f), new Vector3(5f, 0.02f, 0.18f), paint);
                MeshUtil.Box(markings, "DashX-50", new Vector3(x, 0.012f, -50f), new Vector3(5f, 0.02f, 0.18f), paint);
            }

            // crosswalks near the intersections
            for (int i = -1; i <= 1; i += 2)
            {
                Crosswalk(markings, new Vector3(0f, 0f, 50f * i));
                Crosswalk(markings, new Vector3(50f, 0f, 50f * i));
            }
        }

        static void Crosswalk(Transform parent, Vector3 center)
        {
            Material paint = MaterialLibrary.RoadPaint;
            for (int i = -3; i <= 3; i++)
            {
                MeshUtil.Box(parent, "Zebra", center + new Vector3(0f, 0.013f, i * 1.5f) + new Vector3(0f, 0f, 0f),
                    new Vector3(11f, 0.02f, 0.6f), paint);
            }
        }

        // ------------------------------------------------------------------------
        static void Sidewalk(Transform parent, Vector3 center, Vector2 size, Material material)
        {
            Material tiled = material == MaterialLibrary.Sidewalk
                ? MaterialLibrary.Tiled(MaterialLibrary.Sidewalk, "sidewalk_tile", Mathf.Max(2f, size.x / 6f), Mathf.Max(2f, size.y / 6f))
                : material;

            MeshUtil.SolidBox(parent, "Sidewalk", new Vector3(center.x, SidewalkHeight * 0.5f - 0.01f, center.z),
                new Vector3(size.x, SidewalkHeight, size.y), tiled);
        }

        static void Building(Transform parent, Vector3 basePosition, float width, float depth, float height, int seed)
        {
            Material body = MaterialLibrary.Building(seed);
            Material windows = MaterialLibrary.Window(seed);
            Material litWindow = MaterialLibrary.WindowLit;
            Material roof = MaterialLibrary.Concrete;

            MeshUtil.SolidBox(parent, "Building", basePosition + Vector3.up * (height * 0.5f),
                new Vector3(width, height, depth), body);

            int floors = Mathf.Clamp(Mathf.FloorToInt(height / 3.4f), 2, 7);
            for (int f = 1; f < floors; f++)
            {
                float y = basePosition.y + f * 3.2f;
                MeshUtil.Box(parent, "WinFront", new Vector3(basePosition.x, y, basePosition.z + depth * 0.5f + 0.03f),
                    new Vector3(width * 0.84f, 1.15f, 0.06f), (f + seed) % 5 == 0 ? litWindow : windows);
                MeshUtil.Box(parent, "WinBack", new Vector3(basePosition.x, y, basePosition.z - depth * 0.5f - 0.03f),
                    new Vector3(width * 0.84f, 1.15f, 0.06f), windows);
                MeshUtil.Box(parent, "WinRight", new Vector3(basePosition.x + width * 0.5f + 0.03f, y, basePosition.z),
                    new Vector3(0.06f, 1.15f, depth * 0.84f), windows);
                MeshUtil.Box(parent, "WinLeft", new Vector3(basePosition.x - width * 0.5f - 0.03f, y, basePosition.z),
                    new Vector3(0.06f, 1.15f, depth * 0.84f), windows);
            }

            MeshUtil.Box(parent, "Roof", basePosition + Vector3.up * (height + 0.18f),
                new Vector3(width * 1.05f, 0.36f, depth * 1.05f), roof);
            // entrance
            MeshUtil.Box(parent, "Door", new Vector3(basePosition.x, basePosition.y + 1.05f, basePosition.z + depth * 0.5f + 0.05f),
                new Vector3(2.2f, 2.1f, 0.1f), MaterialLibrary.Glass);
        }

        static void BuildLeftBlock(Transform root)
        {
            Transform block = MeshUtil.Empty(root, "BlockWest", Vector3.zero).transform;
            Sidewalk(block, new Vector3(-26f, 0f, 0f), new Vector2(34f, 86f), MaterialLibrary.Sidewalk);

            Building(block, new Vector3(-26f, SidewalkHeight, -25f), 22f, 22f, 16f, 1);
            Building(block, new Vector3(-26f, SidewalkHeight, 15f), 20f, 26f, 22f, 2);

            // low wall along the sidewalk
            Railing(block, new Vector3(-8.6f, SidewalkHeight, -40f), new Vector3(-8.6f, SidewalkHeight, 40f), 0.9f);
        }

        static void BuildPlazaBlock(Transform root)
        {
            Transform block = MeshUtil.Empty(root, "BlockPlaza", Vector3.zero).transform;
            Sidewalk(block, new Vector3(26f, 0f, 0f), new Vector2(34f, 86f), MaterialLibrary.Sidewalk);

            // stairs up to a small podium
            Vector3 stairsBase = new Vector3(26f, SidewalkHeight, -6f);
            int steps = 5;
            float stepHeight = 0.18f;
            float stepDepth = 0.45f;
            for (int i = 0; i < steps; i++)
            {
                MeshUtil.SolidBox(block, "Step" + i,
                    new Vector3(stairsBase.x, stairsBase.y + stepHeight * (i + 0.5f), stairsBase.z + stepDepth * i),
                    new Vector3(9f, stepHeight, stepDepth), MaterialLibrary.Concrete);
            }
            MeshUtil.SolidBox(block, "Podium",
                new Vector3(stairsBase.x, stairsBase.y + stepHeight * steps + 0.1f, stairsBase.z + stepDepth * steps + 2f),
                new Vector3(9f, 0.2f, 4.5f), MaterialLibrary.Concrete);

            // railings beside the stairs
            Railing(block, new Vector3(stairsBase.x - 4.6f, stairsBase.y, stairsBase.z - 1f),
                new Vector3(stairsBase.x - 4.6f, stairsBase.y, stairsBase.z + steps * stepDepth + 3f), 1.0f);
            Railing(block, new Vector3(stairsBase.x + 4.6f, stairsBase.y, stairsBase.z - 1f),
                new Vector3(stairsBase.x + 4.6f, stairsBase.y, stairsBase.z + steps * stepDepth + 3f), 1.0f);

            // benches / planters
            for (int i = 0; i < 4; i++)
            {
                Vector3 p = new Vector3(15f, SidewalkHeight, 12f + i * 8f);
                MeshUtil.SolidBox(block, "Bench", p + Vector3.up * 0.22f, new Vector3(0.6f, 0.1f, 2.4f), MaterialLibrary.Wood);
                MeshUtil.Box(block, "BenchLeg", p + Vector3.up * 0.1f, new Vector3(0.5f, 0.2f, 0.15f), MaterialLibrary.Steel);
            }
        }

        static void Railing(Transform parent, Vector3 start, Vector3 end, float height)
        {
            Material metal = MaterialLibrary.Metal("railing", new Color(0.55f, 0.57f, 0.6f), 0.65f);
            Vector3 delta = end - start;
            float length = delta.magnitude;
            if (length < 0.01f) return;

            Vector3 direction = delta / length;
            int posts = Mathf.Max(2, Mathf.FloorToInt(length / 2.2f));
            for (int i = 0; i <= posts; i++)
            {
                Vector3 p = start + direction * (length * i / posts);
                MeshUtil.SolidBox(parent, "RailPost", p + Vector3.up * (height * 0.5f),
                    new Vector3(0.09f, height, 0.09f), metal);
            }

            Vector3 center = (start + end) * 0.5f + Vector3.up * height;
            Vector3 size = Mathf.Abs(direction.x) > Mathf.Abs(direction.z)
                ? new Vector3(length, 0.08f, 0.06f)
                : new Vector3(0.06f, 0.08f, length);
            MeshUtil.Box(parent, "RailTop", center, size, metal);
            MeshUtil.Box(parent, "RailMid", center - Vector3.up * (height * 0.45f),
                new Vector3(size.x, 0.06f, size.z), metal);
        }

        static void BuildEastBlock(Transform root)
        {
            Transform block = MeshUtil.Empty(root, "BlockEast", Vector3.zero).transform;
            Sidewalk(block, new Vector3(76f, 0f, 0f), new Vector2(42f, 86f), MaterialLibrary.Sidewalk);

            Building(block, new Vector3(76f, SidewalkHeight, -28f), 26f, 20f, 26f, 3);
            Building(block, new Vector3(82f, SidewalkHeight, 20f), 18f, 24f, 14f, 4);

            BuildParkingLot(block, new Vector3(64f, 0f, 20f));
        }

        static void BuildParkingLot(Transform parent, Vector3 center)
        {
            Transform lot = MeshUtil.Empty(parent, "ParkingLot", Vector3.zero).transform;
            MeshUtil.SolidBox(lot, "LotSurface", new Vector3(center.x, 0.02f, center.z),
                new Vector3(20f, 0.04f, 26f), MaterialLibrary.Concrete);

            Material paint = MaterialLibrary.RoadPaint;
            for (int i = 0; i < 5; i++)
            {
                MeshUtil.Box(lot, "ParkLine", new Vector3(center.x - 8f + i * 4f, 0.05f, center.z),
                    new Vector3(0.12f, 0.02f, 20f), paint);
            }

            BuildCar(lot.transform, new Vector3(center.x - 6f, 0.04f, center.z - 4f), UiFactory.Hex("#9AA6B2"), false);
            BuildCar(lot.transform, new Vector3(center.x + 2f, 0.04f, center.z + 6f), UiFactory.Hex("#3E5D8A"), false);
        }

        static GameObject BuildCar(Transform parent, Vector3 position, Color color, bool withLights)
        {
            GameObject car = MeshUtil.Empty(parent, "Car", position);
            Material body = MaterialLibrary.Get("car_" + color.ToString(), color, 0.7f, 0.6f);
            Material glass = MaterialLibrary.Glass;

            MeshUtil.SolidBox(car.transform, "Body", new Vector3(0f, 0.45f, 0f), new Vector3(1.75f, 0.5f, 4.1f), body);
            MeshUtil.Box(car.transform, "Cabin", new Vector3(0f, 0.82f, -0.15f), new Vector3(1.6f, 0.44f, 2f), glass);
            MeshUtil.Axle(car.transform, "WheelFL", new Vector3(-0.8f, 0.28f, 1.35f), 0.28f, 0.18f,
                MaterialLibrary.Tire);
            MeshUtil.Axle(car.transform, "WheelFR", new Vector3(0.8f, 0.28f, 1.35f), 0.28f, 0.18f,
                MaterialLibrary.Tire);
            MeshUtil.Axle(car.transform, "WheelRL", new Vector3(-0.8f, 0.28f, -1.35f), 0.28f, 0.18f,
                MaterialLibrary.Tire);
            MeshUtil.Axle(car.transform, "WheelRR", new Vector3(0.8f, 0.28f, -1.35f), 0.28f, 0.18f,
                MaterialLibrary.Tire);

            MeshUtil.Box(car.transform, "HeadL", new Vector3(-0.6f, 0.45f, 2.06f), new Vector3(0.4f, 0.16f, 0.05f),
                MaterialLibrary.Headlight);
            MeshUtil.Box(car.transform, "HeadR", new Vector3(0.6f, 0.45f, 2.06f), new Vector3(0.4f, 0.16f, 0.05f),
                MaterialLibrary.Headlight);
            MeshUtil.Box(car.transform, "TailL", new Vector3(-0.6f, 0.45f, -2.06f), new Vector3(0.35f, 0.14f, 0.05f),
                MaterialLibrary.Taillight);
            MeshUtil.Box(car.transform, "TailR", new Vector3(0.6f, 0.45f, -2.06f), new Vector3(0.35f, 0.14f, 0.05f),
                MaterialLibrary.Taillight);

            if (withLights)
            {
                MeshUtil.AddSpotLight(car.transform, "HeadlightBeam", new Vector3(0f, 0.5f, 2.1f),
                    Quaternion.Euler(4f, 0f, 0f), new Color(1f, 0.95f, 0.82f), 3.5f, 26f, 52f);
            }

            return car;
        }

        static void BuildNorthBlock(Transform root)
        {
            Transform block = MeshUtil.Empty(root, "BlockNorth", Vector3.zero).transform;
            Sidewalk(block, new Vector3(-26f, 0f, 76f), new Vector2(34f, 44f), MaterialLibrary.Sidewalk);
            Sidewalk(block, new Vector3(26f, 0f, 76f), new Vector2(34f, 44f), MaterialLibrary.Sidewalk);

            Building(block, new Vector3(-26f, SidewalkHeight, 76f), 24f, 24f, 18f, 5);
            Building(block, new Vector3(26f, SidewalkHeight, 76f), 24f, 24f, 12f, 6);
            Building(block, new Vector3(76f, SidewalkHeight, 76f), 30f, 22f, 30f, 7);
            Sidewalk(block, new Vector3(76f, 0f, 76f), new Vector2(44f, 44f), MaterialLibrary.Sidewalk);
        }

        static void BuildConstructionSite(Transform root)
        {
            Transform site = MeshUtil.Empty(root, "Construction", Vector3.zero).transform;
            Vector3 baseCenter = new Vector3(20f, 0f, -76f);
            Sidewalk(site, new Vector3(20f, 0f, -76f), new Vector2(80f, 40f), MaterialLibrary.Dirt);

            // crane
            Material steel = MaterialLibrary.Steel;
            MeshUtil.SolidBox(site, "CraneBase", baseCenter + new Vector3(-20f, 0.3f, 0f),
                new Vector3(2.4f, 0.6f, 2.4f), MaterialLibrary.Concrete);
            MeshUtil.SolidBox(site, "CraneTower", baseCenter + new Vector3(-20f, 9f, 0f),
                new Vector3(1.1f, 18f, 1.1f), steel);
            MeshUtil.SolidBox(site, "CraneJib", baseCenter + new Vector3(-12f, 17.6f, 0f),
                new Vector3(18f, 0.5f, 0.7f), steel);
            MeshUtil.Box(site, "CraneCounter", baseCenter + new Vector3(-28f, 17.2f, 0f),
                new Vector3(4f, 1f, 1.2f), MaterialLibrary.Concrete);

            // steel beams
            for (int i = 0; i < 5; i++)
            {
                MeshUtil.SolidBox(site, "Beam", baseCenter + new Vector3(-6f + i * 2.4f, 0.25f, 8f),
                    new Vector3(0.4f, 0.5f, 9f), steel, Quaternion.Euler(0f, 8f * i, 0f));
            }

            // sand piles
            for (int i = 0; i < 4; i++)
            {
                Vector3 p = baseCenter + new Vector3(10f + i * 4f, 0.1f, -8f + (i % 2) * 3f);
                GameObject pile = MeshUtil.Sphere(site, "SandPile", p + Vector3.up * 0.15f, 1.4f,
                    MaterialLibrary.Get("sand", new Color(0.72f, 0.62f, 0.42f), 0f, 0.15f));
                pile.transform.localScale = new Vector3(2.8f, 0.8f, 2.8f);
            }

            // concrete blocks + cones
            Material coneMat = MaterialLibrary.ConeMaterial;
            for (int i = 0; i < 6; i++)
            {
                Vector3 p = baseCenter + new Vector3(-14f + i * 5f, 0.2f, 14f);
                MeshUtil.SolidCylinder(site, "Cone", p, 0.11f, 0.5f, coneMat);
            }

            // fence
            Material fence = MaterialLibrary.Metal("fence", new Color(0.45f, 0.47f, 0.5f), 0.4f);
            for (int i = 0; i < 10; i++)
            {
                Vector3 p = baseCenter + new Vector3(-38f + i * 8f, 1.1f, 19f);
                MeshUtil.SolidBox(site, "FencePanel", p, new Vector3(7.6f, 2f, 0.08f), fence);
            }
        }

        static void BuildStreetLamps(Transform root)
        {
            Transform lamps = MeshUtil.Empty(root, "StreetLamps", Vector3.zero).transform;
            Material pole = MaterialLibrary.Steel;
            Material glow = MaterialLibrary.StreetLampGlow;

            Vector3[] positions =
            {
                new Vector3(-10f, 0f, 30f),
                new Vector3(-10f, 0f, -30f),
                new Vector3(10f, 0f, 0f),
                new Vector3(40f, 0f, 40f),
                new Vector3(60f, 0f, -40f),
                new Vector3(-40f, 0f, 60f)
            };

            for (int i = 0; i < positions.Length; i++)
            {
                Vector3 p = positions[i];
                MeshUtil.SolidCylinder(lamps, "Pole", p + Vector3.up * 3.5f, 0.11f, 7f, pole);
                MeshUtil.Box(lamps, "Arm", p + new Vector3(0f, 6.9f, 0.7f), new Vector3(0.1f, 0.1f, 1.5f), pole);
                MeshUtil.Box(lamps, "Head", p + new Vector3(0f, 6.8f, 1.4f), new Vector3(0.5f, 0.16f, 0.8f), glow);
                MeshUtil.AddPointLight(lamps, "LampLight", p + new Vector3(0f, 6.5f, 1.4f),
                    new Color(1f, 0.88f, 0.66f), 2.6f, 16f);
            }
        }

        static void BuildTraffic(Transform root)
        {
            GameObject carA = BuildCar(root, new Vector3(3.5f, 0.05f, -80f), UiFactory.Hex("#C8CDD4"), true);
            MovingTraffic trafficA = carA.AddComponent<MovingTraffic>();
            trafficA.PointA = new Vector3(3.5f, 0.05f, -95f);
            trafficA.PointB = new Vector3(3.5f, 0.05f, 40f);
            trafficA.Speed = 11f;

            GameObject carB = BuildCar(root, new Vector3(20f, 0.05f, 53.5f), UiFactory.Hex("#2F3A4A"), true);
            carB.transform.rotation = Quaternion.Euler(0f, 90f, 0f);
            MovingTraffic trafficB = carB.AddComponent<MovingTraffic>();
            trafficB.PointA = new Vector3(-60f, 0.05f, 53.5f);
            trafficB.PointB = new Vector3(85f, 0.05f, 53.5f);
            trafficB.Speed = 9f;
            trafficB.Phase = 0.35f;
        }

        static void BuildCheckpoints(WorldContext context)
        {
            Color blue = UiFactory.Hex("#3FA9F5");
            Color green = UiFactory.Hex("#8FE0A8");

            Checkpoint first = Checkpoint.Create(context.Root, new Vector3(0f, 0f, 20f), 0f, 0, false, blue);
            Checkpoint second = Checkpoint.Create(context.Root, new Vector3(25f, 0f, 50f), 90f, 1, false, blue);
            Checkpoint third = Checkpoint.Create(context.Root, new Vector3(50f, 0f, 20f), 0f, 2, false, blue);
            Checkpoint fourth = Checkpoint.Create(context.Root, new Vector3(25f, 0f, -50f), 90f, 3, false, blue);
            Checkpoint fifth = Checkpoint.Create(context.Root, new Vector3(0f, 0f, -20f), 0f, 4, true, green);

            context.Checkpoints.Add(first);
            context.Checkpoints.Add(second);
            context.Checkpoints.Add(third);
            context.Checkpoints.Add(fourth);
            context.Checkpoints.Add(fifth);
        }
    }
}
