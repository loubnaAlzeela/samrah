"""Generate the spoken calls (docs/voice-lines.md) into assets/voice/<key>.mp3.

Uses edge-tts (Microsoft's online neural voices; the words are sent to that service) with a Saudi
voice, then ffmpeg trims the silence around each word and evens the loudness.
Run from apps/mobile:   pip install edge-tts   then   python tool/make_voice.py [voice]
Voices: ar-SA-HamedNeural (default, male), ar-SA-ZariyahNeural (female).
"""
import asyncio
import os
import subprocess
import sys

import edge_tts

VOICE = sys.argv[1] if len(sys.argv) > 1 else 'ar-SA-HamedNeural'
OUT = 'assets/voice'

# key -> what is said (the keys are what lib/services/game_audio.dart plays)
LINES = {
    'n2': 'اثنين', 'n3': 'ثلاث', 'n4': 'أربع', 'n5': 'خمس', 'n6': 'ست', 'n7': 'سبع', 'n8': 'ثمان', 'n9': 'تسع',
    'n10': 'عشر', 'n11': 'إدعش', 'n12': 'إثنعش', 'n13': 'ثلاثطعش',
    'pass': 'باس', 'double': 'دبل', 'trump': 'الطرنيب', 'hokm': 'حكم',
    'suit_h': 'هاص', 'suit_d': 'ديمن', 'suit_s': 'شريا', 'suit_c': 'سبيت',
    'c_king': 'شيخ الكبة', 'c_queens': 'بنات', 'c_diamonds': 'ديناري', 'c_tricks': 'لطوش', 'c_trix': 'تركس',
    'b_sun': 'صن', 'b_hokm2': 'حكم ثاني', 'b_ashkal': 'أشكل', 'b_pass1': 'بس', 'b_pass2': 'ولا',
    'b_triple': 'تربل', 'b_four': 'فور', 'b_qahwa': 'قهوة',
    's87': 'سبعة وثمانين', 's90': 'تسعين', 's95': 'خمسة وتسعين', 's100': 'مية', 's105': 'مية وخمسة',
    's110': 'مية وعشرة', 's115': 'مية وخمسطعش', 's120': 'مية وعشرين', 's125': 'مية وخمسة وعشرين',
    's130': 'مية وثلاثين', 's135': 'مية وخمسة وثلاثين', 's140': 'مية وأربعين', 's145': 'مية وخمسة وأربعين',
    's150': 'مية وخمسين', 's155': 'مية وخمسة وخمسين', 's160': 'مية وستين', 's165': 'مية وخمسة وستين',
    's170': 'مية وسبعين', 's175': 'مية وخمسة وسبعين', 's180': 'مية وثمانين', 's185': 'مية وخمسة وثمانين',
    's187': 'مية وسبعة وثمانين',
    'h_meld': 'نزّل',
}


async def main():
    os.makedirs(OUT, exist_ok=True)
    for key, text in LINES.items():
        raw = f'{OUT}/{key}.raw.mp3'
        await edge_tts.Communicate(text, VOICE).save(raw)
        # trim leading/trailing silence, even the loudness, mono 44.1 kHz
        subprocess.run([
            'ffmpeg', '-loglevel', 'error', '-y', '-i', raw,
            '-af', 'silenceremove=start_periods=1:start_threshold=-45dB:start_silence=0.02,'
                   'areverse,silenceremove=start_periods=1:start_threshold=-45dB:start_silence=0.05,areverse,'
                   'loudnorm=I=-16:TP=-1.5:LRA=11',
            '-ac', '1', '-ar', '44100', '-b:a', '96k', f'{OUT}/{key}.mp3',
        ], check=True)
        os.remove(raw)
        print(f'{key}: {text}')
    print(f'{len(LINES)} lines, voice {VOICE}')


if __name__ == '__main__':
    asyncio.run(main())
