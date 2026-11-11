using System;
using System.Collections.Generic;

namespace CarIdle.Core
{
    /// <summary>Une compétence de l'arbre de réputation.</summary>
    public sealed class Skill
    {
        public string Id;
        public string Branch;
        public string Name;
        public string Description;
        public int Cost;
        public Dictionary<string, double> Effects;
    }

    /// <summary>Une série de collection : par marques ou par carrosseries, 3 paliers.</summary>
    public sealed class Series
    {
        public string Id;
        public string Name;
        public string[] Brands;
        public string[] Bodies;
        public int[] Tiers;
    }

    /// <summary>Une mission du jour ou un succès. Récompense en minutes de revenus.</summary>
    public sealed class Goal
    {
        public string Id;
        public string Name;
        public string Text;
        public string Stat;
        public int Target;
        public int RewardMinutes;
    }

    /// <summary>
    /// Progression longue : réputation (prestige), arbre de compétences, collections,
    /// missions du jour et succès. Données et fonctions pures, portées du prototype Godot
    /// (scripts/progression.gd) et adaptées au nouveau GDD : les voitures arrivent neuves,
    /// il n'y a plus de mises à neuf ; les récompenses sont en minutes de revenus.
    /// Valeurs à revalider par simulation.
    /// </summary>
    public static class Progression
    {
        // --- Réputation (prestige) ---------------------------------------------------
        // Repartir à zéro rapporte floor(√(gains de la partie / diviseur)) points.
        // Les points gagnés à vie donnent +10 % × √(points) de revenus.

        public const double PrestigeDivisor = 1.0e7;
        public const double RepIncomeBonus = 0.10;

        public static double RepBonus(int repTotal)
        {
            return RepIncomeBonus * Math.Sqrt(Math.Max(repTotal, 0));
        }

        public static int PrestigePoints(double runEarnings)
        {
            if (runEarnings <= 0.0)
                return 0;
            return (int)Math.Floor(Math.Sqrt(runEarnings / PrestigeDivisor));
        }

        /// <summary>Gains de la partie nécessaires pour atteindre <paramref name="points"/> points.</summary>
        public static double EarningsForPoints(int points)
        {
            return (double)points * points * PrestigeDivisor;
        }

        // --- Arbre de compétences ------------------------------------------------------
        // 4 branches de 6 compétences ; une compétence demande la précédente de sa branche.
        // Les effets s'additionnent, sauf ceux de MultKeys qui se multiplient.

        public static readonly string[] Branches = { "revenus", "atelier", "spot", "garage" };

        public static readonly string[] MultKeys =
        {
            "upgrade_cost_mult", "stage_cost_mult", "slot_cost_mult", "spot_gain_mult",
            "spot_cooldown_mult", "rush_mult", "staff_speed_mult",
        };

        public static readonly string[] AddKeys =
        {
            "income_bonus", "offline_full_h", "offline_max_h", "rush_duration", "extra_spots",
            "collection_bonus", "start_slots", "start_stage", "start_coins", "staff_slots",
        };

