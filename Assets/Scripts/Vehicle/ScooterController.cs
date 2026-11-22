using System;
using UnityEngine;

namespace ScooterGame
{
    /// <summary>
    /// Rigidbody + WheelCollider scooter. Handles drive (RWD / AWD), separate front and
    /// rear disc brakes, regenerative braking, speed modes, the wheelie hand-off and the
    /// crash / respawn cycle.
    /// </summary>
    public class ScooterController : MonoBehaviour
    {
        // ---- wiring ------------------------------------------------------------
        public ScooterSpec Spec { get; private set; }
        public Rigidbody Body { get; private set; }
        public WheelCollider FrontWheel { get; private set; }
        public WheelCollider RearWheel { get; private set; }

        Transform _frontVisual;
        Transform _rearVisual;
        Transform _steerVisual;
        WheelieController _wheelie;

        // ---- inputs ------------------------------------------------------------
        float _throttle;
        float _brakeFront;
        float _brakeRear;
        float _steer;
        bool _inputEnabled = true;

        // ---- state -------------------------------------------------------------
        float _currentTorque;
        float _batteryWh;
        float _distanceMeters;
        float _pitch;
        float _pitchRate;
        float _roll;
        float _yawRate;
        float _airTime;
        float _maxAirTime;
        float _lastAirTime;
        int _landingCounter;
        float _wheelieBalanceTime;
        float _stoppieTime;
        float _runTime;

        bool _frontGrounded;
        bool _rearGrounded;
        WheelHit _frontHit;
        WheelHit _rearHit;

        bool _crashed;
        float _crashTimer;
        string _crashReason = string.Empty;
        int _crashCount;
        Vector3 _respawnPosition;
        Quaternion _respawnRotation;

        // ---- public API --------------------------------------------------------
        public DriveMode Drive { get; private set; }
        public int SpeedMode { get; private set; }

        public bool CanToggleDrive { get { return Spec != null && Spec.SupportsAwdToggle; } }
        public float SpeedMps { get; private set; }
        public float SpeedKmh { get { return Mathf.Abs(SpeedMps) * 3.6f; } }
        public float SignedSpeedKmh { get { return SpeedMps * 3.6f; } }
        public float Throttle { get { return _throttle; } }
        public float BrakeFrontInput { get { return _brakeFront; } }
        public float BrakeRearInput { get { return _brakeRear; } }
        public float Steer { get { return _steer; } }
        public float BatteryWh { get { return _batteryWh; } }
        public float BatteryPercent { get { return Mathf.Clamp01(_batteryWh / Mathf.Max(1f, Spec.BatteryWh)) * 100f; } }
        public float DistanceMeters { get { return _distanceMeters; } }
        public float DistanceKm { get { return _distanceMeters / 1000f; } }
        public float RunTime { get { return _runTime; } }
        public float PitchAngle { get { return _pitch; } }
        public float PitchRate { get { return _pitchRate; } }
        public float RollAngle { get { return _roll; } }
        public float YawRate { get { return _yawRate; } }
        public bool FrontGrounded { get { return _frontGrounded; } }
        public bool RearGrounded { get { return _rearGrounded; } }
        public bool IsGrounded { get { return _frontGrounded || _rearGrounded; } }
        public bool IsAirborne { get { return !IsGrounded; } }
        public float AirTime { get { return _airTime; } }
        public float MaxAirTime { get { return _maxAirTime; } }
        public float LastAirTime { get { return _lastAirTime; } }
        public int LandingCounter { get { return _landingCounter; } }
        public bool IsCrashed { get { return _crashed; } }
        public string CrashReason { get { return _crashReason; } }
        public int CrashCount { get { return _crashCount; } }
        public bool WheelieActive { get { return _wheelie != null && _wheelie.Active; } }
        public bool WheelieInBalanceZone { get { return _wheelie != null && _wheelie.InBalanceZone; } }
        public bool WheelieInDanger { get { return _wheelie != null && _wheelie.InDangerZone; } }
        public float WheelieTargetPitch { get { return _wheelie != null ? _wheelie.TargetPitch : 0f; } }
        public float WheelieBalanceTime { get { return _wheelieBalanceTime; } }
        public bool StoppieActive { get { return _brakeFront > 0.5f && _frontGrounded && !_rearGrounded && SpeedKmh > 6f; } }
        public float StoppieTime { get { return _stoppieTime; } }
        public bool HardBraking { get { return _brakeFront > 0.6f || _brakeRear > 0.6f; } }
        public bool InputEnabled { get { return _inputEnabled; } }
        public float MaxSpeedKmh { get { return Mathf.Min(Spec.GearTopSpeedKmh(SpeedMode), Spec.TopSpeedKmh); } }

