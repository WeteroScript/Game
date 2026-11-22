using System.Collections.Generic;
using UnityEngine;

namespace ScooterGame
{
    /// <summary>
    /// Small helpers on top of Unity primitives. Everything is built at runtime so the
    /// repository stays free of binary assets and the scene file stays tiny.
    /// </summary>
    public static class MeshUtil
    {
        // ---- primitives --------------------------------------------------------

        public static GameObject Box(Transform parent, string name, Vector3 localPos, Vector3 size, Material mat)
        {
            return Box(parent, name, localPos, size, mat, Quaternion.identity);
        }

        public static GameObject Box(Transform parent, string name, Vector3 localPos, Vector3 size, Material mat, Quaternion localRot)
        {
            GameObject go = GameObject.CreatePrimitive(PrimitiveType.Cube);
            go.name = name;
            StripCollider(go);
            go.transform.SetParent(parent, false);
            go.transform.localPosition = localPos;
            go.transform.localRotation = localRot;
            go.transform.localScale = size;
            ApplyMaterial(go, mat);
            return go;
        }

        // ---- solid variants (keep the primitive collider) ----------------------

        /// <summary>Like <see cref="Box"/> but keeps the BoxCollider: use for anything drivable or solid.</summary>
        public static GameObject SolidBox(Transform parent, string name, Vector3 localPos, Vector3 size, Material mat)
        {
            return SolidBox(parent, name, localPos, size, mat, Quaternion.identity);
        }

        public static GameObject SolidBox(Transform parent, string name, Vector3 localPos, Vector3 size, Material mat, Quaternion localRot)
        {
            GameObject go = GameObject.CreatePrimitive(PrimitiveType.Cube);
            go.name = name;
            go.transform.SetParent(parent, false);
            go.transform.localPosition = localPos;
            go.transform.localRotation = localRot;
            go.transform.localScale = size;
            ApplyMaterial(go, mat);
            return go;
        }

        /// <summary>Like <see cref="Cylinder"/> but keeps the primitive collider.</summary>
        public static GameObject SolidCylinder(Transform parent, string name, Vector3 localPos, float radius, float height,
            Material mat, Quaternion localRot)
        {
            GameObject go = GameObject.CreatePrimitive(PrimitiveType.Cylinder);
            go.name = name;
            go.transform.SetParent(parent, false);
            go.transform.localPosition = localPos;
            go.transform.localRotation = localRot;
            go.transform.localScale = new Vector3(radius * 2f, height * 0.5f, radius * 2f);
            ApplyMaterial(go, mat);
            return go;
        }

        /// <summary>Cylinder along the local Y axis of the returned object, length = height.</summary>
        public static GameObject Cylinder(Transform parent, string name, Vector3 localPos, float radius, float height, Material mat)
        {
            return Cylinder(parent, name, localPos, radius, height, mat, Quaternion.identity);
        }

        public static GameObject Cylinder(Transform parent, string name, Vector3 localPos, float radius, float height, Material mat, Quaternion localRot)
        {
            GameObject go = GameObject.CreatePrimitive(PrimitiveType.Cylinder);
            go.name = name;
            StripCollider(go);
            go.transform.SetParent(parent, false);
            go.transform.localPosition = localPos;
            go.transform.localRotation = localRot;
            go.transform.localScale = new Vector3(radius * 2f, height * 0.5f, radius * 2f);
            ApplyMaterial(go, mat);
            return go;
        }

        /// <summary>Cylinder lying along the X axis (wheels, axles, handlebars).</summary>
        public static GameObject Axle(Transform parent, string name, Vector3 localPos, float radius, float length, Material mat)
        {
            return Cylinder(parent, name, localPos, radius, length, mat, Quaternion.Euler(0f, 0f, 90f));
        }

        public static GameObject Sphere(Transform parent, string name, Vector3 localPos, float radius, Material mat)
        {
            GameObject go = GameObject.CreatePrimitive(PrimitiveType.Sphere);
            go.name = name;
            StripCollider(go);
            go.transform.SetParent(parent, false);
            go.transform.localPosition = localPos;
            go.transform.localScale = Vector3.one * (radius * 2f);
            ApplyMaterial(go, mat);
            return go;
        }

        public static GameObject Empty(Transform parent, string name, Vector3 localPos)
        {
            GameObject go = new GameObject(name);
            go.transform.SetParent(parent, false);
            go.transform.localPosition = localPos;
            go.transform.localRotation = Quaternion.identity;
            go.transform.localScale = Vector3.one;
            return go;
        }

        public static void StripCollider(GameObject go)
        {
            Collider col = go.GetComponent<Collider>();
            if (col != null)
            {
                col.enabled = false;
                Object.Destroy(col);
            }
        }

