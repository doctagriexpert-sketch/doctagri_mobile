import { NextRequest, NextResponse } from "next/server";
import type { ClimateData, ClimatePoint } from "@/lib/environment";
export const dynamic = "force-dynamic";

export async function GET(request: NextRequest) {
  const lat = Number(request.nextUrl.searchParams.get("lat"));
  const lon = Number(request.nextUrl.searchParams.get("lon"));
  if (!request.nextUrl.searchParams.has("lat") || !request.nextUrl.searchParams.has("lon") ||
      !Number.isFinite(lat) || !Number.isFinite(lon) || Math.abs(lat) > 90 || Math.abs(lon) > 180) {
    return NextResponse.json({ error: "Coordonnées invalides" }, { status: 400 });
  }
  const end = new Date();
  end.setUTCHours(0, 0, 0, 0);
  end.setUTCDate(end.getUTCDate() - 5);
  const start = new Date(end);
  start.setUTCDate(start.getUTCDate() - 29);
  const compact = (date: Date) => date.toISOString().slice(0, 10).replaceAll("-", "");
  const url = `https://power.larc.nasa.gov/api/temporal/daily/point?parameters=PRECTOTCORR,T2M,T2M_MAX,T2M_MIN,ALLSKY_SFC_SW_DWN&community=AG&longitude=${lon}&latitude=${lat}&start=${compact(start)}&end=${compact(end)}&format=JSON`;
  try {
    const response = await fetch(url, { next: { revalidate: 3600 }, signal: AbortSignal.timeout(10000) });
    if (!response.ok) throw new Error(`NASA POWER : HTTP ${response.status}`);
    const payload = await response.json();
    const parameters = payload.properties?.parameter ?? {};
    const read = (name: string, day: string, min: number, max: number): number | null => {
      const value = parameters[name]?.[day];
      return typeof value === "number" && Number.isFinite(value) && value >= min && value <= max
        ? Math.round(value * 10) / 10 : null;
    };
    const series: ClimatePoint[] = [];
    let totalRain = 0, validRainDaysCount = 0, currentDryDays = 0, maxDrySpellDays = 0;
    // Include dates absent from every provider map; unknown days break continuity.
    for (const date = new Date(start); date <= end; date.setUTCDate(date.getUTCDate() + 1)) {
      const day = compact(date);
      const rainMm = read("PRECTOTCORR", day, 0, 2000);
      const tempMean = read("T2M", day, -89, 65);
      const tempMin = read("T2M_MIN", day, -89, 65);
      const tempMax = read("T2M_MAX", day, -89, 65);
      const solarRadiation = read("ALLSKY_SFC_SW_DWN", day, 0, 100);
      if (rainMm !== null) { validRainDaysCount++; totalRain += rainMm; }
      currentDryDays = rainMm !== null && rainMm < 2 ? currentDryDays + 1 : 0;
      maxDrySpellDays = Math.max(maxDrySpellDays, currentDryDays);
      series.push({ dateIso: date.toISOString().slice(0, 10), rainMm, tempMean, tempMin, tempMax,
        solarRadiation, hasMissingData: [rainMm, tempMean, tempMin, tempMax, solarRadiation].includes(null) });
    }
    if (!series.some(point => point.rainMm !== null || point.tempMean !== null)) {
      throw new Error("NASA POWER : aucune donnée météo exploitable sur la période");
    }
    const validDaysCount = series.filter(point => !point.hasMissingData).length;
    const result: ClimateData = {
      provider: "NASA POWER — produits météorologiques et satellitaires",
      periodDays: series.length, validDaysCount, missingDaysCount: series.length - validDaysCount,
      summary: { totalRainMm: validRainDaysCount ? Math.round(totalRain * 10) / 10 : null,
        maxDrySpellDays: validRainDaysCount ? maxDrySpellDays : null, validRainDaysCount, periodDays: series.length },
      series,
    };
    return NextResponse.json(result);
  } catch (error) {
    return NextResponse.json({ error: error instanceof Error ? error.message : "NASA POWER indisponible" }, { status: 502 });
  }
}
