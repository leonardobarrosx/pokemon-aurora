"""Troca os sprites de NPC de Kanto e Hoenn (GBA) pelos do estilo DS.

Para cada sprite de GBA procura o equivalente nos jogos de DS: HeartGold
(líderes de Kanto e Johto, Elite Four, Red, Blue, Pokémon que seguem o
treinador) ou Platinum (classes de treinador). Quem não tem equivalente
(líderes de Hoenn, Equipes Aqua e Magma, Brendan, May...) é montado com as
peças do criador de personagem do Indigo, no mesmo estilo de 4ª geração.

Saída: client/assets/characters/ds/<nome>.png e os NPCs dos mapas kt_/hn_
apontando para eles. Objetos (árvores cortáveis, placas, mochila) continuam
com o sprite de GBA.

Uso: python3 npcs_ds.py   (depois de npcs.py)
"""
import colorsys, json, os, sys
from PIL import Image

HERE = os.path.dirname(os.path.abspath(__file__))
sys.path.insert(0, os.path.join(HERE, "ds"))
ROOT = os.path.abspath(os.path.join(HERE, "../.."))
CDIR = os.path.join(ROOT, "client/assets/maps")
CHARS = os.path.join(ROOT, "client/assets/characters/ds")
CREATOR = os.path.join(ROOT, "client/assets/indigo/character")

HG = lambda s: ("hg", "SPRITE_" + s)
PT = lambda s: ("pt", "OBJ_EVENT_GFX_" + s.upper())

