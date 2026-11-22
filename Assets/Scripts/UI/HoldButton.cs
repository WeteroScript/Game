using UnityEngine;
using UnityEngine.EventSystems;

namespace ScooterGame
{
    /// <summary>
    /// Press-and-hold button that works with several fingers at once (each pointer keeps
    /// its own id, so gas + steering + wheelie can be held simultaneously).
    /// </summary>
    public class HoldButton : MonoBehaviour, IPointerDownHandler, IPointerUpHandler
    {
        const int NoPointer = -9999;

        int _pointerId = NoPointer;

        public bool IsHeld { get; private set; }

        public void OnPointerDown(PointerEventData eventData)
        {
            _pointerId = eventData.pointerId;
            IsHeld = true;
        }

        public void OnPointerUp(PointerEventData eventData)
        {
            if (eventData.pointerId == _pointerId)
            {
                IsHeld = false;
                _pointerId = NoPointer;
            }
        }

        void OnDisable()
        {
            IsHeld = false;
            _pointerId = NoPointer;
        }
    }
}
