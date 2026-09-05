#!/usr/bin/env python3
"""Fetch and normalize Open-Meteo weather data for Tonantzintla."""

from __future__ import annotations

import json
import os
import sys
import time
import urllib.parse
import urllib.request
from datetime import datetime
from pathlib import Path


CACHE_PATH = Path(os.environ.get("XDG_CACHE_HOME", Path.home() / ".cache")) / "tonantzintla" / "weather.json"
CACHE_SCHEMA = 2
USER_AGENT = "Tonantzintla/0.9 (Quickshell weather widget)"


def request_json(url: str) -> dict:
    request = urllib.request.Request(url, headers={"User-Agent": USER_AGENT})
    with urllib.request.urlopen(request, timeout=10) as response:
        return json.load(response)


def condition(code: int, is_day: bool = True) -> tuple[str, str]:
    if code == 0:
        return ("Clear sky", "☀" if is_day else "☾")
    if code in (1, 2):
        return ("Partly cloudy", "◒")
    if code == 3:
        return ("Overcast", "☁")
    if code in (45, 48):
        return ("Fog", "≋")
    if code in (51, 53, 55, 56, 57):
        return ("Drizzle", "☂")
    if code in (61, 63, 65, 66, 67, 80, 81, 82):
        return ("Rain", "☂")
    if code in (71, 73, 75, 77, 85, 86):
        return ("Snow", "❄")
    if code in (95, 96, 99):
        return ("Thunderstorm", "ϟ")
    return ("Unknown sky", "·")


def load_cache(location: str, unit: str, max_age: int = 600) -> dict | None:
    try:
        data = json.loads(CACHE_PATH.read_text())
        if data.get("schema") != CACHE_SCHEMA:
            return None
        if data.get("query") != location or data.get("unit") != unit:
            return None
        if time.time() - float(data.get("fetched_at", 0)) > max_age:
            return None
        return data
    except (OSError, ValueError, TypeError):
        return None


def any_cache(location: str, unit: str) -> dict | None:
    try:
        data = json.loads(CACHE_PATH.read_text())
        if data.get("query") == location and data.get("unit") == unit:
            data["status"] = "CACHED FORECAST"
            return data
    except (OSError, ValueError, TypeError):
        pass
    return None