        public event Action<string> OnCrash;
        public event Action OnRespawn;

        // ------------------------------------------------------------------------
        public void Initialize(ScooterSpec spec, WheelCollider front, WheelCollider rear,
            Transform frontVisual, Transform rearVisual, Transform steerVisual)
        {
            Spec = spec;
            Body = GetComponent<Rigidbody>();
            FrontWheel = front;
            RearWheel = rear;
            _frontVisual = frontVisual;
            _rearVisual = rearVisual;
            _steerVisual = steerVisual;

            Drive = spec.SupportsAwdToggle ? DriveMode.AWD : DriveMode.RWD;
            SpeedMode = 1; // start in the middle mode, like the real LCD
            _batteryWh = spec.BatteryWh;
            _respawnPosition = transform.position;
            _respawnRotation = transform.rotation;
            _wheelie = new WheelieController(this);

            ApplyFriction(spec.GripRoad, spec.GripRoad);
            UpdateWheelVisuals();
        }

        public void SetSpeedMode(int mode)
        {
            if (Spec == null) return;
            SpeedMode = Mathf.Clamp(mode, 0, Mathf.Max(0, Spec.GearCount - 1));
        }

        public void CycleSpeedMode()
        {
            if (Spec == null || Spec.GearCount == 0) return;
            SpeedMode = (SpeedMode + 1) % Spec.GearCount;
        }

        public void ToggleDrive()
        {
            if (Spec == null || !Spec.SupportsAwdToggle) return;
            Drive = Drive == DriveMode.AWD ? DriveMode.RWD : DriveMode.AWD;
        }

        public void SetInputEnabled(bool enabled)
        {
            _inputEnabled = enabled;
            if (!enabled)
            {
                _throttle = 0f;
                _brakeFront = 0f;
                _brakeRear = 0f;
                _steer = 0f;
            }
        }

        public void SetRespawnPoint(Vector3 position, Quaternion rotation)
        {
            _respawnPosition = position;
            _respawnRotation = rotation;
        }

        public void ApplyNoseUpTorque(float torque, ForceMode mode)
        {
            if (Body == null) return;
            // +X rotation tips the nose down, so a "nose up" torque is negative around X.
            Body.AddRelativeTorque(Vector3.right * (-torque), mode);
        }

        // ------------------------------------------------------------------------
        void FixedUpdate()
        {
            if (Spec == null) return;
            float dt = Time.fixedDeltaTime;

            UpdateKinematics(dt);

            if (_crashed)
            {
                UpdateCrash(dt);
                UpdateWheelVisuals();
                return;
            }

            _runTime += dt;
            ReadInputs(dt);
            ApplyFrictionForGround();
            ApplySteering();
            ApplyAerodynamics();
            ApplyDrive(dt);
            ApplyBrakes();
            ApplyBalance();
            TickWheelie(dt);
            UpdateBattery(dt);
            CheckFailures();
            UpdateWheelVisuals();
        }

