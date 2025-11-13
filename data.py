import requests
import csv
import time
import json
from pathlib import Path
from datetime import datetime


api_key = "" # TODO : Use an environment variable here
puuid = "LkQIcJSPlLfdFhdBGJh1DhB5CuOAiWUL5b_ThBL00jm-Nz3eZ-D4j9ddwaeyKbHGO5NxHTGpmE6S7A"
region = "asia"
DATA_DIR = Path("data/items")
ICON_DIR = Path("data/icons")

# ---------------------------
# 1️⃣ Récupération des IDs de matchs (avec pagination)
# ---------------------------
def get_match_ids(puuid, region, count=100):
    all_match_ids = []
    offset = 0

    print("🔍 Récupération de tous les match IDs...")

    while True:
        url = f"https://{region}.api.riotgames.com/lol/match/v5/matches/by-puuid/{puuid}/ids"
        params = {
            "start": offset,
            "count": count,
            "api_key": api_key
        }

        response = requests.get(url, params=params)
        if response.status_code == 429:
            print("⏳ Rate limit atteint, pause 10 secondes...")
            time.sleep(10)
            continue

        if response.status_code != 200:
            print(f"⚠️ Erreur HTTP {response.status_code} à l’offset {offset}")
            print(f"Url : {url}, Offset : {offset}, Count : {count}, Key : {api_key}")
            break

        batch = response.json()
        if not batch:
            print("✅ Fin : plus de matchs à récupérer.")
            break

        all_match_ids.extend(batch)
        offset += count

        print(f"→ {len(batch)} nouveaux matchs récupérés (total = {len(all_match_ids)})")

        time.sleep(1.2)  # éviter le rate limit

    return all_match_ids


# ---------------------------
# 2️⃣ Récupération d’un match complet
# ---------------------------
def get_match_data(match_id, region):
    url = f"https://{region}.api.riotgames.com/lol/match/v5/matches/{match_id}"
    params = {"api_key": api_key}

    for attempt in range(3):
        try:
            response = requests.get(url, params=params)
            if response.status_code == 429:
                print("Rate limit atteint, pause 5s...")
                time.sleep(5)
                continue
            response.raise_for_status()
            return response.json()
        except requests.RequestException as e:
            print(f"Erreur sur {match_id}: {e}")
            time.sleep(2)
    return None

# ---------------------------
# 3️⃣ Gestion des données d’items
# ---------------------------
def get_item_data(version, lang="fr_FR"):
    """Récupère ou télécharge le fichier d'items correspondant à la version donnée."""
    DATA_DIR.mkdir(parents=True, exist_ok=True)
    filepath = DATA_DIR / f"items_{version}.json"

    if filepath.exists():
        with open(filepath, "r", encoding="utf-8") as f:
            return json.load(f)["data"]

    url = f"https://ddragon.leagueoflegends.com/cdn/{version}/data/{lang}/item.json"
    print(f"⬇️ Téléchargement des données items ({version})...")
    response = requests.get(url)
    if response.status_code != 200:
        print(f"⚠️ Impossible de récupérer item.json pour {version}")
        return {}

    data = response.json()
    filepath.write_text(json.dumps(data, ensure_ascii=False, indent=2), encoding="utf-8")
    print(f"✅ Item data {version} sauvegardée dans {filepath}")
    return data["data"]


def download_item_icon(item_id, item_info, version):
    """Télécharge l’icône d’un item spécifique pour la version donnée."""
    ICON_DIR.mkdir(parents=True, exist_ok=True)
    outdir = ICON_DIR / version
    outdir.mkdir(parents=True, exist_ok=True)

    filename = item_info["image"]["full"]
    icon_path = outdir / filename
    if icon_path.exists():
        return str(icon_path)

    base_url = f"https://ddragon.leagueoflegends.com/cdn/{version}/img/item/{filename}"
    try:
        response = requests.get(base_url)
        if response.status_code == 200:
            icon_path.write_bytes(response.content)
            return str(icon_path)
        else:
            print(f"⚠️ Impossible de télécharger {filename} ({response.status_code})")
    except Exception as e:
        print(f"⚠️ Erreur lors du téléchargement de {filename}: {e}")
    return ""

# ---------------------------
# 3️⃣ Extraction des données du joueur
# ---------------------------


