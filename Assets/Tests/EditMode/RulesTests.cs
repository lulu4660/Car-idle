using System.Collections.Generic;
using System.Linq;
using NUnit.Framework;
using CarIdle.Core;

namespace CarIdle.Core.Tests
{
    /// <summary>Règles du GDD vérifiées sur leurs propriétés, en plus des valeurs de référence.</summary>
    public class RulesTests
    {
        [Test]
        public void CostGrowsBy10PercentPerLevel()
        {
            for (int r = 0; r < Economy.BaseIncome.Length; r++)
            {
                for (int l = 0; l < 199; l++)
                    Assert.That(Economy.PartCost(r, l + 1) / Economy.PartCost(r, l), Is.EqualTo(1.10).Within(1e-12));
            }
        }

        [Test]
        public void IncomeIsLinearAndDoublesAtMilestones()
        {
            var levels = new int[10];
            levels[0] = 24;
            double before = Economy.CarIncome(0, levels);
            levels[0] = 25;
            double after = Economy.CarIncome(0, levels);
            // Niveau 24 : (1 + 24) × 1 ; niveau 25 : (1 + 25) × 2, plus 9 pièces au niveau 0.
            Assert.That(before, Is.EqualTo(0.1 * (25 + 9)).Within(1e-12));
            Assert.That(after, Is.EqualTo(0.1 * (52 + 9)).Within(1e-12));
        }

        [Test]
        public void PartsAddUpAndNeverMultiply()
        {
            var a = new int[10];
            a[0] = 200;
            var b = new int[10];
            b[1] = 200;
            var both = new int[10];
            both[0] = 200;
            both[1] = 200;
            double zero = Economy.CarIncome(3, new int[10]);
            double sum = Economy.CarIncome(3, a) + Economy.CarIncome(3, b) - zero;
            Assert.That(Economy.CarIncome(3, both), Is.EqualTo(sum).Within(1e-9));
        }

        [Test]
        public void MaxAffordableNeverOverspends()
        {
            foreach (double budget in new[] { 20.0, 999.0, 1.0e6, 3.3e9, 7.7e15 })
            {
                for (int r = 0; r < 6; r++)
                {
                    foreach (int level in new[] { 0, 10, 50, 120, 199 })
                    {
                        int n = Economy.MaxAffordable(r, level, budget);
                        Assert.That(level + n, Is.LessThanOrEqualTo(Economy.MaxLevel));
                        Assert.That(Economy.CostForLevels(r, level, n), Is.LessThanOrEqualTo(budget * (1 + 1e-12)));
                        if (level + n < Economy.MaxLevel)
                            Assert.That(Economy.CostForLevels(r, level, n + 1), Is.GreaterThan(budget));
                    }
                }
            }
        }

        [Test]
        public void SpotChancesSumToOne()
        {
            Assert.That(Economy.SpotChance.Sum(), Is.EqualTo(1.0).Within(1e-12));
        }

        [Test]
        public void OfflineGainIsCappedAt8Hours()
        {
            Assert.That(Economy.OfflineGain(1.0, 1.0e9), Is.EqualTo(Economy.OfflineGain(1.0, 8 * 3600)));
        }

        [Test]
        public void SkillTreeHas4BranchesOf6()
        {
            foreach (var branch in Progression.Branches)
                Assert.AreEqual(6, Progression.BranchSkills(branch).Count, branch);
            Assert.AreEqual("", Progression.Prerequisite("r1"));
            Assert.AreEqual("r1", Progression.Prerequisite("r2"));
            Assert.AreEqual(1700, Progression.Skills.Sum(s => s.Cost));
        }

        [Test]
        public void SkillEffectsAddOrMultiply()
        {
            var fx = Progression.EffectsOf(new[] { "r1", "r3", "a1", "a3" });
            Assert.That(fx["income_bonus"], Is.EqualTo(0.35).Within(1e-12));
            Assert.That(fx["upgrade_cost_mult"], Is.EqualTo(0.90 * 0.85).Within(1e-12));
            Assert.That(fx["extra_spots"], Is.EqualTo(0.0));
        }

        [Test]
        public void DailyMissionsAreStableAndDistinct()
        {
            var a = Progression.DailyMissions("2026-11-11");
            var b = Progression.DailyMissions("2026-11-11");
            Assert.AreEqual(3, a.Count);
            CollectionAssert.AreEqual(a.Select(m => m.Id + m.Target), b.Select(m => m.Id + m.Target));
            Assert.AreEqual(3, a.Select(m => m.Id).Distinct().Count());
            var days = new HashSet<string>();
            for (int d = 1; d <= 28; d++)
                days.Add(string.Join(",", Progression.DailyMissions("2026-02-" + d.ToString("00")).Select(m => m.Id + m.Target)));
            Assert.That(days.Count, Is.GreaterThan(10), "les missions doivent changer d'un jour à l'autre");
        }

        [Test]
        public void CatalogHas32UniqueCarsWithEveryRarity()
        {
            Assert.AreEqual(32, Catalog.Cars.Length);
            Assert.AreEqual(32, Catalog.Cars.Select(c => c.Id).Distinct().Count());
            for (int r = 0; r < 6; r++)
                Assert.That(Catalog.ByRarity(r).Count, Is.GreaterThan(0));
            Assert.AreEqual("Renolt Clia 5", Catalog.Get("clia5").DisplayName);
        }

        [Test]
        public void SeriesMatchCatalogCars()
        {
            var france = Progression.AllSeries.First(s => s.Id == "fr");
            int count = Catalog.Cars.Count(c => Progression.InSeries(france, c));
            Assert.That(count, Is.GreaterThanOrEqualTo(france.Tiers[2]), "la série doit pouvoir être complétée avec le catalogue");
        }
    }
}