        // ---- kinematics --------------------------------------------------------
        void UpdateKinematics(float dt)
        {
            Vector3 velocity = Body.velocity;
            SpeedMps = Vector3.Dot(velocity, transform.forward);

            Vector3 upLocal = transform.InverseTransformDirection(Vector3.up);
            _pitch = Mathf.Atan2(upLocal.z, upLocal.y) * Mathf.Rad2Deg;
            _roll = Mathf.Atan2(upLocal.x, upLocal.y) * Mathf.Rad2Deg;

            Vector3 angularLocal = transform.InverseTransformDirection(Body.angularVelocity);
            _pitchRate = -angularLocal.x * Mathf.Rad2Deg;
            _yawRate = angularLocal.y * Mathf.Rad2Deg;

            _frontGrounded = FrontWheel != null && FrontWheel.GetGroundHit(out _frontHit);
            _rearGrounded = RearWheel != null && RearWheel.GetGroundHit(out _rearHit);

            bool grounded = _frontGrounded || _rearGrounded;
            if (grounded)
            {
                _distanceMeters += Mathf.Max(0f, SpeedMps) * dt;

                if (_airTime > 0.15f)
                {
                    _lastAirTime = _airTime;
                    _landingCounter++;
                }
                _airTime = 0f;
            }
            else
            {
                _airTime += dt;
                if (_airTime > _maxAirTime) _maxAirTime = _airTime;
            }

            if (_wheelie != null && _wheelie.InBalanceZone) _wheelieBalanceTime += dt;
            if (StoppieActive) _stoppieTime += dt;

            // keep the scooter aligned with the ground normal so the wheels stay planted
        }

        // ---- inputs ------------------------------------------------------------
        void ReadInputs(float dt)
        {
            if (!_inputEnabled)
            {
                _throttle = Mathf.MoveTowards(_throttle, 0f, dt * 8f);
                _brakeFront = Mathf.MoveTowards(_brakeFront, 0f, dt * 8f);
                _brakeRear = Mathf.MoveTowards(_brakeRear, 0f, dt * 8f);
                _steer = Mathf.MoveTowards(_steer, 0f, dt * 8f);
                return;
            }

            _throttle = Mathf.MoveTowards(_throttle, Mathf.Clamp01(PlayerInput.Throttle), dt * 7f);
            _brakeFront = Mathf.MoveTowards(_brakeFront, Mathf.Clamp01(PlayerInput.BrakeFront), dt * 12f);
            _brakeRear = Mathf.MoveTowards(_brakeRear, Mathf.Clamp01(PlayerInput.BrakeRear), dt * 12f);
            _steer = Mathf.MoveTowards(_steer, Mathf.Clamp(PlayerInput.Steer, -1f, 1f), dt * 8f);
        }

        // ---- friction ----------------------------------------------------------
        void ApplyFrictionForGround()
        {
            float frontGrip = Spec.GripRoad;
            float rearGrip = Spec.GripRoad;

            if (_frontGrounded)
            {
                float offRoad = GetSurface(_frontHit);
                frontGrip = Mathf.Lerp(Spec.GripRoad, Spec.GripOffRoad, offRoad);
            }
            if (_rearGrounded)
            {
                float offRoad = GetSurface(_rearHit);
                rearGrip = Mathf.Lerp(Spec.GripRoad, Spec.GripOffRoad, offRoad);
            }

            ApplyFriction(frontGrip, rearGrip);
        }

        static float GetSurface(WheelHit hit)
        {
            if (hit.collider == null) return 0f;
            SurfaceMarker marker = hit.collider.GetComponent<SurfaceMarker>();
            if (marker != null) return marker.OffRoadAmount;
            return 0f;
        }

        void ApplyFriction(float frontStiffness, float rearStiffness)
        {
            if (FrontWheel != null) ScooterFactory.ApplyFrictionCurve(FrontWheel, frontStiffness);
            if (RearWheel != null) ScooterFactory.ApplyFrictionCurve(RearWheel, rearStiffness);
        }

        // ---- steering ----------------------------------------------------------
        void ApplySteering()
        {
            float speed = Mathf.Abs(SpeedMps);
            float falloff = Mathf.Lerp(1f, VehicleTuning.SteerMinFactor,
                Mathf.InverseLerp(VehicleTuning.SteerSpeedFalloffStart, VehicleTuning.SteerSpeedFalloffEnd, speed));

            float angle = _steer * Spec.SteerAngleMax * falloff;
            if (FrontWheel != null) FrontWheel.steerAngle = angle;
            if (RearWheel != null) RearWheel.steerAngle = angle * VehicleTuning.RearSteerFactor;

            if (_steerVisual != null)
            {
                // visual yaw of the handlebar, softer than the physical steering
                float visualAngle = angle * 0.85f;
                _steerVisual.localRotation = Quaternion.Euler(0f, visualAngle, 0f);
            }
        }

