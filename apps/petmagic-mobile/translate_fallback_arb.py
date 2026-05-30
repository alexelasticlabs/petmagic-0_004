import json
import re
import time
import argparse
import urllib.parse
import requests
from pathlib import Path

l10n_dir = Path("lib/l10n")
en_path = l10n_dir / "app_en.arb"
TARGETS = [
    ("app_de.arb", "de"),
    ("app_es.arb", "es"),
    ("app_fr.arb", "fr"),
    ("app_it.arb", "it"),
    ("app_pl.arb", "pl"),
]

placeholder_pattern = re.compile(r"\{[^{}]+\}")
newline_token = "___PM_NL___"

def protect_text(text: str):
    tokens = {}
    idx = 0

    def repl(m):
        nonlocal idx
        token = f"___PM_PH_{idx}___"
        tokens[token] = m.group(0)
        idx += 1
        return token

    protected = placeholder_pattern.sub(repl, text)
    protected = protected.replace("\n", newline_token)
    return protected, tokens


def restore_text(text: str, tokens):
    restored = text.replace(newline_token, "\n")
    for token, value in tokens.items():
        restored = restored.replace(token, value)
    return restored


def parse_args():
    parser = argparse.ArgumentParser()
    parser.add_argument("--locale", help="Locale code: de|es|fr|it|pl", default=None)
    parser.add_argument("--max", type=int, default=0, help="Translate at most N fallback keys per run (0 = all)")
    return parser.parse_args()


def translate_batch_with_retry(target_lang, batch):
    last_error = None
    for attempt in range(3):
        try:
            result = []
            for text in batch:
                query = urllib.parse.urlencode(
                    {
                        "client": "gtx",
                        "sl": "en",
                        "tl": target_lang,
                        "dt": "t",
                        "q": text,
                    }
                )
                url = f"https://translate.googleapis.com/translate_a/single?{query}"
                response = requests.get(url, timeout=8)
                response.raise_for_status()
                payload = response.json()
                translated_text = "".join(part[0] for part in payload[0])
                result.append(translated_text)

            if result and len(result) == len(batch):
                return result
        except Exception as ex:
            last_error = ex
        time.sleep(1.5 * (attempt + 1))
    raise RuntimeError(f"batch translation failed after retries: {last_error}")


args = parse_args()
en_data = json.loads(en_path.read_text(encoding="utf-8"))
failures = []

targets = TARGETS
if args.locale:
    targets = [item for item in TARGETS if item[1] == args.locale]
    if not targets:
        raise ValueError(f"Unknown locale: {args.locale}")

for file_name, lang in targets:
    path = l10n_dir / file_name
    locale_data = json.loads(path.read_text(encoding="utf-8"))
    translated_count = 0

    to_translate = []

    for key, en_value in en_data.items():
        if key.startswith("@"):
            continue
        if key not in locale_data:
            continue
        local_value = locale_data[key]
        if not isinstance(en_value, str) or not isinstance(local_value, str):
            continue
        if local_value != en_value:
            continue

        protected, tokens = protect_text(en_value)
        to_translate.append((key, protected, tokens))

    if args.max > 0:
        to_translate = to_translate[:args.max]

    print(f"{file_name}: queued={len(to_translate)}")

    for index in range(0, len(to_translate), 40):
        chunk = to_translate[index:index + 40]
        protected_values = [item[1] for item in chunk]
        print(f"{file_name}: chunk {index // 40 + 1} ({index + 1}-{index + len(chunk)})")

        try:
            translated_values = translate_batch_with_retry(lang, protected_values)
        except Exception as ex:
            for key, _, _ in chunk:
                failures.append(f"{file_name}:{key}:{ex}")
            continue

        for (key, _, tokens), translated in zip(chunk, translated_values):
            if translated is None:
                failures.append(f"{file_name}:{key}:empty_translation")
                continue
            locale_data[key] = restore_text(str(translated), tokens)
            translated_count += 1

        # Be gentle with public translation endpoints.
        time.sleep(0.4)

    path.write_text(json.dumps(locale_data, ensure_ascii=False, indent=2) + "\n", encoding="utf-8", newline="\n")
    print(f"{file_name}: translated={translated_count}")

if failures:
    print("---TRANSLATION_FAILURES---")
    for item in failures:
        print(item)
else:
    print("---TRANSLATION_FAILURES---")
    print("none")
