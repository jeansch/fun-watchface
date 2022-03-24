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


using Toybox.Graphics;
using Toybox.Lang;
using Toybox.Math;
using Toybox.System;
using Toybox.Activity;
using Toybox.Time;
using Toybox.Time.Gregorian;
using Toybox.WatchUi;
using Toybox.Attention;
using Toybox.UserProfile;
using Toybox.Application.Storage;

var scale_factor = 7;
var zones = [];
var cache;
var sec_triangles = {};
var use_pressure = false;

class FunWatchView extends WatchUi.WatchFace {
  var weather;
  var min_width;
  var utc_width;
  var utc_delta;
  var sec_width;
  var sec_delta;

  var cx;
  var cy;
  var radius;

  var offb;

  var settings_margin;
  var setting_length;
  var setting_padding;
  var setting_width;
  var setting_left_start;
  var setting_right_start;

  var connected = false;
  var old_min;
  var local_time;

  public function initialize() {
    WatchFace.initialize();
    var ds = System.getDeviceSettings();
    use_pressure = ds.elevationUnits == System.UNIT_METRIC;
  }


  public function onLayout(dc) {
    min_width = .5 * (dc.getHeight() / scale_factor);
    utc_width = min_width;
    utc_delta = .3 * dc.getHeight() / (scale_factor * 2);
    sec_width = 1 * utc_width;
    sec_delta = 1 * utc_delta;
    cx = dc.getWidth() / 2;
    cy = dc.getHeight() / 2;
    radius = cx < cy ? cx : cy;
    offb = new Graphics.BufferedBitmap({
       :width=>dc.getWidth(),
        :height=>dc.getHeight()});

    generate_sec_tri();
    old_min = -1;
  }


  function generate_sec_tri() {
    for(var sec = 0; sec <= 59; sec++) {
      sec_triangles.put(sec,
                        triangle(cx, cy, Math.PI - (sec / 60.0) * Math.PI * 2,
                                 -1 * sec_width + radius, sec_delta * (Math.PI / 180),
                                 sec_width));
    }
  }

  function sec_tri(s) {
    return sec_triangles.get(s);
  }



  private function triangle(center_x, center_y, angle, offset, delta, size) {
    var left = [center_x + Math.sin(angle - delta) * offset,
                center_y + Math.cos(angle - delta) * offset];
    var right = [center_x + Math.sin(angle + delta) * offset,
                 center_y + Math.cos(angle + delta) * offset];
    var top = [center_x + Math.sin(angle) * (offset + size),
               center_y + Math.cos(angle) * (offset + size)];
    return [left, right, top];
  }


  function draw_tri(dc, color, tri) {
    dc.setColor(color, Graphics.COLOR_TRANSPARENT);
    dc.drawLine(tri[0][0], tri[0][1], tri[1][0], tri[1][1]);
    dc.drawLine(tri[1][0], tri[1][1], tri[2][0], tri[2][1]);
    dc.drawLine(tri[2][0], tri[2][1], tri[0][0], tri[0][1]);
  }

  function draw_hands(dc, ct, ut) {
    var tri;
    var ct24 = (((ct.hour % 24) * 60) + ct.min) / (24 * 60.0);
    tri = triangle(cx, cy, Math.PI - ct24 * Math.PI * 2,
                   -utc_width + radius, utc_delta * (Math.PI / 180),
                   utc_width);
    dc.setColor(Graphics.COLOR_WHITE, Graphics.COLOR_TRANSPARENT);
    dc.fillPolygon(tri);
    draw_tri(dc, Graphics.COLOR_BLACK, tri);

    var utc = (((ut.hour % 24) * 60) + ut.min) / (24 * 60.0);
    dc.setColor(Graphics.COLOR_YELLOW, Graphics.COLOR_TRANSPARENT);
    tri = triangle(cx, cy, Math.PI - utc * Math.PI * 2,
                   -utc_width + radius, utc_delta * (Math.PI / 180),
                   utc_width);
    dc.fillPolygon(tri);
    dc.setPenWidth(2);
    draw_tri(dc, Graphics.COLOR_BLACK, tri);
  }

