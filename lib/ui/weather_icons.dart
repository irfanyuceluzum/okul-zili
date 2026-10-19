import 'package:flutter/material.dart';

import 'theme.dart';

/// WMO hava durumu kodunun simgesi ve rengi (koyu pano zemini için).
(IconData, Color) weatherIcon(int code, {required bool isDay}) => switch (code) {
      0 => isDay ? (Icons.wb_sunny_rounded, AppColors.recess) : (Icons.nightlight_round, AppColors.panoTextSecondary),
      1 || 2 => (isDay ? Icons.wb_cloudy_outlined : Icons.nights_stay_outlined, AppColors.panoTextSecondary),
      3 => (Icons.cloud_rounded, AppColors.panoTextSecondary),
      45 || 48 => (Icons.foggy, AppColors.panoTextSecondary),
      51 || 53 || 55 || 56 || 57 || 61 || 63 || 65 || 66 || 67 || 80 || 81 || 82 =>
        (Icons.umbrella_rounded, AppColors.panoLesson),
      71 || 73 || 75 || 77 || 85 || 86 => (Icons.ac_unit_rounded, AppColors.panoText),
      95 || 96 || 99 => (Icons.thunderstorm_rounded, AppColors.recess),
      _ => (Icons.cloud_queue_rounded, AppColors.panoTextSecondary),
    };
