import streamlit as st
import pandas as pd
import math

# --- KONSTANTY (Fyzika) ---
CDA = 0.45            # Aerodynamický koeficient
CRR = 0.008           # Valivý odpor
RHO = 1.225           # Hustota vzduchu
G = 9.81              # Gravitace
EFF_MOTOR = 0.85      # Účinnost motoru
EFF_PANEL = 0.70      # Účinnost panelu

st.set_page_config(page_title="Solar Bike Thesis", layout="wide")

# ==============================================================================
# --- DEFINICE ASISTENCE ---
# ==============================================================================
REZIMY_ASISTENCE = {
    "Vypnuto": 0.0,
    "Úroveň 1 (20%)": 0.20,
    "Úroveň 2 (40%)": 0.40,
    "Úroveň 3 (50%)": 0.50,
    "Úroveň 4 (80%)": 0.80,
    "Úroveň 5 (100%)": 1.0
}

# --- DATA LOKALIT ---
LOKALITA_DATA = {
    "Hostouň (Rovina)":      {"sklon": 0.5, "osvit": 3.8},
    "Praha (Mírné kopce)":   {"sklon": 1.5, "osvit": 3.5},
    "Brno (Zvlněné)":        {"sklon": 2.5, "osvit": 3.6},
    "Šumava (Hory)":         {"sklon": 5.0, "osvit": 3.0},
    "Vlastní nastavení":     {"sklon": 0.0, "osvit": 0.0}
}

# ==============================================================================
# --- SIDEBAR: VSTUPNÍ PARAMETRY ---
# ==============================================================================
st.sidebar.header("⚙️ 1) Parametry jízdy")
hmotnost = st.sidebar.number_input("Celková hmotnost (kg)", value=100)
rychlost_kmh = st.sidebar.number_input("Prům. rychlost (km/h)", value=25)

st.sidebar.markdown("---")
st.sidebar.caption("🔧 Kalibrace fyzikálního modelu")
koeficient_realnosti = st.sidebar.slider("Koeficient náročnosti", 1.0, 3.0, 1.8, 0.1)

st.sidebar.header("🔋 2) Baterie a Motor")
# napeti_v = st.sidebar.number_input("Napětí baterie [V]", value=36) # Pro jednoduchost skryto, stačí Wh
kapacita_wh = st.sidebar.number_input("Kapacita baterie [Wh]", value=500)

# Výběr režimu
nazev_rezimu = st.sidebar.selectbox("Režim asistence", list(REZIMY_ASISTENCE.keys()), index=3) 
procento_asistence = REZIMY_ASISTENCE[nazev_rezimu] # Toto je hodnota 0.0 až 1.0

vykon_motoru_nom = st.sidebar.number_input("Nominální výkon motoru [W]", value=250)

st.sidebar.header("☀️ 3) Solár a Lokalita")
vykon_panelu_wp = st.sidebar.number_input("Nominální výkon solar. panelu [Wp]", value=100)
lokalita = st.sidebar.selectbox("Lokalita", list(LOKALITA_DATA.keys()))

if lokalita == "Vlastní nastavení":
    sklon_proc = st.sidebar.slider("Terén - Sklon [%]", -5.0, 15.0, 0.0)
    dodana_energie_wh = st.sidebar.number_input("Dodaná energie z osvitu [Wh]", value=150)
else:
    data = LOKALITA_DATA[lokalita]
    sklon_proc = data["sklon"]
    osvit_regionu = data["osvit"]
    dodana_energie_wh = vykon_panelu_wp * osvit_regionu * EFF_PANEL
    st.sidebar.info(f"📍 {lokalita}: Sklon {sklon_proc}%")


# ==============================================================================
# --- VÝPOČTY (DVĚ METODY) ---
# ==============================================================================

# ----------------------------------------------------------------
# A) TVŮJ ZJEDNODUŠENÝ VÝPOČET (Linear Theoretical)
# ----------------------------------------------------------------
# Přesně podle zadání: celkovy_vykon_motoru = vykon_motoru * procento_asistence
# dojezd = (kapacita_baterie / celkovy_vykon_motoru) * prumerna_rychlost

if procento_asistence > 0:
    celkovy_vykon_motoru_simple = vykon_motoru_nom * procento_asistence
    dojezd_simple = (kapacita_wh / celkovy_vykon_motoru_simple) * rychlost_kmh
else:
    celkovy_vykon_motoru_simple = 0
    dojezd_simple = 0 # Nekonečno teoreticky, ale dáme 0 pro graf

