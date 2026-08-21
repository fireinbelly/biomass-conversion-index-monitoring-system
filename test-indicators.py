#!/usr/bin/env python3
"""Guards the indicator word list in templates/indicators.json.

The list is matched against every prompt in every language at once, which creates three
ways to be wrong, and this checks all three:

  1. It misses real swearing. CJK, Thai and Korean are the interesting cases: those
     scripts have no spaces, so whole-word matching never fires on them.
  2. It fires on innocent text. A term that sits inside an ordinary word is a false
     positive forever - 幹 inside 幹嘛, ばか inside ばかり, 시발 inside 시발점 - and
     because every language is matched at once, a term can also collide with an
     ordinary word in a *different* language: fr `con`, sv `fan`, de `Mist`, en `git`.
  3. It counts things that aren't swearing. OMG, darn, heck and 天啊 are not profanity,
     and neither are the softened forms of real swears (sv jäklar, tl putragis).

Usage: python3 test-indicators.py
"""
import importlib.util
import json
import sys
from pathlib import Path

REPO = Path(__file__).parent
TRACKER = REPO / 'templates' / 'prompt-tracker.py'

spec = importlib.util.spec_from_file_location('prompt_tracker', TRACKER)
tracker = importlib.util.module_from_spec(spec)
spec.loader.exec_module(tracker)
count_curse_words = tracker.count_curse_words

INDICATORS = json.loads((REPO / 'templates' / 'indicators.json').read_text(encoding='utf-8'))
BY_LANGUAGE = INDICATORS['curse_words']

# --- 1. real swearing is caught, in every language the list claims to cover ----------
# One sample per language, phrased the way someone actually swears at a build.
CAUGHT = {
    'en': 'this fucking build is broken again, what the hell',
    'zh': '他媽的這個編譯又壞了，靠北',
    'zh-slang': '這個 bug 讓我想 e04',
    'zh-cjk-nospace': '幹你娘勒這什麼爛API',
    'yue': '呢個 API 好撚煩，仆街',
    'ja': 'クソ、またビルドが壊れた。ちくしょう',
    'ko': '씨발 이 빌드 또 깨졌네 존나 짜증나',
    'th': 'เหี้ยจริง build พังอีกแล้ว',
    'vi': 'đéo hiểu sao cái build này lỗi, đm',
    'es': 'joder, este puto build está roto otra vez',
    'fr': 'putain de merde, ce build est encore cassé',
    'de': 'scheiße, der build ist schon wieder kaputt',
    'pt': 'caralho, esse build quebrou de novo, porra',
    'it': 'cazzo, questa build è di nuovo rotta',
    'ru': 'блядь, эта сборка опять сломалась, пиздец',
    'uk': 'знову гівно, ця збірка не працює',
    'pl': 'kurwa, ten build znowu się wypierdolił',
    'cs': 'do prdele, ten build je zase v hajzlu',
    'sk': 'kurva, ten build je zase pokazený',
    'hu': 'bazd meg, megint szar ez a build',
    'ro': 'futu-i, iar s-a stricat build-ul',
    'bg': 'мамка му, тоя build пак се счупи',
    'sr': 'jebote, opet je sranje ovaj build',
    'sl': 'jebemti, spet je sranje',
    'nl': 'kut, die build is weer stuk, godverdomme',
    'af': 'kak, die build is weer stukkend',
    'sv': 'jävla skitsnack, bygget är sönder igen',
    'no': 'faen, bygget er ødelagt igjen',
    'da': 'for helvede, det er noget lort igen',
    'fi': 'vittu, tämä build on taas rikki, perkele',
    'is': 'helvítis build er bilað aftur',
    'et': 'kurat, see build on jälle katki',
    'lt': 'šūdas, vėl neveikia',
    'lv': 'sūds, atkal nestrādā',
    'tr': 'amk bu build yine bozuldu, siktir',
    'el': 'γαμώτο, χάλασε πάλι το build, μαλάκα',
    'he': 'איזה חרא, הבילד נשבר שוב',
    'ar': 'خرا على هذا الكود',
    'fa': 'کیر توش، باز خراب شد',
    'ur': 'یہ چوتیا کوڈ پھر ٹوٹ گیا',
    'hi': 'ये chutiya build फिर टूट गया',
    'bn': 'এই বাল এর কোড আবার ভাঙল',
    'ta': 'இந்த புண்டை code மறுபடியும் உடைஞ்சு போச்சு',
    'id': 'bangsat, build-nya rusak lagi',
    'ms': 'pukimak, build rosak lagi',
    'tl': 'putangina, sira na naman ang build',
    'ca': 'collons, la build està trencada altre cop',
}

