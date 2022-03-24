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

/* With the exception of getBoundingBox from Garmin Connect IQ SDK */

using Toybox.Time;


function int(x) {
  return x.toNumber();
}

class Utils {

  function ts_to_info(ts) {
    var ret = Time.Gregorian.moment({
        :year => 1970, :month=> 1, :day=> 1,
        :hour=> 0, :minute => 0, :second=> 0});
    ret = ret.add(new Time.Duration(ts));
    return Time.Gregorian.info(ret, Time.FORMAT_SHORT);
  }

  function h_tdt(delta) {
    return delta < 60 ? "<1m" :
      delta < 3600 ? (delta / 60).toNumber().format("%d") + "m" :
      (delta / 3600).toNumber().format("%d") + "h";
  }

  // From Garmin Connect IQ Sdk samples: Analog
  //! Compute a bounding box from the passed in points
  //! @param points Points to include in bounding box
  //! @return The bounding box points
  function getBoundingBox2(points, points2) {
    var min = [9999, 9999];
    var max = [0,0];

    for (var i = 0; i < points.size(); ++i) {
      if (points[i][0] < min[0]) {
        min[0] = points[i][0];
      }

      if (points[i][1] < min[1]) {
        min[1] = points[i][1];
      }

      if (points[i][0] > max[0]) {
        max[0] = points[i][0];
      }

      if (points[i][1] > max[1]) {
        max[1] = points[i][1];
      }
    }

    for (var i = 0; i < points2.size(); ++i) {
      if (points2[i][0] < min[0]) {
        min[0] = points2[i][0];
      }

      if (points2[i][1] < min[1]) {
        min[1] = points2[i][1];
      }

      if (points2[i][0] > max[0]) {
        max[0] = points2[i][0];
      }

      if (points2[i][1] > max[1]) {
        max[1] = points2[i][1];
      }
    }

    return [min, max];
  }

}
