using System;
using NUnit.Framework;
using CarIdle.Core;

namespace CarIdle.Core.Tests
{
    /// <summary>Le relief doit rester roulable : pas de marche, des zones à leur place, la mer à l'est.</summary>
    public class WorldLayoutTests
    {
        private const float Half = WorldLayout.Size / 2f;

        [Test]
        public void NoCliffsAnywhere()
        {
            // Pas de 2 m (la résolution du terrain) : jamais plus de 1,6 m de dénivelé, soit une pente < 39°.
            float worst = 0f;
            for (float x = -Half; x < Half - 2f; x += 2f)
            {
                for (float z = -Half; z < Half - 2f; z += 6f)
                {
                    float h = WorldLayout.Height(x, z);
                    worst = Math.Max(worst, Math.Abs(WorldLayout.Height(x + 2f, z) - h));
                    worst = Math.Max(worst, Math.Abs(WorldLayout.Height(x, z + 2f) - h));
                }
            }
            Assert.That(worst, Is.LessThan(1.6f), "pire dénivelé : " + worst);
        }

        [Test]
        public void CityIsFlat()
        {
            for (float x = -Half; x < WorldLayout.CityEnd - 30f; x += 7f)
            {
                for (float z = -Half; z < Half; z += 13f)
                    Assert.That(WorldLayout.Height(x, z), Is.EqualTo(WorldLayout.GroundLevel).Within(1e-4f));
            }
        }

        [Test]
        public void ZonesAreInOrderFromWestToEast()
        {
            Assert.AreEqual(Surface.Asphalt, At(-400f, 0f));
            Assert.AreEqual(Surface.Dirt, At(-20f, 0f));
            Assert.AreEqual(Surface.Sand, At(250f, 0f));
            Assert.AreEqual(Surface.Water, At(480f, 0f));
        }

        [Test]
        public void SeaIsBelowSeaLevelAndLandAbove()
        {
            for (float z = -Half; z < Half; z += 20f)
            {
                Assert.That(WorldLayout.Height(Half - 5f, z), Is.LessThan(WorldLayout.SeaLevel - 1f), "mer à l'est");
                Assert.That(WorldLayout.Height(WorldLayout.DunesEnd - 40f, z), Is.GreaterThan(WorldLayout.SeaLevel + 1f), "dunes au sec");
            }
        }

        [Test]
        public void SpawnIsOnDrySand()
        {
            float h = WorldLayout.Height(WorldLayout.SpawnX, WorldLayout.SpawnZ);
            Assert.That(h, Is.GreaterThan(WorldLayout.SeaLevel + 1f));
            Assert.AreEqual(Surface.Sand, WorldLayout.SurfaceAt(WorldLayout.SpawnX, WorldLayout.SpawnZ, h));
        }

        [Test]
        public void HeightsFitInTerrainRange()
        {
            for (float x = -Half; x <= Half; x += 5f)
            {
                for (float z = -Half; z <= Half; z += 11f)
                {
                    float h = WorldLayout.Height(x, z);
                    Assert.That(h, Is.InRange(0.5f, WorldLayout.MaxHeight - 0.5f));
                }
            }
        }

        [Test]
        public void GripOrder()
        {
            Assert.That(WorldLayout.Grip(Surface.Asphalt), Is.GreaterThan(WorldLayout.Grip(Surface.Dirt)));
            Assert.That(WorldLayout.Grip(Surface.Dirt), Is.GreaterThan(WorldLayout.Grip(Surface.Sand)));
            Assert.That(WorldLayout.Grip(Surface.Sand), Is.GreaterThan(WorldLayout.Grip(Surface.Water)));
        }

        [Test]
        public void CityHasStreetsAndBlocks()
        {
            Assert.IsTrue(WorldLayout.IsStreet(5f, 30f));
            Assert.IsTrue(WorldLayout.IsStreet(30f, 5f));
            Assert.IsFalse(WorldLayout.IsStreet(40f, 40f));
        }

        private static Surface At(float x, float z)
        {
            return WorldLayout.SurfaceAt(x, z, WorldLayout.Height(x, z));
        }
    }
}