# --- 2. innocent text must score zero ------------------------------------------------
# Every entry here is a real word or phrase that a near-miss term sits inside.
INNOCENT = [
    # English words containing a term
    'hello world, run this in the shell',
    'git status shows a merge conflict on the class assignment',
    'classic assembly output, assign the passphrase',
    'the mist cleared and the fan kept spinning',
    'we watched a comedy skit about pros and cons',
    'the office is on a cul-de-sac and he is a con artist',
    'analyse the cassette and the bassinet',
    # Chinese: 幹/操/靠/三小/媽的 all sit inside ordinary words
    '幹嘛要改主幹分支？樹幹圖太亂了',
    '這個工程師很能幹，是團隊骨幹',
    '三小時後執行資料庫操作',
    '我靠近伺服器機房的時候斷線了',
    '請幫我查我媽的電話號碼格式',
    '干净的代码比注释重要',
    '柒佰元的發票要重開',
    # Cantonese: 撚手小菜 is a dish, 斑鳩 is a bird
    '這間餐廳的撚手小菜好好食',
    '公園入面有好多斑鳩',
    # Japanese: ばかり / カスタム / ボケる / しねぇ
    '設定ファイルばかり増えていく',
    'カスタムフックを追加してください',
    '写真がボケるので設定を直したい',
    'この処理が動作しねぇんだけど',
    # Korean: 시발점 / 씹다 / 졸라대다 / 강아지 새끼
    '이 함수가 시발점입니다',
    '껌을 씹다가 회의에 들어갔다',
    '사용자가 계속 졸라대는 기능이에요',
    '강아지 새끼 사진을 업로드했어요',
    # Thai: หีบ / แม่งาน
    'หีบใส่เอกสารอยู่ในห้อง',
    'เขาเป็นแม่งานของโครงการนี้',
    # Other languages' ordinary words that collide with a swear in another language
    'necesito coger el archivo de la concha de mar',
    'de mist trok op boven het veld',
    'la voiture est dans le garage',
    'wir haben den Mist vom Feld geholt',
    'han är ett stort fan av bandet',
]

# --- 3. minced oaths and mild interjections are not swearing --------------------------
NOT_SWEARING = [
    'omg this is so annoying',
    'darn, heck, gosh, jeez, shoot, frick, crikey, blimey',
    'oh my goodness, what on earth, for goodness sake',
    'shucks, fudge, sugar, dang, drat',
    '天啊，這個好難',
    'あら、大変ですね',
    '어머 세상에',
    'jäklar, det var synd',          # sv, softened jävlar
    'putragis naman o',              # tl, softened putangina
    'aduh kampret banget',           # id, softened
    'no me digas, gilipuertas',      # es, softened gilipollas
    'mannaggia, che sfortuna',       # it, mild
    'бляха муха, вот незадача',      # ru/uk, softened бля
]


def run():
    failures = []

    print('1. real swearing is caught')
    for label, text in sorted(CAUGHT.items()):
        count, found = count_curse_words(text)
        if count:
            print('    PASS  %-16s %s' % (label, ', '.join(sorted(set(found)))))
        else:
            print('    FAIL  %-16s nothing matched: %s' % (label, text))
            failures.append('%s: missed' % label)

    print('\n2. innocent text scores zero')
    for text in INNOCENT:
        count, found = count_curse_words(text)
        if count:
            print('    FAIL  %r tripped %s' % (text, sorted(set(found))))
            failures.append('false positive: %s' % found)
        else:
            print('    PASS  %s' % text[:58])

    print('\n3. minced oaths are not counted')
    for text in NOT_SWEARING:
        count, found = count_curse_words(text)
        if count:
            print('    FAIL  %r tripped %s' % (text, sorted(set(found))))
            failures.append('minced oath counted: %s' % found)
        else:
            print('    PASS  %s' % text[:58])

    # --- 4. no non-English term may be an ordinary English word ----------------------
    # Every list is matched against every prompt, so a Swedish term that happens to be
    # an English word turns every English prompt into a false positive. The system word
    # list is the cheapest check available for that.
    print('\n4. no non-English term collides with an English dictionary word')
    words_file = Path('/usr/share/dict/words')
    if not words_file.exists():
        print('    SKIP  %s not present - this check did NOT run' % words_file)
    else:
        english = {w.strip().lower() for w in words_file.read_text().splitlines() if w.strip()}
        # Accepted homographs are declared in indicators.json with a reason each, so a
        # new collision still fails here instead of being absorbed silently.
        allowed = set(BY_LANGUAGE['en']) | {
            k for k in INDICATORS.get('_english_homographs', {}) if not k.startswith('_')
        }
        collisions = sorted(
            (lang, term)
            for lang, terms in BY_LANGUAGE.items() if lang != 'en'
            for term in terms
            if term not in allowed and term in english
        )
        if collisions:
            for lang, term in collisions:
                print('    FAIL  %s:%r is also an English word' % (lang, term))
            failures.append('%d English collisions' % len(collisions))
        else:
            print('    PASS  checked %d terms against %d English words'
                  % (sum(len(t) for lang, t in BY_LANGUAGE.items() if lang != 'en'), len(english)))

    # --- 5. every term must be lowercase ---------------------------------------------
    # The prompt is lowercased before matching, so an uppercase term can never fire.
    # That failure is silent, which is the worst kind.
    print('\n5. every term is lowercase')
    uppercase = sorted((lang, t) for lang, terms in BY_LANGUAGE.items()
                       for t in terms if t != t.lower())
    if uppercase:
        for lang, term in uppercase:
            print('    FAIL  %s:%r would never match' % (lang, term))
        failures.append('%d uppercase terms' % len(uppercase))
    else:
        print('    PASS  no term would be missed on case')

    total = sum(len(t) for t in BY_LANGUAGE.values())
    print('\n==================================')
    print('  %d terms across %d languages' % (total, len(BY_LANGUAGE)))
    print('  passed' if not failures else '  FAILED: %s' % '; '.join(failures))
    print('==================================')
    return 1 if failures else 0


if __name__ == '__main__':
    sys.exit(run())