        public static readonly Skill[] Skills =
        {
            S("r1", "revenus", "Huile de coude", "+10 % de revenus.", 10, ("income_bonus", 0.10)),
            S("r2", "revenus", "Clients fidèles", "Hors ligne : 100 % pendant 4 h au lieu de 2 h.", 20, ("offline_full_h", 2.0)),
            S("r3", "revenus", "Néons tape-à-l'œil", "+25 % de revenus.", 40, ("income_bonus", 0.25)),
            S("r4", "revenus", "Rush prolongé", "Le rush dure 45 s et rapporte x2,5.", 60, ("rush_duration", 15.0), ("rush_mult", 1.25)),
            S("r5", "revenus", "Nuit blanche", "Hors ligne : jusqu'à 12 h au lieu de 8 h.", 100, ("offline_max_h", 4.0)),
            S("r6", "revenus", "Empire de la nuit", "+100 % de revenus.", 200, ("income_bonus", 1.0)),
            S("a1", "atelier", "Clé à choc", "Améliorations -10 %.", 10, ("upgrade_cost_mult", 0.90)),
            S("a2", "atelier", "Mécano", "+1 mécanicien : il achète les améliorations tout seul.", 20, ("staff_slots", 1.0)),
            S("a3", "atelier", "Fournisseur attitré", "Améliorations -15 %.", 40, ("upgrade_cost_mult", 0.85)),
            S("a4", "atelier", "Chef d'atelier", "Les mécaniciens travaillent 2 fois plus vite.", 60, ("staff_speed_mult", 2.0)),
            S("a5", "atelier", "Équipe de nuit", "+1 mécanicien.", 100, ("staff_slots", 1.0)),
            S("a6", "atelier", "Usine", "Améliorations -30 %.", 180, ("upgrade_cost_mult", 0.70)),
            S("s1", "spot", "Œil de lynx", "Gain immédiat des spots x1,5.", 10, ("spot_gain_mult", 1.5)),
            S("s2", "spot", "Carnet d'adresses", "+1 spot par balade.", 30, ("extra_spots", 1.0)),
            S("s3", "spot", "Radar", "Voitures rares plus fréquentes (attente -30 %).", 40, ("spot_cooldown_mult", 0.70)),
            S("s4", "spot", "Réseau de spotters", "+2 spots par balade.", 70, ("extra_spots", 2.0)),
            S("s5", "spot", "Collectionneur", "Bonus de collection : +1,5 % par modèle au lieu de +1 %.", 100, ("collection_bonus", 0.005)),
            S("s6", "spot", "Légende de la rue", "Gain immédiat des spots x3.", 160, ("spot_gain_mult", 3.0)),
            S("g1", "garage", "Place réservée", "+1 place de garage au départ.", 10, ("start_slots", 1.0)),
            S("g2", "garage", "Plans d'architecte", "Étapes du garage -25 %.", 30, ("stage_cost_mult", 0.75)),
            S("g3", "garage", "Fond de caisse", "Repartir avec 50 K pièces.", 40, ("start_coins", 50000.0)),
            S("g4", "garage", "Promoteur", "Places de garage -50 %.", 70, ("slot_cost_mult", 0.5)),
            S("g5", "garage", "Atelier de départ", "Repartir directement à l'Atelier.", 100, ("start_stage", 1.0)),
            S("g6", "garage", "Showroom de départ", "Repartir directement au Showroom, +1 place.", 200, ("start_stage", 1.0), ("start_slots", 1.0)),
        };

        private static Skill S(string id, string branch, string name, string desc, int cost, params (string key, double value)[] fx)
        {
            var effects = new Dictionary<string, double>();
            foreach (var (key, value) in fx)
                effects[key] = value;
            return new Skill { Id = id, Branch = branch, Name = name, Description = desc, Cost = cost, Effects = effects };
        }

        public static Skill FindSkill(string id)
        {
            foreach (var s in Skills)
            {
                if (s.Id == id)
                    return s;
            }
            return null;
        }

        public static List<Skill> BranchSkills(string branch)
        {
            var list = new List<Skill>();
            foreach (var s in Skills)
            {
                if (s.Branch == branch)
                    list.Add(s);
            }
            return list;
        }

        /// <summary>Compétence précédente dans la branche (prérequis), ou "" pour la première.</summary>
        public static string Prerequisite(string id)
        {
            var s = FindSkill(id);
            if (s == null)
                return "";
            var list = BranchSkills(s.Branch);
            for (int i = 0; i < list.Count; i++)
            {
                if (list[i].Id == id)
                    return i == 0 ? "" : list[i - 1].Id;
            }
            return "";
        }

        public static Dictionary<string, double> EmptyEffects()
        {
            var fx = new Dictionary<string, double>();
            foreach (var k in MultKeys)
                fx[k] = 1.0;
            foreach (var k in AddKeys)
                fx[k] = 0.0;
            return fx;
        }

        public static void AddEffects(Dictionary<string, double> fx, Dictionary<string, double> add)
        {
            foreach (var pair in add)
            {
                if (Array.IndexOf(MultKeys, pair.Key) >= 0)
                    fx[pair.Key] = (fx.TryGetValue(pair.Key, out var m) ? m : 1.0) * pair.Value;
                else
                    fx[pair.Key] = (fx.TryGetValue(pair.Key, out var a) ? a : 0.0) + pair.Value;
            }
        }

