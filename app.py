import streamlit as st
import pandas as pd
import math

# --- KONSTANTY (Fyzika) ---
CDA = 0.45  # Aerodynamika
CRR = 0.008  # Valivý odpor
RHO = 1.225  # Hustota vzduchu
G = 9.81  # Gravitace
EFF_MOTOR = 0.85  # Účinnost motoru
EFF_PANEL = 0.70  # Účinnost panelu

st.set_page_config(page_title="Solar Bike Thesis", layout="wide")

# --- DATABÁZE LOKALIT ---
# Každá lokalita má definovaný: Sklon terénu (%) a Osvit (koeficient pro daný region)
# Osvit je zde "počet efektivních hodin plného výkonu"
LOKALITA_DATA = {
    "Hostouň (Rovina)": {"sklon": 0.5, "osvit": 3.8},
    "Praha (Mírné kopce)": {"sklon": 1.5, "osvit": 3.5},
    "Brno (Zvlněné)": {"sklon": 2.5, "osvit": 3.6},
    "Šumava (Hory)": {"sklon": 5.0, "osvit": 3.0},
    "Itálie (Jih)": {"sklon": 1.0, "osvit": 5.0},
    "Vlastní nastavení": {"sklon": 0.0, "osvit": 0.0}  # Placeholder
}

# --- SIDEBAR: VSTUPNÍ PARAMETRY ---
st.sidebar.header("⚙️ 1) Parametry jízdy")
hmotnost = st.sidebar.number_input("Celková hmotnost (kg)", value=100)
rychlost_kmh = st.sidebar.number_input("Prům. rychlost (km/h)", value=25)

st.sidebar.header("🔋 2) Baterie a Motor")
napeti_v = st.sidebar.number_input("Napětí baterie [V]", value=36)
kapacita_wh = st.sidebar.number_input("Kapacita baterie [Wh]", value=540)
asistence_proc = st.sidebar.slider("Asistence motoru (%)", 0, 100, 100)
vykon_motoru_nom = st.sidebar.number_input("Nominální výkon motoru [W]", value=250)

st.sidebar.header("☀️ 3) Solár a Lokalita")
vykon_panelu_wp = st.sidebar.number_input("Nominální výkon solar. panelu [Wp]", value=100)

# VÝBĚR LOKALITY
lokalita = st.sidebar.selectbox("Vyberte lokalitu jízdy", list(LOKALITA_DATA.keys()))

# AUTOMATICKÝ VÝPOČET ENERGIE DLE LOKALITY
if lokalita == "Vlastní nastavení":
    # Pokud chceš zadávat ručně
    sklon_proc = st.sidebar.slider("Terén - Sklon [%]", -5.0, 15.0, 0.0)
    dodana_energie_wh = st.sidebar.number_input("Dodaná energie z osvitu [Wh]", value=150)
else:
    # Automatické načtení
    data = LOKALITA_DATA[lokalita]
    sklon_proc = data["sklon"]
    osvit_regionu = data["osvit"]

    # Výpočet: Výkon panelu * Osvit lokality * Účinnost
    dodana_energie_wh = vykon_panelu_wp * osvit_regionu * EFF_PANEL

    # Výpis pro uživatele (aby viděl, co se vypočítalo)
    st.sidebar.info(f"📍 **{lokalita}**")
    st.sidebar.write(f"Sklon terénu: **{sklon_proc} %**")
    st.sidebar.success(f"☀️ Automaticky vypočtená energie: **{dodana_energie_wh:.0f} Wh**")

# --- FYZIKÁLNÍ JÁDRO ---
v_ms = rychlost_kmh / 3.6

# 1. Odpory
F_air = 0.5 * RHO * (v_ms ** 2) * CDA
F_roll = hmotnost * G * CRR
F_slope = hmotnost * G * math.sin(math.atan(sklon_proc / 100))
F_total = F_air + F_roll + F_slope
if F_total < 0: F_total = 0

# 2. Výkony
P_mech = F_total * v_ms
P_motor_mech = P_mech * (asistence_proc / 100)
P_elec_needed = P_motor_mech / EFF_MOTOR
P_elec_real = min(P_elec_needed, vykon_motoru_nom / EFF_MOTOR)

# 3. Dojezdy
spotreba_wh_km = P_elec_real / rychlost_kmh if rychlost_kmh > 0 else 0

dojezd_bat = kapacita_wh / spotreba_wh_km if spotreba_wh_km > 0 else 0
dojezd_solar = (kapacita_wh + dodana_energie_wh) / spotreba_wh_km if spotreba_wh_km > 0 else 0
bonus_km = dojezd_solar - dojezd_bat

# --- DASHBOARD (VÝSLEDKY) ---
st.title("🔋 Solar Bike Thesis: Kalkulátor")

# Horní metriky
m1, m2, m3 = st.columns(3)
m1.metric("Spotřeba energie", f"{spotreba_wh_km:.1f} Wh/km")
m2.metric("Dojezd (Jen Baterie)", f"{dojezd_bat:.1f} km")
m3.metric("Dojezd (+ Solární zisk)", f"{dojezd_solar:.1f} km", delta=f"+{bonus_km:.1f} km")

st.divider()

# Graf a detaily
col_graph, col_data = st.columns([2, 1])

with col_graph:
    st.subheader("Porovnání dojezdu")
    chart_data = pd.DataFrame({
        'Zdroj': ['Jen Baterie', 'Baterie + Solár'],
        'Dojezd (km)': [dojezd_bat, dojezd_solar]
    })
    st.bar_chart(chart_data.set_index('Zdroj'))

with col_data:
    st.subheader("Parametry simulace")
    st.write(f"Lokalita: **{lokalita}**")
    st.write(f"Solární zisk: **{dodana_energie_wh:.0f} Wh**")
    st.write("---")
    st.caption("Rozložení odporových sil:")
    st.write(f"Vzduch: {F_air:.1f} N")
    st.write(f"Valení: {F_roll:.1f} N")
    st.write(f"Sklon: {F_slope:.1f} N")