# ----------------------------------------------------------------
# B) FYZIKÁLNÍ VÝPOČET (Physics Simulation)
# ----------------------------------------------------------------
v_ms = rychlost_kmh / 3.6

# 1. Odpory
F_air = 0.5 * RHO * (v_ms**2) * CDA
F_roll = hmotnost * G * CRR
F_slope = hmotnost * G * math.sin(math.atan(sklon_proc/100))
F_total = F_air + F_roll + F_slope
if F_total < 0: F_total = 0

# 2. Výkony
P_mech_total = F_total * v_ms
P_mech_real = P_mech_total * koeficient_realnosti

# 3. Rozdělení (Motor vs Člověk)
# Ve fyzikálním modelu: Asistence % znamená, kolik % z CELKOVÉHO výkonu bere motor
if P_mech_real > 0:
    P_motor_req = P_mech_real * procento_asistence # Motor bere X % z celkové námahy
    P_human = P_mech_real - P_motor_req
else:
    P_human = 0
    P_motor_req = 0

# 4. Spotřeba a Dojezd
P_motor_final = min(P_motor_req, vykon_motoru_nom) # Motor nemůže dát víc než svůj limit
P_elec_battery = P_motor_final / EFF_MOTOR

if rychlost_kmh > 0 and P_elec_battery > 0:
    spotreba_wh_km_phys = P_elec_battery / rychlost_kmh
    dojezd_bat_phys = kapacita_wh / spotreba_wh_km_phys
    dojezd_solar_phys = (kapacita_wh + dodana_energie_wh) / spotreba_wh_km_phys
else:
    dojezd_bat_phys = 0
    dojezd_solar_phys = 0
    spotreba_wh_km_phys = 0

# ==============================================================================
# --- DASHBOARD ---
# ==============================================================================

st.title("🔋 Solar Bike Thesis: Porovnání modelů")
st.markdown(f"**Nastavená rychlost:** {rychlost_kmh} km/h | **Asistence:** {procento_asistence*100:.0f}%")

# Vytvoření záložek pro přehlednost
tab1, tab2 = st.tabs(["📊 Zjednodušený výpočet (Tvůj vzorec)", "🚴 Fyzikální simulace (Realita)"])

with tab1:
    st.subheader("Teoretický (Lineární) výpočet")
    st.info("Tento model ignoruje vítr, kopce i váhu jezdce. Předpokládá konstantní odběr motoru.")
    
    col_a, col_b = st.columns(2)
    with col_a:
        st.write(f"**Vstupní vzorec:**")
        st.code(f"Výkon motoru = {vykon_motoru_nom} * {procento_asistence} = {celkovy_vykon_motoru_simple:.1f} W")
        st.code(f"Dojezd = ({kapacita_wh} / {celkovy_vykon_motoru_simple:.1f}) * {rychlost_kmh}")
    
    with col_b:
        st.metric("Teoretický Dojezd", f"{dojezd_simple:.1f} km")
        st.metric("Konstantní odběr motoru", f"{celkovy_vykon_motoru_simple:.1f} W")

with tab2:
    st.subheader("Fyzikální simulace (Včetně odporů)")
    st.success(f"Tento model započítává váhu {hmotnost} kg, sklon {sklon_proc} % a odpor vzduchu.")
    
    m1, m2, m3 = st.columns(3)
    m1.metric("Reálná Spotřeba", f"{spotreba_wh_km_phys:.1f} Wh/km")
    m2.metric("Dojezd (Fyzika)", f"{dojezd_bat_phys:.1f} km", delta=f"{dojezd_bat_phys - dojezd_simple:.1f} km vs Teorie")
    m3.metric("Dojezd (+ Solár)", f"{dojezd_solar_phys:.1f} km", delta=f"+{(dojezd_solar_phys - dojezd_bat_phys):.1f} km solár")

    st.markdown("---")
    st.write(f"🚴 **Jezdec musí šlapat:** {P_human:.0f} W")
    st.write(f"⚡ **Motor skutečně dává:** {P_motor_final:.0f} W (dle zátěže kopce/větru)")

# Společný graf pro porovnání
st.divider()
st.subheader("⚔️ Porovnání dojezdů")

chart_data = pd.DataFrame({
    "Typ výpočtu": ["Tvůj vzorec (Teorie)", "Fyzika (Baterie)", "Fyzika (+Solár)"],
    "Dojezd (km)": [dojezd_simple, dojezd_bat_phys, dojezd_solar_phys]
})

st.bar_chart(chart_data, x="Typ výpočtu", y="Dojezd (km)")