        /// <summary>Effets cumulés d'un ensemble de compétences possédées.</summary>
        public static Dictionary<string, double> EffectsOf(IEnumerable<string> ownedSkillIds)
        {
            var fx = EmptyEffects();
            foreach (var id in ownedSkillIds)
            {
                var s = FindSkill(id);
                if (s != null)
                    AddEffects(fx, s.Effects);
            }
            return fx;
        }

        // --- Collections ------------------------------------------------------------
        // Chaque palier d'une série donne un bonus de revenus ; les bonus s'additionnent.

        public static readonly Series[] AllSeries =
        {
            new Series { Id = "fr", Name = "Made in France", Brands = new[] { "Renolt", "Peujo", "Citroan", "Dacio" }, Tiers = new[] { 2, 4, 7 } },
            new Series { Id = "de", Name = "Autobahn", Brands = new[] { "Volkswagon", "Audy", "BMV", "Mercedez", "Porshe" }, Tiers = new[] { 2, 5, 10 } },
            new Series { Id = "jp", Name = "JDM", Brands = new[] { "Toyata", "Nisan", "Mazdo" }, Tiers = new[] { 2, 3, 5 } },
            new Series { Id = "it", Name = "Bella Italia", Brands = new[] { "Ferari", "Lamborgino", "Pagany" }, Tiers = new[] { 1, 2, 4 } },
            new Series { Id = "util", Name = "Utilitaires", Bodies = new[] { "fourgon", "combi", "pickup", "monospace" }, Tiers = new[] { 1, 2, 4 } },
            new Series { Id = "open", Name = "Cheveux au vent", Bodies = new[] { "cabriolet", "roadster" }, Tiers = new[] { 1, 2, 3 } },
            new Series { Id = "exo", Name = "Supercars", Bodies = new[] { "supercar" }, Tiers = new[] { 1, 3, 6 } },
        };

        public static readonly double[] SeriesBonusPerTier = { 0.02, 0.04, 0.08 };

        public static bool InSeries(Series series, CarModel model)
        {
            if (series.Brands != null)
                return Array.IndexOf(series.Brands, model.Brand) >= 0;
            return Array.IndexOf(series.Bodies, model.Body) >= 0;
        }

        /// <summary>Palier atteint (0 à 3) pour <paramref name="count"/> modèles de la série.</summary>
        public static int SeriesTier(Series series, int count)
        {
            int t = 0;
            foreach (int need in series.Tiers)
            {
                if (count >= need)
                    t++;
            }
            return t;
        }

        public static double SeriesBonus(int tier)
        {
            double b = 0.0;
            for (int i = 0; i < Math.Min(tier, SeriesBonusPerTier.Length); i++)
                b += SeriesBonusPerTier[i];
            return b;
        }

        // --- Missions du jour -------------------------------------------------------
        // Trois missions tirées chaque jour ; la graine est la date, donc tout le monde
        // a les mêmes missions le même jour.

        private sealed class MissionTemplate
        {
            public string Id;
            public string Text;
            public string Stat;
            public int[] Targets;
            public int RewardMinutes;
        }

        private static readonly MissionTemplate[] Missions =
        {
            new MissionTemplate { Id = "spots", Text = "Spotte {0} voitures", Stat = "spots", Targets = new[] { 2, 3, 5 }, RewardMinutes = 30 },
            new MissionTemplate { Id = "levels", Text = "Achète {0} niveaux de pièces", Stat = "levels", Targets = new[] { 25, 60, 150 }, RewardMinutes = 30 },
            new MissionTemplate { Id = "taps", Text = "Sers {0} clients", Stat = "taps", Targets = new[] { 60, 100, 120 }, RewardMinutes = 20 },
            new MissionTemplate { Id = "drives", Text = "Fais {0} balades", Stat = "drives", Targets = new[] { 1, 2, 3 }, RewardMinutes = 30 },
            new MissionTemplate { Id = "rush", Text = "Déclenche {0} rush", Stat = "rushes", Targets = new[] { 2, 4, 6 }, RewardMinutes = 30 },
            new MissionTemplate { Id = "milestones", Text = "Franchis {0} paliers x2", Stat = "milestones", Targets = new[] { 2, 4, 8 }, RewardMinutes = 45 },
        };

