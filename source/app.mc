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


using Toybox.Application;
using Toybox.Background;
using Toybox.Time;
using Toybox.Application.Storage;
using Toybox.Math;

(:background)
class FunWatch extends Application.AppBase {

  public function initialize() {
    AppBase.initialize();
  }

  function onBackgroundData(data) {
    var computed = {};
    var sunrise = Utils.ts_to_utcinfo(data["sys"]["sunrise"] + data["timezone"]);
    sunrise = [sunrise.hour, sunrise.min];
    var sunset = Utils.ts_to_utcinfo(data["sys"]["sunset"] + data["timezone"]);
    sunset = [sunset.hour, sunset.min];
    computed["sunrise"] = sunrise;
    computed["sunset"] = sunset;
    computed["ingh"] = data["main"]["pressure"] / 33.864;
    computed["temp"] = data["main"]["temp"] - 273.15;
    // https://en.wikipedia.org/wiki/Dew_point
    var rh = data["main"]["humidity"];
    var b = computed["temp"] < 0 ? 17.966 : 17.368;
    var c = computed["temp"] < 0 ? 247.15 : 238.88;
    computed["dew"] = c * ((Math.ln(rh / 100.0) + ((b * computed["temp"]) / (c + computed["temp"]))) /
                           (b - Math.ln(rh / 100.0) - ((b * computed["temp"]) / (c + computed["temp"]))));
    data["computed"] = computed;
    Storage.setValue("data", data);
  }

  function getServiceDelegate() {
    return [new FunServiceDelegate()];
  }

  function getInitialView() {
    Background.registerForTemporalEvent(new Time.Duration(5 * 60));
    var v = new FunWatchView();
    return [v , new FunWatchDelegate(v)];
  }

}