# Nome do GBA (sem frlg_/rse_) -> sprite de DS.
SAME = {
    "youngster": PT("youngster"), "lass": PT("lass"), "gentleman": PT("gentleman"), "hiker": PT("hiker"),
    "picnicker": PT("picnicker"), "camper": PT("camper"), "black_belt": PT("black_belt"), "sailor": PT("sailor"),
    "beauty": PT("beauty"), "bug_catcher": PT("bug_catcher"), "fisherman": PT("fisherman"), "fisher": PT("fisherman"),
    "policeman": PT("policeman"), "expert_m": PT("expert_m"), "expert_f": PT("expert_f"), "ninja_boy": PT("ninja_boy"),
    "pokefan_m": PT("pokefan_m"), "pokefan_f": PT("pokefan_f"), "twin": PT("twin"), "nurse": PT("pokecenter_nurse"),
    "teala": PT("teala"), "mart_employee": PT("cashier_m"), "clerk": PT("cashier_m"), "scientist": PT("scientist_m"),
    "scientist_1": PT("scientist_m"), "scientist_2": PT("scientist_f"), "swimmer_m": PT("swimmer_m"),
    "swimmer_f": PT("swimmer_f"), "swimmer_m_water": PT("swimmer_m"), "swimmer_f_water": PT("swimmer_f"),
    "swimmer_m_land": PT("swimmer_m"), "tuber_m": PT("tuber_m"), "tuber_f": PT("tuber_f"),
    "tuber_m_water": PT("tuber_m"), "tuber_m_swimming": PT("tuber_m"), "rich_boy": PT("rich_boy"),
    "cameraman": PT("cameraman"), "reporter_f": PT("reporter"), "reporter_m": HG("REPORTER"), "artist": PT("artist"),
    "school_kid_m": PT("school_kid_m"), "cycling_triathlete_m": PT("cyclist_m"), "cycling_triathlete_f": PT("cyclist_f"),
    "running_triathlete_m": PT("jogger"), "running_triathlete_f": HG("SPORTSMAN"), "psychic_m": PT("psychic"),
    "hex_maniac": HG("ITAKO"), "channeler": HG("ITAKO"), "maniac": PT("ruin_maniac"), "poke_maniac": HG("MANIA"),
    "rocker": PT("guitarist"), "biker": PT("roughneck"), "gym_guy": PT("gym_guide"), "worker_m": PT("worker"),
    "worker_f": HG("WORKMAN"), "old_man": PT("old_man"), "old_man_1": PT("old_man"), "old_man_2": HG("GSOLDMAN1"),
    "old_woman": PT("old_woman"), "hot_springs_old_woman": HG("GSOLDWOMAN1"), "mg_deliveryman": PT("mystery_gift_deliveryman"),
    "mystery_gift_man": PT("mystery_gift_deliveryman"), "fat_man": HG("GSBIGMAN"), "balding_man": PT("middle_aged_man"),
    "man": HG("GSMAN1"), "man_1": HG("GSMAN1"), "man_2": HG("GSMAN2"), "man_3": HG("GSMAN3"), "man_4": PT("middle_aged_man"),
    "man_5": HG("MAN5"), "woman_1": HG("GSWOMAN1"), "woman_2": HG("GSWOMAN2"), "woman_3": HG("GSWOMAN3"),
    "woman_4": HG("WOMAN2"), "woman_5": HG("WOMAN3"), "boy": HG("GSBOY1"), "boy_1": HG("GSBOY1"), "boy_2": HG("GSBOY2"),
    "boy_3": HG("GSBOY3"), "girl_1": HG("GSGIRL1"), "girl_2": HG("GSGIRL2"), "girl_3": HG("GSGIRL3"),
    "little_boy": HG("GSBABYBOY1"), "little_girl": HG("GSBABYGIRL1"), "cooltrainer_m": PT("ace_trainer_m"),
    "cooltrainer_f": PT("ace_trainer_f"), "rocket_m": HG("ROCKETM"), "rocket_f": HG("ROCKETW"), "chef": PT("waiter"),
    "cook": PT("waiter"), "captain": HG("CAPTAIN"), "gba_kid": PT("kid_with_nds"), "gameboy_kid": PT("kid_with_nds"),
    "crush_girl": PT("battle_girl"), "union_room_receptionist": PT("receptionist"), "link_receptionist": PT("receptionist"),
    "contest_judge": PT("game_director"), "devon_employee": HG("SUIT"), "rooftop_sale_woman": PT("cashier_f"),
    "mom": HG("REDMAMA"), "prof_oak": HG("OOKIDO"), "bill": HG("MASAKI"), "mr_fuji": HG("GSOLDMAN1"),
    "giovanni": HG("SAKAKI"), "lance": HG("WATARU"), "daisy": HG("NANAMI"), "steven": HG("DAIGO"),
    "lt_surge": HG("GSLEADER9"), "sabrina": HG("GSLEADER10"), "misty": HG("GSLEADER11"), "erika": HG("GSLEADER12"),
    "brock": HG("GSLEADER14"), "blaine": HG("GSLEADER15"), "blue": HG("GSLEADER16"), "koga": HG("GSBIGFOUR2"),
    "bruno": HG("GSBIGFOUR3"), "school_kid_f": PT("school_kid_f"), "psychic_f": PT("psychic"),
}
POKEMON = {"pikachu", "clefairy", "jigglypuff", "chansey", "pidgey", "snorlax", "slowbro", "nidorino", "psyduck",
           "zapdos", "nidoran_m", "nidoran_f", "doduo", "fearow", "pidgeot", "machop", "machoke", "spearow", "seel",
           "meowth", "wigglytuff", "mewtwo", "slowpoke", "voltorb", "lapras", "kangaskhan", "cubone", "poliwrath",
           "poochyena", "wingull", "kecleon", "skitty", "azumarill", "azurill", "whismur", "raikou", "entei",
           "moltres", "articuno", "celebi", "jirachi", "registeel", "regirock", "regice", "rayquaza", "zigzagoon_1",
           "zigzagoon_2", "vigoroth_facing_away", "vigoroth_carrying_box", "rayquaza_still", "groudon_front",
           "groudon_asleep"}