  public function draw_sec(dc) {
    var cx_color = Graphics.COLOR_BLUE;
    var nocx_color = Graphics.COLOR_RED;
    if (cache != null) {
      if (cache["delta"] > 7200) {
        cx_color = Graphics.COLOR_YELLOW;
        nocx_color = Graphics.COLOR_YELLOW;
      }
      if (cache["distance"] > 10) {
        cx_color = Graphics.COLOR_PURPLE;
        nocx_color = Graphics.COLOR_PINK;
      }
      if (cache["ai_loc"] == null) {
        cx_color = Graphics.COLOR_GREEN;
        nocx_color = Graphics.COLOR_ORANGE;
      }
    }

    // restore background and draw new sec
    var prev_sec = local_time.sec == 0 ? 59 : local_time.sec - 1;
    var tri = sec_tri(local_time.sec);
    var clip = Utils.getBoundingBox2(sec_tri(prev_sec), tri);
    var bw = clip[1][0] - clip[0][0] + 1;
    var bh = clip[1][1] - clip[0][1] + 1;
    dc.setClip(clip[0][0], clip[0][1], bw, bh);
    if (offb != null) {
      dc.drawBitmap(0, 0, offb);
    }
    dc.setColor(connected ? cx_color: nocx_color, Graphics.COLOR_TRANSPARENT);
    dc.fillPolygon(tri);
    dc.clearClip();
  }

  public function onPartialUpdate(dc) {
    update_zones();
    draw_sec(dc);
  }

  function draw_sun(dc) {
    var sun, a, ev;
    ev = weather["_sunrise"];
    sun = (((ev[0] % 24) * 60) + ev[1]) / (24 * 60.0);
    dc.setColor(Graphics.COLOR_YELLOW, Graphics.COLOR_TRANSPARENT);
    a = Math.PI - sun * Math.PI * 2;
    dc.fillCircle(cx + (radius) * Math.sin(a),
                  cy + (radius) * Math.cos(a), min_width / 1.5);
    ev = weather["_sunset"];
    sun = (((ev[0] % 24) * 60) + ev[1]) / (24 * 60.0);
    dc.setColor(Graphics.COLOR_ORANGE, Graphics.COLOR_TRANSPARENT);
    a = Math.PI - sun * Math.PI * 2;
    dc.fillCircle(cx + (radius) * Math.sin(a),
                  cy + (radius) * Math.cos(a), min_width / 1.5);
  }

  function draw_city(dc, delta) {
    var txt = weather["name"].substring(0, 12) + "(" + Utils.h_tdt(delta) + ")";
    dc.setColor(Graphics.COLOR_LT_GRAY, Graphics.COLOR_TRANSPARENT);
    dc.drawText(cx, cy + radius / 6, Graphics.FONT_TINY,
                txt,
                Graphics.TEXT_JUSTIFY_CENTER | Graphics.TEXT_JUSTIFY_VCENTER);
  }

  function draw_meteo(dc) {
    var txt;
    dc.setColor(Graphics.COLOR_LT_GRAY, Graphics.COLOR_TRANSPARENT);
    txt = Lang.format("$1$/$2$ $3$", [weather["temp"].format("%d"),
                                      weather["dew"].format("%d"),
                                      use_pressure ? weather["pressure"].format("%d") : weather["ingh"].format("%.02f")]);
    dc.drawText(cx, cy + 2 * radius / 6, Graphics.FONT_TINY,
                txt,
                Graphics.TEXT_JUSTIFY_CENTER | Graphics.TEXT_JUSTIFY_VCENTER);
    txt = Lang.format("$1$°$2$",
                      [weather["wind_dir"].format("%d"),
                       weather["wind_spd"].format("%d") +
                       (weather["wind_gst"] > 0 ? "G" + (weather["wind_gst"]).format("%d") : "")]);
    dc.drawText(cx, cy + 3 * radius / 6, Graphics.FONT_TINY,
                txt,
                Graphics.TEXT_JUSTIFY_CENTER | Graphics.TEXT_JUSTIFY_VCENTER);
  }



