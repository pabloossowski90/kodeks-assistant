#!/bin/bash

set -e

echo "Rozpoczynam konfigurację środowiska dla asystenta AI (xUbuntu 24.04)..."

# Aktualizacja pakietów
sudo apt update

# Lista wymaganych pakietów systemowych dla audio/mowy
sudo apt install -y python3-pip python3-venv espeak ffmpeg portaudio19-dev python3-pyaudio git

# Sprawdź czy venv już istnieje
if [ ! -d ".kodeks_venv" ]; then
  python3 -m venv .kodeks_venv
fi

source .kodeks_venv/bin/activate

pip install --upgrade pip

# Wymagane pakiety Pythona
REQUIRED_PKGS="speechrecognition pyttsx3 datetime pyautogui webbrowser openai keyboard"
MISSING_PYAUDIO=0

# Pyaudio czasem sprawia problemy, więc testujemy instalację
pip install pyaudio || MISSING_PYAUDIO=1

# Jeśli pyaudio nie działa — użyj sounddevice + soundfile jako alternatywy
if [ "$MISSING_PYAUDIO" -eq 1 ]; then
    pip install sounddevice soundfile
    EXTRA_AUDIO="sounddevice, soundfile"
    PYAUDIO_NOTE="pyaudio nie zainstalował się poprawnie, używam sounddevice jako alternatywy."
else
    EXTRA_AUDIO=""
    PYAUDIO_NOTE=""
fi

pip install $REQUIRED_PKGS

# Tworzymy plik kodzio.py
cat > kodzio.py << 'EOF'
import sys
import platform
import datetime
import os
import traceback

try:
    import speech_recognition as sr
    import pyttsx3
    import pyautogui
    import webbrowser
    import openai
    import keyboard
    import subprocess
except Exception as e:
    print("Błąd podczas importowania bibliotek:", e)
    print(traceback.format_exc())
    sys.exit(1)

USE_SOUNDDEVICE = False
try:
    import pyaudio
except ImportError:
    try:
        import sounddevice as sd
        import soundfile as sf
        USE_SOUNDDEVICE = True
    except ImportError:
        print("Brakuje zarówno pyaudio jak i sounddevice/soundfile. Sprawdź instalację audio.")
        sys.exit(1)

def say(text):
    try:
        engine = pyttsx3.init()
        engine.say(text)
        engine.runAndWait()
    except Exception as e:
        print(f"Nie mogę mówić: {e}")

def listen_for_kodeks():
    recognizer = sr.Recognizer()
    mic = sr.Microphone() if not USE_SOUNDDEVICE else None
    print("Nasłuchuję słowa 'kodeks'... (naciśnij [ctrl+c] by wyjść)")
    while True:
        try:
            if USE_SOUNDDEVICE:
                print("Używam sounddevice do nagrywania...")
                duration = 4  # sekundy
                fs = 16000
                print("Mów teraz...")
                audio = sd.rec(int(duration * fs), samplerate=fs, channels=1)
                sd.wait()
                sf.write('kodeks_test.wav', audio, fs)
                with sr.AudioFile('kodeks_test.wav') as source:
                    audio_data = recognizer.record(source)
            else:
                with mic as source:
                    recognizer.adjust_for_ambient_noise(source)
                    print("Mów teraz...")
                    audio_data = recognizer.listen(source, timeout=4)
            text = recognizer.recognize_google(audio_data, language="pl-PL").lower()
            print(f"Rozpoznano: {text}")
            if "kodeks" in text:
                respond()
        except sr.UnknownValueError:
            print("Nie rozumiem, powtórz proszę...")
        except KeyboardInterrupt:
            print("\nKończę nasłuchiwanie.")
            break
        except Exception as e:
            print("Błąd podczas rozpoznawania mowy:", e)
            print(traceback.format_exc())

