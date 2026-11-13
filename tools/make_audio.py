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
    x = x - np.mean(x)
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


def resonator(n, sr, freqs):
    """Réponse impulsionnelle d'un échappement : somme de résonances amorties (fréquence,
    amortissement, gain)."""
    t = np.arange(n) / sr
    h = np.zeros(n)
    for f, damp, g in freqs:
        h += g * np.exp(-t * damp) * np.sin(2 * np.pi * f * t)
    return h


def engine(name, rpm, on_load, sr=22050, cycles=None):
    """Quatre cylindres en ligne, modèle « physique » simplifié :
    - une explosion tous les demi-tours (rpm / 30 Hz), chacune un peu différente (combustion
      irrégulière : amplitude, instant, timbre) ; un cylindre légèrement plus faible donne
      la « voix » grave à demi-régime ;
    - les impulsions passent dans l'échappement (résonances amorties, convolution circulaire
      pour une boucle sans raccord) ;
    - admission (souffle filtré qui pulse), bruit mécanique aigu ;
    - en charge : impulsions fortes, saturées ; au lever de pied : faibles, plus de souffle et
      quelques claquements."""
    fire = rpm / 30.0
    if cycles is None:
        cycles = int(np.ceil(1.6 * fire / 4)) * 4          # multiple de 4 explosions
    n = int(round(cycles / fire * sr))
    pulses = np.zeros(n)
    width = max(4, int(sr / fire * 0.18))
    for k in range(cycles):
        cyl = k % 4
        amp = (1.0 if on_load else 0.35) * rng.uniform(0.82, 1.12) * (0.78 if cyl == 2 else 1.0)
        pos = (k / fire + rng.normal(0, 0.012 / fire)) * sr
        i0 = int(pos) % n
        tt = np.arange(width) / sr
        # Front raide, retombée rapide (onde de pression).
        shape = (1 - np.exp(-tt * sr / 6.0)) * np.exp(-tt * fire * (6.0 if on_load else 9.0))
        shape *= 1.0 + 0.25 * rng.normal(size=width) * np.exp(-tt * fire * 4)
        pulses[(i0 + np.arange(width)) % n] += amp * shape
    # Échappement : grave et rond, un peu de métal.
    ir_len = min(n, int(sr * 0.25))
    ir = resonator(ir_len, sr, [(92, 26, 1.0), (185, 34, 0.55), (310, 60, 0.35), (720, 140, 0.18), (1450, 260, 0.08)])
    ir = np.pad(ir, (0, n - ir_len))
    x = np.fft.irfft(np.fft.rfft(pulses) * np.fft.rfft(ir), n)
    x /= np.max(np.abs(x)) + 1e-9
    drive = 2.6 if on_load else 1.2
    x = np.tanh(x * drive) / np.tanh(drive)
    # Admission et souffle, hachés par les explosions.
    env = np.fft.irfft(np.fft.rfft(pulses) * np.fft.rfft(np.pad(np.exp(-np.arange(int(sr * 0.01)) / (sr * 0.004)), (0, n - int(sr * 0.01)))), n)
    env = env / (np.max(env) + 1e-9)
    air = noise_loop(n, sr, lambda f: band(f, 300, 1800 + rpm * 0.15))
    air /= np.max(np.abs(air)) + 1e-9
    x += air * (0.06 + 0.3 * env) * (0.14 if on_load else 0.22)
    # Mécanique (soupapes, distribution) : cliquetis aigus discrets.
    mech = noise_loop(n, sr, lambda f: band(f, 3000, 8000))
    mech /= np.max(np.abs(mech)) + 1e-9
    x += mech * env * 0.015
    # Lever de pied à haut régime : petits claquements dans l'échappement.
    if False:  # claquements retirés (jugés peu réalistes)
        for _ in range(int(cycles / fire * 5)):
            i0 = rng.integers(0, n)
            ln = int(sr * 0.012)
            pop = rng.normal(size=ln) * np.exp(-np.arange(ln) / (ln * 0.2))
            x[(i0 + np.arange(ln)) % n] += pop * 0.6
    # Grave d'ensemble (bloc moteur) : renforce la fondamentale.
    x += 0.25 * np.sin(2 * np.pi * fire * np.arange(n) / sr)
    # Coupe les aigus (au-delà de ~5 kHz) : rejoué plus vite dans les tours, le son ne
    # grésille plus.
    spec = np.fft.rfft(x)
    fr = np.fft.rfftfreq(n, 1.0 / sr)
    spec *= 1.0 / (1.0 + (fr / (3800.0 + rpm * 0.15)) ** 6)
    x = np.fft.irfft(spec, n)
    save(name, x, sr)


ENGINE_RPMS = [1000, 2000, 3500, 5000, 6500]


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


