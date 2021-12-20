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

(:background)
class FunServiceDelegate extends Toybox.System.ServiceDelegate {

  function initialize() {
    System.ServiceDelegate.initialize();
  }


  function get_ai_loc() {
    var ai = Activity.getActivityInfo();
    if (ai != null) {
      if (ai.currentLocation != null) {
        var loc = ai.currentLocation.toDegrees();
        return ai.currentLocation.toDegrees();
      }
    }
    return null;
  }

  function get_data_loc() {
    var data = Storage.getValue("data");
    if (data != null) {
      try {
        return [data["coord"]["lat"], data["coord"]["lon"]];
      } catch (e) {
        return null;
      }
    }
    return null;
  }


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

  function onTemporalEvent() {
    var delta = 7200;
    var ai_loc = get_ai_loc();
    var data_loc = get_data_loc();
    var last_weather = Storage.getValue("last_weather");
    var distance = 100;
    if (ai_loc != null && data_loc != null) {
      try {
        distance = dist(ai_loc, data_loc);
      } catch (e) {
      }
    }
    if (last_weather != null) {
      delta = Time.now().value() - last_weather;
    }
    var loc = ai_loc != null ? ai_loc : data_loc != null ? data_loc : null;
    if (loc != null && (last_weather == null || delta > 1800 || distance > 10)) {
      get_weather(loc[0].toFloat(), loc[1].toFloat());
    } else {
      var data = {};
      data["delta"] = delta;
      data["distance"] = distance;
      data["ai_loc"] = ai_loc;
      data["data_loc"] = data_loc;
      Background.exit(data);
    }
  }

  function weather_received(code, data) {
    if (code == 200) {
      Background.exit(data);
    }
  }

  function get_weather(lat, lon) {
    // Polite request from Vince, developer of the Crystal Watch Face:
    //
    // Please do not abuse this API key, or else I will be forced to make thousands of users of Crystal
    // sign up for their own Open Weather Map free account, and enter their key in settings - a much worse
    // user experience for everyone.
    //
    // Crystal has been registered with OWM on the Open Source Plan, which lifts usage limits for free, so
    // that everyone benefits. However, these lifted limits only apply to the Current Weather API, and *not*
    // the One Call API. Usage of this key for the One Call API risks blocking the key for everyone.
    //
    // If you intend to use this key in your own app, especially for the One Call API, please create your own
    // OWM account, and own key. You should be able to apply for the Open Source Plan to benefit from the same
    // lifted limits as Crystal. Thank you.
    Communications.makeWebRequest("https://api.openweathermap.org/data/2.5/weather",
                                  {"lat"=>lat, "lon"=>lon, "appid"=> "2651f49cb20de925fc57590709b86ce6"},
                                  {:methods => Communications.HTTP_REQUEST_METHOD_GET,
                                   :responseType => Communications.HTTP_RESPONSE_CONTENT_TYPE_JSON
                                  }, method(:weather_received));
  }
}
