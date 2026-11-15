"use client";
import { useEffect, useState } from "react";
import type { ClimateData, RemoteData, SoilData } from "./environment";

export function useRegionalEnvironment(lat: number, lon: number) {
  const key = `${lat},${lon}`;
  const [revision, setRevision] = useState(0);
  const [weather, setWeather] = useState<{ key: string; value: RemoteData<ClimateData> }>({
    key,
    value: { status: "loading" },
  });
  const [soil, setSoil] = useState<{ key: string; value: RemoteData<SoilData> }>({
    key,
    value: { status: "loading" },
  });

  useEffect(() => {
    const controller = new AbortController();
    let active = true;
    setWeather({ key, value: { status: "loading" } });
    setSoil({ key, value: { status: "loading" } });

    async function read<T>(route: string, update: (value: { key: string; value: RemoteData<T> }) => void) {
      try {
        const response = await fetch(`/api/${route}?lat=${lat}&lon=${lon}`, {
          signal: AbortSignal.any([controller.signal, AbortSignal.timeout(15000)]),
        });
        let data: any;
        try {
          data = await response.json();
        } catch {
          throw new Error("Réponse serveur temporairement indisponible");
        }
        if (!response.ok) throw new Error(data?.error || `HTTP ${response.status}`);
        if (active) update({ key, value: { status: "ready", data } });
      } catch (error) {
        if (active) {
          update({
            key,
            value: {
              status: "error",
              error: error instanceof Error ? error.message : "Données indisponibles",
            },
          });
        }
      }
    }

    void read<ClimateData>("nasa-power", setWeather);
    void read<SoilData>("satellite-soil-moisture", setSoil);

    return () => {
      active = false;
      controller.abort();
    };
  }, [key, lat, lon, revision]);

  return {
    weather: weather.key === key ? weather.value : ({ status: "loading" } as RemoteData<ClimateData>),
    soil: soil.key === key ? soil.value : ({ status: "loading" } as RemoteData<SoilData>),
    retry: () => {
      setWeather({ key, value: { status: "loading" } });
      setSoil({ key, value: { status: "loading" } });
      setRevision((value) => value + 1);
    },
  };
}