        // ---- drag --------------------------------------------------------------
        void ApplyAerodynamics()
        {
            float speed = Mathf.Abs(SpeedMps);
            if (speed < 0.4f) return;
            float force = VehicleTuning.AirDragCoefficient * speed * speed;
            Body.AddForce(-transform.forward * Mathf.Sign(SpeedMps) * force, ForceMode.Force);
        }

        // ---- drive -------------------------------------------------------------
        void ApplyDrive(float dt)
        {
            bool awd = Spec.MotorCount == 2 && Drive == DriveMode.AWD;
            int activeMotors = awd ? 2 : 1;

            float topSpeedMps = MaxSpeedKmh / 3.6f;
            float throttle = _throttle;

            float batteryScale = 1f;
            float percent = BatteryPercent;
            if (percent <= 0.01f) batteryScale = 0f;
            else if (percent < VehicleTuning.LowBatteryPercent) batteryScale = VehicleTuning.LowBatteryPowerScale;

            float targetTorque = 0f;
            if (throttle > 0.001f && SpeedMps < topSpeedMps && batteryScale > 0f)
            {
                float power = Spec.PowerPerMotorWatts * activeMotors * batteryScale;
                float vSafe = Mathf.Max(Mathf.Abs(SpeedMps), 1.5f);
                float force = Mathf.Min(power / vSafe, Spec.MaxTractionForcePerMotor * activeMotors);

                float taperStart = topSpeedMps * 0.9f;
                float taper = 1f - Mathf.InverseLerp(taperStart, topSpeedMps + 0.001f, SpeedMps);
                force *= Mathf.Clamp01(taper);

                targetTorque = force * Spec.WheelRadius * throttle;
            }

            float rampStep = Spec.MotorRampRate * Spec.TorqueCeiling * dt;
            _currentTorque = Mathf.MoveTowards(_currentTorque, targetTorque, rampStep);

            if (awd)
            {
                if (FrontWheel != null) FrontWheel.motorTorque = _currentTorque * 0.5f;
                if (RearWheel != null) RearWheel.motorTorque = _currentTorque * 0.5f;
            }
            else
            {
                if (FrontWheel != null) FrontWheel.motorTorque = 0f;
                if (RearWheel != null) RearWheel.motorTorque = _currentTorque;
            }
        }

        // ---- brakes ------------------------------------------------------------
        void ApplyBrakes()
        {
            if (Spec == null) return;

            float frontTorque = Spec.MaxBrakeTorque * _brakeFront;
            float rearTorque = Spec.MaxBrakeTorque * _brakeRear * VehicleTuning.RearBrakeShare;

            // regenerative / electronic brake when the throttle is released
            float regen = 0f;
            if (_throttle < 0.05f && Mathf.Abs(SpeedMps) > 0.8f)
            {
                regen = Spec.RegenBrakeTorque;
            }

            float coast = 0f;
            if (_throttle < 0.05f && _brakeFront < 0.05f && _brakeRear < 0.05f)
            {
                coast = VehicleTuning.RollingResistanceTorque;
            }

            if (FrontWheel != null) FrontWheel.brakeTorque = frontTorque;
            if (RearWheel != null) RearWheel.brakeTorque = rearTorque + regen + coast;

            // A hard front brake at speed can send the rider over the bar (endo risk).
            if (_brakeFront > VehicleTuning.FullFrontBrakeThreshold && SpeedKmh > VehicleTuning.EndoRiskSpeedKmh)
            {
                Body.AddRelativeTorque(Vector3.right * (VehicleTuning.EndoRiskTorque * _brakeFront), ForceMode.Force);
            }
        }

