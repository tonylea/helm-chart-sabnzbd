import json
import os

from configobj import ConfigObj

with open("/settings/settings.json") as f:
    settings = json.load(f)

cfg = ConfigObj("/config/sabnzbd.ini", encoding="utf-8", create_empty=True)
misc = cfg.setdefault("misc", {})
misc["api_key"] = os.environ["API_KEY"]
misc["nzb_key"] = os.environ["NZB_KEY"]
misc["username"] = os.environ["UI_USERNAME"]
misc["password"] = os.environ["UI_PASSWORD"]
misc["download_dir"] = settings["downloadDir"]
misc["complete_dir"] = settings["completeDir"]
misc["cache_limit"] = settings["cacheLimit"]


def flag(value):
    return "1" if value else "0"


servers = cfg.setdefault("servers", {})
for i, server in enumerate(settings["servers"]):
    section = servers.setdefault(server["name"], {})
    section["host"] = server["host"]
    section["port"] = str(int(server["port"]))
    section["ssl"] = flag(server["ssl"])
    section["username"] = os.environ[f"SERVER_{i}_USERNAME"]
    section["password"] = os.environ[f"SERVER_{i}_PASSWORD"]
    section["connections"] = str(int(server["connections"]))
    section["enable"] = flag(server["enable"])

categories = cfg.setdefault("categories", {})
for category in settings["categories"]:
    section = categories.setdefault(category["name"], {})
    section["dir"] = category["dir"]
    section["pp"] = category["pp"]
    section["script"] = category["script"]
    section["priority"] = str(int(category["priority"]))
    os.makedirs(os.path.join(settings["completeDir"], category["dir"]), exist_ok=True)

cfg.write()
