// Généré à partir du prototype Godot (scripts/economy.gd, scripts/progression.gd) le 11 novembre 2026.
// Ces valeurs vérifient que le portage C# donne exactement les mêmes résultats que le prototype.
// Seule différence voulue : FormatNumber(9.96) donne « 10 » (le prototype affichait « 9 »).
using NUnit.Framework;
using CarIdle.Core;

namespace CarIdle.Core.Tests
{
    public class ReferenceValuesTests
    {
        private static void Near(double expected, double actual)
        {
            Assert.That(actual, Is.EqualTo(expected).Within(System.Math.Abs(expected) * 1e-12 + 1e-12));
        }

        [Test]
        public void PartCost()
        {
            Near(20.0, Economy.PartCost(0, 0));
            Near(22.0, Economy.PartCost(0, 1));
            Near(196.994653516153, Economy.PartCost(0, 24));
            Near(216.694118867768, Economy.PartCost(0, 25));
            Near(250556.587996771, Economy.PartCost(0, 99));
            Near(32354356.7155242, Economy.PartCost(0, 150));
            Near(3452823208.37209, Economy.PartCost(0, 199));
            Near(50.0, Economy.PartCost(1, 0));
            Near(55.0, Economy.PartCost(1, 1));
            Near(492.486633790381, Economy.PartCost(1, 24));
            Near(541.73529716942, Economy.PartCost(1, 25));
            Near(626391.469991926, Economy.PartCost(1, 99));
            Near(80885891.7888105, Economy.PartCost(1, 150));
            Near(8632058020.93022, Economy.PartCost(1, 199));
            Near(120.0, Economy.PartCost(2, 0));
            Near(132.0, Economy.PartCost(2, 1));
            Near(1181.96792109692, Economy.PartCost(2, 24));
            Near(1300.16471320661, Economy.PartCost(2, 25));
            Near(1503339.52798062, Economy.PartCost(2, 99));
            Near(194126140.293145, Economy.PartCost(2, 150));
            Near(20716939250.2325, Economy.PartCost(2, 199));
            Near(300.0, Economy.PartCost(3, 0));
            Near(330.0, Economy.PartCost(3, 1));
            Near(2954.91980274229, Economy.PartCost(3, 24));
            Near(3250.41178301652, Economy.PartCost(3, 25));
            Near(3758348.81995156, Economy.PartCost(3, 99));
            Near(485315350.732863, Economy.PartCost(3, 150));
            Near(51792348125.5813, Economy.PartCost(3, 199));
            Near(800.0, Economy.PartCost(4, 0));
            Near(880.0, Economy.PartCost(4, 1));
            Near(7879.7861406461, Economy.PartCost(4, 24));
            Near(8667.76475471072, Economy.PartCost(4, 25));
            Near(10022263.5198708, Economy.PartCost(4, 99));
            Near(1294174268.62097, Economy.PartCost(4, 150));
            Near(138112928334.884, Economy.PartCost(4, 199));
            Near(2000.0, Economy.PartCost(5, 0));
            Near(2200.0, Economy.PartCost(5, 1));
            Near(19699.4653516153, Economy.PartCost(5, 24));
            Near(21669.4118867768, Economy.PartCost(5, 25));
            Near(25055658.7996771, Economy.PartCost(5, 99));
            Near(3235435671.55242, Economy.PartCost(5, 150));
            Near(345282320837.209, Economy.PartCost(5, 199));
        }

        [Test]
        public void CostForLevels()
        {
            Near(20.0, Economy.CostForLevels(0, 0, 1));
            Near(318.74849202, Economy.CostForLevels(0, 0, 10));
            Near(205931.688242871, Economy.CostForLevels(2, 30, 25));
            Near(3797829916962.5, Economy.CostForLevels(5, 100, 100));
            Near(0.0, Economy.CostForLevels(1, 5, 0));
        }

        [Test]
        public void MaxAffordable()
        {
            Assert.AreEqual(0, Economy.MaxAffordable(0, 0, 19.0));
            Assert.AreEqual(1, Economy.MaxAffordable(0, 0, 20.0));
            Assert.AreEqual(18, Economy.MaxAffordable(0, 0, 1000.0));
            Assert.AreEqual(93, Economy.MaxAffordable(3, 40, 1000000000.0));
            Assert.AreEqual(10, Economy.MaxAffordable(5, 190, 9.999999999999999e29));
            Assert.AreEqual(0, Economy.MaxAffordable(0, 200, 1000000000.0));
            Assert.AreEqual(48, Economy.MaxAffordable(2, 0, 123456.0));
        }

        [Test]
        public void CarIncome()
        {
            Near(1.0, Economy.CarIncome(0, new[] { 0, 0, 0, 0, 0, 0, 0, 0, 0, 0 }));
            Near(36.6, Economy.CarIncome(2, new[] { 25, 0, 0, 0, 0, 0, 0, 0, 0, 0 }));
            Near(39768.0, Economy.CarIncome(4, new[] { 200, 150, 100, 50, 25, 24, 1, 0, 0, 0 }));
            Near(352320.0, Economy.CarIncome(5, new[] { 199, 199, 199, 199, 199, 199, 199, 199, 199, 200 }));
        }

        [Test]
        public void SlotCost()
        {
            Near(100.0, Economy.SlotCost(3));
            Near(500.0, Economy.SlotCost(4));
            Near(7812500.0, Economy.SlotCost(10));
            Near(76293945312500.0, Economy.SlotCost(20));
        }

