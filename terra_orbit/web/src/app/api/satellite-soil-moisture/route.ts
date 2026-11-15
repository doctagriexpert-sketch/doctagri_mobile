import { NextRequest, NextResponse } from "next/server";
import type { SoilData } from "@/lib/environment";
export const dynamic = "force-dynamic";

export async function GET(request: NextRequest) {
  const lat = Number(request.nextUrl.searchParams.get("lat"));
  const lon = Number(request.nextUrl.searchParams.get("lon"));
  if (!request.nextUrl.searchParams.has("lat") || !request.nextUrl.searchParams.has("lon") ||
      !Number.isFinite(lat) || !Number.isFinite(lon) || Math.abs(lat) > 90 || Math.abs(lon) > 180) {
    return NextResponse.json({ error: "Coordonnées invalides" }, { status: 400 });
  }
  try {
    // Current-hour model outputs, not SMAP or ECOSTRESS observations.
    const url = `https://api.open-meteo.com/v1/forecast?latitude=${lat}&longitude=${lon}&hourly=soil_moisture_0_to_1cm,soil_temperature_0cm&forecast_hours=1&timezone=UTC`;
    const response = await fetch(url, { next: { revalidate: 1800 }, signal: AbortSignal.timeout(10000) });
    if (!response.ok) throw new Error(`Open-Meteo : HTTP ${response.status}`);
    const payload = await response.json();
    const hourly = payload.hourly ?? {};
    const time = hourly.time?.[0];
    const moisture = hourly.soil_moisture_0_to_1cm?.[0];
    const temperature = hourly.soil_temperature_0cm?.[0];
    const timestamp = typeof time === "string" ? Date.parse(`${time}Z`) : NaN;
    const age = Date.now() - timestamp;
    if (!Number.isFinite(timestamp) || age < 0 || age > 2 * 3600000 ||
        typeof moisture !== "number" || !Number.isFinite(moisture) || moisture < 0 || moisture > 1 ||
        typeof temperature !== "number" || !Number.isFinite(temperature) || temperature < -90 || temperature > 90) {
      throw new Error("Open-Meteo : humidité ou température du sol absente, invalide ou périmée");
    }
    const result: SoilData = {
      provider: "Open-Meteo — modèle météorologique (sélection automatique)",
      asOf: new Date(timestamp).toISOString(), depthCm: "0–1",
      soilMoistureM3M3: moisture, surfaceTempC: temperature,
    };
    return NextResponse.json(result);
  } catch (error) {
    return NextResponse.json({ error: error instanceof Error ? error.message : "Données sol indisponibles" }, { status: 502 });
  }
}
