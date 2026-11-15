"use client";

import React, { useState, useMemo, useEffect } from "react";
import {
  FieldLocation,
  TOGO_OFFICIAL_CANTONS,
  TOGO_COOPERATIVES,
  getRegionForCoordinates,
  TOGO_REGIONS,
} from "@/data/togoData";
import { Navigation, Building2, Search, CheckCircle2, RotateCcw } from "lucide-react";

interface FieldLocationSelectorProps {
  currentLocation: FieldLocation;
  onSelectLocation: (location: FieldLocation) => void;
}

export function FieldLocationSelector({
  currentLocation,
  onSelectLocation,
}: FieldLocationSelectorProps) {
  const [activeMode, setActiveMode] = useState<"cantons" | "gps" | "coop">("cantons");

  // Cascading filters
  const [regionFilter, setRegionFilter] = useState<string>("");
  const [prefectureFilter, setPrefectureFilter] = useState<string>("");
  const [communeFilter, setCommuneFilter] = useState<string>("");
  const [cantonFilter, setCantonFilter] = useState<string>("");
  const [searchTerm, setSearchTerm] = useState<string>("");

  // GPS manual
  const [gpsLoading, setGpsLoading] = useState(false);
  const [gpsError, setGpsError] = useState<string | null>(null);
  const [customLat, setCustomLat] = useState(currentLocation.lat.toFixed(4));
  const [customLon, setCustomLon] = useState(currentLocation.lon.toFixed(4));

  // Sync custom coordinates with currentLocation
  useEffect(() => {
    setCustomLat(currentLocation.lat.toFixed(4));
    setCustomLon(currentLocation.lon.toFixed(4));
  }, [currentLocation.lat, currentLocation.lon]);

  // Extract unique regions
  const uniqueRegions = useMemo(() => {
    return Array.from(new Set(TOGO_OFFICIAL_CANTONS.map((c) => c.region_admin))).sort();
  }, []);

  // Filtered prefectures based on selected region
  const availablePrefectures = useMemo(() => {
    return Array.from(
      new Set(
        TOGO_OFFICIAL_CANTONS
          .filter((c) => !regionFilter || c.region_admin === regionFilter)
          .map((c) => c.prefecture)
      )
    ).sort();
  }, [regionFilter]);

  // Filtered communes based on selected prefecture
  const availableCommunes = useMemo(() => {
    return Array.from(
      new Set(
        TOGO_OFFICIAL_CANTONS
          .filter(
            (c) =>
              (!regionFilter || c.region_admin === regionFilter) &&
              (!prefectureFilter || c.prefecture === prefectureFilter)
          )
          .map((c) => c.commune)
      )
    ).sort();
  }, [regionFilter, prefectureFilter]);

  // Filtered cantons based on cascade
  const availableCantons = useMemo(() => {
    return TOGO_OFFICIAL_CANTONS.filter(
      (c) =>
        (!regionFilter || c.region_admin === regionFilter) &&
        (!prefectureFilter || c.prefecture === prefectureFilter) &&
        (!communeFilter || c.commune === communeFilter)
    ).sort((a, b) => a.name.localeCompare(b.name));
  }, [regionFilter, prefectureFilter, communeFilter]);

  const handleSelectCantonByObject = (c: (typeof TOGO_OFFICIAL_CANTONS)[0]) => {
    setCantonFilter(c.name);
    setRegionFilter(c.region_admin);
    setPrefectureFilter(c.prefecture);
    setCommuneFilter(c.commune);
    onSelectLocation({
      id: c.id,
      name: `Canton de ${c.name}`,
      locality: `${c.canton}, ${c.prefecture}`,
      canton: c.canton,
      commune: c.commune,
      prefecture: c.prefecture,
      region: c.region,
      region_admin: c.region_admin,
      lat: c.lat,
      lon: c.lon,
      penteDeg: c.penteDeg,
      description: `Découpage officiel : Canton de ${c.name} • Commune ${c.commune} • Préfecture de ${c.prefecture} (${c.region_admin})`,
    });
  };

  const handleCantonDropdownChange = (cantonName: string) => {
    setCantonFilter(cantonName);
    if (!cantonName) return;
    const found = availableCantons.find((c) => c.name === cantonName) ||
      TOGO_OFFICIAL_CANTONS.find((c) => c.name === cantonName);
    if (found) {
      handleSelectCantonByObject(found);
    }
  };

  const handleSearchChange = (term: string) => {
    setSearchTerm(term);
    if (!term) return;
    const match = TOGO_OFFICIAL_CANTONS.find(
      (c) => c.name.toLowerCase() === term.toLowerCase().trim()
    );
    if (match) {
      handleSelectCantonByObject(match);
    }
  };

  const handleGetGps = () => {
    if (!navigator.geolocation) {
      setGpsError("La géolocalisation n'est pas supportée par votre navigateur.");
      return;
    }
    setGpsLoading(true);
    setGpsError(null);

    navigator.geolocation.getCurrentPosition(
      (pos) => {
        setGpsLoading(false);
        const lat = pos.coords.latitude;
        const lon = pos.coords.longitude;
        setCustomLat(lat.toFixed(4));
        setCustomLon(lon.toFixed(4));

        const reg = getRegionForCoordinates(lat, lon);
        const pente = TOGO_REGIONS[reg]?.penteMoyenneDeg ?? 2.5;

        onSelectLocation({
          id: "gps_custom",
          name: "Mon champ (Position GPS)",
          locality: `Parcelle GPS (${lat.toFixed(3)}°N, ${lon.toFixed(3)}°E)`,
          canton: "Relevé terrain",
          prefecture: reg,
          region: reg,
          lat,
          lon,
          penteDeg: pente,
          isGps: true,
          description: "Position exacte géoréférencée par capteur terrain",
        });
      },
      (err) => {
        setGpsLoading(false);
        setGpsError(`Erreur GPS : ${err.message}. Vous pouvez saisir les coordonnées manuellement.`);
      },
      { timeout: 10000, enableHighAccuracy: true }
    );
  };

  const handleApplyCustomCoords = () => {
    const lat = parseFloat(customLat);
    const lon = parseFloat(customLon);
    if (isNaN(lat) || isNaN(lon) || lat < 5 || lat > 12 || lon < -1 || lon > 3) {
      setGpsError("Coordonnées hors limites du Togo (Lat attendue ~6-11°N, Lon ~0-2°E).");
      return;
    }
    setGpsError(null);
    const reg = getRegionForCoordinates(lat, lon);
    const pente = TOGO_REGIONS[reg]?.penteMoyenneDeg ?? 2.5;

    onSelectLocation({
      id: `custom_${lat.toFixed(3)}_${lon.toFixed(3)}`,
      name: "Parcelle spécifique",
      locality: `Coordonnées (${lat.toFixed(4)}°N, ${lon.toFixed(4)}°E)`,
      region: reg,
      lat,
      lon,
      penteDeg: pente,
      isGps: true,
      description: "Coordonnées parcellaires saisies manuellement",
    });
  };

  const resetFilters = () => {
    setRegionFilter("");
    setPrefectureFilter("");
    setCommuneFilter("");
    setCantonFilter("");
    setSearchTerm("");
  };

  return (
    <section className="panel" style={{ borderTop: "3px solid #059669" }}>
      <div className="panel-head">
        <div>
          <h2>📍 Localisation de la Parcelle (Référentiel Officiel du Togo)</h2>
          <p className="lede">
            Sélectionnez votre zone parmi les <strong>392 cantons officiels</strong> ou activez le GPS
            de votre champ pour caler les données satellitaires de la NASA.
          </p>
        </div>
        <div style={{ display: "flex", gap: "0.5rem", flexWrap: "wrap" }}>
          <button
            type="button"
            className={activeMode === "cantons" ? "tag active" : "tag"}
            onClick={() => setActiveMode("cantons")}
            style={{ cursor: "pointer" }}
          >
            🏛️ Découpage Officiel
          </button>
          <button
            type="button"
            className={activeMode === "gps" ? "tag active" : "tag"}
            onClick={() => setActiveMode("gps")}
            style={{ cursor: "pointer" }}
          >
            📍 Mon Champ (GPS)
          </button>
          <button
            type="button"
            className={activeMode === "coop" ? "tag active" : "tag"}
            onClick={() => setActiveMode("coop")}
            style={{ cursor: "pointer" }}
          >
            🏢 Espace Coopérative
          </button>
        </div>
      </div>

      <div style={{ marginTop: "1rem" }}>
        {activeMode === "cantons" && (
          <div
            style={{
              background: "#f8fafc",
              padding: "1.25rem",
              borderRadius: "8px",
              border: "1px solid #e2e8f0",
            }}
          >
            {/* 4 Clean Cascading Selectors in a row + Direct Search */}
            <div
              style={{
                display: "grid",
                gridTemplateColumns: "repeat(auto-fit, minmax(180px, 1fr))",
                gap: "1rem",
                alignItems: "flex-end",
              }}
            >
              <div>
                <label style={{ fontSize: "0.8rem", fontWeight: 600, color: "#334155", display: "block", marginBottom: "5px" }}>
                  1. Région ({uniqueRegions.length}) :
                </label>
                <select
                  value={regionFilter}
                  onChange={(e) => {
                    setRegionFilter(e.target.value);
                    setPrefectureFilter("");
                    setCommuneFilter("");
                    setCantonFilter("");
                  }}
                  style={{ width: "100%", padding: "8px 10px", borderRadius: "6px", border: "1px solid #cbd5e1", fontSize: "0.85rem", background: "white" }}
                >
                  <option value="">Toutes les Régions</option>
                  {uniqueRegions.map((reg) => (
                    <option key={reg} value={reg}>
                      {reg}
                    </option>
                  ))}
                </select>
              </div>

              <div>
                <label style={{ fontSize: "0.8rem", fontWeight: 600, color: "#334155", display: "block", marginBottom: "5px" }}>
                  2. Préfecture ({availablePrefectures.length}) :
                </label>
                <select
                  value={prefectureFilter}
                  onChange={(e) => {
                    setPrefectureFilter(e.target.value);
                    setCommuneFilter("");
                    setCantonFilter("");
                  }}
                  style={{ width: "100%", padding: "8px 10px", borderRadius: "6px", border: "1px solid #cbd5e1", fontSize: "0.85rem", background: "white" }}
                >
                  <option value="">Toutes les Préfectures</option>
                  {availablePrefectures.map((pref) => (
                    <option key={pref} value={pref}>
                      {pref}
                    </option>
                  ))}
                </select>
              </div>

              <div>
                <label style={{ fontSize: "0.8rem", fontWeight: 600, color: "#334155", display: "block", marginBottom: "5px" }}>
                  3. Commune ({availableCommunes.length}) :
                </label>
                <select
                  value={communeFilter}
                  onChange={(e) => {
                    setCommuneFilter(e.target.value);
                    setCantonFilter("");
                  }}
                  style={{ width: "100%", padding: "8px 10px", borderRadius: "6px", border: "1px solid #cbd5e1", fontSize: "0.85rem", background: "white" }}
                >
                  <option value="">Toutes les Communes</option>
                  {availableCommunes.map((comm) => (
                    <option key={comm} value={comm}>
                      {comm}
                    </option>
                  ))}
                </select>
              </div>

              <div>
                <label style={{ fontSize: "0.8rem", fontWeight: 600, color: "#065f46", display: "block", marginBottom: "5px" }}>
                  4. Canton ({availableCantons.length}) :
                </label>
                <select
                  value={cantonFilter}
                  onChange={(e) => handleCantonDropdownChange(e.target.value)}
                  style={{
                    width: "100%",
                    padding: "8px 10px",
                    borderRadius: "6px",
                    border: "1.5px solid #059669",
                    fontSize: "0.85rem",
                    background: "#f0fdf4",
                    fontWeight: 600,
                    color: "#065f46",
                  }}
                >
                  <option value="">-- Choisir un canton --</option>
                  {availableCantons.map((c) => (
                    <option key={`${c.id}_${c.commune_id}`} value={c.name}>
                      {c.name} ({c.commune})
                    </option>
                  ))}
                </select>
              </div>

              <div>
                <label style={{ fontSize: "0.8rem", fontWeight: 600, color: "#334155", display: "block", marginBottom: "5px" }}>
                  Recherche rapide :
                </label>
                <div style={{ display: "flex", gap: "6px" }}>
                  <input
                    type="text"
                    list="all-togo-cantons"
                    placeholder="Tapez un canton..."
                    value={searchTerm}
                    onChange={(e) => handleSearchChange(e.target.value)}
                    style={{ flex: 1, padding: "8px 10px", borderRadius: "6px", border: "1px solid #cbd5e1", fontSize: "0.85rem" }}
                  />
                  <datalist id="all-togo-cantons">
                    {TOGO_OFFICIAL_CANTONS.map((c) => (
                      <option key={`dl_${c.id}_${c.commune_id}`} value={c.name}>
                        {c.name} — {c.commune} ({c.prefecture})
                      </option>
                    ))}
                  </datalist>
                  {(regionFilter || prefectureFilter || communeFilter || cantonFilter || searchTerm) && (
                    <button
                      type="button"
                      onClick={resetFilters}
                      style={{
                        padding: "8px 10px",
                        background: "#e2e8f0",
                        border: "none",
                        borderRadius: "6px",
                        fontSize: "0.78rem",
                        cursor: "pointer",
                        display: "flex",
                        alignItems: "center",
                        gap: "4px",
                      }}
                      title="Réinitialiser"
                    >
                      <RotateCcw size={12} />
                      Effacer
                    </button>
                  )}
                </div>
              </div>
            </div>
          </div>
        )}

        {activeMode === "gps" && (
          <div style={{ background: "#f8fafc", padding: "1.25rem", borderRadius: "8px", border: "1px solid #e2e8f0" }}>
            <div style={{ display: "flex", alignItems: "center", justifyContent: "space-between", flexWrap: "wrap", gap: "0.5rem", marginBottom: "0.75rem" }}>
              <strong>Coordonnées GPS de la parcelle (Précision 10–30 m)</strong>
              <button
                type="button"
                onClick={handleGetGps}
                disabled={gpsLoading}
                style={{
                  display: "flex",
                  alignItems: "center",
                  gap: "6px",
                  background: "#059669",
                  color: "white",
                  border: "none",
                  borderRadius: "6px",
                  padding: "8px 14px",
                  cursor: "pointer",
                  fontSize: "0.85rem",
                  fontWeight: 600,
                }}
              >
                <Navigation size={14} />
                {gpsLoading ? "Localisation en cours..." : "Me géolocaliser sur mon champ"}
              </button>
            </div>

            {gpsError && <p style={{ color: "#b91c1c", fontSize: "0.85rem", margin: "0.5rem 0" }}>{gpsError}</p>}

            <p style={{ fontSize: "0.85rem", color: "#64748b", margin: "0.5rem 0" }}>
              Ou saisissez directement les coordonnées GPS de votre champ :
            </p>

            <div style={{ display: "flex", gap: "1rem", alignItems: "flex-end", marginTop: "0.75rem", flexWrap: "wrap" }}>
              <label style={{ flex: "1 1 180px", fontSize: "0.85rem" }}>
                Latitude (°N) :
                <input
                  type="text"
                  value={customLat}
                  onChange={(e) => setCustomLat(e.target.value)}
                  style={{ width: "100%", padding: "8px 10px", borderRadius: "6px", border: "1px solid #cbd5e1", marginTop: "4px" }}
                />
              </label>
              <label style={{ flex: "1 1 180px", fontSize: "0.85rem" }}>
                Longitude (°E) :
                <input
                  type="text"
                  value={customLon}
                  onChange={(e) => setCustomLon(e.target.value)}
                  style={{ width: "100%", padding: "8px 10px", borderRadius: "6px", border: "1px solid #cbd5e1", marginTop: "4px" }}
                />
              </label>
              <button
                type="button"
                onClick={handleApplyCustomCoords}
                style={{
                  background: "#0284c7",
                  color: "white",
                  border: "none",
                  borderRadius: "6px",
                  padding: "9px 18px",
                  cursor: "pointer",
                  fontSize: "0.85rem",
                  fontWeight: 600,
                }}
              >
                Appliquer les coordonnées
              </button>
            </div>
          </div>
        )}

        {activeMode === "coop" && (
          <div>
            <p style={{ fontSize: "0.85rem", color: "#64748b", marginBottom: "0.75rem" }}>
              Sélectionnez une <strong>coopérative agricole</strong> pour caler les bilans hydriques sur son
              bassin de parcelles adhérentes :
            </p>
            <div style={{ display: "grid", gridTemplateColumns: "repeat(auto-fill, minmax(320px, 1fr))", gap: "0.75rem" }}>
              {TOGO_COOPERATIVES.map((coop) => {
                const isSelected = currentLocation.id === coop.id;
                return (
                  <div
                    key={coop.id}
                    onClick={() =>
                      onSelectLocation({
                        id: coop.id,
                        name: coop.name,
                        locality: coop.zone,
                        region: coop.region,
                        lat: coop.lat,
                        lon: coop.lon,
                        penteDeg: TOGO_REGIONS[coop.region]?.penteMoyenneDeg ?? 2.5,
                        description: `${coop.filiere} • ${coop.membres} producteurs • ${coop.superficieTotaleHa} ha`,
                      })
                    }
                    style={{
                      padding: "12px 14px",
                      borderRadius: "8px",
                      cursor: "pointer",
                      border: isSelected ? "1.5px solid #059669" : "1px solid #e2e8f0",
                      background: isSelected ? "#f0fdf4" : "#ffffff",
                      display: "flex",
                      justifyContent: "space-between",
                      alignItems: "center",
                    }}
                  >
                    <div>
                      <div style={{ fontWeight: 600, color: "#0f172a", fontSize: "0.9rem" }}>
                        <Building2 size={14} style={{ display: "inline", marginRight: "6px", verticalAlign: "middle" }} />
                        {coop.name}
                      </div>
                      <div style={{ fontSize: "0.78rem", color: "#475569", marginTop: "3px" }}>
                        Zone : {coop.zone} ({coop.region}) • Filière : <strong>{coop.filiere}</strong>
                      </div>
                      <div style={{ fontSize: "0.75rem", color: "#059669", marginTop: "3px" }}>
                        {coop.membres} membres adhérents • {coop.superficieTotaleHa} hectares suivis
                      </div>
                    </div>
                    {isSelected && <CheckCircle2 size={20} color="#059669" />}
                  </div>
                );
              })}
            </div>
          </div>
        )}

        {/* Current selected summary banner */}
        <div
          style={{
            marginTop: "1rem",
            padding: "0.75rem 1rem",
            background: "#f1f5f9",
            borderRadius: "6px",
            display: "flex",
            justifyContent: "space-between",
            alignItems: "center",
            flexWrap: "wrap",
            gap: "0.5rem",
            fontSize: "0.85rem",
          }}
        >
          <div>
            <span style={{ color: "#64748b" }}>Cible sélectionnée : </span>
            <strong style={{ color: "#0f172a" }}>{currentLocation.name}</strong> ({currentLocation.locality})
          </div>
          <div style={{ fontFamily: "monospace", color: "#0369a1", fontWeight: 600 }}>
            GPS : {currentLocation.lat.toFixed(4)}° N, {currentLocation.lon.toFixed(4)}° E
          </div>
        </div>
      </div>
    </section>
  );
}