  function draw_circular_things(dc) {
    var start, end, cos_a, sin_a, a;
    var bat_color = 0, bat;
    var i;

    for (i = 0; i <= 59; i += 1) {
        a = Math.PI - i / 60.0 * (2 * Math.PI);
        cos_a = Math.cos(a);
        sin_a = Math.sin(a);
        start = radius;
        dc.setPenWidth(i % 5 ? 1 : 4);
        end = i % 5 ? radius - (radius / (scale_factor * 4)) : radius - (radius / (scale_factor * 3));
        dc.setColor(i % 5 ? Graphics.COLOR_LT_GRAY:
                    Graphics.COLOR_WHITE, Graphics.COLOR_TRANSPARENT);
        dc.drawLine(cx + start * sin_a, cy + start * cos_a,
                    cx + end * sin_a , cy + end * cos_a);
    }

    bat = System.getSystemStats().battery;
    for (i = 0; i <= 30; i += 1) {
      a = Math.PI - i / 60.0 * (2 * Math.PI);
      cos_a = Math.cos(a);
      sin_a = Math.sin(a);
      bat_color = bat >= 40 ? Graphics.COLOR_GREEN : bat >= 20 ? Graphics.COLOR_YELLOW : Graphics.COLOR_RED;
      dc.setColor(i * 100 / 30 <= bat ? bat_color : Graphics.COLOR_DK_GRAY, Graphics.COLOR_TRANSPARENT);
      dc.setPenWidth(i * 100 / 30 <= bat ? 4: 1);
      start = radius - min_width - 1 * (radius / (scale_factor * 3));
      end = radius - min_width - 2 * (radius / (scale_factor * 3));
      dc.drawLine(cx + start * sin_a, cy + start * cos_a,
                  cx + end * sin_a , cy + end * cos_a);
    }

    dc.setPenWidth(2);
    dc.setColor(Graphics.COLOR_YELLOW, Graphics.COLOR_TRANSPARENT);
    for (var h = 0; h <= (60 * 2 - 1); h += 5) {
        a = Math.PI - h / 120.0 * (2 * Math.PI);
        cos_a = Math.cos(a);
        sin_a = Math.sin(a);
        start = radius - (radius / (scale_factor * 3));
        end = radius - 2 * (radius / (scale_factor * 3));
        dc.drawLine(cx + start * sin_a, cy + start * cos_a,
                    cx + end * sin_a , cy + end * cos_a);
      }
  }


  function draw_time(dc) {
    var now = Gregorian.info(Time.now(), Time.FORMAT_MEDIUM);
    dc.setColor(Graphics.COLOR_WHITE, Graphics.COLOR_TRANSPARENT);
    dc.drawText(cx, cy - min_width * 3.5, Graphics.FONT_SMALL,
                Lang.format("$1$ $2$ $3$", [now.day_of_week, now.month, now.day]),
                Graphics.TEXT_JUSTIFY_CENTER | Graphics.TEXT_JUSTIFY_VCENTER);
    dc.drawText(cx, cy - min_width, Graphics.FONT_NUMBER_HOT,
                now.hour.format("%02d") + ":" + now.min.format("%02d"),
                Graphics.TEXT_JUSTIFY_CENTER | Graphics.TEXT_JUSTIFY_VCENTER);
  }


  public function get_hr() {
    var ai = Activity.getActivityInfo();
    if ((ai != null) && (ai.currentHeartRate != null)) {
      return ai.currentHeartRate;
    }
    return 0;
  }

  public function draw_hr(dc, hr) {
    var min = 0; var max = 0;
    var i;
    hr;
    if ((hr > 0) && (zones.size() > 0)) {
      var hr_color = hr <= zones[1] ? Graphics.COLOR_LT_GRAY:
        hr > zones[1] && hr <= zones[2] ? Graphics.COLOR_BLUE:
        hr > zones[2] && hr <= zones[3] ? Graphics.COLOR_GREEN:
        hr > zones[3] && hr <= zones[4] ? Graphics.COLOR_YELLOW:
        Graphics.COLOR_RED;
      for (i = 0; i < zones.size() - 1; i++) {
        if (hr > zones[i]) {
          max = zones[i+1];
          min = zones[i];
        }
      }
      max = max == 0 ? zones[1] : max;
      var range = max - min;
      var start = radius - min_width - 1 * (radius / (scale_factor * 3));
      var end = radius - min_width - 2 * (radius / (scale_factor * 3));
      var inc = range / 30.0 ;
      for (i = 0; i <= range; i+= inc) {
        var a = Math.PI + Math.PI - (Math.PI) * i / range;
        var cos_a = Math.cos(a);
        var sin_a = Math.sin(a);
        dc.setPenWidth(i + min <= hr ? 4: 1);
        dc.setColor(i + min <= hr ? (i + min < 50 ? Graphics.COLOR_DK_GRAY : hr_color) : Graphics.COLOR_DK_GRAY, Graphics.COLOR_TRANSPARENT);
        dc.drawLine(cx + start * sin_a, cy + start * cos_a,
                    cx + end * sin_a , cy + end * cos_a);
      }
    }
  }