        public static void ApplyMaterial(GameObject go, Material mat, bool castShadows = true, bool receiveShadows = true)
        {
            if (mat == null) return;
            Renderer r = go.GetComponent<Renderer>();
            if (r == null) return;
            r.sharedMaterial = mat;
            r.shadowCastingMode = castShadows
                ? UnityEngine.Rendering.ShadowCastingMode.On
                : UnityEngine.Rendering.ShadowCastingMode.Off;
            r.receiveShadows = receiveShadows;
        }

        // ---- custom meshes -----------------------------------------------------

        /// <summary>
        /// Driveable ramp: flat ground at z = 0, rising to <paramref name="height"/> at z = length.
        /// Returns a GameObject with a mesh, renderer and a convex MeshCollider.
        /// </summary>
        public static GameObject Ramp(Transform parent, string name, Vector3 localPos, float width, float length, float height, Material mat, float yaw = 0f)
        {
            Mesh mesh = CreateWedgeMesh(width, length, height);
            GameObject go = new GameObject(name);
            go.transform.SetParent(parent, false);
            go.transform.localPosition = localPos;
            go.transform.localRotation = Quaternion.Euler(0f, yaw, 0f);

            MeshFilter filter = go.AddComponent<MeshFilter>();
            filter.sharedMesh = mesh;
            MeshRenderer renderer = go.AddComponent<MeshRenderer>();
            renderer.sharedMaterial = mat;
            renderer.shadowCastingMode = UnityEngine.Rendering.ShadowCastingMode.On;

            MeshCollider collider = go.AddComponent<MeshCollider>();
            collider.sharedMesh = mesh;
            collider.convex = true;
            return go;
        }

        public static Mesh CreateWedgeMesh(float width, float length, float height)
        {
            float hw = width * 0.5f;
            Vector3[] v = new Vector3[6];
            v[0] = new Vector3(-hw, 0f, 0f);
            v[1] = new Vector3(hw, 0f, 0f);
            v[2] = new Vector3(hw, 0f, length);
            v[3] = new Vector3(-hw, 0f, length);
            v[4] = new Vector3(-hw, height, length);
            v[5] = new Vector3(hw, height, length);

            List<int> tris = new List<int>(36);
            // ramp surface (outward normal points up / backwards)
            AddQuad(tris, v, 0, 1, 5, 4, (Vector3.up + Vector3.back).normalized);
            // bottom (outward points down)
            AddQuad(tris, v, 3, 2, 1, 0, Vector3.down);
            // vertical back face
            AddQuad(tris, v, 4, 5, 2, 3, Vector3.forward);
            // left side
            AddQuad(tris, v, 0, 4, 3, 3, Vector3.left);
            // right side
            AddQuad(tris, v, 1, 2, 5, 5, Vector3.right);

            Mesh mesh = new Mesh();
            mesh.name = "Wedge";
            mesh.vertices = v;
            mesh.triangles = tris.ToArray();
            mesh.RecalculateNormals();
            mesh.RecalculateBounds();
            return mesh;
        }

        /// <summary>
        /// Adds a quad with a guaranteed outward winding. Degenerate quads (a == d) are
        /// used for the side triangles of the wedge.
        /// </summary>
        static void AddQuad(List<int> tris, Vector3[] verts, int a, int b, int c, int d, Vector3 outward)
        {
            Vector3 n = Vector3.Cross(verts[b] - verts[a], verts[c] - verts[a]);
            bool flip = Vector3.Dot(n, outward) < 0f;

            if (!flip)
            {
                tris.Add(a); tris.Add(b); tris.Add(c);
                if (d != c) { tris.Add(a); tris.Add(c); tris.Add(d); }
            }
            else
            {
                tris.Add(a); tris.Add(c); tris.Add(b);
                if (d != c) { tris.Add(a); tris.Add(d); tris.Add(c); }
            }
        }

        // ---- lighting ----------------------------------------------------------

        public static Light AddPointLight(Transform parent, string name, Vector3 localPos, Color color, float intensity, float range, bool shadows = false)
        {
            GameObject go = new GameObject(name);
            go.transform.SetParent(parent, false);
            go.transform.localPosition = localPos;
            Light light = go.AddComponent<Light>();
            light.type = LightType.Point;
            light.color = color;
            light.intensity = intensity;
            light.range = range;
            light.shadows = shadows ? LightShadows.Soft : LightShadows.None;
            light.renderMode = LightRenderMode.ForceVertex;
            return light;
        }

        public static Light AddSpotLight(Transform parent, string name, Vector3 localPos, Quaternion localRot, Color color, float intensity, float range, float angle)
        {
            GameObject go = new GameObject(name);
            go.transform.SetParent(parent, false);
            go.transform.localPosition = localPos;
            go.transform.localRotation = localRot;
            Light light = go.AddComponent<Light>();
            light.type = LightType.Spot;
            light.color = color;
            light.intensity = intensity;
            light.range = range;
            light.spotAngle = angle;
            light.shadows = LightShadows.None;
            return light;
        }
    }
}
