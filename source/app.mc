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
    if (data.get("cache") == true) {
      Storage.setValue("cache", data);
    } else {
      var sunrise = Utils.ts_to_info(int(data["sunrise"]));
      data["_sunrise"] = [sunrise.hour, sunrise.min];
      var sunset = Utils.ts_to_info(int(data["sunset"]));
      data["_sunset"] = [sunset.hour, sunset.min];
      Storage.setValue("weather", data);
      Storage.setValue("last_weather", Time.now().value());
      Storage.deleteValue("cache");
    }
  }

  function getServiceDelegate() {
    return [new FunServiceDelegate()];
  }

  function getInitialView() {
    Background.registerForTemporalEvent(new Time.Duration(5 * 60));
    return [new FunWatchView(), new FunWatchDelegate()];
  }

  public function getSettingsView() {
    return [new SettingsView(), new SettingsViewDelegate()];
  }
}
