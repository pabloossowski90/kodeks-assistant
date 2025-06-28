# Skrypt konfiguracyjny Kodzio - 3-etapowy bootstrap z walidacją i komunikatem końcowym
import os
import subprocess
import sys
import time

def etap(nazwa, komendy):
    print(f"\n🟡 Uruchamianie etapu {nazwa}...")
    for cmd in komendy:
        print(f"▶️ {cmd}")
        wynik = subprocess.run(cmd, shell=True)
        if wynik.returncode != 0:
            print(f"❌ Błąd w etapie {nazwa}. Zatrzymuję instalację.")
            sys.exit(1)
    print(f"✅ Etap {nazwa} zakończony poprawnie.")

def restart(etap_nr):
    print(f"\n♻️ Restart środowiska po etapie {etap_nr}...\n")
    time.sleep(2)

# Etap 1 – podstawowe pakiety
etap("1: Bazowe pakiety", [
    "sudo apt update",
    "sudo apt install -y python3-pip git"
])
restart(1)

# Etap 2 – narzędzia dla Kodzia
etap("2: Pakiety dla Kodzia", [
    "pip install --upgrade pip",
    "pip install openai requests"
])
restart(2)

# Etap 3 – walidacja i czyszczenie
etap("3: Walidacja", [
    "python3 -c \"import openai, requests\""
])

# Komunikat końcowy
print("\n🎉 Wszystko gotowe, mordo. Kodzio stoi jak skała.")