        /// <summary>Les 3 missions du jour pour une date au format AAAA-MM-JJ.</summary>
        public static List<Goal> DailyMissions(string day)
        {
            var rng = new DeterministicRandom(StableHash(day));
            var pool = new List<MissionTemplate>(Missions);
            var result = new List<Goal>();
            for (int i = 0; i < 3; i++)
            {
                var m = pool[rng.Next(pool.Count)];
                pool.Remove(m);
                int target = m.Targets[rng.Next(m.Targets.Length)];
                result.Add(new Goal
                {
                    Id = m.Id,
                    Name = m.Id,
                    Text = string.Format(m.Text, target),
                    Stat = m.Stat,
                    Target = target,
                    RewardMinutes = m.RewardMinutes,
                });
            }
            return result;
        }

        /// <summary>Hachage FNV-1a 32 bits : identique sur toutes les plateformes, contrairement à string.GetHashCode.</summary>
        public static uint StableHash(string text)
        {
            uint h = 2166136261;
            foreach (char c in text)
            {
                h ^= c;
                h *= 16777619;
            }
            return h;
        }

        // --- Succès -----------------------------------------------------------------
        // Objectifs permanents ; chacun se réclame une fois.

        public static readonly Goal[] Achievements =
        {
            A("first_spot", "Premier spot", "Spotte ta première voiture.", "spots", 1, 10),
            A("spots_10", "Spotter du dimanche", "Spotte 10 voitures.", "spots", 10, 30),
            A("spots_100", "Spotter acharné", "Spotte 100 voitures.", "spots", 100, 90),
            A("models_10", "Petite collection", "Possède 10 modèles.", "models", 10, 60),
            A("models_25", "Grande collection", "Possède 25 modèles.", "models", 25, 150),
            A("levels_500", "Cambouis", "Achète 500 niveaux de pièces.", "levels", 500, 60),
            A("levels_5000", "Chef mécano", "Achète 5 000 niveaux de pièces.", "levels", 5000, 120),
            A("part_100", "Pièce de course", "Monte une pièce au niveau 100.", "max_part", 100, 60),
            A("part_200", "Pièce parfaite", "Monte une pièce au niveau 200.", "max_part", 200, 150),
            A("stage_1", "Atelier ouvert", "Construis l'Atelier.", "stage", 1, 30),
            A("stage_3", "Roi du hangar", "Construis le Hangar.", "stage", 3, 90),
            A("taps_1000", "Service express", "Sers 1 000 clients.", "taps", 1000, 30),
            A("rush_25", "Pied au plancher", "Déclenche 25 rush.", "rushes", 25, 60),
            A("drives_10", "Grand voyageur", "Fais 10 balades.", "drives", 10, 60),
            A("prestige_1", "Nouveau départ", "Repars à zéro une première fois (prestige).", "prestiges", 1, 90),
            A("prestige_5", "Légende du quartier", "Fais 5 prestiges.", "prestiges", 5, 150),
            A("rare", "Ça brille", "Spotte une voiture Rare ou mieux.", "best_rarity", 2, 60),
            A("legend", "Licorne", "Spotte une voiture Légendaire ou mieux.", "best_rarity", 4, 150),
            A("series", "Série complète", "Atteins le palier 3 d'une collection.", "best_series", 3, 150),
        };

        private static Goal A(string id, string name, string text, string stat, int target, int minutes)
        {
            return new Goal { Id = id, Name = name, Text = text, Stat = stat, Target = target, RewardMinutes = minutes };
        }
    }

    /// <summary>Générateur pseudo-aléatoire déterministe (xorshift32), identique partout.</summary>
    public sealed class DeterministicRandom
    {
        private uint _state;

        public DeterministicRandom(uint seed)
        {
            _state = seed == 0 ? 0x9E3779B9u : seed;
        }

        public uint NextUInt()
        {
            uint x = _state;
            x ^= x << 13;
            x ^= x >> 17;
            x ^= x << 5;
            _state = x;
            return x;
        }

        /// <summary>Entier dans [0, max).</summary>
        public int Next(int max)
        {
            return (int)(NextUInt() % (uint)max);
        }

        /// <summary>Réel dans [0, 1).</summary>
        public double NextDouble()
        {
            return NextUInt() / 4294967296.0;
        }
    }
}
