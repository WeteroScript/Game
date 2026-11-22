using UnityEngine;

namespace ScooterGame
{
    /// <summary>
    /// Data description of a real scooter. Both vehicles are free and available from the start.
    /// Numbers are taken from the manufacturer specs (see docs/VEHICLES.md).
    /// </summary>
    public class ScooterSpec
    {
        public string Id;
        public string DisplayName;
        public string Tagline;
        public string DriveDescription;

        // ---- Real world data (also used by the menu cards) ---------------------
        public float MassKg = 37f;
        public float MaxLoadKg = 120f;
        public float PowerWatts = 2000f;
        public float PeakPowerWatts = 2400f;
        public int MotorCount = 1;
        public float TopSpeedKmh = 70f;
        public float RangeKm = 75f;
        public float BatteryVoltage = 60f;
        public float BatteryAmpHours = 20f;
        public float WheelInches = 11f;
        public string BatteryText;
        public string BrakesText;
        public string SuspensionText;
        public string FeaturesText;

        // ---- Simulation --------------------------------------------------------
        /// <summary>Wheel radius in meters, derived from the tire size.</summary>
        public float WheelRadius = 0.14f;
        public float WheelBase = 1.06f;
        public float DeckLength = 0.51f;
        public float DeckWidth = 0.22f;
        public float DeckHeight = 0.17f;

        public float BatteryWh = 1200f;
        public float[] GearTopSpeedsKmh = { 20f, 40f, 70f };
        public bool SupportsAwdToggle = false;

        public float PowerPerMotorWatts = 2000f;
        public float MaxTractionForcePerMotor = 700f;
        public float MotorRampRate = 4f;      // fraction of the torque ceiling per second
        public float TorqueCeiling = 120f;    // N*m, used only to scale the ramp rate

        public float MaxBrakeTorque = 60f;
        public float RegenBrakeTorque = 14f;
        public float RegenEfficiency = 0.55f;

        public float GripRoad = 1.8f;
        public float GripOffRoad = 0.95f;
        public float SteerAngleMax = 26f;

        // ---- Wheelie -----------------------------------------------------------
        public float WheelieLiftTime = 0.8f;        // seconds to target angle at mid speed
        public float WheelieBalanceGain = 130f;     // N*m per radian
        public float WheelieBalanceDamping = 8f;    // N*m per rad/s
        public float WheelieMaxTorque = 460f;
        public float WheelieEquilibrium = 38f;      // degrees

        // ---- Look --------------------------------------------------------------
        public Color FrameColor = new Color(0.09f, 0.09f, 0.10f);
        public Color AccentColor = new Color(0.85f, 0.85f, 0.87f);
        public bool OffRoadTires = true;
        public bool OrangeAccents = false;

        public int GearCount { get { return GearTopSpeedsKmh != null ? GearTopSpeedsKmh.Length : 0; } }

        public float GearTopSpeedKmh(int gear)
        {
            if (GearTopSpeedsKmh == null || GearTopSpeedsKmh.Length == 0) return TopSpeedKmh;
            int i = Mathf.Clamp(gear, 0, GearTopSpeedsKmh.Length - 1);
            return GearTopSpeedsKmh[i];
        }