        // ---- balance -----------------------------------------------------------
        void ApplyBalance()
        {
            bool grounded = IsGrounded;
            float support = grounded ? 1f : 0.12f;

            // lean into the turn
            float speedAbs = Mathf.Abs(SpeedMps);
            float leanFactor = Mathf.Clamp01(speedAbs / VehicleTuning.LeanIntoTurnFullSpeed);
            float targetRoll = -_steer * VehicleTuning.LeanIntoTurnMaxAngle * leanFactor;
            float rollError = (targetRoll - _roll) * Mathf.Deg2Rad;
            float rollRate = Vector3.Dot(Body.angularVelocity, transform.forward);

            float rollTorque = rollError * VehicleTuning.RollStabilityGain
                               - rollRate * VehicleTuning.RollStabilityDamping;
            rollTorque *= support;
            rollTorque = Mathf.Clamp(rollTorque, -VehicleTuning.RollMaxTorque, VehicleTuning.RollMaxTorque);
            Body.AddRelativeTorque(Vector3.forward * rollTorque, ForceMode.Force);

            // pitch stabilisation only when the wheelie controller is not in charge
            bool wheelieActive = _wheelie != null && _wheelie.Active;
            if (!wheelieActive && grounded)
            {
                float targetPitch = GetSlopePitch();
                float pitchError = (targetPitch - _pitch) * Mathf.Deg2Rad;
                float pitchRate = _pitchRate * Mathf.Deg2Rad;
                // A locked front brake takes the stabiliser out of the fight, so a long
                // front-only brake at speed can really endo the scooter.
                float stabilityScale = (_brakeFront > 0.8f && SpeedKmh > VehicleTuning.EndoRiskSpeedKmh)
                    ? 0.5f
                    : 1f;

                float noseUp = pitchError * VehicleTuning.PitchStabilityGain * stabilityScale
                               - pitchRate * VehicleTuning.PitchStabilityDamping;
                noseUp = Mathf.Clamp(noseUp, -VehicleTuning.PitchMaxTorque, VehicleTuning.PitchMaxTorque);
                ApplyNoseUpTorque(noseUp, ForceMode.Force);
            }

            Body.AddRelativeTorque(Vector3.up * (-_yawRate * Mathf.Deg2Rad * VehicleTuning.YawDamping), ForceMode.Force);
        }

        /// <summary>Pitch angle (deg, nose up) that matches the slope under the wheels.</summary>
        float GetSlopePitch()
        {
            Vector3 normal;
            if (_frontGrounded && _rearGrounded)
            {
                normal = (_frontHit.normal + _rearHit.normal) * 0.5f;
            }
            else if (_frontGrounded)
            {
                normal = _frontHit.normal;
            }
            else if (_rearGrounded)
            {
                normal = _rearHit.normal;
            }
            else
            {
                return _pitch;
            }

            Vector3 projected = Vector3.ProjectOnPlane(normal, transform.right);
            float forwardComponent = Vector3.Dot(projected, transform.forward);
            float upComponent = Vector3.Dot(projected, Vector3.up);
            float slope = Mathf.Atan2(forwardComponent, Mathf.Max(0.0001f, upComponent)) * Mathf.Rad2Deg;
            return -slope;
        }

        // ---- wheelie -----------------------------------------------------------
        void TickWheelie(float dt)
        {
            if (_wheelie == null) return;
            _wheelie.Tick(dt, PlayerInput.Wheelie, _throttle, PlayerInput.BodyPitch,
                SpeedKmh, Drive, Spec, IsGrounded, _crashed);
        }

        // ---- battery -----------------------------------------------------------
        void UpdateBattery(float dt)
        {
            if (Spec == null) return;

            float speed = Mathf.Abs(SpeedMps);
            float tractiveForce = _currentTorque / Mathf.Max(0.01f, Spec.WheelRadius);
            float mechanicalWatts = tractiveForce * speed;
            float electricalWatts = mechanicalWatts / VehicleTuning.MotorEfficiency;

            if (_throttle > 0.02f) electricalWatts += VehicleTuning.MotorSpinupLossWatts * _throttle;
            electricalWatts += VehicleTuning.IdleDrainWatts;

            bool coasting = _throttle < 0.05f && speed > 1f;
            if (coasting)
            {
                float regenForce = Spec.RegenBrakeTorque / Mathf.Max(0.01f, Spec.WheelRadius);
                float regenWatts = regenForce * speed * Spec.RegenEfficiency;
                electricalWatts -= regenWatts;
            }

            _batteryWh -= electricalWatts * dt / 3600f * GameConfig.BatteryDrainMultiplier;
            _batteryWh = Mathf.Clamp(_batteryWh, 0f, Spec.BatteryWh);
        }

