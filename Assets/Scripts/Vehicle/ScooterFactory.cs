using UnityEngine;

namespace ScooterGame
{
    /// <summary>
    /// Builds the scooter: rigidbody + WheelColliders + the visible model.
    /// The model is assembled from primitives at runtime, with separate objects for the
    /// wheels, handlebar, suspension and hub motors so it can be swapped for an imported
    /// rigged mesh later (see docs/MODELS.md).
    /// </summary>
    public static class ScooterFactory
    {
        public const string FrontWheelColliderName = "WC_Front";
        public const string RearWheelColliderName = "WC_Rear";

        struct WheelParts
        {
            public Transform Pivot;
            public Transform Hub;
        }

        public static ScooterController Build(ScooterSpec spec, Transform parent, Vector3 position, Quaternion rotation)
        {
            GameObject root = new GameObject("Scooter_" + spec.Id);
            root.transform.SetParent(parent, false);
            root.transform.position = position;
            root.transform.rotation = rotation;

            Rigidbody rb = root.AddComponent<Rigidbody>();
            rb.mass = spec.MassKg;
            rb.drag = 0.02f;
            rb.angularDrag = 3.5f;
            rb.interpolation = RigidbodyInterpolation.Interpolate;
            rb.collisionDetectionMode = CollisionDetectionMode.ContinuousDynamic;
            rb.centerOfMass = new Vector3(0f, 0.42f, -0.02f);
            rb.useGravity = true;
            rb.ConfigureVehicleSubsteps(5f, 12, 15);

            PhysicMaterial slippery = new PhysicMaterial("PM_ScooterBody");
            slippery.dynamicFriction = 0.15f;
            slippery.staticFriction = 0.15f;
            slippery.bounciness = 0f;
            slippery.frictionCombine = PhysicMaterialCombine.Minimum;

            BoxCollider box = root.AddComponent<BoxCollider>();
            box.material = slippery;
            box.center = new Vector3(0f, 0.41f, 0f);
            box.size = new Vector3(spec.DeckWidth + 0.02f, 0.44f, spec.DeckLength + 0.5f);

            // ---- wheels (physics) ----
            float halfBase = spec.WheelBase * 0.5f;
            float wheelTopY = spec.WheelRadius + VehicleTuning.SuspensionDistance;

            WheelCollider frontWheel = CreateWheelCollider(root.transform, FrontWheelColliderName,
                new Vector3(0f, wheelTopY, halfBase), spec);
            WheelCollider rearWheel = CreateWheelCollider(root.transform, RearWheelColliderName,
                new Vector3(0f, wheelTopY, -halfBase), spec);

            // ---- visible model ----
            Transform steerVisual;
            Transform frontPivot;
            Transform rearPivot;
            Transform frontHub;
            Transform rearHub;
            BuildModel(spec, root.transform, out steerVisual, out frontPivot, out rearPivot, out frontHub, out rearHub);

            ScooterController controller = root.AddComponent<ScooterController>();
            controller.Initialize(spec, frontWheel, rearWheel, frontPivot, rearPivot, steerVisual);

            root.AddComponent<ScooterAudio>();

            return controller;
        }

        // ------------------------------------------------------------------------
        static WheelCollider CreateWheelCollider(Transform parent, string name, Vector3 localPos, ScooterSpec spec)
        {
            GameObject go = new GameObject(name);
            go.transform.SetParent(parent, false);
            go.transform.localPosition = localPos;

            WheelCollider wheel = go.AddComponent<WheelCollider>();
            wheel.radius = spec.WheelRadius;
            wheel.mass = Mathf.Max(1f, spec.MassKg * VehicleTuning.WheelMassFraction);
            wheel.suspensionDistance = VehicleTuning.SuspensionDistance;
            wheel.forceAppPointDistance = 0.02f;

            JointSpring spring = wheel.suspensionSpring;
            spring.spring = VehicleTuning.SuspensionSpring;
            spring.damper = VehicleTuning.SuspensionDamper;
            spring.targetPosition = VehicleTuning.SuspensionTarget;
            wheel.suspensionSpring = spring;

            ApplyFrictionCurve(wheel, spec.GripRoad);
            return wheel;
        }

