#!/usr/bin/env python3
"""App Store Connect API из командной строки. Без зависимостей: stdlib + openssl.

    python3 -I asc.py status  BUNDLE
    python3 -I asc.py version BUNDLE VERSION BUILD [--auto]
    python3 -I asc.py texts   BUNDLE VERSION LOCALE [--notes F] [--description F] [--promo F]
                                                    [--keywords S] [--support URL] [--marketing URL]
    python3 -I asc.py shots   BUNDLE VERSION LOCALE DISPLAY_TYPE DIR
    python3 -I asc.py review  BUNDLE VERSION show | set FILE
    python3 -I asc.py submit  BUNDLE VERSION
    python3 -I asc.py changes BUNDLE [--testflight]   PR с последней версии в App Store
                                                    (или с последней сборки) — черновик «Что нового»
    python3 -I asc.py call    METHOD PATH [JSON_BODY]

Ключ: ~/.appstoreconnect/config.json ({"key_id", "issuer_id"}) и
private_keys/AuthKey_<key_id>.p8; переменные ASC_KEY_ID / ASC_ISSUER_ID имеют приоритет.
Ни ключ, ни идентификаторы в репозиторий не кладём.
"""
import base64
import glob
import hashlib
import json
import os
import pathlib
import subprocess
import sys
import time
import urllib.error
import urllib.parse
import urllib.request

try:  # корпоративный TLS-прокси: доверять системной связке ключей, если truststore есть
    import truststore
    truststore.inject_into_ssl()
except ImportError:
    pass

BASE = "https://api.appstoreconnect.apple.com"
HOME = pathlib.Path.home() / ".appstoreconnect"


def config():
    cfg = json.loads((HOME / "config.json").read_text()) if (HOME / "config.json").exists() else {}
    key_id = os.environ.get("ASC_KEY_ID") or cfg.get("key_id")
    issuer = os.environ.get("ASC_ISSUER_ID") or cfg.get("issuer_id")
    if not key_id or not issuer:
        sys.exit("нет ключа: заполни ~/.appstoreconnect/config.json или ASC_KEY_ID / ASC_ISSUER_ID")
    return key_id, issuer, HOME / "private_keys" / f"AuthKey_{key_id}.p8"


def b64(b):
    return base64.urlsafe_b64encode(b).rstrip(b"=").decode()


def der_to_raw(der):
    """ECDSA-подпись openssl (DER SEQUENCE{r, s}) → 64 байта r||s для JWT ES256."""
    pos = 3 if der[1] & 0x80 else 2  # длина SEQUENCE в короткой или длинной форме
    out = b""
    for _ in range(2):
        length = der[pos + 1]
        out += der[pos + 2:pos + 2 + length].lstrip(b"\0").rjust(32, b"\0")
        pos += 2 + length
    return out


_token = (0, "")


def token():
    global _token
    now = int(time.time())
    if _token[0] > now + 60:
        return _token[1]
    key_id, issuer, key = config()
    head = b64(json.dumps({"alg": "ES256", "kid": key_id, "typ": "JWT"}).encode())
    body = b64(json.dumps({"iss": issuer, "iat": now, "exp": now + 1200,
                           "aud": "appstoreconnect-v1"}).encode())
    der = subprocess.run(["openssl", "dgst", "-sha256", "-sign", str(key)],
                         input=f"{head}.{body}".encode(), capture_output=True, check=True).stdout
    _token = (now + 1200, f"{head}.{body}.{b64(der_to_raw(der))}")
    return _token[1]


def request(method, url, data=None, headers=None):
    req = urllib.request.Request(url, data=data, method=method, headers=headers or {})
    with urllib.request.urlopen(req, timeout=120) as r:
        return r.read()


def call(method, path, body=None, **params):
    url = path if path.startswith("http") else BASE + path
    if params:
        url += "?" + urllib.parse.urlencode(params)
    data = json.dumps(body, ensure_ascii=False).encode() if body is not None else None
    try:
        raw = request(method, url, data, {"Authorization": "Bearer " + token(),
                                          "Content-Type": "application/json"})
    except urllib.error.HTTPError as e:
        sys.exit(f"{method} {path} → {e.code}\n{e.read().decode()}")
    return json.loads(raw) if raw else {}


def get(path, **params):
    return call("GET", path, **params)


def rel(kind, id_):
    return {"data": {"type": kind, "id": id_}}


def app_id(bundle):
    data = get("/v1/apps", **{"filter[bundleId]": bundle})["data"]
    return data[0]["id"] if data else sys.exit(f"нет приложения {bundle}")


def find_version(aid, ver):
    data = get(f"/v1/apps/{aid}/appStoreVersions", **{"filter[versionString]": ver})["data"]
    return data[0] if data else sys.exit(f"нет версии {ver}; создай её командой version")


def localization(vid, locale):
    for loc in get(f"/v1/appStoreVersions/{vid}/appStoreVersionLocalizations")["data"]:
        if loc["attributes"]["locale"] == locale:
            return loc["id"]
    sys.exit(f"нет локализации {locale}")