        // ------------------------------------------------------------------------
        public static ScooterSpec CreateG4()
        {
            ScooterSpec s = new ScooterSpec();
            s.Id = "g4";
            s.DisplayName = "KugooKirin G4";
            s.Tagline = "2026 · задний привод";
            s.DriveDescription = "RWD — один задний хаб-мотор";
            s.MassKg = 37f;
            s.MaxLoadKg = 120f;
            s.PowerWatts = 2000f;
            s.PeakPowerWatts = 2400f;
            s.MotorCount = 1;
            s.TopSpeedKmh = 70f;
            s.RangeKm = 75f;
            s.BatteryVoltage = 60f;
            s.BatteryAmpHours = 20f;
            s.WheelInches = 11f;
            s.BatteryText = "60V 20Ah";
            s.BrakesText = "Передний + задний дисковые";
            s.SuspensionText = "Регулируемая двойная";
            s.FeaturesText = "LCD · фара · стоп-сигнал · поворотники · ключ";

            s.WheelRadius = 0.5f * 11f * 0.0254f;   // 11" tire -> 0.14 m
            s.WheelBase = 1.06f;
            s.DeckLength = 0.51f;
            s.DeckWidth = 0.22f;
            s.BatteryWh = s.BatteryVoltage * s.BatteryAmpHours;
            s.GearTopSpeedsKmh = new float[] { 20f, 40f, 70f };
            s.SupportsAwdToggle = false;

            s.PowerPerMotorWatts = 2000f;
            s.MaxTractionForcePerMotor = 320f;   // current-limited launch, ~0-50 km/h in ~2 s
            s.MotorRampRate = 4.2f;
            s.TorqueCeiling = 45f;               // 320 N * 0.14 m
            s.MaxBrakeTorque = 62f;
            s.RegenBrakeTorque = 8f;
            s.GripRoad = 1.85f;
            s.GripOffRoad = 0.95f;
            s.SteerAngleMax = 26f;

            // RWD: легче поднять, сложнее удержать баланс.
            s.WheelieLiftTime = 0.75f;
            s.WheelieBalanceGain = 128f;
            s.WheelieBalanceDamping = 7.5f;
            s.WheelieMaxTorque = 470f;
            s.WheelieEquilibrium = 37f;

            s.FrameColor = new Color(0.085f, 0.088f, 0.095f);
            s.AccentColor = new Color(0.86f, 0.87f, 0.9f);
            s.OffRoadTires = true;
            s.OrangeAccents = false;
            return s;
        }

        public static ScooterSpec CreateF3ProMax()
        {
            ScooterSpec s = new ScooterSpec();
            s.Id = "f3";
            s.DisplayName = "Kugoo F3 Pro Max";
            s.Tagline = "полный привод AWD";
            s.DriveDescription = "AWD — передний + задний моторы, переключение в RWD";
            s.MassKg = 32.5f;
            s.MaxLoadKg = 130f;
            s.PowerWatts = 2200f;
            s.PeakPowerWatts = 2400f;
            s.MotorCount = 2;
            s.TopSpeedKmh = 68f;
            s.RangeKm = 70f;
            s.BatteryVoltage = 52f;
            s.BatteryAmpHours = 23.4f;
            s.WheelInches = 10f;
            s.BatteryText = "52V 23.4Ah";
            s.BrakesText = "Дисковые + электронный тормоз";
            s.SuspensionText = "Передняя и задняя амортизация";
            s.FeaturesText = "LCD · AWD/RWD · фара · стоп-сигнал · габариты";

            s.WheelRadius = 0.5f * 10f * 0.0254f;   // 10" tire -> 0.127 m
            s.WheelBase = 1.0f;
            s.DeckLength = 0.48f;
            s.DeckWidth = 0.21f;
            s.BatteryWh = s.BatteryVoltage * s.BatteryAmpHours;
            s.GearTopSpeedsKmh = new float[] { 30f, 51f, 66f };
            s.SupportsAwdToggle = true;

            s.PowerPerMotorWatts = 1100f;
            s.MaxTractionForcePerMotor = 150f;   // 2 x 150 N in AWD, 150 N in RWD
            s.MotorRampRate = 5.0f;
            s.TorqueCeiling = 40f;               // 300 N * 0.127 m
            s.MaxBrakeTorque = 58f;
            s.RegenBrakeTorque = 7f;
            s.GripRoad = 1.9f;
            s.GripOffRoad = 1.0f;
            s.SteerAngleMax = 27f;

            // AWD: передний мотор тянет вниз -> поднимать тяжелее, но баланс стабильнее.
            s.WheelieLiftTime = 0.8f;
            s.WheelieBalanceGain = 168f;
            s.WheelieBalanceDamping = 14f;
            s.WheelieMaxTorque = 430f;
            s.WheelieEquilibrium = 39f;

            s.FrameColor = new Color(0.1f, 0.1f, 0.105f);
            s.AccentColor = new Color(0.95f, 0.45f, 0.08f);
            s.OffRoadTires = false;
            s.OrangeAccents = true;
            return s;
        }

        public static ScooterSpec[] All()
        {
            return new ScooterSpec[] { CreateG4(), CreateF3ProMax() };
        }

        public static ScooterSpec Get(string id)
        {
            ScooterSpec[] all = All();
            for (int i = 0; i < all.Length; i++)
            {
                if (all[i].Id == id) return all[i];
            }
            return all[0];
        }
    }
}