        public static void ApplyFrictionCurve(WheelCollider wheel, float stiffness)
        {
            WheelFrictionCurve forward = wheel.forwardFriction;
            forward.extremumSlip = 0.4f;
            forward.extremumValue = 1f;
            forward.asymptoteSlip = 0.8f;
            forward.asymptoteValue = 0.6f;
            forward.stiffness = stiffness;
            wheel.forwardFriction = forward;

            WheelFrictionCurve sideways = wheel.sidewaysFriction;
            sideways.extremumSlip = 0.25f;
            sideways.extremumValue = 1f;
            sideways.asymptoteSlip = 0.6f;
            sideways.asymptoteValue = 0.8f;
            sideways.stiffness = stiffness * 1.1f;
            wheel.sidewaysFriction = sideways;
        }

        // ------------------------------------------------------------------------
        static void BuildModel(ScooterSpec spec, Transform root,
            out Transform steerVisual, out Transform frontPivot, out Transform rearPivot,
            out Transform frontHub, out Transform rearHub)
        {
            float r = spec.WheelRadius;
            float halfBase = spec.WheelBase * 0.5f;

            Material frameMat = MaterialLibrary.Frame(spec.FrameColor);
            Material deckMat = MaterialLibrary.Deck(spec.FrameColor * 1.15f);
            Material accentMat = MaterialLibrary.Metal("accent_" + spec.Id, spec.AccentColor, 0.55f);
            Material chrome = MaterialLibrary.Chrome;
            Material steel = MaterialLibrary.Steel;

            GameObject body = MeshUtil.Empty(root, "Body", Vector3.zero);

            // ---------- deck ----------
            float deckZ = -0.02f;
            MeshUtil.Box(body.transform, "Deck", new Vector3(0f, spec.DeckHeight, deckZ),
                new Vector3(spec.DeckWidth, 0.042f, spec.DeckLength), deckMat);
            // grip tape
            MeshUtil.Box(body.transform, "GripTape", new Vector3(0f, spec.DeckHeight + 0.023f, deckZ),
                new Vector3(spec.DeckWidth * 0.94f, 0.004f, spec.DeckLength * 0.96f),
                MaterialLibrary.Get("griptape", new Color(0.08f, 0.08f, 0.085f), 0f, 0.1f));
            // side rails
            MeshUtil.Box(body.transform, "RailR", new Vector3(spec.DeckWidth * 0.5f, spec.DeckHeight, deckZ),
                new Vector3(0.012f, 0.03f, spec.DeckLength * 0.98f), accentMat);
            MeshUtil.Box(body.transform, "RailL", new Vector3(-spec.DeckWidth * 0.5f, spec.DeckHeight, deckZ),
                new Vector3(0.012f, 0.03f, spec.DeckLength * 0.98f), accentMat);
            // deck front/rear closed ends
            MeshUtil.Box(body.transform, "DeckFront", new Vector3(0f, spec.DeckHeight - 0.01f, deckZ + spec.DeckLength * 0.5f),
                new Vector3(spec.DeckWidth * 0.9f, 0.06f, 0.03f), frameMat);
            MeshUtil.Box(body.transform, "DeckRear", new Vector3(0f, spec.DeckHeight - 0.01f, deckZ - spec.DeckLength * 0.5f),
                new Vector3(spec.DeckWidth * 0.9f, 0.06f, 0.03f), frameMat);

            // ---------- rear swingarm + shock ----------
            Vector3 rearAxle = new Vector3(0f, r, -halfBase);
            Vector3 swingPivot = new Vector3(0f, spec.DeckHeight - 0.02f, deckZ - spec.DeckLength * 0.5f + 0.02f);
            Tube(body.transform, "SwingarmR", new Vector3(0.062f, swingPivot.y, swingPivot.z),
                new Vector3(0.062f, rearAxle.y, rearAxle.z), 0.018f, frameMat);
            Tube(body.transform, "SwingarmL", new Vector3(-0.062f, swingPivot.y, swingPivot.z),
                new Vector3(-0.062f, rearAxle.y, rearAxle.z), 0.018f, frameMat);
            Tube(body.transform, "ShockAbsorber", new Vector3(0f, spec.DeckHeight + 0.03f, swingPivot.z + 0.06f),
                new Vector3(0f, r + 0.045f, rearAxle.z + 0.09f), 0.022f, steel);
            Tube(body.transform, "ShockSpring", new Vector3(0f, spec.DeckHeight + 0.015f, swingPivot.z + 0.055f),
                new Vector3(0f, r + 0.06f, rearAxle.z + 0.085f), 0.028f,
                MaterialLibrary.Get("spring", new Color(0.75f, 0.6f, 0.05f), 0.8f, 0.5f));

            // rear fender
            MeshUtil.Box(body.transform, "RearFender", new Vector3(0f, r + 0.115f, rearAxle.z - 0.02f),
                new Vector3(spec.DeckWidth * 0.8f, 0.02f, r * 1.35f), frameMat);
            // rear brake caliper
            MeshUtil.Box(body.transform, "RearCaliper", new Vector3(0.052f, r + 0.01f, rearAxle.z + 0.02f),
                new Vector3(0.03f, 0.05f, 0.055f), MaterialLibrary.Caliper);

            // taillight + turn signals + plate
            MeshUtil.Box(body.transform, "TailLight", new Vector3(0f, spec.DeckHeight + 0.01f, rearAxle.z - 0.02f),
                new Vector3(0.1f, 0.022f, 0.02f), MaterialLibrary.Taillight);
            MeshUtil.Box(body.transform, "TurnSignalL", new Vector3(-0.11f, r + 0.1f, rearAxle.z - 0.03f),
                new Vector3(0.035f, 0.02f, 0.02f), MaterialLibrary.TurnSignal);
            MeshUtil.Box(body.transform, "TurnSignalR", new Vector3(0.11f, r + 0.1f, rearAxle.z - 0.03f),
                new Vector3(0.035f, 0.02f, 0.02f), MaterialLibrary.TurnSignal);
            MeshUtil.Box(body.transform, "Plate", new Vector3(0f, r + 0.16f, rearAxle.z - 0.06f),
                new Vector3(0.09f, 0.06f, 0.006f), MaterialLibrary.Get("plate", new Color(0.85f, 0.85f, 0.85f), 0f, 0.3f));

            // battery box under the deck
            MeshUtil.Box(body.transform, "BatteryBox", new Vector3(0f, spec.DeckHeight - 0.055f, deckZ),
                new Vector3(spec.DeckWidth * 0.86f, 0.06f, spec.DeckLength * 0.82f), frameMat);

            // ---------- steering assembly ----------
            Vector3 stemBase = new Vector3(0f, spec.DeckHeight + 0.06f, halfBase - 0.13f);
            steerVisual = MeshUtil.Empty(root, "SteerAssembly", stemBase).transform;
            Transform steer = steerVisual;

            // folding mechanism
            MeshUtil.Box(steer, "FoldingHinge", new Vector3(0f, 0.03f, 0f),
                new Vector3(0.075f, 0.1f, 0.13f), frameMat);
            MeshUtil.Axle(steer, "FoldingPivot", new Vector3(0f, 0.02f, -0.01f), 0.022f, 0.1f, chrome);
            MeshUtil.Box(steer, "FoldingLatch", new Vector3(0f, 0.075f, -0.055f),
                new Vector3(0.045f, 0.04f, 0.03f), MaterialLibrary.Hazard);

            // key ignition
            MeshUtil.Cylinder(steer, "KeyIgnition", new Vector3(0.055f, 0.085f, 0.03f), 0.016f, 0.028f, chrome,
                Quaternion.Euler(90f, 0f, 0f));

            // telescopic stem: outer + inner tube
            float stemTop = spec.Id == "f3" ? 1.06f : 1.02f;
            float stemLen = stemTop - stemBase.y;
            MeshUtil.Cylinder(steer, "StemOuter", new Vector3(0f, 0.14f, 0.01f), 0.032f, stemLen * 0.45f, frameMat);
            MeshUtil.Cylinder(steer, "StemInner", new Vector3(0f, stemLen * 0.62f, 0.01f), 0.024f, stemLen * 0.72f, chrome);
            MeshUtil.Cylinder(steer, "StemClamp", new Vector3(0f, stemLen * 0.44f, 0.01f), 0.038f, 0.035f, accentMat);

            // handlebar
            float barY = stemLen - 0.02f;
            float gripHalf = spec.Id == "f3" ? 0.28f : 0.30f;
            MeshUtil.Axle(steer, "Handlebar", new Vector3(0f, barY, 0.01f), 0.017f, gripHalf * 2f, frameMat);
            MeshUtil.Axle(steer, "GripL", new Vector3(-gripHalf + 0.05f, barY, 0.01f), 0.026f, 0.1f,
                MaterialLibrary.Get("grip", new Color(0.07f, 0.07f, 0.08f), 0f, 0.25f));
            MeshUtil.Axle(steer, "GripR", new Vector3(gripHalf - 0.05f, barY, 0.01f), 0.026f, 0.1f,
                MaterialLibrary.Get("grip", new Color(0.07f, 0.07f, 0.08f), 0f, 0.25f));
            // brake levers
            MeshUtil.Box(steer, "LeverL", new Vector3(-0.19f, barY - 0.01f, 0.075f),
                new Vector3(0.015f, 0.012f, 0.13f), chrome, Quaternion.Euler(0f, 12f, 0f));
            MeshUtil.Box(steer, "LeverR", new Vector3(0.19f, barY - 0.01f, 0.075f),
                new Vector3(0.015f, 0.012f, 0.13f), chrome, Quaternion.Euler(0f, -12f, 0f));

            // LCD display
            MeshUtil.Box(steer, "DisplayHousing", new Vector3(0f, barY + 0.045f, 0.055f),
                new Vector3(0.15f, 0.055f, 0.085f), frameMat, Quaternion.Euler(-18f, 0f, 0f));
            MeshUtil.Box(steer, "DisplayScreen", new Vector3(0f, barY + 0.073f, 0.058f),
                new Vector3(0.125f, 0.006f, 0.062f), MaterialLibrary.Screen, Quaternion.Euler(-18f, 0f, 0f));
            // throttle thumb lever
            MeshUtil.Box(steer, "Throttle", new Vector3(0.09f, barY - 0.02f, 0.05f),
                new Vector3(0.03f, 0.02f, 0.06f), MaterialLibrary.Get("thumb", new Color(0.15f, 0.15f, 0.16f), 0f, 0.3f));

            // headlight
            MeshUtil.Box(steer, "HeadlightHousing", new Vector3(0f, barY - 0.075f, 0.075f),
                new Vector3(0.085f, 0.06f, 0.05f), frameMat);
            MeshUtil.Box(steer, "HeadlightLens", new Vector3(0f, barY - 0.075f, 0.103f),
                new Vector3(0.07f, 0.045f, 0.008f), MaterialLibrary.Headlight);
            Light headlight = MeshUtil.AddSpotLight(steer, "HeadlightBeam",
                new Vector3(0f, barY - 0.075f, 0.11f), Quaternion.identity,
                new Color(1f, 0.96f, 0.85f), 4.5f, 30f, 48f);
            headlight.transform.localRotation = Quaternion.Euler(6f, 0f, 0f);

            // ---------- front suspension ----------
            Vector3 frontAxle = new Vector3(0f, r, halfBase);
            Tube(steer, "ForkR", new Vector3(0.058f, 0.02f, -0.01f),
                new Vector3(0.058f, r - stemBase.y, frontAxle.z - stemBase.z), 0.019f, frameMat);
            Tube(steer, "ForkL", new Vector3(-0.058f, 0.02f, -0.01f),
                new Vector3(-0.058f, r - stemBase.y, frontAxle.z - stemBase.z), 0.019f, frameMat);
            // front shock (telescopic) for F3
            if (spec.Id == "f3")
            {
                Tube(steer, "FrontShock", new Vector3(0f, 0.06f, 0.02f),
                    new Vector3(0f, r - stemBase.y + 0.04f, frontAxle.z - stemBase.z), 0.026f, steel);
            }
            // front brake caliper + disc cover
            MeshUtil.Box(steer, "FrontCaliper", new Vector3(0.055f, r - stemBase.y + 0.01f, frontAxle.z - stemBase.z + 0.02f),
                new Vector3(0.03f, 0.05f, 0.055f), MaterialLibrary.Caliper);

            // brand decal on the deck side
            MeshUtil.Box(body.transform, "Decal", new Vector3(spec.DeckWidth * 0.5f + 0.007f, spec.DeckHeight, deckZ),
                new Vector3(0.004f, 0.018f, spec.DeckLength * 0.42f), accentMat);

            // ---------- wheels (visual) ----------
            frontPivot = BuildWheel(spec, root, "WheelFront", r, spec.MotorCount == 2, spec.OffRoadTires, true, out frontHub);
            rearPivot = BuildWheel(spec, root, "WheelRear", r, true, spec.OffRoadTires, false, out rearHub);

            frontPivot.position = root.TransformPoint(new Vector3(0f, r, halfBase));
            rearPivot.position = root.TransformPoint(new Vector3(0f, r, -halfBase));
            frontPivot.rotation = root.rotation;
            rearPivot.rotation = root.rotation;
        }