def crickets(sr=22050, seconds=12.0):
    """Nuit d'été : un chœur de grillons des champs. Chaque grillon chante par « chirps »
    de 3 ou 4 pulsations (15 ms chacune, porteuse vers 4,5 kHz qui glisse un peu), un chirp
    toutes les 0,5 à 0,9 s, avec de petites irrégularités ; les plus lointains sont plus
    doux et plus ternes. Placés en boucle circulaire : aucun raccord audible. Plus un fond
    de nuit très doux (souffle d'air)."""
    n = int(seconds * sr)
    x = np.zeros(n)
    for c in range(9):
        dist = rng.uniform(0.25, 1.0)          # 1 = proche
        f0 = rng.uniform(4100, 5200)
        period = rng.uniform(0.5, 0.95)
        pulses = int(rng.integers(3, 5))
        pulse_len = rng.uniform(0.012, 0.018)
        gap = rng.uniform(0.010, 0.016)
        t0 = rng.uniform(0, period)
        pl = int(pulse_len * sr)
        tt = np.arange(pl) / sr
        env = np.sin(np.pi * np.arange(pl) / pl) ** 1.5
        while t0 < seconds:
            if rng.random() < 0.92:             # parfois un chirp sauté
                amp = dist * rng.uniform(0.8, 1.1)
                f = f0 * rng.uniform(0.99, 1.01)
                for k in range(pulses):
                    start = int((t0 + k * (pulse_len + gap)) * sr)
                    sweep = f * (1.0 + 0.03 * tt / pulse_len)
                    tone = np.sin(2 * np.pi * np.cumsum(sweep) / sr) + 0.18 * np.sin(4 * np.pi * np.cumsum(sweep) / sr)
                    x[(start + np.arange(pl)) % n] += tone * env * amp * (0.85 + 0.15 * (k == 0))
            t0 += period * rng.uniform(0.95, 1.06)
    # Les lointains : un peu étouffés (passe-bas doux dans le domaine des fréquences).
    spec = np.fft.rfft(x)
    f = np.fft.rfftfreq(n, 1.0 / sr)
    spec *= 1.0 / (1.0 + (f / 7000.0) ** 4)
    x = np.fft.irfft(spec, n)
    x /= np.max(np.abs(x)) + 1e-9
    bed = noise_loop(n, sr, lambda f: band(f, 80, 1200) / np.maximum(f, 80) ** 0.7)
    x += bed / (np.max(np.abs(bed)) + 1e-9) * 0.06
    save("crickets", x, sr, peak=0.5)

def rain_loop(sr=22050, seconds=8.0):
    """Pluie : un souffle large (gouttes lointaines innombrables) et des impacts proches,
    petits clics filtrés à des hauteurs variées ; boucle sans raccord (placement circulaire)."""
    n = int(seconds * sr)
    bed = noise_loop(n, sr, lambda f: band(f, 400, 7000) / np.maximum(f, 400) ** 0.25)
    bed /= np.max(np.abs(bed)) + 1e-9
    x = bed * 0.55
    for _ in range(int(seconds * 140)):
        i = rng.integers(0, n)
        ln = int(sr * rng.uniform(0.004, 0.02))
        f0 = rng.uniform(1500, 5000)
        tt = np.arange(ln) / sr
        drop = np.sin(2 * np.pi * f0 * tt) * np.exp(-tt * rng.uniform(250, 600)) * rng.uniform(0.1, 0.5)
        x[(i + np.arange(ln)) % n] += drop
    spec = np.fft.rfft(x)
    fr = np.fft.rfftfreq(n, 1.0 / sr)
    spec *= 1.0 / (1.0 + (fr / 6500.0) ** 4)
    save("rain", np.fft.irfft(spec, n), sr, peak=0.6)


def thunder(sr=22050, seconds=4.5):
    """Tonnerre : craquement court puis grondement grave qui roule et s'éteint."""
    n = int(seconds * sr)
    t = np.arange(n) / sr
    rumble = bp_noise(n, sr, 25, 220)
    roll = 0.6 + 0.4 * np.sin(2 * np.pi * 1.3 * t + 1.0) * np.sin(2 * np.pi * 0.37 * t)
    env = (1 - np.exp(-t * 6)) * np.exp(-t * 0.9) * roll
    crack = bp_noise(n, sr, 300, 4000) * np.exp(-t * 9) * (t < 0.6)
    x = rumble * env + crack * 0.5
    fade = int(sr * 0.2)
    x[-fade:] *= np.linspace(1, 0, fade)
    save("thunder", x, sr, peak=0.9)


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
    # Moteur : 5 régimes, en charge (on) et au lever de pied (off).
    for r in ENGINE_RPMS:
        engine("engine_on_%d" % r, r, True)
        engine("engine_off_%d" % r, r, False)
    skid()
    gravel()
    wind()
    sea()
    water()
    crickets()
    rain_loop()
    thunder()
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