def build_id(aid, number):
    data = get("/v1/builds", **{"filter[app]": aid, "filter[version]": number})["data"]
    if not data:
        sys.exit(f"нет сборки {number}")
    state = data[0]["attributes"]["processingState"]
    return data[0]["id"] if state == "VALID" else sys.exit(f"сборка {number}: {state}, дождись VALID")


def status(bundle):
    aid = app_id(bundle)
    print("app", aid)
    for v in get(f"/v1/apps/{aid}/appStoreVersions", limit=5)["data"]:
        a = v["attributes"]
        print("version", a["versionString"], a["appStoreState"], a.get("releaseType"), v["id"])
    for b in get("/v1/builds", **{"filter[app]": aid, "sort": "-uploadedDate", "limit": 5})["data"]:
        a = b["attributes"]
        print("build", a["version"], a["processingState"], "expired" if a["expired"] else "")
    for s in get("/v1/reviewSubmissions", **{"filter[app]": aid, "limit": 5})["data"]:
        a = s["attributes"]
        print("submission", a["state"], a.get("submittedDate") or "", s["id"])


def version(bundle, ver, build, auto=False):
    aid = app_id(bundle)
    bid = build_id(aid, build)
    existing = get(f"/v1/apps/{aid}/appStoreVersions", **{"filter[versionString]": ver})["data"]
    if existing:
        vid = existing[0]["id"]
        call("PATCH", f"/v1/appStoreVersions/{vid}/relationships/build", rel("builds", bid))
    else:
        vid = call("POST", "/v1/appStoreVersions", {"data": {
            "type": "appStoreVersions",
            "attributes": {"platform": "IOS", "versionString": ver,
                           "releaseType": "AFTER_APPROVAL" if auto else "MANUAL"},
            "relationships": {"app": rel("apps", aid), "build": rel("builds", bid)}}})["data"]["id"]
    print("version", ver, vid, "build", build)


def texts(bundle, ver, locale, flags):
    lid = localization(find_version(app_id(bundle), ver)["id"], locale)
    from_file = {"--description": "description", "--notes": "whatsNew", "--promo": "promotionalText"}
    plain = {"--support": "supportUrl", "--marketing": "marketingUrl", "--keywords": "keywords"}
    attrs = {from_file[f]: pathlib.Path(v).read_text().strip() for f, v in flags.items() if f in from_file}
    attrs |= {plain[f]: v for f, v in flags.items() if f in plain}
    if not attrs:
        sys.exit("нечего менять")
    call("PATCH", f"/v1/appStoreVersionLocalizations/{lid}",
         {"data": {"type": "appStoreVersionLocalizations", "id": lid, "attributes": attrs}})
    print("updated", ", ".join(attrs))


def upload(set_id, path):
    data = pathlib.Path(path).read_bytes()
    shot = call("POST", "/v1/appScreenshots", {"data": {
        "type": "appScreenshots",
        "attributes": {"fileName": os.path.basename(path), "fileSize": len(data)},
        "relationships": {"appScreenshotSet": rel("appScreenshotSets", set_id)}}})["data"]
    for op in shot["attributes"]["uploadOperations"]:
        chunk = data[op["offset"]:op["offset"] + op["length"]]
        request(op["method"], op["url"], chunk, {h["name"]: h["value"] for h in op["requestHeaders"]})
    call("PATCH", f"/v1/appScreenshots/{shot['id']}", {"data": {
        "type": "appScreenshots", "id": shot["id"],
        "attributes": {"uploaded": True, "sourceFileChecksum": hashlib.md5(data).hexdigest()}}})


def shots(bundle, ver, locale, kind, folder):
    files = sorted(glob.glob(os.path.join(folder, "*.png")))
    if not files:
        sys.exit(f"в {folder} нет png")
    lid = localization(find_version(app_id(bundle), ver)["id"], locale)
    sets = {s["attributes"]["screenshotDisplayType"]: s["id"]
            for s in get(f"/v1/appStoreVersionLocalizations/{lid}/appScreenshotSets")["data"]}
    set_id = sets.get(kind)
    if set_id:
        for s in get(f"/v1/appScreenshotSets/{set_id}/appScreenshots")["data"]:
            call("DELETE", f"/v1/appScreenshots/{s['id']}")
    else:
        set_id = call("POST", "/v1/appScreenshotSets", {"data": {
            "type": "appScreenshotSets", "attributes": {"screenshotDisplayType": kind},
            "relationships": {"appStoreVersionLocalization":
                              rel("appStoreVersionLocalizations", lid)}}})["data"]["id"]
    for f in files:
        upload(set_id, f)
    states = []
    for _ in range(30):
        states = [s["attributes"]["assetDeliveryState"]["state"]
                  for s in get(f"/v1/appScreenshotSets/{set_id}/appScreenshots")["data"]]
        if all(s == "COMPLETE" for s in states):
            break
        time.sleep(10)
    print(kind, len(files), "uploaded", states)