        static Transform BuildWheel(ScooterSpec spec, Transform root, string name, float radius,
            bool hasMotor, bool offRoad, bool isFront, out Transform hub)
        {
            Transform pivot = MeshUtil.Empty(root, name, Vector3.zero).transform;

            // tire (lies along the X axis)
            MeshUtil.Axle(pivot, "Tire", Vector3.zero, radius, 0.076f, MaterialLibrary.Tire);
            // sidewall shading rings
            MeshUtil.Axle(pivot, "SidewallL", new Vector3(-0.02f, 0f, 0f), radius * 0.99f, 0.03f,
                MaterialLibrary.Get("sidewall", new Color(0.045f, 0.045f, 0.05f), 0f, 0.1f));
            MeshUtil.Axle(pivot, "SidewallR", new Vector3(0.02f, 0f, 0f), radius * 0.99f, 0.03f,
                MaterialLibrary.Get("sidewall", new Color(0.045f, 0.045f, 0.05f), 0f, 0.1f));
            // rim
            MeshUtil.Axle(pivot, "Rim", Vector3.zero, radius * 0.58f, 0.082f, MaterialLibrary.Rim);
            // spokes
            for (int i = 0; i < 5; i++)
            {
                float a = i * (360f / 5f);
                MeshUtil.Box(pivot, "Spoke" + i, Vector3.zero,
                    new Vector3(0.084f, 0.012f, radius * 0.9f), MaterialLibrary.Rim,
                    Quaternion.Euler(a, 0f, 0f));
            }

            hub = MeshUtil.Empty(pivot, "HubMotor", Vector3.zero).transform;
            if (hasMotor)
            {
                MeshUtil.Axle(hub, "MotorCan", Vector3.zero, radius * 0.40f, 0.095f, MaterialLibrary.MotorHub);
                MeshUtil.Axle(hub, "MotorRing", new Vector3(0f, 0f, 0f), radius * 0.41f, 0.03f,
                    MaterialLibrary.Get("motorring", new Color(0.32f, 0.33f, 0.35f), 1f, 0.7f));
            }
            else
            {
                MeshUtil.Axle(hub, "AxleCap", Vector3.zero, radius * 0.22f, 0.09f, MaterialLibrary.Rim);
            }

            // disc brake rotor (on the left side of the wheel)
            MeshUtil.Axle(pivot, "DiscRotor", new Vector3(isFront ? -0.045f : 0.045f, 0f, 0f),
                radius * 0.5f, 0.006f, MaterialLibrary.BrakeRotor);
            // rotor holes (visual detail, cheap: 6 small dark boxes)
            for (int i = 0; i < 6; i++)
            {
                float a = i * 60f;
                Vector3 p = Quaternion.Euler(a, 0f, 0f) * new Vector3(isFront ? -0.043f : 0.043f, radius * 0.34f, 0f);
                MeshUtil.Box(pivot, "RotorHole" + i, p, new Vector3(0.008f, 0.02f, 0.02f),
                    MaterialLibrary.Get("rotorhole", new Color(0.2f, 0.2f, 0.21f), 0.9f, 0.4f));
            }

            // tread blocks
            int blocks = offRoad ? 14 : 10;
            for (int i = 0; i < blocks; i++)
            {
                float a = i * (360f / blocks);
                Vector3 p = Quaternion.Euler(a, 0f, 0f) * new Vector3(0f, radius * 0.93f, 0f);
                Vector3 size = offRoad
                    ? new Vector3(0.086f, 0.045f, 0.05f)
                    : new Vector3(0.078f, 0.016f, 0.05f);
                MeshUtil.Box(pivot, "Tread" + i, p, size, MaterialLibrary.Tire, Quaternion.Euler(a, 0f, 0f));
            }

            return pivot;
        }

        /// <summary>Cylinder between two local points of the parent.</summary>
        static GameObject Tube(Transform parent, string name, Vector3 from, Vector3 to, float radius, Material mat)
        {
            Vector3 dir = to - from;
            float len = dir.magnitude;
            if (len < 0.0001f) return null;
            Quaternion rot = Quaternion.FromToRotation(Vector3.up, dir.normalized);
            return MeshUtil.Cylinder(parent, name, (from + to) * 0.5f, radius, len, mat, rot);
        }
    }
}