        [Test]
        public void OfflineGain()
        {
            Near(600.0, Economy.OfflineGain(10.0, 60.0));
            Near(72000.0, Economy.OfflineGain(10.0, 7200.0));
            Near(86000.0, Economy.OfflineGain(10.0, 10000.0));
            Near(180000.0, Economy.OfflineGain(10.0, 50000.0));
            Near(0.0, Economy.OfflineGain(3.5, -5.0));
            Near(222000.0, Economy.OfflineGain(10.0, 30000.0, 14400.0, 43200.0));
        }

        [Test]
        public void RollRarity()
        {
            Assert.AreEqual(0, Economy.RollRarity(0.0));
            Assert.AreEqual(0, Economy.RollRarity(0.59));
            Assert.AreEqual(1, Economy.RollRarity(0.6));
            Assert.AreEqual(1, Economy.RollRarity(0.849));
            Assert.AreEqual(2, Economy.RollRarity(0.85));
            Assert.AreEqual(2, Economy.RollRarity(0.949));
            Assert.AreEqual(3, Economy.RollRarity(0.95));
            Assert.AreEqual(3, Economy.RollRarity(0.989));
            Assert.AreEqual(4, Economy.RollRarity(0.99));
            Assert.AreEqual(4, Economy.RollRarity(0.9989));
            Assert.AreEqual(5, Economy.RollRarity(0.999));
            Assert.AreEqual(5, Economy.RollRarity(0.99999));
        }

        [Test]
        public void SpotGain()
        {
            Near(1200.0, Economy.SpotGain(0, 0.0));
            Near(900000.0, Economy.SpotGain(3, 250.0));
            Near(14400000000.0, Economy.SpotGain(5, 1000000.0));
        }

        [Test]
        public void TapGain()
        {
            Near(1.0, Economy.TapGain(0.0));
            Near(5.0, Economy.TapGain(100.0));
            Near(50000000.0, Economy.TapGain(1000000000.0));
        }

        [Test]
        public void FormatNumber()
        {
            Assert.AreEqual("0", Economy.FormatNumber(0.0));
            Assert.AreEqual("3", Economy.FormatNumber(3.0));
            Assert.AreEqual("3,4", Economy.FormatNumber(3.4));
            Assert.AreEqual("10", Economy.FormatNumber(9.96));
            Assert.AreEqual("999", Economy.FormatNumber(999.0));
            Assert.AreEqual("1,00 K", Economy.FormatNumber(1000.0));
            Assert.AreEqual("12,3 K", Economy.FormatNumber(12345.0));
            Assert.AreEqual("999 K", Economy.FormatNumber(999949.0));
            Assert.AreEqual("1,00 M", Economy.FormatNumber(999950.0));
            Assert.AreEqual("1,84 M", Economy.FormatNumber(1840000.0));
            Assert.AreEqual("5,00 B", Economy.FormatNumber(5000000000.0));
            Assert.AreEqual("1,00 T", Economy.FormatNumber(1000000000000.0));
            Assert.AreEqual("2,50 aa", Economy.FormatNumber(2500000000000000.0));
            Assert.AreEqual("1,00 ab", Economy.FormatNumber(1e18));
            Assert.AreEqual("730 ab", Economy.FormatNumber(7.3e20));
            Assert.AreEqual("-12,3 K", Economy.FormatNumber(-12345.0));
        }

        [Test]
        public void FormatDuration()
        {
            Assert.AreEqual("5 s", Economy.FormatDuration(5.0));
            Assert.AreEqual("2 min 05", Economy.FormatDuration(125.0));
            Assert.AreEqual("1 h 13", Economy.FormatDuration(4380.0));
        }

        [Test]
        public void PrestigePoints()
        {
            Assert.AreEqual(0, Progression.PrestigePoints(0.0));
            Assert.AreEqual(0, Progression.PrestigePoints(9900000.0));
            Assert.AreEqual(1, Progression.PrestigePoints(10000000.0));
            Assert.AreEqual(6, Progression.PrestigePoints(410000000.0));
            Assert.AreEqual(10000, Progression.PrestigePoints(1000000000000000.0));
        }

        [Test]
        public void RepBonus()
        {
            Near(0.0, Progression.RepBonus(0));
            Near(0.1, Progression.RepBonus(1));
            Near(0.4, Progression.RepBonus(16));
            Near(1.58113883008419, Progression.RepBonus(250));
        }

        [Test]
        public void SeriesBonus()
        {
            Near(0.0, Progression.SeriesBonus(0));
            Near(0.02, Progression.SeriesBonus(1));
            Near(0.06, Progression.SeriesBonus(2));
            Near(0.14, Progression.SeriesBonus(3));
            Near(0.14, Progression.SeriesBonus(5));
        }

        [Test]
        public void SeriesTierMadeInFrance()
        {
            Assert.AreEqual(0, Progression.SeriesTier(Progression.AllSeries[0], 0));
            Assert.AreEqual(0, Progression.SeriesTier(Progression.AllSeries[0], 1));
            Assert.AreEqual(1, Progression.SeriesTier(Progression.AllSeries[0], 2));
            Assert.AreEqual(2, Progression.SeriesTier(Progression.AllSeries[0], 4));
            Assert.AreEqual(3, Progression.SeriesTier(Progression.AllSeries[0], 7));
            Assert.AreEqual(3, Progression.SeriesTier(Progression.AllSeries[0], 10));
        }
    }
}
