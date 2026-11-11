using System;
using System.Collections.Generic;
using System.Globalization;

namespace CarIdle.Core
{
    /// <summary>Une pièce améliorable d'une voiture et la statistique de course qu'elle nourrit.</summary>
    public readonly struct PartInfo
    {
        public readonly string Name;
        public readonly string Stat;

        public PartInfo(string name, string stat)
        {
            Name = name;
            Stat = stat;
        }
    }

    /// <summary>Une étape du garage : nombre de pièces débloquées et prix de construction.</summary>
    public readonly struct StageInfo
    {
        public readonly string Name;
        public readonly int Parts;
        public readonly double Cost;

        public StageInfo(string name, int parts, double cost)
        {
            Name = name;
            Parts = parts;
            Cost = cost;
        }
    }

    /// <summary>
    /// Règles de l'économie (GDD, « Formules v2 » et « Paramètres de départ »), portées du
    /// prototype Godot (scripts/economy.gd). Fonctions pures, sans état et sans Unity :
    /// le même code sert au jeu, aux tests et, plus tard, au serveur qui fera foi.
    /// Règles : coût ×1,10 par niveau, revenu linéaire, ×2 aux paliers 25/50/100/150/200,
    /// les échelles s'additionnent et ne se multiplient jamais.
    /// </summary>
    public static class Economy
    {
        public static readonly string[] RarityNames = { "Commune", "Peu commune", "Rare", "Épique", "Légendaire", "Mythique" };
        public static readonly double[] BaseIncome = { 1.0, 2.5, 6.0, 15.0, 40.0, 100.0 };
        public static readonly double[] SpotChance = { 0.60, 0.25, 0.10, 0.04, 0.009, 0.001 };
        public static readonly double[] SpotGainMinutes = { 20.0, 30.0, 45.0, 60.0, 120.0, 240.0 };

        public static readonly int[] Milestones = { 25, 50, 100, 150, 200 };
        public const int MaxLevel = 200;
        public const double CostGrowth = 1.10;
        public const double CostFactor = 20.0;

        /// <summary>10 pièces par voiture, débloquées par étape du garage.</summary>
        public static readonly PartInfo[] Parts =
        {
            new PartInfo("Admission", "Puissance"),
            new PartInfo("Échappement", "Puissance"),
            new PartInfo("Pneus", "Adhérence"),
            new PartInfo("Reprog moteur", "Puissance"),
            new PartInfo("Turbo", "Puissance"),
            new PartInfo("Boîte", "Accélération"),
            new PartInfo("Allègement", "Poids"),
            new PartInfo("Embrayage", "Départ"),
            new PartInfo("Aéro", "Vitesse max"),
            new PartInfo("Nitro", "Boost"),
        };

        public static readonly StageInfo[] Stages =
        {
            new StageInfo("Box", 3, 0.0),
            new StageInfo("Atelier", 6, 1.0e5),
            new StageInfo("Showroom", 8, 5.0e7),
            new StageInfo("Hangar", 10, 5.0e9),
        };

        public const int StartSlots = 3;
        public const int MaxSlots = 20;
        public const double CollectionBonus = 0.01;
        public const double OfflineFullSeconds = 7200.0;
        public const double OfflineMaxSeconds = 28800.0;
        public const double OfflineLateRate = 0.5;

        public const double TapFraction = 0.05;
        public const double TapMin = 1.0;
        public const double RushTaps = 20.0;
        public const double RushDecay = 0.12;
        public const double RushDuration = 30.0;
        public const double RushMult = 2.0;

        /// <summary>C(ℓ) = 20 × B × 1,10^ℓ : prix pour passer du niveau ℓ au niveau ℓ+1.</summary>
        public static double PartCost(int rarity, int level)
        {
            return CostFactor * BaseIncome[rarity] * Math.Pow(CostGrowth, level);
        }

        /// <summary>Prix de <paramref name="count"/> niveaux d'affilée à partir de <paramref name="level"/> (somme géométrique).</summary>
        public static double CostForLevels(int rarity, int level, int count)
        {
            if (count <= 0)
                return 0.0;
            return PartCost(rarity, level) * (Math.Pow(CostGrowth, count) - 1.0) / (CostGrowth - 1.0);
        }

        /// <summary>Nombre de niveaux qu'on peut payer avec <paramref name="budget"/>, plafonné au niveau max.</summary>
        public static int MaxAffordable(int rarity, int level, double budget)
        {
            int remaining = MaxLevel - level;
            if (remaining <= 0)
                return 0;
            if (double.IsPositiveInfinity(budget))
                return remaining;
            double c0 = PartCost(rarity, level);
            if (budget < c0)
                return 0;
            int n = (int)Math.Floor(Math.Log(budget * (CostGrowth - 1.0) / c0 + 1.0) / Math.Log(CostGrowth));
            n = Math.Min(n, remaining);
            while (n > 0 && CostForLevels(rarity, level, n) > budget * (1.0 + 1e-12))
                n--;
            return n;
        }