def respond():
    options = [
        "Cześć, słucham Cię!",
        f"Jest {datetime.datetime.now().strftime('%Y-%m-%d %H:%M')}",
        "Co mogę dla Ciebie zrobić?",
    ]
    say(options[0])
    print(options[0])
    while True:
        try:
            command = recognize_once()
            if command is None:
                continue
            if "data" in command or "dzisiaj" in command:
                msg = f"Dzisiejsza data to {datetime.datetime.now().strftime('%A, %d %B %Y, %H:%M')}"
                print(msg)
                say(msg)
            elif "przeglądarka" in command or "otwórz" in command:
                say("Otwieram przeglądarkę.")
                print("Otwieram przeglądarkę...")
                webbrowser.open("https://www.google.com")
            elif "zrzut ekranu" in command or "screenshot" in command:
                filename = f"screenshot_{datetime.datetime.now().strftime('%Y%m%d_%H%M%S')}.png"
                pyautogui.screenshot(filename)
                say("Zrobiłem zrzut ekranu.")
                print(f"Zrzut ekranu zapisany jako {filename}")
            elif "github" in command and "repozytorium" in command:
                handle_github()
            elif "koniec" in command or "wyjdź" in command:
                say("Kończę. Do zobaczenia!")
                print("Kończę.")
                break
            else:
                say("Nie rozumiem tej komendy. Spróbuj jeszcze raz.")
                print("Nie rozumiem tej komendy.")
        except Exception as e:
            print("Błąd w obsłudze polecenia:", e)
            print(traceback.format_exc())

def recognize_once():
    recognizer = sr.Recognizer()
    if USE_SOUNDDEVICE:
        duration = 4
        fs = 16000
        print("Mów polecenie...")
        audio = sd.rec(int(duration * fs), samplerate=fs, channels=1)
        sd.wait()
        sf.write('command.wav', audio, fs)
        with sr.AudioFile('command.wav') as source:
            audio_data = recognizer.record(source)
    else:
        with sr.Microphone() as source:
            recognizer.adjust_for_ambient_noise(source)
            print("Mów polecenie...")
            try:
                audio_data = recognizer.listen(source, timeout=4)
            except sr.WaitTimeoutError:
                return None
    try:
        text = recognizer.recognize_google(audio_data, language="pl-PL").lower()
        print(f"Usłyszałem: {text}")
        return text
    except sr.UnknownValueError:
        print("Nie rozumiem, powtórz proszę...")
        return None
    except Exception as e:
        print("Błąd rozpoznawania mowy:", e)
        return None

def handle_github():
    token = os.environ.get("GITHUB_TOKEN")
    if not token:
        say("Brakuje tokena GitHub! Ustaw zmienną GITHUB_TOKEN.")
        print("Brakuje tokena GitHub! Eksportuj go: export GITHUB_TOKEN=...") 
        return
    say("Jakie repozytorium chcesz utworzyć lub zaktualizować?")
    print("Podaj nazwę repozytorium [owner/repo]:")
    repo = input()
    if "/" not in repo:
        say("Nazwa repo niepoprawna.")
        print("Nazwa repozytorium niepoprawna.")
        return
    say("Podaj ścieżkę folderu do wrzucenia na GitHub:")
    print("Podaj ścieżkę folderu do wrzucenia:")
    path = input().strip()
    if not os.path.isdir(path):
        say("Folder nie istnieje.")
        print("Podany folder nie istnieje.")
        return
    # git init, add, commit, push
    try:
        subprocess.run(["git", "-C", path, "init"], check=True)
        subprocess.run(["git", "-C", path, "add", "."], check=True)
        subprocess.run(["git", "-C", path, "commit", "-m", "auto: aktualizacja przez kodzio"], check=False)
        url = f"https://{token}:x-oauth-basic@github.com/{repo}.git"
        subprocess.run(["git", "-C", path, "remote", "add", "origin", url], check=False)
        subprocess.run(["git", "-C", path, "push", "-u", "origin", "master"], check=False)
        say("Repozytorium zaktualizowane.")
        print("Repozytorium zaktualizowane.")
    except Exception as e:
        say("Wystąpił błąd z Gitem.")
        print("Błąd podczas obsługi Gita:", e)

if __name__ == "__main__":
    try:
        listen_for_kodeks()
    except Exception as e:
        print("Błąd krytyczny:", e)
        print(traceback.format_exc())
EOF

echo ""
echo "Wszystko gotowe, mordo."
if [ "$PYAUDIO_NOTE" != "" ]; then
    echo "Uwaga: $PYAUDIO_NOTE"
fi
echo "Aby uruchomić asystenta, wpisz: source .kodeks_venv/bin/activate && python kodzio.py"