# Sem equivalente no DS: montados com o criador (peças do Indigo, estilo 4ª geração).
LOOKS = {
    "aqua_member_m": ({"gender": "m", "hair": "boy1", "hat": "beanie", "top": "scarf", "bottom": "jeans"},
                      {"hat": "#3050a0", "top": "#202838", "top2": "#4878d0", "bottom": "#283048", "hair": "#303030"}),
    "aqua_member_f": ({"gender": "f", "hair": "girl2", "hat": "beanie", "top": "scarf", "bottom": "jeans"},
                      {"hat": "#3050a0", "top": "#202838", "top2": "#4878d0", "bottom": "#283048", "hair": "#303030"}),
    "magma_member_m": ({"gender": "m", "hair": "boy1", "hat": "beanie", "top": "hoodie", "bottom": "jeans"},
                       {"hat": "#c03030", "top": "#a02828", "top2": "#303030", "bottom": "#583030", "hair": "#303030"}),
    "magma_member_f": ({"gender": "f", "hair": "girl2", "hat": "beanie", "top": "hoodie", "bottom": "jeans"},
                       {"hat": "#c03030", "top": "#a02828", "top2": "#303030", "bottom": "#583030", "hair": "#303030"}),
    "archie": ({"gender": "m", "hair": "boy4", "top": "scarf", "bottom": "jeans"},
               {"hair": "#202020", "top": "#2848a0", "top2": "#f0f0f0", "bottom": "#203070", "skin": "#c08860"}),
    "maxie": ({"gender": "m", "hair": "boy3", "acc": "glasses", "top": "trench", "bottom": "formalb"},
              {"hair": "#c04020", "top": "#b03028", "top2": "#303030", "bottom": "#282828"}),
    "matt": ({"gender": "m", "hair": "boy1", "top": "tank", "bottom": "jeans"}, {"hair": "#303030", "top": "#2848a0", "bottom": "#203070"}),
    "shelly": ({"gender": "f", "hair": "girl3", "top": "scarf", "bottom": "shorts"}, {"hair": "#e0a040", "top": "#2848a0", "bottom": "#203070"}),
    "tabitha": ({"gender": "m", "hair": "boy2", "top": "hoodie", "bottom": "jeans"}, {"hair": "#383838", "top": "#a02828", "bottom": "#583030"}),
    "courtney": ({"gender": "f", "hair": "girl1", "top": "hoodie", "bottom": "jeans"}, {"hair": "#d06090", "top": "#a02828", "bottom": "#583030"}),
    "rival_brendan_normal": ({"gender": "m", "hair": "boy2", "hat": "beanie", "top": "jacket", "bottom": "shorts", "bag": "rucksack"},
                             {"hat": "#f0f0f0", "top": "#d03030", "top2": "#303030", "bottom": "#303030", "bag": "#40a040"}),
    "rival_may_normal": ({"gender": "f", "hair": "girl1", "hat": "headband", "top": "tshirt", "bottom": "shorts", "bag": "sporty"},
                         {"hair": "#8a5030", "hat": "#d03030", "top": "#d03030", "bottom": "#305030", "bag": "#e0c030"}),
    "wally": ({"gender": "m", "hair": "boy3", "top": "collared", "bottom": "jeans"}, {"hair": "#60b060", "top": "#f0f0f0", "bottom": "#506070"}),
    "prof_birch": ({"gender": "m", "hair": "boy4", "top": "vest", "bottom": "shorts"}, {"hair": "#6a4020", "top": "#e0e0c0", "bottom": "#506070"}),
    "norman": ({"gender": "m", "hair": "boy1", "top": "jacket", "bottom": "formalb"}, {"hair": "#303030", "top": "#c05030", "bottom": "#4a4a4a"}),
    "scott": ({"gender": "m", "hair": "boy2", "acc": "glasses", "top": "collared", "bottom": "jeans"}, {"hair": "#303030", "top": "#d0b040", "bottom": "#3a4a6a"}),
    "zinnia": ({"gender": "f", "hair": "girl4", "top": "trench", "bottom": "long"}, {"hair": "#303030", "top": "#506040", "bottom": "#303030"}),
    "roxanne": ({"gender": "f", "hair": "girl2", "top": "school", "bottom": "schoolb"}, {"hair": "#5a3020", "top": "#e8e0d0", "bottom": "#4a5aa0"}),
    "brawly": ({"gender": "m", "hair": "boy4", "top": "tank", "bottom": "shorts"}, {"hair": "#3a3a6a", "top": "#40a0d0", "bottom": "#e0e0e0"}),
    "wattson": ({"gender": "m", "hair": "boy3", "top": "classy", "bottom": "formalb"}, {"hair": "#f0f0f0", "top": "#e0c030", "bottom": "#506070"}),
    "flannery": ({"gender": "f", "hair": "girl3", "top": "tank", "bottom": "jeans"}, {"hair": "#d03020", "top": "#202020", "bottom": "#606060"}),
    "winona": ({"gender": "f", "hair": "girl4", "top": "jumpsuit", "bottom": "jumpb"}, {"hair": "#8060c0", "top": "#a0c8e8", "bottom": "#a0c8e8"}),
    "tate": ({"gender": "m", "hair": "boy2", "top": "collared", "bottom": "shorts"}, {"hair": "#303060", "top": "#a03050", "bottom": "#303060"}),
    "liza": ({"gender": "f", "hair": "girl2", "top": "collared", "bottom": "shorts"}, {"hair": "#303060", "top": "#a03050", "bottom": "#303060"}),
    "wallace": ({"gender": "m", "hair": "boy3", "hat": "beret", "top": "lord", "bottom": "lordb"}, {"hair": "#50a0c0", "hat": "#f0f0f0", "top": "#f0f0f0", "top2": "#5090d0", "bottom": "#f0f0f0"}),
    "sidney": ({"gender": "m", "hair": "boy4", "top": "vest", "bottom": "jeans"}, {"hair": "#303030", "top": "#303030", "bottom": "#303030"}),
    "phoebe": ({"gender": "f", "hair": "girl1", "acc": "flower", "top": "tank", "bottom": "shorts"}, {"hair": "#303030", "top": "#e0e0e0", "bottom": "#c04070", "skin": "#c08860"}),
    "glacia": ({"gender": "f", "hair": "girl4", "top": "formal", "bottom": "long"}, {"hair": "#e0e0f0", "top": "#a0d0f0", "bottom": "#a0d0f0"}),
    "drake": ({"gender": "m", "hair": "boy3", "top": "trench", "bottom": "jeans"}, {"hair": "#d0d0d0", "top": "#f0f0f0", "bottom": "#404060"}),
    "lorelei": ({"gender": "f", "hair": "girl4", "acc": "glasses", "top": "formal", "bottom": "long"}, {"hair": "#a02030", "top": "#4a60a0", "bottom": "#303060"}),
    "agatha": ({"gender": "f", "hair": "girl2", "top": "classy", "bottom": "long"}, {"hair": "#c0c0c0", "top": "#6a4080", "bottom": "#4a3050"}),
}
MODE = "walk"
ORDER = ["base", "bottom", "top", "bag", "hair", "hat", "acc"]
REGIONS = {"base": {1: "skin"}, "hair": {1: "hair"}, "top": {1: "top", 2: "top2"}, "bottom": {1: "bottom", 2: "bottom2", 3: "shoes"},
           "hat": {1: "hat", 2: "hat2"}, "bag": {1: "bag", 2: "bag2"}, "acc": {1: "acc", 2: "acc2"}}


