using System;
using UnityEngine;

namespace ScooterGame
{
    /// <summary>
    /// Detects wheelies, stoppies, jumps and spins, and turns them into score + combo.
    /// A trick keeps the combo alive for <see cref="ComboWindow"/> seconds.
    /// </summary>
    public class TrickSystem
    {
        public const float ComboWindow = 2.5f;
        public const float MaxMultiplier = 5f;

        public int Score { get; private set; }
        public int Combo { get; private set; }
        public float ComboTimeLeft { get; private set; }
        public string LastTrick { get; private set; }
        public int LastTrickPoints { get; private set; }
        public int TrickCount { get; private set; }

        public float ComboMultiplier
        {
            get { return Mathf.Min(MaxMultiplier, 1f + Combo * 0.15f); }
        }

        public event Action<string, int> OnTrick;

        float _wheelieAccum;
        float _stoppieAccum;
        float _airYaw;
        int _lastLandingCounter;
        int _lastWheelieFloors;
        int _lastStoppieFloors;

        public TrickSystem()
        {
            LastTrick = string.Empty;
        }

        public void Tick(float dt, ScooterController scooter)
        {
            if (scooter == null) return;

            if (ComboTimeLeft > 0f)
            {
                ComboTimeLeft -= dt;
                if (ComboTimeLeft <= 0f)
                {
                    ComboTimeLeft = 0f;
                    Combo = 0;
                }
            }

            TickWheelie(scooter);
            TickStoppie(scooter);
            TickAir(scooter, dt);
        }

        void TickWheelie(ScooterController scooter)
        {
            if (scooter.WheelieInBalanceZone)
            {
                _wheelieAccum += Time.deltaTime;
                // small ticks while balancing keep the combo alive
                int floors = Mathf.FloorToInt(_wheelieAccum / 0.5f);
                if (floors > _lastWheelieFloors)
                {
                    _lastWheelieFloors = floors;
                    AddScore("WHEELIE", 10);
                }
            }
            else
            {
                if (_wheelieAccum >= 0.45f && !scooter.IsCrashed)
                {
                    int points = Mathf.RoundToInt(_wheelieAccum * 35f);
                    AddScore("WHEELIE " + _wheelieAccum.ToString("0.0") + " c", points);
                }
                _wheelieAccum = 0f;
                _lastWheelieFloors = 0;
            }
        }

        void TickStoppie(ScooterController scooter)
        {
            if (scooter.StoppieActive)
            {
                _stoppieAccum += Time.deltaTime;
                int floors = Mathf.FloorToInt(_stoppieAccum / 0.4f);
                if (floors > _lastStoppieFloors)
                {
                    _lastStoppieFloors = floors;
                    AddScore("STOPPIE", 12);
                }
            }
            else
            {
                if (_stoppieAccum >= 0.35f && !scooter.IsCrashed)
                {
                    int points = Mathf.RoundToInt(_stoppieAccum * 45f);
                    AddScore("STOPPIE " + _stoppieAccum.ToString("0.0") + " c", points);
                }
                _stoppieAccum = 0f;
                _lastStoppieFloors = 0;
            }
        }

        void TickAir(ScooterController scooter, float dt)
        {
            if (scooter.IsAirborne)
            {
                _airYaw += scooter.YawRate * dt;
            }
            else if (scooter.LandingCounter != _lastLandingCounter)
            {
                _lastLandingCounter = scooter.LandingCounter;

                float airTime = scooter.LastAirTime;
                if (airTime >= 0.3f)
                {
                    int points = Mathf.RoundToInt(airTime * 110f);
                    AddScore("JUMP " + airTime.ToString("0.0") + " c", points);
                }

                float spins = Mathf.Abs(_airYaw);
                if (spins >= 150f)
                {
                    int halfTurns = Mathf.FloorToInt(spins / 180f);
                    AddScore(halfTurns > 1 ? ("SPIN x" + halfTurns) : "SPIN", 55 * halfTurns);
                }

                _airYaw = 0f;
            }
        }

        void AddScore(string trickName, int points)
        {
            if (points <= 0) return;

            int gained = Mathf.RoundToInt(points * ComboMultiplier);
            Score += gained;
            TrickCount++;
            Combo = Mathf.Clamp(Combo + 1, 0, 999);
            ComboTimeLeft = ComboWindow;
            LastTrick = trickName;
            LastTrickPoints = gained;

            if (OnTrick != null) OnTrick(trickName, gained);
        }

        public void BreakCombo()
        {
            Combo = 0;
            ComboTimeLeft = 0f;
            _wheelieAccum = 0f;
            _stoppieAccum = 0f;
            _lastWheelieFloors = 0;
            _lastStoppieFloors = 0;
            _airYaw = 0f;
        }
    }
}