def review(bundle, ver, action, path=None):
    vid = find_version(app_id(bundle), ver)["id"]
    detail = get(f"/v1/appStoreVersions/{vid}/appStoreReviewDetail").get("data")
    if action == "show":
        print(detail["attributes"]["notes"] if detail else "(заметок нет)")
        return
    notes = pathlib.Path(path).read_text().strip()
    if detail:
        call("PATCH", f"/v1/appStoreReviewDetails/{detail['id']}", {"data": {
            "type": "appStoreReviewDetails", "id": detail["id"], "attributes": {"notes": notes}}})
    else:
        call("POST", "/v1/appStoreReviewDetails", {"data": {
            "type": "appStoreReviewDetails", "attributes": {"notes": notes},
            "relationships": {"appStoreVersion": rel("appStoreVersions", vid)}}})
    print("review notes updated")


def submit(bundle, ver):
    aid = app_id(bundle)
    v = find_version(aid, ver)
    state = v["attributes"]["appStoreState"]
    if state != "PREPARE_FOR_SUBMISSION":
        sys.exit(f"версия {ver} в состоянии {state}, отправлять нечего")
    # Черновик отправки не отменяется, а Apple держит один на платформу — переиспользуем.
    drafts = get("/v1/reviewSubmissions", **{"filter[app]": aid, "filter[state]": "READY_FOR_REVIEW"})["data"]
    sid = drafts[0]["id"] if drafts else call("POST", "/v1/reviewSubmissions", {"data": {
        "type": "reviewSubmissions", "attributes": {"platform": "IOS"},
        "relationships": {"app": rel("apps", aid)}}})["data"]["id"]
    call("POST", "/v1/reviewSubmissionItems", {"data": {"type": "reviewSubmissionItems", "relationships": {
        "reviewSubmission": rel("reviewSubmissions", sid),
        "appStoreVersion": rel("appStoreVersions", v["id"])}}})
    r = call("PATCH", f"/v1/reviewSubmissions/{sid}", {"data": {
        "type": "reviewSubmissions", "id": sid, "attributes": {"submitted": True}}})["data"]
    print("submission", r["attributes"]["state"])


SKIP = ("Сборка ", "update.json", "README")


def changes(bundle, testflight=False):
    """Коммиты main после сборки, которая сейчас в App Store (или последней загруженной)."""
    aid = app_id(bundle)
    if testflight:
        build = get("/v1/builds", **{"filter[app]": aid, "sort": "-uploadedDate", "limit": 1})["data"][0]
        label = f"последней загруженной сборки {build['attributes']['version']}"
    else:
        live = get(f"/v1/apps/{aid}/appStoreVersions", **{"filter[appStoreState]": "READY_FOR_SALE"})["data"]
        if not live:
            sys.exit("в App Store нет выпущенной версии")
        build = get(f"/v1/appStoreVersions/{live[0]['id']}/build")["data"]
        label = f"версии {live[0]['attributes']['versionString']} в App Store (сборка {build['attributes']['version']})"
    number = build["attributes"]["version"]
    git = ["git", "-C", str(pathlib.Path(__file__).resolve().parents[1])]
    subprocess.run(git + ["fetch", "-q", "origin", "main"], check=True)
    since = subprocess.run(git + ["log", "origin/main", "--format=%H", "--reverse",
                                  f"-SCURRENT_PROJECT_VERSION: {number}", "--", "app/project.yml"],
                           capture_output=True, text=True, check=True).stdout.split()
    if not since:
        sys.exit(f"не нашёл коммит, где номер сборки стал {number}")
    log = subprocess.run(git + ["log", "--format=%s", f"{since[0]}..origin/main"],
                         capture_output=True, text=True, check=True).stdout.splitlines()
    print(f"Изменения после {label}:")
    for subject in log:
        if not subject.startswith(SKIP):
            print("•", subject)


def main(argv):
    if not argv:
        sys.exit(__doc__)
    cmd, args = argv[0], argv[1:]
    flags, pos, i = {}, [], 0
    while i < len(args):
        if args[i].startswith("--") and i + 1 < len(args) and not args[i + 1].startswith("--"):
            flags[args[i]] = args[i + 1]
            i += 2
        else:
            if not args[i].startswith("--"):
                pos.append(args[i])
            i += 1
    commands = {"status": status, "shots": shots, "review": review, "submit": submit}
    if cmd in commands:
        commands[cmd](*pos)
    elif cmd == "version":
        version(*pos, auto="--auto" in args)
    elif cmd == "changes":
        changes(*pos, testflight="--testflight" in args)
    elif cmd == "texts":
        texts(*pos, flags)
    elif cmd == "call":
        method, path, *body = pos
        print(json.dumps(call(method, path, json.loads(body[0]) if body else None),
                         ensure_ascii=False, indent=1))
    else:
        sys.exit(__doc__)


if __name__ == "__main__":
    main(sys.argv[1:])
