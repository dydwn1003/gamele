#!/usr/bin/env python3
"""게임 효과음·배경음악을 코드로 합성해 audio/*.wav 로 저장한다 (외부 음원 없음)."""
import math, random, struct, wave, os

SR = 22050
OUT = os.path.join(os.path.dirname(os.path.abspath(__file__)), "..", "audio")
random.seed(7)


def save(name, samples, peak=0.85):
    m = max(1e-9, max(abs(s) for s in samples))
    g = peak / m
    with wave.open(os.path.join(OUT, name + ".wav"), "wb") as w:
        w.setnchannels(1); w.setsampwidth(2); w.setframerate(SR)
        w.writeframes(b"".join(struct.pack("<h", int(max(-1, min(1, s * g)) * 32767)) for s in samples))


def n(sec): return int(sec * SR)
def env(i, total, a=0.005, d=None):
    t = i / SR; T = total / SR
    if t < a: return t / a
    if d is None: d = T - a
    return max(0.0, 1.0 - (t - a) / d)
def sine(f, t): return math.sin(2 * math.pi * f * t)
def tri(f, t):
    x = (f * t) % 1.0
    return 4 * abs(x - 0.5) - 1
def noise(): return random.uniform(-1, 1)


class LP:
    def __init__(self): self.y = 0.0
    def __call__(self, x, a): self.y += a * (x - self.y); return self.y


def whoosh(sec, f0, f1, vol=1.0):
    out, lp, lp2 = [], LP(), LP()
    N = n(sec)
    for i in range(N):
        k = i / N
        a = 0.02 + 0.25 * (f0 + (f1 - f0) * k)
        x = lp(noise(), a) - lp2(noise(), a * 0.2)
        out.append(x * math.sin(math.pi * k) * vol)
    return out


def tone(freqs, sec, decay=None, wave_fn=sine, vol=1.0, a=0.005):
    N = n(sec); out = []
    for i in range(N):
        t = i / SR
        e = env(i, N, a, decay)
        out.append(sum(wave_fn(f, t) for f in freqs) / len(freqs) * e * vol)
    return out


def mix(*tracks):
    L = max(len(t) for t in tracks)
    return [sum(t[i] for t in tracks if i < len(t)) for i in range(L)]


def seq(parts, gap):
    out = []
    for p in parts:
        start = len(out) - n(gap) if out else 0
        start = max(0, start)
        need = start + len(p)
        out += [0.0] * max(0, need - len(out))
        for i, s in enumerate(p): out[start + i] += s
    return out


def thump(sec, f0, f1, vol=1.0):
    N = n(sec); out = []; ph = 0
    for i in range(N):
        k = i / N
        f = f0 + (f1 - f0) * k
        ph += 2 * math.pi * f / SR
        out.append(math.sin(ph) * (1 - k) ** 2 * vol)
    return out


def noise_burst(sec, lp_a=0.3, vol=1.0):
    N = n(sec); lp = LP(); return [lp(noise(), lp_a) * (1 - i / N) ** 3 * vol for i in range(N)]


