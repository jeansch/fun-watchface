/* This file is part of fun-watchface */
/* Copyright (C) 2021  Jean Schurger */

/* This program is free software; you can redistribute it and/or modify */
/* it under the terms of the GNU General Public License as published by */
/* the Free Software Foundation; either version 3 of the License, or */
/* (at your option) any later version. */

/* This program is distributed in the hope that it will be useful, */
/* but WITHOUT ANY WARRANTY; without even the implied warranty of */
/* MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the */
/* GNU General Public License for more details. */

/* You should have received a copy of the GNU General Public License */
/* along with this program; if not, write to the Free Software Foundation, */
/* Inc., 51 Franklin Street, Fifth Floor, Boston, MA 02110-1301  USA */

using Toybox.Background;
using Toybox.Communications;
using Toybox.System;
using Toybox.Math;
using Toybox.Application.Storage;
using Toybox.Time;
using Toybox.Time.Gregorian;

(:background)
class FunServiceDelegate extends Toybox.System.ServiceDelegate {

  function toRadians(d) {
    return d * Math.PI / 180;
  }

  function atan2(y, x) {
    var angle = 0;
    if (x == 0) {
      if (y == 0) {
        angle = 0;
      } else if (y > 0) {
        angle = Math.PI/2;
      } else {
        angle = -Math.PI/2;
      }
    } else {
      angle = Math.atan(y/x);
      if (x < 0) {
        if (y > 0) {
          angle += Math.PI;
        } else if (y < 0) {
          angle -= Math.PI;
        } else {
          angle = Math.PI;
        }
      }
    }
    return angle;
  }

  function dist(co1, co2) {
    var phi_1 = toRadians(co1[0]);
    var phi_2 = toRadians(co2[0]);
    var delta_phi = toRadians(co2[0] - co1[0]);
    var delta_lambda = toRadians(co2[1] - co1[1]);
    var a = Math.pow(Math.sin(delta_phi / 2.0), 2) +
      Math.cos(phi_1) * Math.cos(phi_2) *
      Math.pow(Math.sin(delta_lambda / 2.0), 2);
    return 6925 * atan2(Math.sqrt(a), Math.sqrt(1 - a));
    // return (6371000 * (2 * atan2(Math.sqrt(a), Math.sqrt(1 - a)))) / 1840; // nm
  }

  function ts_to_info(ts) {
    var ret = Time.Gregorian.moment({
        :year => 1970, :month=> 1, :day=> 1,
        :hour=> 0, :minute => 0, :second=> 0});
    ret = ret.add(new Time.Duration(ts));
    return Time.Gregorian.info(ret, Time.FORMAT_SHORT);
  }

  function initialize() {
    System.ServiceDelegate.initialize();
  }

  function get_ai_loc() {
    var ai = Activity.getActivityInfo();
    if (ai != null) {
      if (ai.currentLocation != null) {
        return ai.currentLocation.toDegrees();
      }
    }
    return null;
  }

  function get_cache_ai_loc() {
    var cache = Storage.getValue("cache");
    if (cache != null) {
      try {
        return cache["ai_loc"];
      } catch (e) {
        return null;
      }
    }
    return null;
  }

  function get_last_weather_loc() {
    var weather = Storage.getValue("weather");
    if (weather != null) {
      try {
        return [weather["lat"], weather["lon"]];
      } catch (e) {
        return null;
      }
    }
    return null;
  }

  function onTemporalEvent() {
    var delta = 3600 + 1;
    var ai_loc = get_ai_loc();
    if (ai_loc == null) {
      ai_loc = Storage.getValue("view_loc");
    }
    if (ai_loc == null) {
      ai_loc = get_cache_ai_loc();
    }
    var last_weather_loc = get_last_weather_loc();
    var distance = 100;
    if (ai_loc != null && last_weather_loc != null) {
      try {
        distance = dist(ai_loc, last_weather_loc);
      } catch (e) {
      }
    }
    var loc = ai_loc != null ? ai_loc : last_weather_loc != null ? last_weather_loc : null;
    var last_weather = Storage.getValue("last_weather");
    var hour_changed = false;
    if (last_weather != null) {
      delta = Time.now().value() - last_weather;
    }
    if (loc != null && (distance > 10 || delta > 1800)) {
      get_weather(loc[0].toFloat(), loc[1].toFloat());
    } else {
      var cache = {};
      cache["cache"] = true;
      cache["delta"] = delta;
      cache["distance"] = distance;
      cache["ai_loc"] = ai_loc;
      Background.exit(cache);
    }
  }

  function weather_received(code, data) {
    if (code == 200) {
      Background.exit(data);
    }
  }

  function get_weather(lat, lon) {
    var s = System.getDeviceSettings();
    var uri = "https://wb.elaine.fi/wb/" +
      s.uniqueIdentifier + "/" + s.partNumber + "/" +
      lat.format("%f") + "/" + lon.format("%f");
    var options = {
      :methods => Communications.HTTP_REQUEST_METHOD_GET,
      :responseType => Communications.HTTP_RESPONSE_CONTENT_TYPE_JSON
    };
    Communications.makeWebRequest(uri, null, options,
                                  method(:weather_received));
  }

  function onStorageChanged() {
    System.println("Storage changed");
  }
}