def build_forecast(location: str, unit: str) -> dict:
    geocode_query = urllib.parse.urlencode({"name": location, "count": 1, "language": "en", "format": "json"})
    geocode = request_json("https://geocoding-api.open-meteo.com/v1/search?" + geocode_query)
    results = geocode.get("results") or []
    if not results:
        raise RuntimeError("Location not found")

    place = results[0]
    params = {
        "latitude": place["latitude"],
        "longitude": place["longitude"],
        "current": "temperature_2m,apparent_temperature,is_day,weather_code,wind_speed_10m,relative_humidity_2m,precipitation",
        "hourly": "temperature_2m,weather_code,precipitation_probability",
        "daily": "weather_code,temperature_2m_max,temperature_2m_min,precipitation_probability_max,sunrise,sunset",
        "temperature_unit": "fahrenheit" if unit == "fahrenheit" else "celsius",
        "wind_speed_unit": "mph" if unit == "fahrenheit" else "kmh",
        "timezone": "auto",
        "forecast_days": 5,
    }
    forecast = request_json("https://api.open-meteo.com/v1/forecast?" + urllib.parse.urlencode(params))
    current = forecast.get("current") or {}
    current_units = forecast.get("current_units") or {}
    hourly = forecast.get("hourly") or {}
    daily = forecast.get("daily") or {}
    now_text = str(current.get("time", ""))
    now_hour = now_text[:13]
    hour_times = hourly.get("time") or []
    start = next((index for index, value in enumerate(hour_times) if str(value)[:13] >= now_hour), 0)

    weather_code = int(current.get("weather_code", -1))
    label, icon = condition(weather_code, bool(current.get("is_day", 1)))
    hourly_rows = []
    for index in range(start, min(start + 8, len(hour_times))):
        code = int((hourly.get("weather_code") or [-1] * len(hour_times))[index])
        row_label, row_icon = condition(code, True)
        hourly_rows.append({
            "time": str(hour_times[index])[11:16],
            "temp": round(float((hourly.get("temperature_2m") or [0] * len(hour_times))[index])),
            "precipitation": int((hourly.get("precipitation_probability") or [0] * len(hour_times))[index] or 0),
            "code": code,
            "condition": row_label,
            "icon": row_icon,
        })

    day_times = daily.get("time") or []
    sunrise_times = daily.get("sunrise") or []
    sunset_times = daily.get("sunset") or []
    daily_rows = []
    for index, date_text in enumerate(day_times[:5]):
        code = int((daily.get("weather_code") or [-1] * len(day_times))[index])
        row_label, row_icon = condition(code, True)
        date = datetime.strptime(date_text, "%Y-%m-%d")
        daily_rows.append({
            "day": date.strftime("%a").upper(),
            "date": date.strftime("%d %b").upper(),
            "max": round(float((daily.get("temperature_2m_max") or [0] * len(day_times))[index])),
            "min": round(float((daily.get("temperature_2m_min") or [0] * len(day_times))[index])),
            "precipitation": int((daily.get("precipitation_probability_max") or [0] * len(day_times))[index] or 0),
            "code": code,
            "condition": row_label,
            "icon": row_icon,
            "sunrise": str(sunrise_times[index])[11:16] if index < len(sunrise_times) else "--:--",
            "sunset": str(sunset_times[index])[11:16] if index < len(sunset_times) else "--:--",
        })

    display_location = place.get("name", location)
    admin = place.get("admin1")
    country = place.get("country_code", "")
    if admin and admin.lower() != str(display_location).lower():
        display_location += ", " + admin

    return {
        "schema": CACHE_SCHEMA,
        "ok": True,
        "status": "FORECAST SYNCHRONIZED",
        "query": location,
        "unit": unit,
        "unit_symbol": "°F" if unit == "fahrenheit" else "°C",
        "wind_unit": current_units.get("wind_speed_10m", "mph" if unit == "fahrenheit" else "km/h"),
        "location": display_location,
        "country": country,
        "latitude": float(place["latitude"]),
        "longitude": float(place["longitude"]),
        "timezone": forecast.get("timezone_abbreviation", ""),
        "updated": now_text[11:16],
        "fetched_at": int(time.time()),
        "current": {
            "temp": round(float(current.get("temperature_2m", 0))),
            "feels": round(float(current.get("apparent_temperature", 0))),
            "humidity": int(current.get("relative_humidity_2m", 0)),
            "precipitation": round(float(current.get("precipitation", 0)), 1),
            "wind": round(float(current.get("wind_speed_10m", 0))),
            "code": weather_code,
            "condition": label,
            "icon": icon,
        },
        "hourly": hourly_rows,
        "daily": daily_rows,
    }


def main() -> int:
    location = (sys.argv[1] if len(sys.argv) > 1 else "").strip()
    unit = sys.argv[2] if len(sys.argv) > 2 else "celsius"
    if not location:
        print(json.dumps({
            "ok": False,
            "status": "SET A LOCATION",
            "location": "",
            "unit": unit,
            "unit_symbol": "°F" if unit == "fahrenheit" else "°C",
        }, separators=(",", ":")))
        return 0
    cached = load_cache(location, unit)
    if cached:
        print(json.dumps(cached, separators=(",", ":")))
        return 0
    try:
        data = build_forecast(location, unit)
        CACHE_PATH.parent.mkdir(parents=True, exist_ok=True)
        CACHE_PATH.write_text(json.dumps(data, separators=(",", ":")))
    except Exception as error:  # Network and malformed responses share one graceful path.
        data = any_cache(location, unit) or {
            "ok": False,
            "status": str(error).upper(),
            "query": location,
            "unit": unit,
            "unit_symbol": "°F" if unit == "fahrenheit" else "°C",
            "location": location,
            "current": {}, "hourly": [], "daily": [],
        }
    print(json.dumps(data, separators=(",", ":")))
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