        public static int MilestonesPassed(int level)
        {
            int m = 0;
            foreach (int s in Milestones)
            {
                if (level >= s)
                    m++;
            }
            return m;
        }

        /// <summary>Prochain palier ×2, ou -1 si tous sont franchis.</summary>
        public static int NextMilestone(int level)
        {
            foreach (int s in Milestones)
            {
                if (level < s)
                    return s;
            }
            return -1;
        }

        /// <summary>R_voiture = B × 1/10 × Σ (1 + ℓᵢ) × 2^mᵢ, sur les 10 pièces. Jamais de produit entre pièces.</summary>
        public static double CarIncome(int rarity, IReadOnlyList<int> levels)
        {
            double sum = 0.0;
            foreach (int level in levels)
                sum += (1.0 + level) * Math.Pow(2.0, MilestonesPassed(level));
            return BaseIncome[rarity] * 0.1 * sum;
        }

        public static double CollectionMultiplier(int uniqueModels)
        {
            return 1.0 + CollectionBonus * uniqueModels;
        }

        /// <summary>Prix de la place n (numéro de la place achetée) : 100 × 5^(n−3).</summary>
        public static double SlotCost(int n)
        {
            return 100.0 * Math.Pow(5.0, n - 3);
        }

        /// <summary>100 % pendant 2 h, puis 50 % jusqu'à 8 h (durées réglables par l'arbre de compétences).</summary>
        public static double OfflineGain(double incomePerSecond, double seconds, double fullSeconds = OfflineFullSeconds, double maxSeconds = OfflineMaxSeconds)
        {
            double s = Math.Max(0.0, Math.Min(seconds, maxSeconds));
            double full = Math.Min(s, fullSeconds);
            double late = Math.Max(0.0, s - fullSeconds);
            return incomePerSecond * (full + OfflineLateRate * late);
        }

        /// <summary>Tirage de rareté à partir d'un nombre uniforme dans [0, 1).</summary>
        public static int RollRarity(double u)
        {
            double acc = 0.0;
            for (int i = 0; i < SpotChance.Length; i++)
            {
                acc += SpotChance[i];
                if (u < acc)
                    return i;
            }
            return 0;
        }

        /// <summary>Gain immédiat d'un spot : 20 à 240 minutes du revenu actuel selon la rareté.</summary>
        public static double SpotGain(int rarity, double incomePerSecond)
        {
            return Math.Max(incomePerSecond, TapMin) * SpotGainMinutes[rarity] * 60.0;
        }

        /// <summary>Gain d'un appui sur SERVIR.</summary>
        public static double TapGain(double incomePerSecond)
        {
            return Math.Max(incomePerSecond * TapFraction, TapMin);
        }

        private static readonly string[] Suffixes = { "K", "M", "B", "T" };

        /// <summary>999 → « 999 », 12 345 → « 12,3 K », 1e18 → « 1,00 ab ».</summary>
        public static string FormatNumber(double x)
        {
            if (double.IsInfinity(x))
                return "illimité";
            if (x < 0.0)
                return "-" + FormatNumber(-x);
            if (x < 1000.0)
            {
                if (x < 10.0)
                {
                    if (Math.Abs(x - Math.Round(x)) > 0.05)
                        return x.ToString("0.0", CultureInfo.InvariantCulture).Replace('.', ',');
                    // Le prototype affichait 9,96 comme « 9 » : ici on arrondit au plus proche.
                    return ((long)Math.Round(x)).ToString(CultureInfo.InvariantCulture);
                }
                return ((long)Math.Floor(x)).ToString(CultureInfo.InvariantCulture);
            }
            int e = (int)Math.Floor(Math.Log(x) / Math.Log(1000.0));
            double v = x / Math.Pow(1000.0, e);
            if (v >= 999.95)
            {
                e++;
                v /= 1000.0;
            }
            string suffix;
            if (e - 1 < Suffixes.Length)
            {
                suffix = Suffixes[e - 1];
            }
            else
            {
                int k = e - 1 - Suffixes.Length;
                suffix = new string(new[] { (char)('a' + (k / 26) % 26), (char)('a' + k % 26) });
            }
            string digits = v < 10.0 ? v.ToString("0.00", CultureInfo.InvariantCulture)
                : v < 100.0 ? v.ToString("0.0", CultureInfo.InvariantCulture)
                : ((int)v).ToString(CultureInfo.InvariantCulture);
            return digits.Replace('.', ',') + " " + suffix;
        }

        public static string FormatDuration(double seconds)
        {
            int s = (int)seconds;
            if (s < 60)
                return s + " s";
            if (s < 3600)
                return string.Format(CultureInfo.InvariantCulture, "{0} min {1:00}", s / 60, s % 60);
            return string.Format(CultureInfo.InvariantCulture, "{0} h {1:00}", s / 3600, (s % 3600) / 60);
        }
    }
}
