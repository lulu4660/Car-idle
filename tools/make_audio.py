"""Fabrique tous les sons de la balade par synthèse (aucun enregistrement, aucune licence) :
    python3 tools/make_audio.py
Boucles sans raccord audible (bruits construits dans le domaine des fréquences, donc
périodiques ; sons de moteur avec un nombre entier de cycles) et sons courts.
Sortie : assets/audio/*.wav (mono 16 bits). Relancer `godot --headless --import` ensuite.
"""
import os
import wave
import numpy as np

OUT = os.path.join(os.path.dirname(__file__), "..", "assets", "audio")
rng = np.random.default_rng(7)


def save(name, x, sr, peak=0.85):
    x = np.asarray(x, dtype=np.float64)
    x = x / (np.max(np.abs(x)) + 1e-9) * peak
    with wave.open(os.path.join(OUT, name + ".wav"), "wb") as f:
        f.setnchannels(1)
        f.setsampwidth(2)
        f.setframerate(sr)
        f.writeframes((x * 32767).astype("<i2").tobytes())


def noise_loop(n, sr, shape):
    """Bruit périodique de n échantillons ; `shape(f)` donne le gain par fréquence (Hz)."""
    spec = rng.normal(size=n // 2 + 1) + 1j * rng.normal(size=n // 2 + 1)
    f = np.fft.rfftfreq(n, 1.0 / sr)
    spec *= shape(f)
    spec[0] = 0
    return np.fft.irfft(spec, n)


def band(f, lo, hi, soft=0.25):
    """Passe-bande à flancs doux."""
    up = 1.0 / (1.0 + (lo / np.maximum(f, 1e-6)) ** (2 / soft))
    down = 1.0 / (1.0 + (f / hi) ** (2 / soft))
    return up * down


def periodic_lfo(n, cycles, depth, phase=0.0):
    t = np.arange(n) / n
    return 1.0 + depth * np.sin(2 * np.pi * cycles * t + phase)


def engine(name, firing_hz, bright, seconds=2.0, sr=22050):
    """Quatre cylindres : harmoniques par demi-ordres du régime, écrêtage doux (grognement),
    souffle d'échappement haché par les explosions."""
    n = int(seconds * sr)
    t = np.arange(n) / sr
    # Légère irrégularité du régime, périodique sur la boucle.
    wob = 0.012 * np.sin(2 * np.pi * 3 * t / seconds) + 0.008 * np.sin(2 * np.pi * 7 * t / seconds + 1.3)
    phase = 2 * np.pi * firing_hz * t + wob * firing_hz / 4
    x = np.zeros(n)
    for k in range(1, 40):
        order = k / 2.0                      # demi-ordres
        fk = firing_hz * order
        if fk > sr * 0.45:
            break
        amp = 1.0 / (order ** (1.5 - bright * 0.6))
        if k % 2 == 1:
            amp *= 0.35                      # demi-ordres impairs : la « voix » du moteur
        if k == 2:
            amp *= 1.6                       # fréquence d'explosion
        x += amp * np.sin(order * phase + rng.uniform(0, 2 * np.pi))
    x = np.tanh(x * (1.2 + bright * 1.5))
    puls = np.clip(np.sin(phase), 0, 1) ** 3
    hiss = noise_loop(n, sr, lambda f: band(f, 300 + 900 * bright, 2500 + 4000 * bright))
    hiss = hiss / np.max(np.abs(hiss))
    x += hiss * puls * (0.25 + 0.5 * bright)
    low = noise_loop(n, sr, lambda f: band(f, 30, 160))
    x += low / np.max(np.abs(low)) * 0.25
    save(name, x, sr)


def skid(sr=32000, seconds=2.0):
    """Crissement de pneus : bandes de bruit étroites vers 1 kHz qui fluctuent."""
    n = int(seconds * sr)
    x = np.zeros(n)
    for fc, w, g, cyc in [(820, 60, 1.0, 5), (1180, 90, 0.8, 7), (1640, 140, 0.5, 9), (2400, 400, 0.25, 4)]:
        part = noise_loop(n, sr, lambda f: np.exp(-((f - fc) / w) ** 2))
        part = part / np.max(np.abs(part))
        x += g * part * periodic_lfo(n, cyc, 0.35, rng.uniform(0, 6))
    hiss = noise_loop(n, sr, lambda f: band(f, 1500, 7000))
    x += hiss / np.max(np.abs(hiss)) * 0.18
    save("skid", x, sr)


def gravel(sr=32000, seconds=2.5):
    """Roulage sur terre et sable : souffle grave et petits cailloux."""
    n = int(seconds * sr)
    base = noise_loop(n, sr, lambda f: band(f, 80, 1800) / np.sqrt(np.maximum(f, 40)))
    base = base / np.max(np.abs(base))
    grains = np.zeros(n)
    for _ in range(int(seconds * 90)):
        i = rng.integers(0, n)
        ln = rng.integers(40, 220)
        env = np.exp(-np.arange(ln) / (ln * 0.25))
        idx = (i + np.arange(ln)) % n
        grains[idx] += rng.normal(size=ln) * env * rng.uniform(0.2, 1.0)
    g2 = np.fft.irfft(np.fft.rfft(grains) * band(np.fft.rfftfreq(n, 1 / sr), 900, 6000), n)
    save("gravel", base + g2 / (np.max(np.abs(g2)) + 1e-9) * 0.7, sr)


def wind(sr=22050, seconds=4.0):
    n = int(seconds * sr)
    x = noise_loop(n, sr, lambda f: band(f, 60, 900) / np.maximum(f, 60) ** 0.6)
    x *= periodic_lfo(n, 2, 0.2) * periodic_lfo(n, 5, 0.1, 1.0)
    save("wind", x, sr)


def sea(sr=22050, seconds=9.0):
    """Ressac : bruit dont le volume et la brillance montent et retombent (3 vagues)."""
    n = int(seconds * sr)
    t = np.arange(n) / n
    lowp = noise_loop(n, sr, lambda f: band(f, 70, 700) / np.maximum(f, 70) ** 0.4)
    high = noise_loop(n, sr, lambda f: band(f, 900, 6000))
    lowp /= np.max(np.abs(lowp))
    high /= np.max(np.abs(high))
    swell = (0.5 + 0.5 * np.sin(2 * np.pi * (3 * t) - 1.2)) ** 2.2
    swell = 0.25 + 0.75 * swell * (0.8 + 0.2 * np.sin(2 * np.pi * t + 0.7))
    save("sea", lowp * (0.5 + 0.5 * swell) + high * swell ** 1.5 * 0.55, sr)


def water(sr=22050, seconds=2.5):
    """Voiture dans l'eau : remous et bulles."""
    n = int(seconds * sr)
    x = noise_loop(n, sr, lambda f: band(f, 200, 2600) / np.maximum(f, 200) ** 0.3)
    x /= np.max(np.abs(x))
    x *= periodic_lfo(n, 9, 0.35) * periodic_lfo(n, 4, 0.25, 2.0)
    t = np.arange(n) / sr
    for _ in range(40):
        i = rng.integers(0, n)
        ln = int(sr * rng.uniform(0.03, 0.08))
        f0 = rng.uniform(300, 900)
        tt = np.arange(ln) / sr
        blob = np.sin(2 * np.pi * (f0 + f0 * 2.5 * tt / tt[-1]) * tt) * np.hanning(ln)
        x[(i + np.arange(ln)) % n] += blob * 0.5
    save("water", x, sr)


def crickets(sr=22050, seconds=4.0):
    """Nuit : grillons (trains de petits cris aigus) sur un fond très doux."""
    n = int(seconds * sr)
    t = np.arange(n) / sr
    x = np.zeros(n)
    for fc, rate, gain, ph in [(4300, 14, 1.0, 0.0), (4900, 17, 0.6, 0.4), (3700, 11, 0.45, 0.9)]:
        chirp = (np.sin(2 * np.pi * rate * t + ph) > 0.2).astype(float)
        group = (np.sin(2 * np.pi * (rate / 28.0) * t + ph * 3) > -0.3).astype(float)
        k = np.hanning(int(sr * 0.012))
        env = np.convolve(chirp * group, k / k.sum(), mode="same")
        x += gain * env * np.sin(2 * np.pi * fc * t)
    # Raccord : fondu des deux extrémités.
    fade = int(sr * 0.05)
    ramp = np.linspace(0, 1, fade)
    x[:fade] *= ramp
    x[-fade:] *= ramp[::-1]
    bed = noise_loop(n, sr, lambda f: band(f, 2500, 7000))
    save("crickets", x + bed / np.max(np.abs(bed)) * 0.04, sr, peak=0.6)


def shot(name, seconds, sr, build, peak=0.9):
    n = int(seconds * sr)
    t = np.arange(n) / sr
    x = build(n, t, sr)
    fade = int(sr * 0.01)
    x[-fade:] *= np.linspace(1, 0, fade)
    save(name, x, sr, peak)


def bp_noise(n, sr, lo, hi):
    spec = np.fft.rfft(rng.normal(size=n)) * band(np.fft.rfftfreq(n, 1 / sr), lo, hi)
    x = np.fft.irfft(spec, n)
    return x / (np.max(np.abs(x)) + 1e-9)


def main():
    os.makedirs(OUT, exist_ok=True)
    # Moteur : boucle grave (1 500 tr/min, explosions à 50 Hz) et aiguë (4 980 tr/min, 166 Hz).
    engine("engine_low", 50.0, 0.15)
    engine("engine_high", 166.0, 0.9)
    skid()
    gravel()
    wind()
    sea()
    water()
    crickets()
    # Choc : coup sourd + tôle.
    shot("impact", 0.45, 22050, lambda n, t, sr:
         np.sin(2 * np.pi * (95 - 60 * t / 0.45) * t) * np.exp(-t * 14)
         + bp_noise(n, sr, 300, 3500) * np.exp(-t * 28) * 0.9
         + np.sin(2 * np.pi * 530 * t) * np.exp(-t * 22) * 0.25)
    # Réception de saut : suspension qui talonne.
    shot("land", 0.4, 22050, lambda n, t, sr:
         np.sin(2 * np.pi * (70 - 35 * t / 0.4) * t) * np.exp(-t * 11)
         + bp_noise(n, sr, 100, 900) * np.exp(-t * 18) * 0.6)
    # Gerbe d'eau.
    shot("splash", 0.9, 22050, lambda n, t, sr:
         bp_noise(n, sr, 500, 7000) * (1 - np.exp(-t * 90)) * np.exp(-t * 5.5)
         + bp_noise(n, sr, 120, 600) * np.exp(-t * 9) * 0.7)
    # Changement de rapport : petit « clac » et souffle.
    shot("shift", 0.12, 22050, lambda n, t, sr:
         bp_noise(n, sr, 700, 4000) * np.exp(-t * 55) * 0.8
         + np.sin(2 * np.pi * 180 * t) * np.exp(-t * 70), peak=0.6)
    # Interface : clic bref.
    shot("click", 0.06, 22050, lambda n, t, sr:
         np.sin(2 * np.pi * 1300 * t) * np.exp(-t * 90) + np.sin(2 * np.pi * 650 * t) * np.exp(-t * 70) * 0.5, peak=0.5)
    # Points de dérapage gagnés : deux notes montantes.
    shot("score", 0.4, 22050, lambda n, t, sr:
         (np.sin(2 * np.pi * 660 * t) * (t < 0.12) + np.sin(2 * np.pi * 990 * t) * (t >= 0.1)) * np.exp(-np.maximum(t - 0.1, 0) * 9)
         * np.minimum(1, t * 200), peak=0.5)
    print("sons écrits dans", os.path.normpath(OUT))


if __name__ == "__main__":
    main()