def hexrgb(h):
    h = h.lstrip("#")
    return tuple(int(h[i:i + 2], 16) / 255 for i in (0, 2, 4))


def compose(look, colors, catalog):
    """Mesma montagem de indigo_character.gd (modo andando), em Python."""
    out = Image.new("RGBA", (256, 256))
    gender = look.get("gender", "m")
    for slot in ORDER:
        choice = look.get(slot, {"hair": "boy2", "top": "jacket", "bottom": "jeans"}.get(slot, ""))
        if choice == "" and slot != "base":
            continue
        key = "base|" + gender if slot == "base" else "%s|%s|%s" % (slot, choice, gender)
        if key not in catalog:
            key = "%s|%s|x" % (slot, choice)
        if key not in catalog or MODE not in catalog[key]["modes"]:
            continue
        part = catalog[key]
        img = Image.open(os.path.join(CREATOR, part["modes"][MODE])).convert("RGBA")
        swaps = {}
        for i, p in enumerate(part["palette"]):
            region = REGIONS[slot].get(int(part["groups"][i]), "")
            if region not in colors:
                continue
            src = colorsys.rgb_to_hsv(*(c / 255 for c in p))
            tgt = colorsys.rgb_to_hsv(*hexrgb(colors[region]))
            ref = colorsys.rgb_to_hsv(*(c / 255 for c in part["defaults"].get(str(part["groups"][i]), [128, 128, 128])))
            s = min(1, src[1] * tgt[1] / max(ref[1], .05)); v = min(1, src[2] * tgt[2] / max(ref[2], .05))
            swaps[tuple(p)] = tuple(int(round(c * 255)) for c in colorsys.hsv_to_rgb(tgt[0], s, v))
        if swaps:
            px = img.load()
            for y in range(img.height):
                for x in range(img.width):
                    r, g, b, a = px[x, y]
                    if a and (r, g, b) in swaps:
                        px[x, y] = swaps[(r, g, b)] + (a,)
        out.alpha_composite(img)
    return out


