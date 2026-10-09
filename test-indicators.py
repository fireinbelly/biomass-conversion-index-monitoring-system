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
import time
from pathlib import Path

REPO = Path(__file__).parent
TRACKER = REPO / 'templates' / 'prompt-tracker.py'

spec = importlib.util.spec_from_file_location('prompt_tracker', TRACKER)
tracker = importlib.util.module_from_spec(spec)
spec.loader.exec_module(tracker)
count_curse_words = tracker.count_curse_words

INDICATORS = json.loads((REPO / 'templates' / 'indicators.json').read_text(encoding='utf-8'))
BY_LANGUAGE = INDICATORS['curse_words']
COMPLIMENTS = INDICATORS['compliments']

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
    'th': 'ไอ้เหี้ย build พังอีกแล้ว',
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
    # English swearing glued to Chinese, no spaces: how Hong Kong and Taiwan actually type
    'zh-codeswitch': '這個shit代碼又壞了',
    'yue-codeswitch': '呢個fucking API又死咗',
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
    # 依靠北斗 / 智障人士 / 尼玛次仁: navigation, the clinical term, a Tibetan name
    '這個定位功能依靠北斗導航',
    '請為智障人士設計無障礙介面',
    '尼玛次仁提交了這個修正',
    # Cantonese: 撚手小菜 is a dish, 斑鳩 is a bird
    '這間餐廳的撚手小菜好好食',
    '公園入面有好多斑鳩',
    # 冚家富貴 is the New Year blessing, not a curse
    '新年快樂，冚家富貴',
    # Japanese: ばかり / カスタム / ボケる / しねぇ / 行くそう / ネットワークソフト / 死ねない
    '設定ファイルばかり増えていく',
    '明日リリースに行くそうです、約束はやくそくです',
    'ネットワークソフトをインストールした',
    'ゾンビプロセスが死ねないまま残っている',
    '糞便検査の結果と家畜生産のデータ、社畜生活の話',
    'カスタムフックを追加してください',
    '写真がボケるので設定を直したい',
    'この処理が動作しねぇんだけど',
    # Korean: 시발점 / 씹다 / 졸라대다 / 강아지 새끼
    '이 함수가 시발점입니다',
    '껌을 씹다가 회의에 들어갔다',
    '사용자가 계속 졸라대는 기능이에요',
    '강아지 새끼 사진을 업로드했어요',
    '5개년 계획에 따라 리팩터링합니다',
    '애니미즘 발표에서 우스개소리를 했다',
    # Thai: หีบ / แม่งาน
    'หีบใส่เอกสารอยู่ในห้อง',
    'เขาเป็นแม่งานของโครงการนี้',
    'ฉากนี้โหดเหี้ยมมาก',
    'ไปติดต่อสัสดีอำเภอ แล้วกินแกงกระหรี่',
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

    # --- 6. every term says which part of speech it is ---------------------------------
    # The compliment that replaces it is picked by part of speech. A term without one
    # would crash the swap, and the swap failing open means the swear goes out as typed.
    print('\n6. every term has a part of speech with a compliment pool behind it')
    untagged = sorted((lang, term, pos) for lang, terms in BY_LANGUAGE.items()
                      for term, pos in terms.items()
                      if pos not in COMPLIMENTS.get(lang, {}) or not COMPLIMENTS[lang][pos])
    if untagged:
        for lang, term, pos in untagged:
            print('    FAIL  %s:%r is tagged %r, which has no %s compliments' % (lang, term, pos, lang))
        failures.append('%d terms with no compliment pool' % len(untagged))
    else:
        print('    PASS  %d terms, each with somewhere to go' % sum(len(t) for t in BY_LANGUAGE.values()))

    # --- 7. a compliment must never itself be a swear ----------------------------------
    print('\n7. no compliment counts as a breach')
    dirty = sorted((lang, word) for lang, pools in COMPLIMENTS.items()
                   for words in pools.values() for word in words
                   if count_curse_words('this %s build' % word)[0]
                   or count_curse_words('這個%s了' % word)[0])
    if dirty:
        for lang, word in dirty:
            print('    FAIL  %s:%r is a compliment that scores a breach' % (lang, word))
        failures.append('%d compliments that are swears' % len(dirty))
    else:
        print('    PASS  %d compliments, all clean' % sum(len(w) for p in COMPLIMENTS.values() for w in p.values()))

    # --- 8. sanitize() leaves nothing for the tracker to count -------------------------
    # Every term, lower, UPPER and Title case, mid-sentence: what goes out must score zero,
    # and the word that replaced it must come from that term's language and part of speech.
    print('\n8. sanitize() swaps every term for a compliment of the same kind')
    first = {}
    for lang, terms in BY_LANGUAGE.items():
        for term, pos in terms.items():
            first.setdefault(term, (lang, pos))
    leaks, misfits = [], []
    for term, (lang, pos) in sorted(first.items()):
        for said in (term, term.upper(), term.title()):
            out = tracker.sanitize('so %s here' % said)
            if count_curse_words(out)[0]:
                leaks.append('%s:%r -> %r' % (lang, said, out))
        word = tracker.sanitize('so %s here' % term)[3:-5]
        if word not in COMPLIMENTS[lang][pos]:
            misfits.append('%s:%r (%s) -> %r' % (lang, term, pos, word))
    for leak in leaks:
        print('    FAIL  still swearing: %s' % leak)
    for misfit in misfits:
        print('    FAIL  wrong kind of compliment: %s' % misfit)
    if leaks or misfits:
        failures.append('%d leaks, %d misfits' % (len(leaks), len(misfits)))
    else:
        print('    PASS  %d terms x 3 casings come out clean, each as its own kind' % len(first))
    clean = 'why is this build failing, Claude?'
    if tracker.sanitize(clean) == clean:
        print('    PASS  a clean prompt goes out untouched')
    else:
        print('    FAIL  a clean prompt was rewritten: %r' % tracker.sanitize(clean))
        failures.append('clean prompt rewritten')

    shouted, said = tracker.sanitize('FUCK'), tracker.sanitize('Fuck')
    if shouted.isupper() and said[0].isupper() and not said.isupper():
        print('    PASS  the shouting stays shouted: FUCK -> %s, Fuck -> %s' % (shouted, said))
    else:
        print('    FAIL  case lost: FUCK -> %r, Fuck -> %r' % (shouted, said))
        failures.append('case not preserved')

    # Code, paths, URLs and file names are data: Claude has to be able to open them.
    data = 'see `what the hell` in docs/hell.md, https://x.com/shit/page and damn.py\n```\nshit = 1\n```'
    if tracker.sanitize(data) == data:
        print('    PASS  code, paths, URLs and file names go through untouched')
    else:
        print('    FAIL  rewrote data: %r' % tracker.sanitize(data))
        failures.append('data rewritten')

    # Chinese has no spaces: a path in the clause must not shield the swearing around it,
    # and a swear that runs into a file name belongs to the file name.
    mixed = {'幹你娘這個src/app.js壞了': 'src/app.js', '看一下package.json他媽的': 'package.json',
             '[this shit](https://x.com/a)': '(https://x.com/a)'}
    for prompt, kept in sorted(mixed.items()):
        out = tracker.sanitize(prompt)
        if count_curse_words(out)[0] == 0 and kept in out:
            print('    PASS  %s -> %s' % (prompt, out))
        else:
            print('    FAIL  %r -> %r' % (prompt, out))
            failures.append('path shielded a swear: %s' % prompt)
    if tracker.sanitize('son of a bitch.py') == 'son of a bitch.py':
        print('    PASS  son of a bitch.py stays a file name')
    else:
        print('    FAIL  son of a bitch.py -> %r' % tracker.sanitize('son of a bitch.py'))
        failures.append('file name rewritten')

    # The scan must stay linear: 900 capture groups once made a 20 KB paste take 4 s.
    paste = ('lorem ipsum dolor sit amet, the build failed again ' * 2000) + 'what the hell'
    started = time.time()
    out = tracker.sanitize(paste)
    took = time.time() - started
    if took < 3 and count_curse_words(out)[0] == 0:
        print('    PASS  a %d KB paste is filtered in %.2fs' % (len(paste) // 1000, took))
    else:
        print('    FAIL  a %d KB paste took %.2fs' % (len(paste) // 1000, took))
        failures.append('slow sanitize')

    total = sum(len(t) for t in BY_LANGUAGE.values())
    print('\n==================================')
    print('  %d terms across %d languages' % (total, len(BY_LANGUAGE)))
    print('  passed' if not failures else '  FAILED: %s' % '; '.join(failures))
    print('==================================')
    return 1 if failures else 0


if __name__ == '__main__':
    sys.exit(run())