def extract_player_data(match, puuid):
    info = match.get("info", {})
    metadata = match.get("metadata", {})
    version_full = info.get("gameVersion", "")
    version = ".".join(version_full.split(".")[:2])  # Ex: "15.22"

    item_data = get_item_data(version)

    for p in info.get("participants", []):
        if p["puuid"] == puuid:
            ts = info.get("gameStartTimestamp")
            challenges = p.get("challenges", {}) 
            item_ids = [p.get(f"item{i}") for i in range(7)]
            item_details = []
            for item_id in item_ids:
                if not item_id or str(item_id) not in item_data:
                    item_details.append({"id": item_id, "name": "", "icon_path": ""})
                    continue
                item_info = item_data[str(item_id)]
                icon_path = download_item_icon(str(item_id), item_info, version)
                item_details.append({
                    "id": item_id,
                    "name": item_info["name"],
                    "icon_path": icon_path,
                })

            return {
                "match_id": metadata.get("matchId"),
                "end_of_game_result": info.get("endOfGameResult"),
                "game_mode": info.get("gameMode"),
                "game_name": info.get("gameName"),
                "duration_sec": info.get("gameDuration"),
                "game_version": info.get("gameVersion"),
                "win": p.get("win"),
                "game_ended_in_early_surrender": p.get("gameEndedInEarlySurrender"),
                "championName": p.get("championName"),
                "lane": p.get("lane"),
                "champ_level": p.get("champLevel"),
                "gold_earned": p.get("goldEarned"),
                "items_purchased": p.get("itemsPurchased"),
                "items": ";".join([str(i["id"]) for i in item_details if i["id"]]),
                "item_names": ";".join([i["name"] for i in item_details if i["name"]]),
                "item_icons": ";".join([i["icon_path"] for i in item_details if i["icon_path"]]),
                "vision_score": p.get("vision_score"),
                "damage_dealt": p.get("totalDamageDealt"),
                "damage_dealt_to_champion": p.get("totalDamageDealtToChampion"),
                "damage_dealt_to_buildings": p.get("damageDealtToBuildings"),
                "damage_dealt_to_objectives": p.get("damageDealtToObjectives"),
                "damage_dealt_to_turrets": p.get("damageDealtToTurrets"),
                "damage_taken": p.get("totalDamageTaken"),
                "minions_killed": p.get("totalMinionsKilled"),
                "baron_kills": p.get("baronKills"),
                "dragon_kills": p.get("dragonKills"),
                "win": p.get("win"),
                "first_bloodKill": p.get("firstBloodAssist"),
                "first_tower_kill": p.get("firstTowerKill"),
                "kills": p.get("kills"),
                "solo_kills": challenges.get("soloKills"),
                "double_kills": p.get("doubleKills"),
                "triple_kills": p.get("tripleKills"),
                "quadra_kills": p.get("quadraKills"),
                "penta_kills": p.get("pentaKills"),
                "largest_multi_kill": p.get("largestMultiKill"),
                "kill_participation": p.get("challenges", {}).get("killParticipation"),
                "deaths": p.get("deaths"),
                "assists": p.get("assists"),
            }
    return None 

# ---------------------------
# 4️⃣ Écriture CSV
# ---------------------------
def write_csv(data, filename="faker_all_matches.csv"):
    if not data:
        print("⚠️ Aucune donnée à écrire.")
        return

    keys = list(data[0].keys())
    with open(filename, "w", newline="", encoding="utf-8") as f:
        writer = csv.DictWriter(f, fieldnames=keys)
        writer.writeheader()
        writer.writerows(data)
    print(f"✅ Fichier CSV créé : {filename} ({len(data)} matchs)")


# ---------------------------
# 5️⃣ MAIN
# ---------------------------
if __name__ == "__main__":
    all_data = []

    # Récupération de tous les match IDs avec pagination
    match_ids = get_match_ids(puuid, region, count=100)

    # Récupération détaillée de chaque match
    for i, match_id in enumerate(match_ids, 1):
        print(f"({i}/{len(match_ids)}) → Match {match_id}")
        match = get_match_data(match_id, region)
        if not match:
            print("⚠️ Échec récupération, on passe au suivant.")
            continue

        player_data = extract_player_data(match, puuid)
        if player_data:
            all_data.append(player_data)

        time.sleep(1.2)

    # Export CSV
    write_csv(all_data)
