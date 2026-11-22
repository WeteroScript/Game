using UnityEngine;

namespace ScooterGame
{
    /// <summary>
    /// Wheelie state machine. Lift is never instant: the target angle ramps over
    /// 0.5-1.5 s depending on speed, and the drive mode changes both how hard the
    /// nose comes up and how stable the balance is:
    ///
    ///  * G4 (RWD)      - easy to lift, weak damping, harder to keep in the zone.
    ///  * F3 Pro Max AWD - the front motor pulls the nose down (lift ~1.55x slower),
    ///                     but the stronger damping makes the balance calmer.
    ///  * F3 Pro Max RWD - behaves close to the G4.
    /// </summary>
    public class WheelieController
    {
        public const float MinSpeedKmh = 15f;
        public const float BalanceMinAngle = 25f;
        public const float BalanceMaxAngle = 55f;

        readonly ScooterController _scooter;
        float _liftProgress;

        public bool Active { get; private set; }
        public bool InBalanceZone { get; private set; }
        public float LiftProgress { get { return _liftProgress; } }
        public float TargetPitch { get; private set; }
        public float CurrentPitch { get { return _scooter != null ? _scooter.PitchAngle : 0f; } }
        public bool AboveBalanceZone { get { return CurrentPitch > BalanceMaxAngle; } }
        public bool InDangerZone { get { return CurrentPitch > 60f; } }

        public WheelieController(ScooterController scooter)
        {
            _scooter = scooter;
        }

        public void Reset()
        {
            _liftProgress = 0f;
            Active = false;
            InBalanceZone = false;
            TargetPitch = 0f;
        }

        public void Tick(float dt, bool held, float throttle, float bodyPitchInput,
            float speedKmh, DriveMode drive, ScooterSpec spec, bool grounded, bool crashed)
        {
            bool awd = spec.MotorCount == 2 && drive == DriveMode.AWD;
            bool canLift = grounded && !crashed && speedKmh > MinSpeedKmh;

            float liftTime = Mathf.Lerp(spec.WheelieLiftTime * 1.7f, spec.WheelieLiftTime * 0.75f,
                Mathf.InverseLerp(MinSpeedKmh, 46f, speedKmh));
            if (awd) liftTime *= 1.55f; // front hub motor pulls the nose back down

            if (held && canLift)
            {
                Active = true;
                _liftProgress = Mathf.MoveTowards(_liftProgress, 1f, dt / Mathf.Max(0.18f, liftTime));
            }
            else
            {
                _liftProgress = Mathf.MoveTowards(_liftProgress, 0f, dt / 0.45f);
                if (_liftProgress <= 0.001f)
                {
                    Active = false;
                    InBalanceZone = false;
                    TargetPitch = 0f;
                    return;
                }
            }

            float pitch = _scooter.PitchAngle;
            float equilibrium = spec.WheelieEquilibrium;

            // Throttle raises the angle, releasing the throttle lowers it,
            // the body-lean input trims the target.
            float throttleFactor = 0.55f + 0.45f * Mathf.Clamp01(throttle);
            // lean-back input can deliberately push past the balance zone: that is the
            // only way to reach the 70-80 degree loop-out, exactly like yanking the bar.
            float target = equilibrium * throttleFactor
                           + bodyPitchInput * 34f
                           + (throttle > 0.85f ? 5f : 0f);
            target = Mathf.Clamp(target * Mathf.Clamp01(_liftProgress), 0f, 80f);
            TargetPitch = target;

            // Static torque needed to hold the frame against gravity around the rear patch.
            float gravityTorque = spec.MassKg * Mathf.Abs(Physics.gravity.y) * 0.40f
                                  * Mathf.Cos(Mathf.Clamp(pitch, 0f, 89f) * Mathf.Deg2Rad);

            float error = (target - pitch) * Mathf.Deg2Rad;
            float rate = _scooter.PitchRate * Mathf.Deg2Rad;

            float torque = gravityTorque
                           + error * spec.WheelieBalanceGain
                           - rate * spec.WheelieBalanceDamping;

            torque = Mathf.Clamp(torque, -spec.WheelieMaxTorque, spec.WheelieMaxTorque);
            _scooter.ApplyNoseUpTorque(torque, ForceMode.Force);

            InBalanceZone = pitch >= BalanceMinAngle && pitch <= BalanceMaxAngle;
        }
    }
}
