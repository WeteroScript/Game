using System.Collections.Generic;
using UnityEngine;

namespace ScooterGame
{
    public class WorldContext
    {
        public MapId Map;
        public Transform Root;
        public Vector3 SpawnPosition;
        public Quaternion SpawnRotation = Quaternion.identity;
        public readonly List<Checkpoint> Checkpoints = new List<Checkpoint>();

        public void Destroy()
        {
            Checkpoints.Clear();
            if (Root == null) return;
            // deactivate first: Object.Destroy is deferred, and the old wheels would keep
            // simulating (and colliding with the new scooter) for the rest of the frame
            Root.gameObject.SetActive(false);
            Object.Destroy(Root.gameObject);
        }
    }

    public static class WorldBuilder
    {
        public static WorldContext Build(MapId map)
        {
            WorldContext context = new WorldContext();
            context.Map = map;

            GameObject root = new GameObject("World_" + map);
            context.Root = root.transform;

            if (map == MapId.StraightTrack)
            {
                TrackMap.Build(context);
            }
            else
            {
                CityMap.Build(context);
            }

            SkyAndLighting.Apply(map, context.Root);
            return context;
        }
    }
}