        // ---- failure -----------------------------------------------------------
        void CheckFailures()
        {
            if (_crashed) return;

            if (_wheelie != null && _wheelie.Active && _pitch > VehicleTuning.LoopOutAngle)
            {
                Crash("Loop out — переворот через заднее колесо");
            }
            else if (Mathf.Abs(_roll) > VehicleTuning.FallRollAngle)
            {
                Crash("Потеря равновесия");
            }
            else if (_pitch < VehicleTuning.EndoCrashAngle)
            {
                Crash("Endo — через руль");
            }
        }

        public void Crash(string reason)
        {
            if (_crashed) return;
            _crashed = true;
            _crashCount++;
            _crashReason = reason;
            _crashTimer = 0f;
            SetInputEnabled(false);
            if (_wheelie != null) _wheelie.Reset();

            if (Body != null)
            {
                Body.AddRelativeTorque(new Vector3(
                    UnityEngine.Random.Range(-40f, 40f), 15f, UnityEngine.Random.Range(40f, 90f)), ForceMode.Force);
                Body.AddForce(Vector3.up * (Spec.MassKg * 1.2f), ForceMode.Force);
            }

            if (OnCrash != null) OnCrash(reason);
        }

        void UpdateCrash(float dt)
        {
            _crashTimer += dt;
            if (Body != null)
            {
                FrontWheel.brakeTorque = 0f;
                RearWheel.brakeTorque = 0f;
                FrontWheel.motorTorque = 0f;
                RearWheel.motorTorque = 0f;
            }
            if (_crashTimer >= GameConfig.RespawnDelay)
            {
                Respawn();
            }
        }

        public void Respawn()
        {
            _crashed = false;
            _crashTimer = 0f;
            _crashReason = string.Empty;
            _currentTorque = 0f;
            _airTime = 0f;
            _throttle = 0f;
            _brakeFront = 0f;
            _brakeRear = 0f;
            _steer = 0f;
            if (_wheelie != null) _wheelie.Reset();

            if (Body != null)
            {
                Body.velocity = Vector3.zero;
                Body.angularVelocity = Vector3.zero;
            }
            transform.position = _respawnPosition;
            transform.rotation = _respawnRotation;
            if (Body != null) Body.WakeUp();

            SetInputEnabled(true);
            UpdateWheelVisuals();
            if (OnRespawn != null) OnRespawn();
        }

        // ---- visuals -----------------------------------------------------------
        void UpdateWheelVisuals()
        {
            if (FrontWheel != null && _frontVisual != null)
            {
                Vector3 position;
                Quaternion rotation;
                FrontWheel.GetWorldPose(out position, out rotation);
                _frontVisual.position = position;
                _frontVisual.rotation = rotation;
            }

            if (RearWheel != null && _rearVisual != null)
            {
                Vector3 position;
                Quaternion rotation;
                RearWheel.GetWorldPose(out position, out rotation);
                _rearVisual.position = position;
                _rearVisual.rotation = rotation;
            }
        }

        // ---- collisions --------------------------------------------------------
        void OnCollisionEnter(Collision collision)
        {
            if (_crashed || Body == null) return;
            if (collision.contactCount <= 0) return;

            float impact = collision.relativeVelocity.magnitude;
            if (impact < VehicleTuning.HardImpactSpeed) return;

            for (int i = 0; i < collision.contactCount; i++)
            {
                Vector3 normal = collision.GetContact(i).normal;
                if (Mathf.Abs(normal.y) < 0.55f)
                {
                    Crash("Столкновение на скорости");
                    return;
                }
            }
        }
    }

    /// <summary>Marks a collider as asphalt / dirt / grass and how much grip it removes.</summary>
    public class SurfaceMarker : MonoBehaviour
    {
        [Range(0f, 1f)] public float OffRoadAmount = 0f;

        public SurfaceMarker Configure(float offRoadAmount)
        {
            OffRoadAmount = Mathf.Clamp01(offRoadAmount);
            return this;
        }
    }
}
