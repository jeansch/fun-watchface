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

class FunWatchView extends WatchUi.WatchFace {
  var data;

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

  var last_connected = false;
  var last_dnd = false;
  var last_alarm = false;
  var last_nc = 0;
  var last_hr = 0;

  var zones = null;

  public function initialize() {
    WatchFace.initialize();
  }


  public function onLayout(dc) {
    min_width = .5 * (dc.getHeight() / scale_factor);
    utc_width = min_width;
    utc_delta = .3 * dc.getHeight() / (scale_factor * 2);
    sec_width = .5 * utc_width;
    sec_delta = .5 * utc_delta;

    cx = dc.getWidth() / 2;
    cy = dc.getHeight() / 2;
    radius = cx < cy ? cx : cy;
    offb = new Graphics.BufferedBitmap({
        :width=>dc.getWidth(),
        :height=>dc.getHeight()});


    zones = UserProfile.getHeartRateZones(UserProfile.HR_ZONE_SPORT_GENERIC);
    if (zones != null) {
      Storage.setValue("zones", zones);
    }
    zones = Storage.getValue("zones");
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


  private function draw_hands(dc, ct, ut) {
    var tri;
    var ct24 = (((ct.hour % 24) * 60) + ct.min) / (24 * 60.0);
    dc.setColor(Graphics.COLOR_WHITE, Graphics.COLOR_TRANSPARENT);
    tri = triangle(cx, cy, Math.PI - ct24 * Math.PI * 2,
                   -utc_width + radius, utc_delta * (Math.PI / 180),
                   utc_width);
    dc.fillPolygon(tri);
    dc.setColor(Graphics.COLOR_BLACK, Graphics.COLOR_TRANSPARENT);
    dc.drawLine(tri[0][0], tri[0][1], tri[1][0], tri[1][1]);
    dc.drawLine(tri[1][0], tri[1][1], tri[2][0], tri[2][1]);
    dc.drawLine(tri[2][0], tri[2][1], tri[0][0], tri[0][1]);

    var utc = (((ut.hour % 24) * 60) + ut.min) / (24 * 60.0);
    dc.setColor(Graphics.COLOR_YELLOW, Graphics.COLOR_TRANSPARENT);
    tri = triangle(cx, cy, Math.PI - utc * Math.PI * 2,
                   -utc_width + radius, utc_delta * (Math.PI / 180),
                   utc_width);
    dc.fillPolygon(tri);
    dc.setPenWidth(2);
    dc.setColor(Graphics.COLOR_BLACK, Graphics.COLOR_TRANSPARENT);
    dc.drawLine(tri[0][0], tri[0][1], tri[1][0], tri[1][1]);
    dc.drawLine(tri[1][0], tri[1][1], tri[2][0], tri[2][1]);
    dc.drawLine(tri[2][0], tri[2][1], tri[0][0], tri[0][1]);

  }

  public function onPartialUpdate(dc) {
    if (null != offb) {
      dc.drawBitmap(0, 0, offb);
    }
    // Seconds
    var ct = System.getClockTime();
    var tri = triangle(cx, cy, Math.PI - (ct.sec / 60.0) * Math.PI * 2,
                       -1 * sec_width + radius, sec_delta * (Math.PI / 180),
                       sec_width);
    var clip = Utils.getBoundingBox(tri);
    var bw = clip[1][0] - clip[0][0] + 1;
    var bh = clip[1][1] - clip[0][1] + 1;
    dc.setClip(clip[0][0], clip[0][1], bw, bh);
    dc.setColor(last_connected ? Graphics.COLOR_BLUE: Graphics.COLOR_RED, Graphics.COLOR_TRANSPARENT);
    dc.fillPolygon(tri);

    var settings = System.getDeviceSettings();
    if ((last_connected != settings.phoneConnected) ||
        (last_dnd != settings.doNotDisturb) ||
        (last_alarm != settings.alarmCount) ||
        (last_nc != settings.notificationCount)) {
      draw_settings(dc);
    }
    if (zones != null) {
      if (last_hr != get_hr()) {
        draw_hr(dc);
      }
    }
  }


  private function draw_sun(dc) {
    var sun, a, ev;
    ev = data["computed"]["sunrise"];
    sun = (((ev[0] % 24) * 60) + ev[1]) / (24 * 60.0);
    dc.setColor(Graphics.COLOR_YELLOW, Graphics.COLOR_TRANSPARENT);
    a = Math.PI - sun * Math.PI * 2;
    dc.fillCircle(cx + (radius) * Math.sin(a),
                  cy + (radius) * Math.cos(a), min_width / 1.5);
    ev = data["computed"]["sunset"];
    sun = (((ev[0] % 24) * 60) + ev[1]) / (24 * 60.0);
    dc.setColor(Graphics.COLOR_ORANGE, Graphics.COLOR_TRANSPARENT);
    a = Math.PI - sun * Math.PI * 2;
    dc.fillCircle(cx + (radius) * Math.sin(a),
                  cy + (radius) * Math.cos(a), min_width / 1.5);
  }

  private function draw_city(dc, delta) {
    var txt = data["name"].substring(0, 12) + "(" + Utils.h_tdt(delta) + ")";
    dc.setColor(Graphics.COLOR_LT_GRAY, Graphics.COLOR_TRANSPARENT);
    dc.drawText(cx, cy + radius / 6, Graphics.FONT_TINY,
                txt,
                Graphics.TEXT_JUSTIFY_CENTER | Graphics.TEXT_JUSTIFY_VCENTER);
  }

  private function draw_meteo(dc) {
    var txt;
    dc.setColor(Graphics.COLOR_LT_GRAY, Graphics.COLOR_TRANSPARENT);
    data["computed"]["temp"] = 10;
    data["computed"]["dew"] = -12;
    txt = Lang.format("$1$/$2$ $3$", [data["computed"]["temp"].format("%d"),
                                          data["computed"]["dew"].format("%d"),
                                          data["computed"]["ingh"].format("%.02f")]);
    dc.drawText(cx, cy + 2 * radius / 6, Graphics.FONT_TINY,
                txt,
                Graphics.TEXT_JUSTIFY_CENTER | Graphics.TEXT_JUSTIFY_VCENTER);
    txt = Lang.format("$1$°$2$$3$",
                      [data["wind"]["deg"].format("%d"),
                       (data["wind"]["speed"] * 1.95652173913).format("%d"),
                       data["wind"].get("gust") ? "G" + (data["wind"]["gust"] * 1.95652173913).format("%d") : ""]);
    dc.drawText(cx, cy + 3 * radius / 6, Graphics.FONT_TINY,
                txt,
                Graphics.TEXT_JUSTIFY_CENTER | Graphics.TEXT_JUSTIFY_VCENTER);
  }



  private function draw_circular_things(dc) {
    var start, end, cos_a, sin_a, a;
    var bat_color = 0, bat;
    var i;
    bat = System.getSystemStats().battery;
    for (var h = 0; h <= (60 * 2 - 1); h += 1) {
      if (0 == h % 2) {
        i = h / 2;
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
        if (i <= 30) {
          bat_color = bat >= 40 ? Graphics.COLOR_GREEN : bat >= 20 ? Graphics.COLOR_YELLOW : Graphics.COLOR_RED;
          dc.setColor(i * 100 / 30 <= bat ? bat_color : Graphics.COLOR_DK_GRAY, Graphics.COLOR_TRANSPARENT);
          dc.setPenWidth(i * 100 / 30 <= bat ? 4: 1);
          start = radius - min_width - 1 * (radius / (scale_factor * 3));
          end = radius - min_width - 2 * (radius / (scale_factor * 3));
          dc.drawLine(cx + start * sin_a, cy + start * cos_a,
                      cx + end * sin_a , cy + end * cos_a);
        }
      }
      if (h % 5 == 0) {
        a = Math.PI - h / 120.0 * (2 * Math.PI);
        cos_a = Math.cos(a);
        sin_a = Math.sin(a);
        dc.setPenWidth(2);
        dc.setColor(Graphics.COLOR_YELLOW, Graphics.COLOR_TRANSPARENT);
        start = radius - (radius / (scale_factor * 3));
        end = radius - 2 * (radius / (scale_factor * 3));
        dc.drawLine(cx + start * sin_a, cy + start * cos_a,
                    cx + end * sin_a , cy + end * cos_a);
      }
    }
  }


  private function draw_time(dc) {
    dc.setColor(Graphics.COLOR_WHITE, Graphics.COLOR_TRANSPARENT);
    var now = Gregorian.info(Time.now(), Time.FORMAT_MEDIUM);
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

  public function draw_hr(dc) {
    var min = 0;
    var i;
    var max = 0;
    last_hr = get_hr();

    if ((last_hr > 0) && (zones.size() > 0)) {
      var hr_color = last_hr <= zones[1] ? Graphics.COLOR_LT_GRAY:
        last_hr > zones[1] && last_hr <= zones[2] ? Graphics.COLOR_BLUE:
        last_hr > zones[2] && last_hr <= zones[3] ? Graphics.COLOR_GREEN:
        last_hr > zones[3] && last_hr <= zones[4] ? Graphics.COLOR_YELLOW:
        Graphics.COLOR_RED;
      for (i = 0; i < zones.size() - 1; i++) {
        if (last_hr > zones[i]) {
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
        dc.setPenWidth(i + min <= last_hr ? 4: 1);
      dc.setColor(i + min <= last_hr ? (i + min < 50 ? Graphics.COLOR_DK_GRAY : hr_color) : Graphics.COLOR_DK_GRAY, Graphics.COLOR_TRANSPARENT);
        dc.drawLine(cx + start * sin_a, cy + start * cos_a,
                    cx + end * sin_a , cy + end * cos_a);
      }
    }
  }

  public function draw_settings(dc) {
    var set_x, set_y;
    var setting_width = radius / 16;
    var setting_length = radius / 3;
    var settings = System.getDeviceSettings();
    dc.setPenWidth(1);

    /* dc.setColor(settings.phoneConnected ? Graphics.COLOR_BLUE : Graphics.COLOR_DK_GRAY, */
    /*             Graphics.COLOR_BLACK); */
    /* set_x = cx - (radius - (min_width + radius / 4)); */
    /* set_y = cy - setting_length / 2 - setting_length / 4; */
    /* dc.setClip(set_x, set_y, setting_width, setting_length); */
    /* dc.clear(); */
    /* dc.fillRoundedRectangle(set_x, set_y, */
    /*                         settings.phoneConnected ? setting_width : setting_width / 2, */
    /*                         setting_length - setting_width / 2, */
    /*                         radius / 16); */


    settings.notificationCount = settings.notificationCount > 5 ? 5 : settings.notificationCount;
    set_x = cx - setting_length / 2;
    set_y = cy - (radius - (min_width + radius / 5));
    dc.setColor(settings.notificationCount ? Graphics.COLOR_DK_GREEN : settings.doNotDisturb ? Graphics.COLOR_DK_RED : Graphics.COLOR_DK_GRAY, Graphics.COLOR_BLACK);
    dc.setClip(set_x, set_y, setting_length, setting_width);
    dc.clear();

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
    dc.setClip(set_x, set_y, setting_length, setting_width);
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

    last_connected = settings.phoneConnected;
    last_dnd = settings.doNotDisturb;
    last_alarm = settings.alarmCount;
    last_nc = settings.notificationCount;
  }

  public function onUpdate(dc) {

    var tdc;
    if (offb != null) {
      dc.clearClip();
      tdc = offb.getDc();
    } else {
      tdc = dc;
    }

    zones = UserProfile.getHeartRateZones(UserProfile.HR_ZONE_SPORT_GENERIC);
    if (zones == null) {
      zones = Storage.getValue("zones");
    } else {
      zones = Storage.setValue("zones", zones);
    }


    data = Storage.getValue("data");
    var local_time = System.getClockTime();
    var utc_time = Time.now().add(new Time.Duration(-local_time.timeZoneOffset + local_time.dst));
    tdc.setColor(Graphics.COLOR_WHITE, Graphics.COLOR_BLACK);
    tdc.clear();

    if (data != null) {
      try {
        var delta = Time.now().value() - data["dt"];
        if (delta < 86400) {
          draw_sun(tdc);
          draw_city(tdc, delta);
          draw_meteo(tdc);
        }
      } catch (e) {
      }
    }
    draw_circular_things(tdc);
    draw_hands(tdc, local_time, Gregorian.info(utc_time, Time.FORMAT_MEDIUM));
    draw_time(tdc);

    zones = Storage.getValue("zones");
    if (zones != null) {
      draw_hr(tdc);
    }
    draw_settings(tdc);
    onPartialUpdate(dc);
  }


  function onExitSleep() {
    WatchUi.requestUpdate();
  }

  /* function onEnterSleep() { */
  /* } */

}

class FunWatchDelegate extends WatchUi.WatchFaceDelegate {
  public function initialize(view) {
    WatchFaceDelegate.initialize();
  }
}