os.makedirs(OUT, exist_ok=True)
# ------------------------------------------------------------- 효과음
save("swing", whoosh(0.2, 0.3, 1.0, 1.0), 0.6)
save("dodge", whoosh(0.28, 0.6, 0.2, 1.0), 0.55)
save("hit", mix(noise_burst(0.12, 0.5), thump(0.15, 180, 60, 0.9)), 0.8)
save("crit", mix(noise_burst(0.14, 0.6), thump(0.18, 220, 60), tone([1800, 2700], 0.25, 0.25, vol=0.25)), 0.85)
save("hurt", mix(thump(0.2, 140, 50), tone([300, 220], 0.25, 0.25, tri, 0.3)), 0.75)
save("enemy_die", mix(noise_burst(0.4, 0.15, 0.8), thump(0.35, 120, 40)), 0.7)
save("smash", mix(noise_burst(0.5, 0.08, 1.0), thump(0.6, 90, 30, 1.2)), 0.9)
save("pickup", seq([tone([880], 0.08, 0.08), tone([1320], 0.12, 0.12)], 0.02), 0.5)
save("coin", tone([1567, 2093, 3136], 0.35, 0.35), 0.45)
save("potion", seq([tone([300 + 80 * k], 0.06, 0.06, sine, 1) for k in range(6)], 0.0), 0.5)
save("equip", mix(tone([1200, 1750, 2600], 0.25, 0.2), noise_burst(0.05, 0.6, 0.5)), 0.5)
save("anvil", mix(tone([660, 1410, 2210, 3120], 0.7, 0.6), noise_burst(0.04, 0.7)), 0.7)
save("ui_click", tone([1200], 0.04, 0.04, tri), 0.35)
save("ui_open", whoosh(0.18, 0.2, 0.6, 1.0), 0.35)
save("error", tone([140, 147], 0.2, 0.2, tri), 0.4)
save("chest", mix(seq([noise_burst(0.15, 0.05, 0.6)], 0), seq([[0.0] * n(0.12), tone([1047, 1319, 1568, 2093], 0.6, 0.6, sine, 0.6)], 0)), 0.6)
C, E, G = 523.25, 659.25, 783.99
save("levelup", seq([tone([C], 0.15, 0.15, tri), tone([E], 0.15, 0.15, tri), tone([G], 0.15, 0.15, tri), tone([C * 2, G], 0.6, 0.6, tri)], 0.03), 0.6)
save("quest", seq([tone([E, G], 0.18, 0.18), tone([G * 1.5, C * 2], 0.35, 0.35)], 0.02), 0.5)
save("quest_done", seq([tone([C, E], 0.14, 0.14, tri), tone([E, G], 0.14, 0.14, tri), tone([G, C * 2], 0.14, 0.14, tri), tone([C * 2, E * 2, G * 2], 0.8, 0.8, tri)], 0.02), 0.6)
fire = whoosh(1.6, 0.1, 0.4, 1.0)
save("beacon", mix(fire, [0.0] * n(0.3) + tone([C / 2, G / 2, E], 1.3, 1.3, sine, 0.7, a=0.3)), 0.75)


# ------------------------------------------------------------- 배경음악
def note(m): return 440.0 * 2 ** ((m - 69) / 12)


def music(chords, beat_sec, bars_per_chord, arp=True, length_mul=1):
    total = n(beat_sec * 4 * bars_per_chord * len(chords) * length_mul)
    out = [0.0] * total
    chord_len = n(beat_sec * 4 * bars_per_chord)
    for ci in range(len(chords) * length_mul):
        root, third, fifth = chords[ci % len(chords)]
        start = ci * chord_len
        # 패드 (느린 어택)
        for i in range(chord_len):
            t = (start + i) / SR
            k = i / chord_len
            e = min(1.0, k * 6) * min(1.0, (1 - k) * 6)
            s = 0.0
            for m in (root, third, fifth):
                f = note(m)
                s += sine(f, t) + 0.3 * sine(f * 1.003, t) + 0.15 * sine(f * 2, t)
            s += 0.8 * sine(note(root - 12), t)  # 베이스
            out[start + i] += s * e * 0.12
        if arp:
            pattern = [root + 12, third + 12, fifth + 12, third + 24, fifth + 12, third + 12, root + 24, fifth + 12]
            step = n(beat_sec / 2)
            for j in range(chord_len // step):
                m = pattern[j % len(pattern)]
                f = note(m)
                L = n(0.6)
                for i in range(L):
                    idx = start + j * step + i
                    if idx >= total: break
                    out[idx] += tri(f, i / SR) * math.exp(-i / SR * 6) * 0.18
    # 끝과 시작을 부드럽게 이어 붙여 반복 재생 시 끊김을 줄인다
    fade = n(0.05)
    for i in range(fade):
        out[i] *= i / fade; out[-1 - i] *= i / fade
    return out


# A단조 - F - C - G - Am - F - G - E
prog = [(57, 60, 64), (53, 57, 60), (48, 52, 55), (55, 59, 62), (57, 60, 64), (53, 57, 60), (55, 59, 62), (52, 56, 59)]
save("music_field", music(prog, 0.5, 1), 0.6)
save("music_title", music([(57, 60, 64), (53, 57, 60), (48, 52, 55), (52, 56, 59)], 0.75, 1, arp=True), 0.55)
print("audio files:", sorted(os.listdir(OUT)))
