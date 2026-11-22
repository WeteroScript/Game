using UnityEngine;

namespace ScooterGame
{
    public enum GameMode
    {
        FreeRide = 0,
        TimeAttack = 1,
        Freestyle = 2
    }

    public enum MapId
    {
        StraightTrack = 0,
        City = 1
    }

    public enum DriveMode
    {
        RWD = 0,
        AWD = 1
    }

    /// <summary>
    /// Global gameplay constants. Values are tuned for an arcade-simulator mix,
    /// see docs/TECHNICAL.md for the reasoning behind each group.
    /// </summary>
    public static class GameConfig
    {
        public const string ProductName = "Kugoo Freeride";
        public const string CompanyName = "WeteroScript";
        public const string BundleId = "com.weteroscript.kugoowheelie";
        public const string Version = "1.0.0";

        /// <summary>Gravity is slightly stronger than real life: the scooter feels heavier and settles faster.</summary>
        public const float Gravity = -14f;

        public const int TargetFrameRate = 60;
        public const float FreestyleDuration = 90f;
        public const float TimeAttackLimit = 300f;

        /// <summary>Time between the crash moment and the automatic respawn.</summary>
        public const float RespawnDelay = 2.4f;

        public static bool PostProcessingEnabled = true;

        /// <summary>
        /// Battery consumption is compressed for gameplay: 1 = realistic (a full pack lasts ~45 min
        /// at 70 km/h), 6 = a run drains the pack in about 6-7 minutes.
        /// </summary>
        public const float BatteryDrainMultiplier = 6f;

        public const string SceneryLayerName = "Default";
    }

    /// <summary>
    /// Shared vehicle tuning. Per-vehicle differences live in <see cref="ScooterSpec"/>.
    /// All torque values are in N*m and angles in degrees.
    /// </summary>
    public static class VehicleTuning
    {
        // ---- Wheel suspension --------------------------------------------------
        public const float SuspensionDistance = 0.09f;
        public const float SuspensionSpring = 32000f;
        public const float SuspensionDamper = 3400f;
        public const float SuspensionTarget = 0.45f;
        public const float WheelMassFraction = 0.10f;

        // ---- Rolling resistance / drag ----------------------------------------
        public const float RollingResistanceTorque = 0.5f;
        public const float AirDragCoefficient = 0.160f; // multiplied by v^2 (N)

        // ---- Steering ----------------------------------------------------------
        public const float SteerSpeedFalloffStart = 2f;
        public const float SteerSpeedFalloffEnd = 22f;
        public const float SteerMinFactor = 0.42f;
        public const float RearSteerFactor = 0.3f;

        // ---- Balance (fake gyroscopic / rider balance assist) ------------------
        // Roll: two-wheeled vehicles need an artificial upright torque to be playable.
        public const float RollStabilityGain = 260f;   // N*m per radian of roll error
        public const float RollStabilityDamping = 46f; // N*m per rad/s
        public const float RollMaxTorque = 520f;
        public const float LeanIntoTurnMaxAngle = 21f;
        public const float LeanIntoTurnFullSpeed = 14f; // m/s

        // Pitch: keeps the frame aligned with the ground when not doing a wheelie.
        public const float PitchStabilityGain = 120f;
        public const float PitchStabilityDamping = 26f;
        public const float PitchMaxTorque = 380f;

        // Yaw: prevents endless spinning from wheel friction.
        public const float YawDamping = 6f;

        // ---- Brakes ------------------------------------------------------------
        public const float RearBrakeShare = 0.85f;
        public const float FullFrontBrakeThreshold = 0.85f;
        public const float EndoRiskSpeedKmh = 30f;
        public const float EndoRiskTorque = 55f;
        public const float EndoCrashAngle = -26f;

        // ---- Crash thresholds --------------------------------------------------
        public const float LoopOutAngle = 74f;
        public const float FallRollAngle = 62f;
        public const float HardImpactSpeed = 7.5f;

        // ---- Battery -----------------------------------------------------------
        public const float MotorEfficiency = 0.80f;
        public const float MotorSpinupLossWatts = 260f;
        public const float IdleDrainWatts = 0.6f;
        public const float LowBatteryPercent = 8f;
        public const float LowBatteryPowerScale = 0.4f;
    }
}
