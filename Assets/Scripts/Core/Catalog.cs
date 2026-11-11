using System.Collections.Generic;

namespace CarIdle.Core
{
    /// <summary>Un modèle de voiture du jeu. Le nom réel n'est jamais affiché : marque et nom sont modifiés.</summary>
    public sealed class CarModel
    {
        public string Id;
        public string Brand;
        public string Name;
        public int Rarity;
        public string Body;
        /// <summary>Couleur par défaut, en hexadécimal sans « # ».</summary>
        public string Color;

        public string DisplayName => Brand + " " + Name;
    }

    /// <summary>
    /// Catalogue provisoire, repris du prototype Godot (32 modèles, noms modifiés).
    /// Il sera remplacé par la table du serveur ; chaque modèle aura son modèle 3D.
    /// </summary>
    public static class Catalog
    {
        public static readonly CarModel[] Cars =
        {
            // Communes
            C("clia5", "Renolt", "Clia 5", 0, "compacte", "9a6b4f"),
            C("peujo280", "Peujo", "280", 0, "compacte", "c9c9c9"),
            C("gulf8", "Volkswagon", "Gulf 8", 0, "compacte", "5c5f66"),
            C("citroan_c3", "Citroan", "C-Trois", 0, "citadine", "d8d2c4"),
            C("yariz", "Toyata", "Yariz", 0, "citadine", "b8312f"),
            C("sandaro", "Dacio", "Sandaro", 0, "suv", "7d7a70"),
            C("peujo3080", "Peujo", "3080", 0, "suv", "2b2d33"),
            C("octavio", "Skado", "Octavio Break", 0, "break", "8a8f96"),
            C("kongo", "Renolt", "Kongo", 0, "monospace", "e8e4dc"),
            C("transiz", "Fourd", "Transiz", 0, "fourgon", "e0781e"),
            // Peu communes
            C("gulf_gti", "Volkswagon", "Gulf GTJ", 1, "compacte", "d23a2c"),
            C("mimi_s", "Mimi", "Coopar S", 1, "citadine", "2f5d3a"),
            C("megana_rs", "Renolt", "Megana RS", 1, "sportback", "f2a516"),
            C("audy_s3", "Audy", "S-Trois", 1, "berline", "4a4d52"),
            C("transpoter", "Volkswagon", "Transpoter", 1, "combi", "3f6f8f"),
            C("hilox", "Toyata", "Hilox", 1, "pickup", "b9b6ae"),
            C("mx6", "Mazdo", "MX-6", 1, "roadster", "a3161c"),
            // Rares
            C("m3_e64", "BMV", "M3 E64", 2, "coupe", "8f9aa3"),
            C("gtx_r35", "Nisan", "GT-X R35", 2, "coupe", "e6e6e2"),
            C("119_carrera", "Porshe", "119 Carrera", 2, "coupe", "d9b44a"),
            C("amg_c36", "Mercedez", "C-36 AMJ", 2, "berline", "2b2b2e"),
            C("modele_s", "Teslo", "Modèle Z", 2, "fastback", "a8acb2"),
            C("serie4c", "BMV", "Série 4 Cabrio", 2, "cabriolet", "1f3a5c"),
            C("defendor", "Land Rouver", "Defendor", 2, "4x4", "4f5a3a"),
            // Épiques
            C("119_gt3rs", "Porshe", "119 GT3 RS", 3, "supercar", "6fbf3f"),
            C("huracon", "Lamborgino", "Huracon", 3, "supercar", "f28c1c"),
            C("r9", "Audy", "R9", 3, "supercar", "b9bcc0"),
            // Légendaires
            C("f04", "Ferari", "F04", 4, "supercar", "d01f1f"),
            C("carrera_tg", "Porshe", "Carrera TG", 4, "roadster", "a7aaad"),
            C("f2", "McLaran", "F2", 4, "supercar", "e3c84a"),
            // Mythiques
            C("zondo", "Pagany", "Zondo R", 5, "supercar", "3b3f44"),
            C("uno1", "Konigseg", "Uno:1", 5, "supercar", "f4f1ea"),
        };

        private static CarModel C(string id, string brand, string name, int rarity, string body, string color)
        {
            return new CarModel { Id = id, Brand = brand, Name = name, Rarity = rarity, Body = body, Color = color };
        }

        public static CarModel Get(string id)
        {
            foreach (var c in Cars)
            {
                if (c.Id == id)
                    return c;
            }
            return null;
        }

        public static List<CarModel> ByRarity(int rarity)
        {
            var list = new List<CarModel>();
            foreach (var c in Cars)
            {
                if (c.Rarity == rarity)
                    list.Add(c);
            }
            return list;
        }
    }
}