def main():
    sys.argv = [sys.argv[0], ROOT]
    import ds_npcs
    import sinnoh
    hg = ds_npcs.tables()
    catalog = json.load(open(os.path.join(CREATOR, "catalog.json")))["parts"]
    os.makedirs(CHARS, exist_ok=True)
    made, kept, total = {}, set(), 0

    def convert(base):
        if base in made:
            return made[base]
        dest = None
        if base in POKEMON:
            mon = base.split("_facing")[0].split("_carrying")[0].split("_still")[0].split("_front")[0].split("_asleep")[0]
            mon = mon.rstrip("_12").rstrip("_")
            s = "SPRITE_FOLLOWER_MON_" + mon.upper()
            name = "hg_follow_" + mon
            if s in hg and ds_npcs.sheet(hg[s], os.path.join(CHARS, name + ".png")):
                dest = "ds/" + name
        elif base in SAME:
            src, s = SAME[base]
            if src == "hg" and s in hg:
                name = "hg_" + s.replace("SPRITE_", "").lower()
                if ds_npcs.sheet(hg[s], os.path.join(CHARS, name + ".png")):
                    dest = "ds/" + name
            elif src == "pt":
                name = "pt_" + s.replace("OBJ_EVENT_GFX_", "").lower()
                if sinnoh.sprite_sheet(s, os.path.join(CHARS, name + ".png")):
                    dest = "ds/" + name
        elif base in LOOKS:
            name = "look_" + base
            compose(*LOOKS[base], catalog).save(os.path.join(CHARS, name + ".png"))
            dest = "ds/" + name
        made[base] = dest
        return dest

    for f in sorted(os.listdir(CDIR)):
        if not (f.endswith(".json") and f[:3] in ("kt_", "hn_")):
            continue
        p = os.path.join(CDIR, f)
        d = json.load(open(p))
        changed = False
        for n in d.get("npcs", []):
            s = n.get("sprite", "")
            if not s.startswith("gba/"):
                continue
            base = s[4:].split("_", 1)[1]
            dest = convert(base)
            if dest:
                n["sprite"] = dest
                changed = True
                total += 1
            else:
                kept.add(base)
        if changed:
            json.dump(d, open(p, "w"), separators=(",", ":"))
    print(total, "NPCs no estilo DS,", sum(1 for v in made.values() if v), "sprites; mantidos do GBA:", sorted(kept))


if __name__ == "__main__":
    main()