  public function draw_settings(dc, settings) {
    var set_x, set_y;
    var setting_width = radius / 16;
    var setting_length = radius / 3;
    dc.setPenWidth(1);
    connected = settings.phoneConnected;
    settings.notificationCount = settings.notificationCount > 5 ? 5 : settings.notificationCount;
    set_x = cx - setting_length / 2;
    set_y = cy - (radius - (min_width + radius / 5));
    dc.setColor(settings.notificationCount ? Graphics.COLOR_DK_GREEN : settings.doNotDisturb ? Graphics.COLOR_DK_RED : Graphics.COLOR_DK_GRAY, Graphics.COLOR_BLACK);

    // dc.setClip(set_x, set_y, setting_length, setting_width);
    // dc.clear();

    if (settings.notificationCount || settings.doNotDisturb) {
      for(var i = 0; i < (settings.doNotDisturb ? 1 : settings.notificationCount); i++) {
        dc.fillRoundedRectangle(set_x + i * (setting_length / (settings.doNotDisturb ? 1 : settings.notificationCount)),
                                set_y,
                                (setting_length / (settings.doNotDisturb ? 1 : settings.notificationCount)) - setting_width / 2,
                                setting_width, radius / 16);
      }
    } else {
      dc.fillRoundedRectangle(set_x,
                              set_y,
                              setting_length - setting_width / 2,
                              settings.notificationCount ? setting_width : setting_width / 2,
                              radius / 16);
    }

    dc.setColor(settings.alarmCount ? Graphics.COLOR_RED : Graphics.COLOR_DK_GRAY, Graphics.COLOR_BLACK);
    set_x = cx - setting_length / 2;
    set_y = cy + (radius - (min_width + radius / 5));

    // dc.setClip(set_x, set_y, setting_length, setting_width);
    // dc.clear();
    if (settings.alarmCount) {
      for(var i = 0; i < settings.alarmCount; i++) {
        dc.fillRoundedRectangle(set_x + i * (setting_length / settings.alarmCount),
                                set_y,
                                setting_length / settings.alarmCount - setting_width / 2, radius / 16,
                                setting_width);
      }
    } else {
      dc.fillRoundedRectangle(set_x, set_y,
                              setting_length - setting_width / 2,
                              settings.alarmCount ? setting_width : setting_width / 2,
                              radius / 16);
    }

    // dc.clearClip();
  }

  function update_zones() {
    if (zones.size() == 0) {
      var zones_from_storage = Storage.getValue("zones");
      if (zones_from_storage == null) {
        zones = UserProfile.getHeartRateZones(UserProfile.HR_ZONE_SPORT_GENERIC);
        if (zones != null) {
          Storage.setValue("lock", true);
          Storage.setValue("zones", zones);
          Storage.setValue("lock", false);
        }
      } else {
        zones = zones_from_storage;
      }
    }
  }


  public function update_cached_loc() {
    var ai = Activity.getActivityInfo();
    if (ai != null) {
      if (ai.currentLocation != null) {
        var write_loc = false;
        var ai_loc = ai.currentLocation.toDegrees();
        var loc_from_storage = Storage.getValue("view_loc");
        if (loc_from_storage == null) {
          write_loc = true;
        } else {
          if (ai_loc[0] != loc_from_storage[0] or ai_loc[1] != loc_from_storage[1]) {
            write_loc = true;
          }
        }
        if (write_loc) {
          Storage.setValue("lock", true);
          Storage.setValue("view_loc", ai_loc);
          Storage.setValue("lock", false);
        }
      }
    }
  }

  public function onUpdate(dc) {
    var tdc;
    if (offb != null) {
      tdc = offb.getDc();
    } else {
      tdc = dc;
    }

    local_time = System.getClockTime();
    if (old_min != local_time.min) {
      update_zones();
      update_cached_loc();
      weather = Storage.getValue("weather");
      cache = Storage.getValue("cache");
      tdc.setColor(Graphics.COLOR_WHITE, Graphics.COLOR_BLACK);
      tdc.clear();
      draw_circular_things(tdc);
      var utc_time = Time.now().add(new Time.Duration(-local_time.timeZoneOffset + local_time.dst));
      draw_hands(tdc, local_time, Gregorian.info(utc_time, Time.FORMAT_MEDIUM));
      draw_time(tdc);
      draw_hr(tdc, get_hr());
      draw_settings(tdc, System.getDeviceSettings());

      if (weather != null) {
        if (weather.get("updated") != null) {
          var delta = Time.now().value() - weather["updated"];
          if (delta < 86400) {
            try {
              draw_sun(tdc);
              draw_city(tdc, delta);
              draw_meteo(tdc);
            } catch (e) {
            }
          }
        }
      }
      old_min = local_time.min;

    }
    if (offb != null) {
      dc.drawBitmap(0, 0, offb);
    }
    draw_sec(dc);
  }


  function onExitSleep() {
    WatchUi.requestUpdate();
  }

  /* function onEnterSleep() { */
  /* } */

}

class FunWatchDelegate extends WatchUi.WatchFaceDelegate {
  public function initialize() {
    WatchFaceDelegate.initialize();
  }

  public function onPowerBudgetExceeded(pi) {
    // System.println("Budget exceeded, average:" +
    //                pi.executionTimeAverage.format("%f"));
  }

}
